#!/bin/bash
# triage.sh - prima passata di diagnosi su una macchina Linux. SOLA LETTURA: non tocca niente.
# Parte della skill sysadmin-thelinuxnerd. Una chiamata, tutto il quadro, niente dati grezzi.
# Uso:  triage.sh            quadro completo
#       triage.sh --ssh      solo la parte SSH / attacchi

set -u
# /usr/sbin non e' sempre nel PATH ( cron, sessioni non di login ): senza, sshd -T tace e ogni controllo sotto passa
PATH="$PATH:/usr/sbin:/sbin"
H() { printf '\n\033[1m=== %s ===\033[0m\n' "$1"; }
OGGI=$( LC_ALL=C date "+%b %e" )
SOLO_SSH=${1:-}

if [ "$SOLO_SSH" != "--ssh" ]; then
H "MACCHINA"
hostname; uptime; LC_ALL=C date
[ -r /etc/os-release ] || { [ -r /etc/debian_version ] && echo "Debian $( cat /etc/debian_version )"; }
[ -r /etc/os-release ] && ( . /etc/os-release; echo "$PRETTY_NAME   ( fine supporto: si guarda, SKILL.md punto 1 )" )

H "MEMORIA E CARICO"
free -m
echo "-- i 5 processi piu' pesanti --"
ps -eo pid,user,%mem,rss,comm --sort=-rss | head -6

H "DISCO"
df -h -x tmpfs -x devtmpfs 2>/dev/null | grep -v '^Filesystem\|^File' | sort -k5 -rn | head -5
echo "-- inode oltre l'80% --"
df -i -x tmpfs -x devtmpfs 2>/dev/null | awk 'NR>1 && $5+0 > 80 {print}' | head -3 || true

H "SERVIZI IN ASCOLTO SULL'ESTERNO"
ss -ltnp 2>/dev/null | grep -vE '127\.0\.0\.1|\[::1\]' | awk 'NR>1 {print $4"\t"$6}' | sed 's/users:(//; s/)$//' | cut -c1-110

H "UNITA' SYSTEMD IN ERRORE"
systemctl --failed --no-legend --no-pager 2>/dev/null | head -10 || echo "( nessuna )"

H "AGGIORNAMENTI ( SKILL.md, punto 3-bis: paranoia )"
ORA=$( date +%s )
eta() { [ -e "$1" ] && echo $(( ( ORA - $( stat -c %Y "$1" ) ) / 86400 )) || echo -1; }
if command -v apt-get >/dev/null 2>&1; then
  dpkg-query -W -f='${Status}' unattended-upgrades 2>/dev/null | grep -q 'ok installed' \
    || echo "⚠ unattended-upgrades NON installato: e' regola fissa, va messo"
  P=$( apt-config dump 2>/dev/null | grep -E '^APT::Periodic::(Update-Package-Lists|Unattended-Upgrade) ' )
  echo "${P:-( nessuna impostazione APT::Periodic )}"
  echo "$P" | grep -q 'Unattended-Upgrade "1"' || echo "⚠ APT::Periodic::Unattended-Upgrade non e' \"1\": installato ma spento"
  echo "$P" | grep -q 'Update-Package-Lists "1"' || echo "⚠ APT::Periodic::Update-Package-Lists non e' \"1\": le liste non si rinfrescano"
  printf 'apt-daily-upgrade.timer: %s\n' "$( systemctl is-enabled apt-daily-upgrade.timer 2>/dev/null; true )"
  L=/var/log/unattended-upgrades/unattended-upgrades.log
  G=$( eta "$L" )
  if [ "$G" -lt 0 ]; then echo "⚠ nessun log di unattended-upgrades: non ha mai girato"
  else
    echo "ultimo giro di unattended-upgrades: $G giorni fa"
    [ "$G" -ge 2 ] && echo "⚠ fermo da $G giorni: un controllo che tace e' un sintomo"
    E=$( tail -300 "$L" 2>/dev/null | grep -E 'ERROR|WARNING' | tail -3 )
    [ -n "$E" ] && echo "⚠ errori recenti nel log:" && echo "$E" | cut -c1-140
    # i pacchetti che scarta a ogni giro ( dipendenze, apt_preferences ): restano scoperti per sempre, in silenzio
    X=$( tail -300 "$L" 2>/dev/null | grep -E 'non viene aggiornato|not upgraded|will not be upgraded|kept back' | grep -oE '(Il pacchetto|[Pp]ackage) [^ ]+' | awk '{print $NF}' | sort -u | tr '\n' ' ' )
    [ -n "$X" ] && echo "⚠ scartati da unattended-upgrades a ogni giro ( vanno capiti, non ignorati ): $X"
  fi
  G=$( eta /var/lib/apt/periodic/update-success-stamp )
  [ "$G" -lt 0 ] && G=$( eta /var/lib/apt/lists/partial )
  echo "liste dei pacchetti rinfrescate: $G giorni fa"
  [ "$G" -ge 2 ] && echo "⚠ liste vecchie: il conteggio qui sotto non e' affidabile, apt-get update fallisce? ( SKILL.md 3-bis, punto 3 )"
  SIM=$( LC_ALL=C apt-get -s -o Debug::NoLocking=1 dist-upgrade 2>/dev/null | grep '^Inst ' )
  TOT=$( echo -n "$SIM" | grep -c . ); SEC=$( echo -n "$SIM" | grep -ci 'security' )
  echo "pendenti: $TOT    di sicurezza: $SEC"
  [ "$SEC" -gt 0 ] && echo "⚠ $SEC aggiornamenti di SICUREZZA pendenti: se il prossimo giro automatico non li prende ( o c'erano gia' al precedente ), si riferisce per primo" && echo "$SIM" | grep -i security | awk '{print "   "$2}' | head -8
  # "di sicurezza" vede solo la distribuzione: terze parti e blacklist non le aggiorna nessuno ( SKILL.md 3-bis, punto 4 )
  echo "$SIM" | sed -nE 's/^Inst [^ ]+ .*\([^ ]+ ([^ ]+).*/\1/p' | sort | uniq -c | sort -rn | head -5 | sed 's/^/   pendenti da: /'
  BL=$( apt-config dump 2>/dev/null | sed -n 's/^Unattended-Upgrade::Package-Blacklist:: "\(.*\)";/\1/p' | tr '\n' ' ' )
  [ -n "$BL" ] && echo "⚠ in blacklist, mai aggiornati da soli ( chi li aggiorna? /root/READ.md ): $BL"
  HOLD=$( apt-mark showhold 2>/dev/null )
  [ -n "$HOLD" ] && echo "pacchetti trattenuti ( ognuno ha il motivo in /root/READ.md? ): $( echo $HOLD )"
elif command -v dnf >/dev/null 2>&1; then
  printf 'dnf-automatic: %s\n' "$( systemctl is-enabled dnf-automatic.timer dnf-automatic-install.timer 2>/dev/null | tr '\n' ' '; true )"
  systemctl is-enabled dnf-automatic.timer dnf-automatic-install.timer 2>/dev/null | grep -q enabled \
    || echo "⚠ dnf-automatic NON attivo: e' regola fissa, va messo"
  SEC=$( dnf -C -q updateinfo list --security 2>/dev/null | grep -c . )
  echo "aggiornamenti di sicurezza pendenti ( dalla cache ): $SEC"
  [ "$SEC" -gt 0 ] && echo "⚠ $SEC aggiornamenti di SICUREZZA pendenti: si riferisce per primo"
fi
echo "-- installato ma non in uso --"
[ -e /var/run/reboot-required ] \
  && echo "⚠ riavvio pendente da $( eta /var/run/reboot-required ) giorni, per: $( tr '\n' ' ' < /var/run/reboot-required.pkgs 2>/dev/null | cut -c1-100 )"
K=$( ls -1 /boot/vmlinuz-* 2>/dev/null | sed 's|/boot/vmlinuz-||' | sort -V | tail -1 )
[ -n "$K" ] && [ "$K" != "$( uname -r )" ] && echo "⚠ kernel in esecuzione $( uname -r ), installato $K: serve un riavvio"
if command -v needrestart >/dev/null 2>&1; then
  NR=$( needrestart -b 2>/dev/null | sed -n 's/^NEEDRESTART-SVC: //p' )
  [ -n "$NR" ] && echo "⚠ servizi con librerie vecchie ( patch installata, non caricata ): $( echo $NR | cut -c1-200 )"
elif command -v needs-restarting >/dev/null 2>&1; then
  needs-restarting -r >/dev/null 2>&1 || echo "⚠ needs-restarting: serve un riavvio"
else
  echo "( needrestart non c'e': i servizi con librerie vecchie non si vedono, si installa )"
fi
echo "( fuori da apt/dnf - pannelli, WordPress, composer, docker - lo inventaria /root/READ.md, non questo script )"

H "ULTIMI ACCESSI RIUSCITI"
last -n 8 -F 2>/dev/null | head -8
fi

H "SSH: VOLUME ATTACCHI DI OGGI ( $OGGI )"
LOG=/var/log/auth.log
if [ -r "$LOG" ]; then
  TOT=$( grep -c "^$OGGI.*sshd" "$LOG" 2>/dev/null )
  IPS=$( grep "^$OGGI" "$LOG" 2>/dev/null | grep -oE 'from [0-9.]+' | sort -u | wc -l )
  echo "eventi sshd: $TOT    IP distinti: $IPS"
  echo "-- i 5 IP piu' insistenti --"
  grep "^$OGGI" "$LOG" 2>/dev/null | grep -oE 'from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | awk '{print $2}' | sort | uniq -c | sort -rn | head -5
  echo "-- login riusciti oggi --"
  grep "^$OGGI" "$LOG" 2>/dev/null | grep Accepted | awk '{print $9, $11}' | sort | uniq -c | sort -rn | head -5
  echo "-- riusciti NON-root negli ultimi log ( vuoto = bene ) --"
  grep Accepted "$LOG" 2>/dev/null | grep -v 'for root' | tail -3
else
  echo "$LOG non leggibile"
fi

H "SSH: QUANTO E' SATURA LA PORTA 22 ADESSO"
echo "connessioni sulla 22: $( ss -tn 2>/dev/null | grep -c ':22 ' )    processi sshd: $( pgrep -c sshd )"
echo "-- e quanto ne regge sshd prima di scartare --"
# con un blocco Match gli OpenSSH piu' vecchi rifiutano "sshd -T" senza una connessione di prova
sshdT() { sshd -T 2>/dev/null || sshd -T -C user=root,host=localhost,addr=127.0.0.1 2>/dev/null; }
sshdT >/dev/null || echo "⚠ sshd -T non risponde: i controlli SSH qui sotto NON sono stati fatti"
sshdT | grep -iE 'maxstartups|logingracetime|permitrootlogin|passwordauthentication|kbdinteractiveauthentication|^port '
sshdT | grep -qiE '^(passwordauthentication|kbdinteractiveauthentication) yes' \
  && echo "⚠ SSH accetta ancora le password: la regola e' solo chiave ( SKILL.md, punto 3 )"
K=$( grep -cE '^[^#]*(ssh-|ecdsa-|sk-)' /root/.ssh/authorized_keys 2>/dev/null ); K=${K:-0}
S=$( grep -E '^[^#]*(ssh-|ecdsa-|sk-)' /root/.ssh/authorized_keys 2>/dev/null | awk 'NF<3' | wc -l )
echo "chiavi autorizzate per root: $K    senza commento ( di chi sono? ): $S"

H "DIFESE"
printf 'fail2ban: %s   ' "$( systemctl is-active fail2ban 2>/dev/null; true )"
printf 'ufw: %s\n' "$( systemctl is-active ufw 2>/dev/null; true )"
systemctl is-active fail2ban >/dev/null 2>&1 || echo "⚠ fail2ban non attivo: va messo su ogni macchina esposta ( SKILL.md, punto 3 )"
if systemctl is-active fail2ban >/dev/null 2>&1; then
  for J in $( fail2ban-client status 2>/dev/null | sed -n 's/.*Jail list:\s*//p' | tr ',' ' ' ); do
    echo "-- jail $J --"
    fail2ban-client status "$J" 2>/dev/null | grep -E 'Currently banned|Total banned|Currently failed' | sed 's/^[ |`-]*//'
  done
fi
echo "-- regole iptables in INPUT --"
N=$( iptables -S INPUT 2>/dev/null | wc -l )
echo "$N regole ( policy: $( iptables -S INPUT 2>/dev/null | head -1 | awk '{print $3}' ) )"
[ "$N" -le 1 ] && echo "⚠ INPUT è vuoto: nessun filtro, tutto quello che ascolta è esposto"

H "COPIE CON LA DATA DOPO L'ESTENSIONE ( sfuggono ai glob, o ci finiscono dentro )"
B=$( find /etc -regextype posix-extended -type f -regex '.*\.(conf|sh|php|cnf|ini|local)\.(bak|old|orig|save|[0-9]{6,})[^/]*' 2>/dev/null )
echo "in /etc: $( echo -n "$B" | grep -c . )"; echo "$B" | head -5

H "MODIFICHE RECENTI IN /etc ( 7 giorni )"
find /etc -type f -mtime -7 2>/dev/null | grep -vE '/etc/(mtab|resolv.conf|adjtime|ld.so.cache)|/etc/letsencrypt/' | head -12
echo
echo "( sola lettura: niente e' stato modificato )"

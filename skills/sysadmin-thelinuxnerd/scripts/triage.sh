#!/bin/bash
# triage.sh - prima passata di diagnosi su una macchina Linux. SOLA LETTURA: non tocca niente.
# Parte della skill sysadmin-thelinuxnerd. Una chiamata, tutto il quadro, niente dati grezzi.
# Uso:  triage.sh            quadro completo
#       triage.sh --ssh      solo la parte SSH / attacchi

set -u
H() { printf '\n\033[1m=== %s ===\033[0m\n' "$1"; }
OGGI=$( LC_ALL=C date "+%b %e" )
SOLO_SSH=${1:-}

if [ "$SOLO_SSH" != "--ssh" ]; then
H "MACCHINA"
hostname; uptime; LC_ALL=C date
[ -r /etc/debian_version ] && echo "Debian $( cat /etc/debian_version )"

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
sshd -T 2>/dev/null | grep -iE 'maxstartups|logingracetime|permitrootlogin|passwordauthentication|kbdinteractiveauthentication|^port '
sshd -T 2>/dev/null | grep -qiE '^(passwordauthentication|kbdinteractiveauthentication) yes' \
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

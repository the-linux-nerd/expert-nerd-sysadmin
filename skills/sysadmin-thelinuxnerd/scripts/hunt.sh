#!/bin/bash
# hunt.sh - caccia agli impianti su una macchina Debian. SOLA LETTURA: non tocca, non uccide, non rimuove.
# Parte della skill sysadmin-thelinuxnerd ( references/intrusione.md, punto 4 ). Cerca le tecniche, non i nomi.
# Uso:  hunt.sh              i controlli veloci
#       hunt.sh --debsums    anche i binari di pacchetto alterati ( lento: minuti )
#
# L'appartenenza ai pacchetti si chiede a dpkg ADESSO, mai a una lista fotografata prima: una baseline
# congelata invecchia in ore e segnala come impianti gli strumenti installati dopo.
# ⚠ Il lsattr sulle directory di sistema fa scattare una regola auditd sulla LETTURA dei flag, se c'e':
# e' una regola sbagliata ( si audita la scrittura ), ma se esiste questo giro ingolfa audit.log.

set -u
PATH="$PATH:/usr/sbin:/sbin"
H() { printf '\n\033[1m=== %s ===\033[0m\n' "$1"; }
N() { echo -n "$1" | grep -c . ; }
TMP=$( mktemp -d ); trap 'rm -rf "$TMP"' EXIT

# --- quello che dpkg dichiara, letto adesso; usrmerge: /bin /sbin /lib* si normalizzano sotto /usr ---
norm() { sed -E 's#^/(bin|sbin|lib|lib32|lib64|libx32)/#/usr/\1/#'; }
{ cat /var/lib/dpkg/info/*.list; cat /var/lib/dpkg/diversions 2>/dev/null; } | norm | sort -u > "$TMP/pkg"
senza_pacchetto() { norm | sort -u | comm -23 - "$TMP/pkg"; }

H "MACCHINA"
hostname; LC_ALL=C date
[ -r /etc/os-release ] && . /etc/os-release && echo "${PRETTY_NAME:-?}"
echo "file dichiarati da dpkg: $( wc -l < "$TMP/pkg" )"

H "1. PROCESSI TRAVESTITI DA THREAD DEL KERNEL, O CON L'ESEGUIBILE CANCELLATO"
# un thread vero non ha exe e ha PPid 2; chi ha un exe e un nome da thread si sta travestendo
for p in /proc/[0-9]*; do
  pid=${p#/proc/}; [ "$pid" = "$$" ] && continue
  exe=$( readlink "$p/exe" 2>/dev/null ) || continue
  comm=$( cat "$p/comm" 2>/dev/null ); ppid=$( awk '/^PPid/ {print $2}' "$p/status" 2>/dev/null )
  if echo "$comm" | grep -qE '^(kworker|kthreadd|ksoftirqd|kswapd|migration|watchdog|rcu_|jbd2|irq/|cpuhp|khugepaged|kcompactd)'; then
    echo "⚠ pid $pid '$comm' ha un eseguibile ( $exe ) e PPid $ppid: un thread del kernel non ne ha"
  fi
  case "$exe" in *" (deleted)")
    echo "eseguibile cancellato: pid $pid '$comm' -> $exe" ;; esac
done | head -20 > "$TMP/proc"
[ -s "$TMP/proc" ] && cat "$TMP/proc" || echo "( nessuno )"
echo "( un 'cancellato' e' anche un servizio non riavviato dopo un aggiornamento: si guarda il nome )"

H "2. FILE IMMUTABILI NELLE DIRECTORY DI SISTEMA ( chattr +i: la rimozione fallisce )"
find /etc /usr/bin /usr/sbin /usr/lib /usr/libexec /usr/local /root /var/spool/cron /tmp /var/tmp /dev/shm \
     -xdev -maxdepth 3 -type f -print0 2>/dev/null | xargs -0 -r lsattr 2>/dev/null | awk '$1 ~ /i/' > "$TMP/imm"
echo "trovati: $( wc -l < "$TMP/imm" )"; head -10 "$TMP/imm"

H "3. GENERATORI SYSTEMD SENZA PACCHETTO ( girano a ogni boot, prima di tutto )"
find /etc/systemd/system-generators /etc/systemd/user-generators /usr/local/lib/systemd \
     /usr/lib/systemd/system-generators /usr/lib/systemd/user-generators \
     /lib/systemd/system-generators /lib/systemd/user-generators /run/systemd/system-generators \
     -type f 2>/dev/null | senza_pacchetto > "$TMP/gen"
echo "trovati: $( wc -l < "$TMP/gen" )"; head -10 "$TMP/gen"

H "4. REGOLE UDEV E UNITA' SYSTEMD SENZA PACCHETTO ( le altre vie di resurrezione )"
find /etc/udev/rules.d /usr/lib/udev/rules.d /lib/udev/rules.d /run/udev/rules.d -type f 2>/dev/null \
  | senza_pacchetto > "$TMP/udev"
echo "-- udev: $( wc -l < "$TMP/udev" )"; head -8 "$TMP/udev"
find /etc/systemd/system /usr/lib/systemd/system /lib/systemd/system -type f \
     \( -name '*.service' -o -name '*.timer' -o -name '*.path' -o -name '*.socket' \) 2>/dev/null \
  | senza_pacchetto > "$TMP/unit"
echo "-- unita' systemd: $( wc -l < "$TMP/unit" )  ( per ognuna: stat, e cosa lancia )"
while read -r u; do
  printf '%s  ctime %s  -> %s\n' "$u" "$( stat -c %z "$u" | cut -c1-10 )" \
    "$( grep -hE '^(ExecStart|Unit|OnCalendar)=' "$u" | head -2 | tr '\n' ' ' | cut -c1-90 )"
done < <( head -15 "$TMP/unit" )
echo "-- cron fuori dai pacchetti --"
find /etc/cron.d /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly -type f 2>/dev/null \
  | senza_pacchetto | head -10
ls /var/spool/cron/crontabs/ 2>/dev/null | sed 's/^/crontab utente: /'

H "5. ESEGUIBILI NELLE DIRECTORY DI SISTEMA SENZA PACCHETTO ( il controllo che rende di piu' )"
find /usr/bin /usr/sbin /usr/libexec /usr/lib/systemd /bin /sbin -xdev -type f 2>/dev/null > "$TMP/cand"
find /usr/lib /lib -xdev -maxdepth 2 -type f \( -perm /111 -o -name '*.so*' \) 2>/dev/null >> "$TMP/cand"
senza_pacchetto < "$TMP/cand" > "$TMP/orfani"
echo "trovati: $( wc -l < "$TMP/orfani" )   per directory:"
xargs -r -d '\n' dirname < "$TMP/orfani" | sort | uniq -c | sort -rn | head -6
# dpkg da' a ogni file l'mtime della build, quindi mtime < ctime e' normale sui file di pacchetto;
# su questi no: un mtime di mesi prima del ctime e' una data scritta a mano
echo "-- i piu' recenti per ctime ( il ctime non si falsifica con touch ) --"
xargs -r -d '\n' stat -c '%Z %Y %s %n' < "$TMP/orfani" | sort -rn | head -25 \
  | while read -r c m s f; do
      tag=""; [ $(( c - m )) -gt 2592000 ] && tag="  ⚠ mtime $(( (c - m) / 86400 )) giorni prima del ctime"
      printf '%s  ctime %s  %s byte%s\n' "$f" "$( date -d "@$c" +%F )" "$s" "$tag"
    done

H "6. FILE IN /dev/shm ( li' non ci vive niente di lungo, tanto meno nascosto )"
find /dev/shm -mindepth 1 2>/dev/null | head -10 | while read -r f; do ls -la "$f" | cut -c1-120; done
[ -z "$( find /dev/shm -mindepth 1 2>/dev/null | head -1 )" ] && echo "( vuota )"

H "7. CONNESSIONI IN USCITA, CON IL PROCESSO CHE LE APRE"
# un IP da solo non e' un indicatore: si fotografa il processo, si grida solo con un secondo indizio
echo "-- tentativi in corso ( SYN-SENT: verso un indirizzo bloccato in uscita e' rumore atteso ) --"
ss -tnp state syn-sent 2>/dev/null | awk 'NR>1 {print $4, $5}' | head -8
echo "-- stabilite verso fuori, per processo --"
ss -tnp state established 2>/dev/null | awk 'NR>1' | grep -vE '127\.0\.0\.1|\[::1\]' \
  | grep -oE 'pid=[0-9]+' | sort | uniq -c | sort -rn | head -8 | while read -r n p; do
    pid=${p#pid=}; exe=$( readlink "/proc/$pid/exe" 2>/dev/null )
    tag=""; echo "$exe" | norm | grep -qxFf - "$TMP/pkg" || tag="  ⚠ eseguibile senza pacchetto"
    printf '%4s  pid %-7s %s%s\n' "$n" "$pid" "${exe:-?}" "$tag"
  done

H "INVARIANTI DI PRIVILEGIO ( si sorvegliano, non si sistemano una volta )"
echo "UID 0 oltre a root: $( awk -F: '$3==0 && $1!="root" {print $1}' /etc/passwd | tr '\n' ' ' )"
echo "-- NOPASSWD in sudoers --"
grep -rhE '^[^#]*NOPASSWD' /etc/sudoers /etc/sudoers.d/ 2>/dev/null | cut -c1-110 | head -8
[ -s /etc/ld.so.preload ] && echo "⚠ /etc/ld.so.preload non e' vuoto: $( cat /etc/ld.so.preload )"
echo "-- auto_prepend_file / auto_append_file valorizzati ( infettano tutti i siti senza toccarne un file ) --"
grep -rHE '^\s*(php_admin_value\[)?auto_(prepend|append)_file\]?\s*=\s*[^; ]' /etc/php* /opt/*/etc 2>/dev/null \
  | cut -c1-140 | head -8

if [ "${1:-}" = "--debsums" ]; then
  H "BINARI DI PACCHETTO ALTERATI ( debsums )"
  if command -v debsums >/dev/null; then debsums -s 2>&1 | head -20
  else echo "debsums non installato"; fi
fi
echo
echo "( sola lettura: niente e' stato modificato. Prima di toccare qualcosa: references/intrusione.md, punto 6 )"

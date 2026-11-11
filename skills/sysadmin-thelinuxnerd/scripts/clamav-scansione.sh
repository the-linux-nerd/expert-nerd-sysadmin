#!/bin/bash
# 11/11/2026, decisione di Fabio: scansione ClamAV periodica di /var/www su ogni macchina.
# Incrementale: ogni notte i file con ctime negli ultimi 2 giorni ( il ctime non si falsifica con
# touch ), la prima domenica del mese tutto ( su un web server: 1,5 milioni di file ). Si salta se la memoria non basta: clamscan carica ~1 GB di firme.
# Stampa solo i riscontri e gli errori: l'output del cron va a root. Non sposta niente: la
# quarantena la decide una persona.
set -o pipefail
DIR=/var/log/clamav-scansione; mkdir -p "$DIR"; D=$(date +%Y%m%d-%H%M); LOG=$DIR/$D.log
LISTA=$(mktemp); trap 'rm -f "$LISTA"' EXIT
exec 9>/var/lock/clamav-scansione.lock; flock -n 9 || exit 0
find /var/log/clamav-scansione -name '*.log' -mtime +60 -delete
DISP=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)
if [ "$DISP" -lt 1500 ]; then echo "ATTENZIONE clamav-scansione: saltata, $DISP MB disponibili ( servono 1500 )" | tee "$LOG"; exit 1; fi
find /var/lib/clamav/daily.cvd -mtime -3 2>/dev/null | grep -q . || { echo "ATTENZIONE clamav-scansione: firme vecchie o assenti in /var/lib/clamav" | tee "$LOG"; exit 1; }
# fuori: le copie fatte da noi ( backups, disallineamenti, storico ), i repository, i log
ESCL='/(backups|disallineamenti|storico-file-progetto|\.git|node_modules)/|/var/log/|\.log$'
if { [ "$(date +%u)" = 7 ] && [ "$(date +%-d)" -le 7 ]; } || [ "$1" = tutto ]; then GIRO=completo; find /var/www -xdev -type f -size -50M 2>/dev/null
else GIRO=incrementale; find /var/www -xdev -type f -cmin -2900 -size -50M 2>/dev/null; fi | grep -Ev "$ESCL" > "$LISTA"
N=$(wc -l < "$LISTA")
echo "$(date '+%F %T') giro $GIRO, $N file" >> "$LOG"
[ "$N" -eq 0 ] && exit 0
nice -n 19 ionice -c3 clamscan --infected --no-summary --max-filesize=50M --max-scansize=200M --file-list="$LISTA" >> "$LOG" 2>&1
R=$?
echo "$(date '+%F %T') fine, codice $R" >> "$LOG"
if [ $R -eq 1 ]; then
  echo "ATTENZIONE clamav-scansione su $(hostname): file riconosciuti ( giro $GIRO, $N file ), $LOG:"; grep 'FOUND$' "$LOG"; exit 1
elif [ $R -ne 0 ]; then
  echo "ATTENZIONE clamav-scansione su $(hostname): clamscan uscito con $R, ultime righe di $LOG:"; tail -15 "$LOG"; exit 1
fi
exit 0

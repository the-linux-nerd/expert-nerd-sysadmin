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
# solo quello che si esegue o si serve come codice: immagini, pdf e media triplicano i file e il
# tempo ( misurato l'11/11/2026 su un web server: 400 mila file in 2 giorni, 190 mila immagini;
# clamscan fa ~3 file/s sui file misti e ~43 sui php ). Un'immagine con dentro una webshell e'
# pericolosa solo con un'estensione eseguibile, e quella e' qui.
CODICE='\.(php[0-9]?|phtml|phar|inc|js|mjs|html?|svg|sh|py|pl|cgi|asp|aspx|jsp)$|/\.(htaccess|user\.ini)$|/[^./]+$'
# GIRO si decide fuori dalla pipe: dentro sarebbe un sottoprocesso, e il valore si perderebbe
GIRO=incrementale; { [ "$(date +%u)" = 7 ] && [ "$(date +%-d)" -le 7 ]; } && GIRO=completo; [ "$1" = tutto ] && GIRO=completo
if [ $GIRO = completo ]; then find /var/www -xdev -type f -size -50M 2>/dev/null
else find /var/www -xdev -type f -cmin -2900 -size -50M 2>/dev/null; fi | grep -Ev "$ESCL" | grep -Ei "$CODICE" > "$LISTA"
N=$(wc -l < "$LISTA")
echo "$(date '+%F %T') giro $GIRO, $N file" >> "$LOG"
[ "$N" -eq 0 ] && exit 0
timeout 5h nice -n 19 ionice -c3 clamscan --infected --no-summary --max-filesize=50M --max-scansize=200M --file-list="$LISTA" >> "$LOG" 2>&1
R=$?
echo "$(date '+%F %T') fine, codice $R" >> "$LOG"
if [ $R -eq 1 ]; then
  echo "ATTENZIONE clamav-scansione su $(hostname): file riconosciuti ( giro $GIRO, $N file ), $LOG:"; grep 'FOUND$' "$LOG"; exit 1
elif [ $R -eq 124 ]; then
  echo "ATTENZIONE clamav-scansione su $(hostname): fermata dopo 5 ore ( giro $GIRO, $N file ), il resto non e' stato guardato"; exit 1
elif [ $R -ne 0 ]; then
  echo "ATTENZIONE clamav-scansione su $(hostname): clamscan uscito con $R, ultime righe di $LOG:"; tail -15 "$LOG"; exit 1
fi
exit 0

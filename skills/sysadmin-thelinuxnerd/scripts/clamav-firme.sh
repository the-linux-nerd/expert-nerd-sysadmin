#!/bin/bash
# 11/11/2026, decisione di Fabio: il freshclam 0.103 di buster e' bloccato dal CDN di ClamAV
# ( "Forbidden; Blocked by CDN" dal 03/11/2026 ). Le firme le scarica cvdupdate, lo strumento
# ufficiale di ClamAV per i mirror, e qui si copiano in /var/lib/clamav dopo averle verificate.
# Da togliere con la migrazione a una Debian con ClamAV 1.x ( freshclam torna a funzionare ).
# Stampa solo in caso di errore: l'output del cron va a root.
set -o pipefail
B=/var/lib/cvdupdate; DB=$B/db; DEST=/var/lib/clamav; LOG=/var/log/clamav-firme.log
export HOME=$B PYTHONPATH=$(ls /opt/cvdupdate/wheels/*.whl | paste -sd:)
exec 9>/var/lock/clamav-firme.lock; flock -n 9 || exit 0
mkdir -p "$DB"
[ -s "$B/.cvdupdate/config.json" ] || python3 -m cvdupdate config set --dbdir "$DB" --logdir "$B/log" >>"$LOG" 2>&1
if ! python3 -m cvdupdate update >>"$LOG" 2>&1; then
  echo "ATTENZIONE clamav-firme: cvdupdate fallito, ultime righe di $LOG:"; tail -20 "$LOG"; exit 1
fi
E=0
for f in main daily bytecode; do
  if ! sigtool --info "$DB/$f.cvd" 2>&1 | grep -q 'Verification OK'; then
    echo "ATTENZIONE clamav-firme: $f.cvd non verificato da sigtool"; E=1; continue
  fi
  cmp -s "$DB/$f.cvd" "$DEST/$f.cvd" && continue
  install -o clamav -g clamav -m 644 "$DB/$f.cvd" "$DEST/.$f.cvd.nuovo" && mv -f "$DEST/.$f.cvd.nuovo" "$DEST/$f.cvd"
  echo "$(date '+%F %T') $f.cvd aggiornato: $(sigtool --info "$DEST/$f.cvd" | awk '/^Version/{print $2}')" >>"$LOG"
done
# le firme in /var/lib/clamav non devono avere piu' di 3 giorni
find "$DEST/daily.cvd" -mtime -3 2>/dev/null | grep -q . || { echo "ATTENZIONE clamav-firme: daily.cvd piu' vecchio di 3 giorni"; E=1; }
exit $E

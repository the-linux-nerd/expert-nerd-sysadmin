#!/bin/bash
# Installa la skill TheLinuxNerd e le sue risorse nel ~/.claude di questa macchina.
# Idempotente: si puo' rilanciare dopo ogni "git pull".
# Uso:  ./install.sh            installa
#       ./install.sh --dry-run  dice solo cosa farebbe

set -u
CD=$( cd "$( dirname "$0" )" && pwd )
DEST="$HOME/.claude"
DATA=$( date +%Y%m%d )
BAK="$DEST/backups/$DATA-thelinuxnerd"
DRY=${1:-}
n=0

fai() {
  if [ "$DRY" = "--dry-run" ]; then echo "  [dry-run] $*"; else eval "$@"; fi
  n=$(( n + 1 ))
}

# Copia un file mettendo da parte quello vecchio solo se e' diverso: niente backup inutili.
metti() {
  local sorgente="$1" destinazione="$2"
  if [ -f "$destinazione" ] && cmp -s "$sorgente" "$destinazione"; then
    echo "  = $destinazione ( gia' aggiornato )"
    return
  fi
  if [ -f "$destinazione" ]; then
    # La data va nel nome della cartella, non dopo l'estensione: "todo.py.bak-20260923" non e'
    # piu' un .py, e "x.conf.bak-..." sfugge a ogni glob "*.conf" ( o ci finisce dentro ).
    local copia="$BAK/${destinazione#$DEST/}"
    echo "  ~ $destinazione ( il precedente va in $copia )"
    fai "mkdir -p '$( dirname "$copia" )'"
    # -n: rilanciato due volte nello stesso giorno, la prima copia ( l'originale vero ) resta
    fai "cp -an '$destinazione' '$copia'"
  else
    echo "  + $destinazione"
  fi
  fai "mkdir -p '$( dirname "$destinazione" )'"
  fai "cp -a '$sorgente' '$destinazione'"
}

echo "== skill =="
for s in "$CD"/skills/*/; do
  nome=$( basename "$s" )
  while IFS= read -r f; do
    rel=${f#$s}
    metti "$f" "$DEST/skills/$nome/$rel"
  done < <( find "$s" -type f )
done

echo "== bin =="
for f in "$CD"/bin/*; do
  metti "$f" "$DEST/bin/$( basename "$f" )"
  fai "chmod +x '$DEST/bin/$( basename "$f" )'"
done

echo "== memoria =="
# Le memorie del metodo si chiamano nerd-*.md: vivono nel repo e si modificano solo li'.
# Tutte le altre sono della macchina: install.sh non le legge e non le tocca.
# I server sono sessioni aperte come root da /root, quindi il progetto e' "-root".
MEM="$DEST/projects/-root/memory"
if [ -d "$MEM" ]; then
  for f in "$CD"/memory/nerd-*.md; do
    b=$( basename "$f" ); vecchio=${b#nerd-}
    # migrazione una tantum: la copia installata prima del prefisso, se e' la stessa, va nel backup
    if [ -f "$MEM/$vecchio" ] && [ ! -f "$MEM/$b" ]; then
      if sed 's/^name: nerd-/name: /; s/\[\[nerd-/[[/g' "$f" | cmp -s - "$MEM/$vecchio"; then
        echo "  > $vecchio diventa $b ( la vecchia va in $BAK/ )"
        fai "mkdir -p '$BAK/projects/-root/memory'"
        fai "cp -an '$MEM/MEMORY.md' '$BAK/projects/-root/memory/MEMORY.md'"
        fai "mv '$MEM/$vecchio' '$BAK/projects/-root/memory/$vecchio'"
        fai "sed -i 's#($vecchio)#($b)#' '$MEM/MEMORY.md'"
      else
        echo "  ⚠ $MEM/$vecchio e' stata modificata qui: non la migro, e $b non la installo accanto."
        echo "    Le modifiche che valgono per il metodo vanno nel repo; poi si toglie la vecchia e si rilancia."
        continue
      fi
    elif [ -f "$MEM/$b" ] && ! cmp -s "$f" "$MEM/$b"; then
      echo "  ⚠ $b e' diversa da quella del repo: le memorie nerd- si modificano nel repo, non qui."
      echo "    Vince il repo; la versione locale resta nel backup."
    fi
    metti "$f" "$MEM/$b"
    titolo=$( sed -n 's/^description: *//p' "$f" | head -1 )
    if ! grep -q "($b)" "$MEM/MEMORY.md" 2>/dev/null; then
      echo "  + riga in MEMORY.md per $b"
      fai "printf -- '- [%s](%s) — %s\n' \"\${b%.md}\" \"$b\" \"$titolo\" >> '$MEM/MEMORY.md'"
    fi
  done
  # quelle che il repo non ha piu': si segnalano, non si cancellano
  for f in "$MEM"/nerd-*.md; do
    [ -e "$f" ] && [ ! -f "$CD/memory/$( basename "$f" )" ] \
      && echo "  ? $f non e' piu' nel repo: se e' il caso si toglie a mano, con la sua riga in MEMORY.md"
  done
else
  echo "  ( $MEM non esiste: la memoria si installa da sola alla prima sessione, rilancia dopo )"
fi

echo "== hook anti-segreti del repository =="
if [ -d "$CD/.git" ]; then
  fai "git -C '$CD' config core.hooksPath .githooks"
  echo "  + pre-commit attivo"
else
  echo "  ( non e' un clone git: hook saltato )"
fi

echo
[ "$DRY" = "--dry-run" ] && echo "dry-run: $n operazioni NON eseguite" || echo "fatto: $n operazioni"
echo "Verifica:  ls $DEST/skills/  &&  $DEST/bin/todo.py -c"

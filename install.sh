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
  # solo se serve: un chmod rifatto a ogni giro gonfia il conteggio delle operazioni
  [ -x "$DEST/bin/$( basename "$f" )" ] || fai "chmod +x '$DEST/bin/$( basename "$f" )'"
done

echo "== cron =="
# I cron del metodo ( cron/ ) vanno in /etc/cron.d, ma solo da root e solo su Debian: i tracker
# delle CVE sono quelli di Debian. Il precedente, se diverso, va in /var/backups/<data>-thelinuxnerd/.
if [ "$( id -u )" -eq 0 ] && [ -d /etc/cron.d ] && grep -qx 'ID=debian' /etc/os-release 2>/dev/null; then
  for f in "$CD"/cron/*; do
    [ -f "$f" ] || continue
    d="/etc/cron.d/$( basename "$f" )"
    if [ -f "$d" ] && cmp -s "$f" "$d"; then
      echo "  = $d ( gia' aggiornato )"
      continue
    fi
    if [ -f "$d" ]; then
      echo "  ~ $d ( il precedente va in /var/backups/$DATA-thelinuxnerd/ )"
      fai "mkdir -p '/var/backups/$DATA-thelinuxnerd' && cp -an '$d' '/var/backups/$DATA-thelinuxnerd/'"
    else
      echo "  + $d"
    fi
    # cron.d vuole root:root e niente scrittura per altri, se no il file si ignora in silenzio
    fai "install -o root -g root -m 0644 '$f' '$d'"
  done
else
  echo "  ( non root o non Debian: cron saltati )"
fi

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
      # la riga si compone fuori da eval: una description con le virgolette la spezzerebbe
      riga=$( printf -- '- [%s](%s) — %s' "${b%.md}" "$b" "$titolo" )
      fai "printf '%s\n' \"\$riga\" >> '$MEM/MEMORY.md'"
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

echo "== hook di sessione =="
# Registra in settings.json un hook di SessionStart, una volta sola ( si riconosce dal nome dello script ).
registra_hook() {
  local cmd="$1" segno="$2" timeout="$3"
  local SET="$DEST/settings.json"
  if [ -f "$SET" ] && grep -qF "$segno" "$SET"; then
    echo "  = SessionStart $segno ( gia' registrato )"
    return
  fi
  echo "  + SessionStart: $cmd"
  if [ -f "$SET" ]; then
    fai "mkdir -p '$BAK' && cp -an '$SET' '$BAK/settings.json'"
  fi
  fai "python3 - '$SET' '$cmd' '$timeout' <<'PY'
import json, os, sys
p, cmd, t = sys.argv[1], sys.argv[2], int(sys.argv[3])
d = json.load(open(p)) if os.path.exists(p) else {}
d.setdefault('hooks', {}).setdefault('SessionStart', []).append({'hooks': [{'type': 'command', 'command': cmd, 'timeout': t}]})
json.dump(d, open(p + '.nuovo', 'w'), indent=2, ensure_ascii=False)
os.replace(p + '.nuovo', p)
PY"
}
# la skill si aggiorna da sola dal repository, una volta al giorno ( SKILL.md, «Prima di cominciare» )
registra_hook "bash $DEST/bin/nerd-aggiorna.sh hook $CD" "nerd-aggiorna.sh hook" 90
# i pendenti che unattended-upgrades non fa: blacklist, hold, terze parti ( SKILL.md 3-bis, punto 4 )
registra_hook "bash $DEST/bin/nerd-esclusi.sh hook" "nerd-esclusi.sh hook" 30

echo "== hook anti-segreti del repository =="
if [ -d "$CD/.git" ]; then
  if [ "$( git -C "$CD" config --get core.hooksPath )" = ".githooks" ]; then
    echo "  = pre-commit ( gia' attivo )"
  else
    echo "  + pre-commit attivo"
    fai "git -C '$CD' config core.hooksPath .githooks"
  fi
else
  echo "  ( non e' un clone git: hook saltato )"
fi

echo
[ "$DRY" = "--dry-run" ] && echo "dry-run: $n operazioni NON eseguite" || echo "fatto: $n operazioni"
echo "Verifica:  ls $DEST/skills/  &&  $DEST/bin/todo.py -c"

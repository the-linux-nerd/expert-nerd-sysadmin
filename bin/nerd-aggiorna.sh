#!/bin/bash
# nerd-aggiorna.sh — la skill si aggiorna da sola dal repository
#
# NOTA
# Il metodo cresce nel repository, non sulla macchina: una copia installata un mese fa lavora con
# le regole di un mese fa. La regola "all'inizio di ogni lavoro si guarda il repo" non bastava:
# il 04/11/2026 web02 e web03 erano indietro di 7 commit, cloudpanel01 di 6, e la copia installata
# di web02 non era nemmeno quella del suo clone. Quindi lo fa un hook di SessionStart, una volta
# al giorno, e lo registra install.sh ( SKILL.md, «Prima di cominciare: la skill si aggiorna da sola» ).
#
# UTILIZZO
# nerd-aggiorna.sh [tutto] [CLONE]   controlla adesso e dice com'e' andata
# nerd-aggiorna.sh hook [CLONE]      per il SessionStart: al massimo una volta ogni 24 ore, muto se non c'e' niente
#
# Si aggiorna solo con un fast-forward su un clone pulito. Commit locali, modifiche o storia
# divergente non si toccano: si dice cosa fare ( le lezioni vanno al generale come patch ).

# Tutto fra graffe: bash legge lo script mentre lo esegue, e install.sh sovrascrive proprio
# questo file in ~/.claude/bin; cosi' e' gia' tutto letto prima di cominciare.
{
MODO=${1:-tutto}
R=${2:-$HOME/thelinuxnerd}
STAMP="${HOME:?}/.claude/.thelinuxnerd-controllo"
SKILL=sysadmin-thelinuxnerd

[ "$MODO" = "hook" ] && [ -n "$( find "$STAMP" -mmin -1440 2>/dev/null )" ] && exit 0

if [ ! -d "$R/.git" ]; then
  echo "⚠ skill $SKILL: il clone $R non c'e'. Si installa con: git clone https://github.com/the-linux-nerd/expert-nerd-sysadmin.git $R && cd $R && ./install.sh"
  exit 0
fi

# lo stamp si tocca solo a controllo riuscito: senza rete si riprova alla sessione dopo
if ! timeout 30 git -C "$R" fetch -q origin 2>/dev/null; then
  [ "$MODO" != "hook" ] && echo "skill $SKILL: fetch fallito ( rete o GitHub ), riprovo alla prossima sessione"
  exit 0
fi
touch "$STAMP"

if ! AB=$( git -C "$R" rev-list --left-right --count HEAD...@{u} 2>/dev/null ); then
  echo "⚠ skill $SKILL: il branch di $R non ha un upstream, non so se e' aggiornato"
  exit 0
fi
read -r A B <<< "$AB"
SPORCHI=$( git -C "$R" status --porcelain | grep -c . )
PRIMA=$( git -C "$R" rev-parse --short HEAD )

if [ "$B" -gt 0 ]; then
  if [ "$A" -eq 0 ] && [ "$SPORCHI" -eq 0 ]; then
    LOG=$( git -C "$R" log --format='   %h %s' HEAD..@{u} | head -8 )
    if git -C "$R" pull -q --ff-only && ( cd "$R" && ./install.sh >/dev/null 2>&1 ); then
      echo "skill $SKILL aggiornata da $PRIMA a $( git -C "$R" rev-parse --short HEAD ) ( $B commit ):"
      echo "$LOG"
      echo "→ Dillo al sistemista in una riga, coi titoli. Se la skill era gia' in contesto, si rilegge ~/.claude/skills/$SKILL/SKILL.md."
    else
      echo "⚠ skill $SKILL: pull o install.sh falliti in $R ( era a $PRIMA, origin ha $B commit in piu' ): si lavora con la versione installata e si avvisa il generale"
    fi
  else
    echo "⚠ skill $SKILL indietro di $B commit, ma il clone $R ha $A commit locali e $SPORCHI file modificati: niente pull, niente reset."
    echo "→ I commit locali vanno al generale come patch ( git -C $R format-patch --stdout @{u} | claude-posta.py manda --a generale ); quando sono in origin, git -C $R reset --hard @{u} e ./install.sh"
  fi
  exit 0
fi

if [ "$A" -gt 0 ]; then
  echo "⚠ skill $SKILL: $A commit locali in $R non ancora in origin. Vanno al generale come patch ( git -C $R format-patch --stdout @{u} ), poi git reset --hard @{u} quando il generale li ha pushati."
fi

# clone aggiornato ma copia installata diversa: install.sh non e' stato rilanciato dopo un pull
# si confrontano solo i file del clone: quelli in piu' nella copia installata ( un SKILL.md.bak-* su
# web02 ) install.sh non li toglie, e con diff -r si rilancerebbe ogni giorno dicendo "riallineata"
DIVERSI=$( cd "$R/skills/$SKILL" && find . -type f | while read -r f; do cmp -s "$f" "$HOME/.claude/skills/$SKILL/$f" || echo "$f"; done | grep -c . )
if [ "$A" -eq 0 ] && [ "$SPORCHI" -eq 0 ] && [ "$DIVERSI" -gt 0 ]; then
  if ( cd "$R" && ./install.sh >/dev/null 2>&1 ); then
    echo "skill $SKILL: la copia installata non era quella del clone ( $PRIMA ), riallineata con install.sh"
  else
    echo "⚠ skill $SKILL: la copia installata non e' quella del clone ( $PRIMA ) e install.sh e' fallito"
  fi
  exit 0
fi

[ "$MODO" != "hook" ] && [ "$A" -eq 0 ] && echo "skill $SKILL aggiornata: $PRIMA, come origin"
exit 0
}

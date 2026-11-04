#!/bin/bash
# nerd-esclusi.sh — gli aggiornamenti che il giro automatico NON fa, da ricordare al sistemista umano
#
# NOTA
# unattended-upgrades ( o dnf-automatic ) aggiorna da solo solo una parte dei pacchetti: quelli in
# Package-Blacklist, quelli in hold, quelli dei repository fuori dalle origini ammesse ( PHP del
# pannello, MySQL di terze parti, nginx ufficiale ) restano indietro per sempre, e il conteggio
# "di sicurezza: 0" non li vede. Misurato il 04/11/2026 su un web server con pannello: 0 di
# sicurezza, 117 pendenti di PHP in blacklist. Questo script li conta e li dice; come hook di
# SessionStart lo ricorda a ogni sessione ( SKILL.md, punto 3-bis ).
#
# UTILIZZO
# nerd-esclusi.sh          elenco per esteso
# nerd-esclusi.sh hook     per il SessionStart: muto se non c'e' niente, risultato in cache per 60 minuti
#
# Legge soltanto: niente apt-get update, niente lock ( la simulazione usa Debug::NoLocking ).

MODO=${1:-tutto}
set -f  # le voci della blacklist ( php.*, nginx* ) non vanno espanse come glob
CACHE="${HOME:?}/.claude/.nerd-esclusi"

if [ "$MODO" = "hook" ] && [ -n "$( find "$CACHE" -mmin -60 2>/dev/null )" ]; then
  cat "$CACHE"; exit 0
fi

ORA=$( date +%s )
eta_ore() { [ -e "$1" ] && echo $(( ( ORA - $( stat -c %Y "$1" ) ) / 3600 )) || echo -1; }
OUT=""
riga() { OUT="$OUT$*
"; }

if command -v apt-get >/dev/null 2>&1; then
  SIM=$( LC_ALL=C apt-get -s -o Debug::NoLocking=1 dist-upgrade 2>/dev/null | grep '^Inst ' )
  # nome e origine: "Inst php7.1-zip [7.1.33-1] (7.1.33-2 cloudpanel:bullseye [amd64])"
  NO=$( echo -n "$SIM" | sed -nE 's/^Inst ([^ ]+) .*\([^ ]+ ([^ ,]+).*/\1 \2/p' )
  BL=$( apt-config dump 2>/dev/null | sed -n 's/^Unattended-Upgrade::Package-Blacklist:: "\(.*\)";/\1/p' )
  TOT=$( echo -n "$NO" | grep -c . )
  # sulla riga intera: l'origine -security puo' essere la seconda ( "Debian:13/stable, Debian-Security:13/stable-security" )
  SEC=$( echo -n "$SIM" | grep -ci 'security' )
  # le voci della blacklist sono espressioni regolari sul nome, ancorate all'inizio
  NBL=0
  for p in $BL; do
    n=$( echo -n "$NO" | awk -v p="^($p)" '$1 ~ p' | grep -c . )
    [ "$n" -gt 0 ] || continue
    NBL=$(( NBL + n ))
    es=$( echo -n "$NO" | awk -v p="^($p)" '$1 ~ p {print $1}' | head -3 | tr '\n' ' ' )
    riga "   $n in blacklist \"$p\" ( $es)"
  done
  # in hold: apt-get -s non li elenca, si confrontano installato e candidato
  for h in $( apt-mark showhold 2>/dev/null ); do
    v=$( LC_ALL=C apt-cache policy "$h" 2>/dev/null | awk '/Installed:/{i=$2} /Candidate:/{c=$2} END{if(i!=c && c!="(none)") print i" -> "c}' )
    [ -n "$v" ] && riga "   in hold: $h $v" && NBL=$(( NBL + 1 ))
  done
  # il resto, per origine: se e' ancora qui dopo il giro automatico, fuori dalle origini ammesse
  ALTRI=$( echo -n "$NO" | awk -v bl="$( echo $BL | tr ' ' '|' )" 'bl=="" || $1 !~ "^(" bl ")" {print $2}' | sort | uniq -c | sort -rn | head -4 )
  [ -n "$ALTRI" ] && riga "$( echo "$ALTRI" | sed 's/^ *\([0-9]*\) /   \1 da /' )"
  L=/var/log/unattended-upgrades/unattended-upgrades.log
  # l'ora dell'ultimo giro dallo stamp, non dal log: il log e' nella lingua della macchina
  # ( "Avvio script avanzamento senza controllo" su camera-max ), e il grep in inglese dava "mai"
  P=/var/lib/apt/periodic
  ULT=$( [ -e $P/unattended-upgrades-stamp ] && date -r $P/unattended-upgrades-stamp '+%F %R' )
  [ -z "$ULT" ] && ULT=$( [ -f "$L" ] && grep -E 'Starting unattended upgrades|Avvio script' "$L" | tail -1 | cut -c1-16 )
  LIS=$( eta_ore /var/lib/apt/periodic/update-success-stamp )
  [ "$LIS" -lt 0 ] && LIS=$( eta_ore "$( ls -td /var/lib/apt/lists/*_Packages 2>/dev/null | head -1 )" )
  if [ "$TOT" -gt 0 ]; then
    OUT="⚠ AGGIORNAMENTI DA FARE A MANO su $( hostname ): $TOT pendenti che il giro automatico non fa ( ultimo giro: ${ULT:-mai} )
$OUT"
    # liste scaricate dopo l'ultimo giro: quei pacchetti il giro non li ha ancora visti
    if [ "$SEC" -gt 0 ] && [ $P/update-success-stamp -nt $P/unattended-upgrades-stamp ]; then
      riga "   $SEC di sicurezza arrivati con le liste dopo l'ultimo giro ( $ULT ): li installa il prossimo, si ricontrolla dopo"
    elif [ "$SEC" -gt 0 ]; then
      riga "⚠ $SEC di SICUREZZA della distribuzione: c'erano gia' all'ultimo giro ( $ULT ) e non sono andati, il meccanismo automatico non funziona"
    fi
    [ "$LIS" -ge 48 ] && riga "⚠ liste dei pacchetti vecchie di $LIS ore: il conteggio non e' affidabile"
  fi
elif command -v dnf >/dev/null 2>&1; then
  # --disableexcludes=all: i pacchetti in exclude= non comparirebbero proprio
  PEN=$( dnf -C -q check-update --disableexcludes=all 2>/dev/null | awk 'NF==3 && $1 ~ /\./ {print $1}' )
  ESC=$( dnf -C -q check-update 2>/dev/null | awk 'NF==3 && $1 ~ /\./ {print $1}' )
  NESC=$( comm -23 <( echo "$PEN" | sort ) <( echo "$ESC" | sort ) | grep -c . )
  TIPO=$( sed -n 's/^ *upgrade_type *= *//p' /etc/dnf/automatic.conf 2>/dev/null )
  TOT=$( echo -n "$PEN" | grep -c . )
  if [ "$TOT" -gt 0 ]; then
    riga "⚠ AGGIORNAMENTI DA FARE A MANO su $( hostname ): $TOT pendenti ( dnf-automatic: upgrade_type=${TIPO:-?} ), di cui $NESC in exclude="
    riga "   $( echo "$PEN" | head -5 | tr '\n' ' ' )"
  fi
fi

[ -n "$OUT" ] && [ "$MODO" = "hook" ] && OUT="${OUT}→ Ricordalo al sistemista umano nella prima risposta di questa sessione: vanno fatti a mano, con una finestra decisa da lui ( SKILL.md sysadmin-thelinuxnerd, punto 3-bis )."
[ "$MODO" = "hook" ] && printf '%s' "$OUT" > "$CACHE"
[ -n "$OUT" ] && printf '%s\n' "$OUT"
[ -z "$OUT" ] && [ "$MODO" != "hook" ] && echo "nessun aggiornamento pendente fuori dal giro automatico"
exit 0

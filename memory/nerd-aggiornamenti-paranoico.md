---
name: nerd-aggiornamenti-paranoico
description: Regola fissa di Fabio: aggiornamenti di sicurezza automatici su ogni macchina, e a ogni giro si verifica che siano applicati davvero; un pendente di sicurezza da piu' di 24 ore si riferisce per primo
metadata:
  type: feedback
---

**TheLinuxNerd e' PARANOICO sugli aggiornamenti.** Detto da Fabio il 04/11/2026. Su ogni macchina
gli aggiornamenti di sicurezza si applicano da soli ( `unattended-upgrades` su Debian/Ubuntu,
`dnf-automatic` sulle RHEL ), e ce li si mette **la prima volta che ci si mette mano**, senza
chiedere. Poi, **a ogni giro**, si verifica che sia successo davvero: non ci si fida del servizio
attivo, ne' del pannello, ne' del conteggio di `apt` finche' non si e' visto il numero.

**Why:** una macchina che non si aggiorna non si difende, e quasi mai lo dice. Nella bonifica
raccontata in `intrusione.md` ( punto 9 ) `apt` annunciava 199 aggiornamenti che non esistevano, e
l'ingresso piu' probabile era un pannello non piu' aggiornabile.

**How to apply:** la ricetta e le sei verifiche stanno nel punto 3-bis della skill
**sysadmin-thelinuxnerd**, e la prima passata la fa `triage.sh` ( sezione AGGIORNAMENTI ). Le cose
che non si mollano: un aggiornamento di sicurezza pendente da piu' di 24 ore si riferisce **per
primo**; una patch installata ma non caricata ( riavvio pendente, servizi con librerie vecchie )
non e' applicata; ogni hold ha il suo motivo in `/root/READ.md`; il software fuori da `apt` ha
scritto chi lo aggiorna. Il riavvio della macchina e i passaggi di versione restano
all'amministratore. Vedi anche [[nerd-fail2ban-sempre-su-ogni-macchina]].

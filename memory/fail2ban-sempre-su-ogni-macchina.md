---
name: fail2ban-sempre-su-ogni-macchina
description: Regola fissa di Fabio: fail2ban va installato su ogni macchina esposta a Internet, non si valuta caso per caso
metadata:
  type: feedback
---

**TheLinuxNerd mette SEMPRE fail2ban sulle macchine.** Detto da Fabio il 23/09/2026, subito
dopo averlo visto installare su un web server in produzione. Non e' una valutazione da rifare ogni volta: su qualunque
macchina esposta a Internet fail2ban ci va, e ce lo si mette **la prima volta che ci si mette
mano**, senza chiedere il permesso.

**Why:** il 23/09/2026, su una macchina esposta, erano **25.531 tentativi SSH in undici ore da 440 IP**. La
chiave publickey teneva benissimo, quindi il rischio non era l'intrusione: era che il traffico da
solo saturasse `MaxStartups` e **chiudesse fuori Fabio dalla sua stessa macchina**, che e'
esattamente quello che era successo. ⚠ *"Tanto ho solo la chiave, le password sono spente"* non
e' un motivo per non metterlo: era proprio quella la situazione.

**How to apply:** e' un intervento additivo e reversibile che non cambia come gli altri usano la
macchina, quindi sta nel lato *"si fa da soli"*, non fra le cose che decide Fabio. La ricetta
completa ( `jail.local`, la verifica con `fail2ban-regex`, `ignoreip` solo localhost, `mode`
normal e non aggressive ) sta nel punto 3 della skill **sysadmin-thelinuxnerd**, che e' il posto
da cui prenderla: qui resta solo la regola. Su Debian EOL il pacchetto arriva da
`archive.debian.org`, che funziona. Se la macchina espone anche proftpd, postfix o dovecot, le
jail corrispondenti si propongono nello stesso giro.

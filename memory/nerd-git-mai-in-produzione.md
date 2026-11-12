---
name: nerd-git-mai-in-produzione
description: Regola fissa di Fabio: git non è un sistema di deploy, mai un repository in stable/ o in produzione; il deploy lo fa il framework
metadata:
  type: feedback
---

**Git non è un sistema di deploy: in produzione ( `stable/` ) non ci sta un repository, per nessuna
ragione.** Detto da Fabio il 12/11/2026, davanti a un censimento che proponeva di fare di uno
`stable/` un checkout dello stesso repository del `dev/` "per vedere se la produzione si era
allontanata".

**Why:** un `.git` in produzione è superficie d'attacco che non serve a niente. Il 04/11/2026 su un
web server `/.git/HEAD` rispondeva 200, e da sette IP in otto giorni era stato scaricato l'intero
repository, fino a 5,9 GB per volta, credenziali comprese. In più occupa spazio per niente: storia e
oggetti duplicano quello che sta già sul remote.

**How to apply:**
- il codice vive nel repository del `dev/` ( o in quello del framework ), e arriva in produzione con
  **i meccanismi di deploy del framework**, che ci sono e funzionano, mai con `git pull` o un checkout;
- uno `stable/` senza `.git` è giusto, non è un'anomalia da correggere;
- se si trova un `.git` in `stable/`, si verifica che la storia sia sul remote ( `rev-list
  --left-right --count HEAD...@{u}` = `0 0` ), poi lo si porta **fuori** dal deploy, in una copia
  datata in `/var/backups/`, che contiene ancora i segreti della storia: toglierlo del tutto lo decide
  l'amministratore;
- un deploy vecchio che ha solo `stable/` e codice suo: il codice va in un repository, ma da un
  `dev/` o da un clone fuori dalla document root, non con un `.git` lasciato nel deploy;
- vale anche per le proposte: "versioniamo la produzione" non si propone.

# TheLinuxNerd — il metodo, diffuso sulle macchine

Il modo in cui **TheLinuxNerd** amministra le sue macchine Linux, scritto in una skill
per Claude Code, più gli strumenti che la skill usa. Nato il **23/09/2026** dal giro su un brute force SSH.

## Cosa c'è dentro

| percorso | cos'è |
|---|---|
| `skills/sysadmin-thelinuxnerd/` | la skill: il metodo in dodici punti ( misurare prima, backup datato, testare la config, fail2ban sempre, "active non è una verifica", il confine fra quello che si fa da soli e quello che decide Fabio ) |
| `skills/sysadmin-thelinuxnerd/references/intrusione.md` | quando la macchina è davvero compromessa: gli strati, dove si nascondono gli impianti, l'ordine della bonifica, e la sorveglianza che non è teatro — si apre dal punto 7 della skill |
| `skills/sysadmin-thelinuxnerd/scripts/hunt.sh` | caccia agli impianti, **sola lettura**: processi travestiti, immutabili, generatori systemd e regole udev senza pacchetto, eseguibili orfani, `/dev/shm`, connessioni col processo, invarianti di privilegio |
| `skills/sysadmin-thelinuxnerd/scripts/triage.sh` | prima passata di diagnosi, **sola lettura**: carico, disco, porte esposte, volume degli attacchi SSH, stato delle difese, modifiche recenti in `/etc` |
| `skills/todo-elenco/` | come si presentano all'utente le voci aperte di un `TODO.md` — la skill sopra ci rimanda |
| `bin/todo.py` | legge il `TODO.md` una riga per voce, invece di riversarlo intero nel contesto. ⚠ **Copia, non fonte**: il sorgente è `~/Dropbox/.claude/` di Fabio, diffuso sui server da `diffondi-server.sh`; qui si aggiorna copiandolo da lì quando cambia, **non si modifica nel repo** |
| `memory/` | le regole fisse, in forma di memoria di Claude, tutte col prefisso `nerd-`: *fail2ban va sempre messo*, *SSH solo a chiave* |

I fatti della singola macchina — a cosa serve, cosa espone, cosa è già stato deciso — **non stanno qui**: vanno in un `/root/READ.md` locale, che la skill sa di dover leggere e che non si pubblica.

## Installare su una macchina nuova

    git clone <questo repo> ~/thelinuxnerd
    cd ~/thelinuxnerd
    ./install.sh --dry-run     # prima si guarda cosa farebbe
    ./install.sh

Copia dentro `~/.claude/` ( skill, `bin/`, e le memorie in `projects/-root/memory/` ), e mette da
parte con `.bak-AAAAMMGG` qualunque file diverso che stia già lì. È **idempotente**: rilanciarlo
dopo ogni `git pull` è il modo normale di aggiornare.

**Le memorie del metodo si chiamano `nerd-*.md`, e solo loro.** Vivono nel repo e si modificano
solo qui: `install.sh` le copia nella memoria della macchina, e se ne trova una modificata sul
posto lo dice e vince il repo. Tutte le altre memorie sono **della macchina** — clienti, percorsi,
decisioni — e non escono mai: `install.sh` non le legge, e il pre-commit rifiuta in `memory/`
qualunque file senza il prefisso. Un fatto di una macchina non va dentro una `nerd-`: va in una
memoria col nome suo, o nel `/root/READ.md`.

⚠ Se `~/.claude/projects/-root/memory/` non esiste ancora, le memorie vengono saltate: nasce alla
prima sessione di Claude su quella macchina, poi basta rilanciare `install.sh`.

## Cosa NON c'è dentro, e perché

- **Segreti: password, chiavi private, chiavi pubbliche SSH, `.env`, `authorized_keys`.** Questo
  repository si diffonde su più macchine, quindi è il posto sbagliato. Ci sono due barriere: il
  `.gitignore` e l'hook `pre-commit` in `.githooks/`, che blocca il commit se in stage compare
  qualcosa che somiglia a una credenziale. `install.sh` attiva l'hook da solo
  ( `git config core.hooksPath .githooks` ); se serve scavalcarlo, `git commit --no-verify`.
- **Il `CLAUDE.md`**, che ha già il suo canale di diffusione: metterlo anche
  qui vorrebbe dire due sorgenti di verità che divergono.
- **I `TODO.md` e i `.bak-*` delle macchine**: sono stato di quella macchina, non metodo. Il
  `.gitignore` li esclude apposta.

## Aggiornare il metodo

Si modifica **qui**, si committa, e sulle altre macchine `git pull && ./install.sh`. Modificare
direttamente un `~/.claude/skills/...` su una macchina qualsiasi funziona per quella macchina e
si perde al primo aggiornamento.

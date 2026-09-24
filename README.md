# TheLinuxNerd — il metodo, diffuso sulle macchine

Il modo in cui **TheLinuxNerd** amministra le sue macchine Linux, scritto in una skill
per Claude Code, più gli strumenti che la skill usa. Nato il **23/09/2026** dalla lunga maturazione di numerosi esperimenti, tentativi ed errori nell'insegare a un'AI come si amministrano le macchine Linux.

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

## Aggiornare il metodo
Il bello di questo approccio è che crea un'esperienza condivisa fra le macchine amministrate; quando
serve si modifica **qui**, si committa, e sulle altre macchine `git pull && ./install.sh`.
La skill lo fa da sola: all'inizio di un lavoro, se l'ultimo controllo ha più di sette giorni,
fa `fetch`, `pull --ff-only` e `install.sh`.

`install.sh` sovrascrive **solo i file che il repo porta**: le skill che stanno in `skills/`
( `sysadmin-thelinuxnerd`, `todo-elenco` ), gli script di `bin/` e le memorie `nerd-*.md`. Le
altre skill e le altre memorie della macchina non le legge e non le tocca, e i file aggiunti a
mano dentro una cartella del repo restano. Una modifica fatta direttamente sulla macchina a uno
di quei file, invece, sparisce al primo aggiornamento — la versione precedente finisce in
`~/.claude/backups/<data>-thelinuxnerd/`, ma nessuno la va a riprendere: va portata qui.

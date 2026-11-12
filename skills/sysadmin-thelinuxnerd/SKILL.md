---
name: sysadmin-thelinuxnerd
description: Come si amministra una macchina Linux, nel metodo di TheLinuxNerd. Prima si misura e si quantifica, poi si tocca poco e con backup datato, si testa la config prima di ricaricarla, si verifica che il servizio faccia davvero il suo lavoro e non solo che sia "active", e si separa quello che si fa da soli da quello che deve decidere l'amministratore. Attivare ogni volta che si mette mano a una macchina: sintomi ( "l'ssh mi rifiuta", "il sito è lento", "lo spazio è finito", "non mi arriva la posta" ), domande di sicurezza ( "ci sono problemi?", "siamo sotto attacco?", "è compromessa?" ), interventi su servizi e configurazioni ( sshd, apache, nginx, proftpd, fail2ban, firewall, cron, mysql, certbot ), siti WordPress e pannelli di hosting, sospetta compromissione ( "hanno bucato un sito", "c'è un file strano", "il plugin di sicurezza mi ha avvisato" ), backup e monitoraggio ( "i backup ci sono?", "perché non mi è arrivato l'avviso?" ), controlli di stato e giri di manutenzione, takeout di una macchina da dismettere o da trasferire ( "facciamo il backup della macchina per poi eliminarla", "spostiamo il server", "takeout" ), o di un sito solo da archiviare ( "archiviamo il sito", "togliamo il sito da CloudPanel" ). Contiene anche le regole fisse, prima fra tutte che **fail2ban va messo su ogni macchina esposta a Internet** , che **SSH accetta solo chiavi**, che **FTP in chiaro non si usa, solo SFTP** e che **gli aggiornamenti di sicurezza si applicano da soli e si verificano a ogni giro** ( "la macchina è aggiornata?", unattended-upgrades, riavvio pendente ), senza starci a ragionare ogni volta: attivare quindi anche quando si prepara o si eredita una macchina nuova. Vale pure quando la richiesta sembra una riga sola: è lì che si sbaglia diagnosi. Alla fine di ogni lavoro la skill si migliora da sola con quello che si è imparato ( commit nel repository ).
---

# Amministrazione di sistema, come la fa TheLinuxNerd

Nata il **23/09/2026** su un web server in produzione, dal giro su un brute force SSH:
l'amministratore arriva dicendo *"mi ha rifiutato la connessione ssh due volte prima di lasciarmi
accedere, c'è qualche problema di sicurezza?"*, e la risposta giusta non era né "sì sei sotto
attacco" né "no è tutto a posto".

Il filo è uno solo:

> **Misura prima, cambia poco e in modo reversibile, verifica che funzioni davvero, e scrivi
> quello che resta invece di raccontarlo.**

## Prima di cominciare: la skill si aggiorna da sola

Il metodo cresce nel repository ( `github.com/the-linux-nerd/expert-nerd-sysadmin` ), non sulla
macchina: una copia installata un mese fa lavora con le regole di un mese fa. ⚠ **La regola a
memoria non bastava**: il 04/11/2026 web02 e web03 erano indietro di 7 commit, cloudpanel01 di 6, e
la copia installata di web02 non era nemmeno quella del suo clone. Quindi l'aggiornamento **lo fa
un hook**, non la buona volontà:

- `install.sh` registra `bin/nerd-aggiorna.sh` come hook di `SessionStart`. **Una volta al giorno**
  fa `fetch`; se origin è avanti e il clone è pulito, `pull --ff-only` e `install.sh`; se la copia
  installata non è quella del clone, rilancia `install.sh`. Senza niente da dire, tace;
- ⚠ **se l'hook ha scritto qualcosa, si riferisce all'amministratore nella prima risposta**, in una
  riga coi titoli dei commit, anche se ha chiesto altro. Se la skill era già in contesto, **si
  rilegge questo file**: quella caricata è la versione vecchia;
- **all'inizio di un lavoro lungo**, o se la sessione è aperta da più di un giorno, lo si lancia a
  mano: `bash ~/.claude/bin/nerd-aggiorna.sh` ( senza `hook` non guarda l'ora dell'ultimo controllo );
- ⚠ **commit locali, modifiche o storia divergente non si forzano mai**: niente `reset`, niente
  `pull` a forza. Lo script lo dice, e i commit locali vanno al generale come patch ( sezione
  sotto ); quando sono in origin, `git reset --hard @{u}` e `./install.sh`;
- se il `fetch` fallisce ( niente rete, niente accesso a GitHub ) il controllo si ripete alla
  sessione dopo: l'ora dell'ultimo controllo ( `~/.claude/.thelinuxnerd-controllo` ) si segna solo
  quando è riuscito;
- il clone standard è `~/thelinuxnerd`; se sta altrove, l'hook lo sa perché `install.sh` gli passa
  il percorso, ma lo si segnala: l'installazione standard è quella.

⚠ **Chi può pushare sul repository esegue codice come root su tutte le macchine**, alla prima
sessione del giorno dopo. Per questo il push lo fa solo il generale, e una patch che arriva da una
macchina si legge e si prova prima di pusharla.

## Alla fine di ogni lavoro: la skill impara

Il metodo è **l'esperienza di tutte le macchine messa insieme**: ogni sessione che ci lavora la
legge all'inizio, e **alla fine la restituisce migliorata**. Detto da Fabio il 04/11/2026: la skill
si migliora costantemente con l'esperienza di ogni capitano. Una lezione che resta in una
conversazione, o nel `/root/READ.md` di una macchina sola, le altre macchine la ripagano da capo.

**Prima della risposta di chiusura di ogni lavoro amministrativo o di sicurezza**, la domanda è una:

> **Che cosa ho imparato qui che un'altra macchina pagherebbe di nuovo?**

Una diagnosi sbagliata prima di quella giusta, un comando che mentiva, una verifica che mancava, un
numero che ha smentito una regola, uno script che non ha fatto quello che doveva. Se c'è, **va nel
repository nello stesso lavoro**, non "dopo":

| cosa si è imparato | dove va |
|---|---|
| un fatto di **questa** macchina ( a cosa serve, cosa è già deciso ) | `/root/READ.md`, non qui |
| un modo di ragionare, una trappola, una verifica | il punto giusto di questo `SKILL.md` |
| il dettaglio lungo di un caso ( intrusione, takeout ) | `references/` |
| un controllo che si rifà a mano ogni volta | uno script in `scripts/`, o `triage.sh` / `hunt.sh` |
| una regola fissa, da non ridiscutere | una memoria `memory/nerd-*.md` |

Come si scrive, perché la skill resti leggibile e non diventi un diario:

- **col numero e la data**: *"misurato il 03/11/2026: 50.632 IP distinti"*, non *"a volte gli
  attacchi sono distribuiti"*. È il numero che convince la sessione dopo a non rifare l'errore;
- **anonimo**: niente hostname, IP, domini o nomi di clienti — il repository si diffonde su tutte le
  macchine, e il `pre-commit` ferma solo i segreti evidenti. *"un web server in produzione"*,
  *"un sito WordPress dietro un pannello"*;
- **correggere vince su aggiungere**: se la lezione smentisce una riga, **si cambia quella riga**,
  non se ne aggiunge una accanto che la contraddice. Se un punto è cresciuto troppo, lo si accorcia
  spostando il racconto in `references/`;
- **una lezione, un commit**, col messaggio `<cosa>: <perché>`, senza il nome della macchina.

La procedura, nel clone standard:

    cd ~/thelinuxnerd && git pull -q --ff-only     # prima si parte dall'ultima versione
    # ... modifica ...
    git add -A && git commit -m "<cosa>: <perché>" && git push -q && ./install.sh

- ⚠ **Se il `push` viene rifiutato perché il repo è andato avanti**, `git pull --rebase` e di nuovo
  `push`; un conflitto si risolve leggendo le due versioni, **mai** con `--force`.
- ⚠ **Se la macchina non ha le credenziali per pushare**, la lezione non si perde: si manda la
  patch ( `git format-patch -1 --stdout` ) al generale con `claude-posta.py manda --a generale`, che
  la applica e la pusha. Il commit locale si toglie dopo, quando il `pull` lo riporta.
- Una modifica fatta direttamente nei file installati in `~/.claude/` **si perde** al prossimo
  `install.sh`: si fa sempre nel clone.

Nella risposta di chiusura c'è sempre una riga che lo dice: `skill: migliorata ( <hash>, <cosa> )`,
oppure `skill: niente da aggiungere`. Senza quella riga il lavoro non è chiuso: è proprio il passo
che si salta quando si ha fretta, ed è quello che fa crescere il metodo.

## Prima di cominciare: calabash

Le operazioni ricorrenti si fanno con gli script di **calabash** ( `github.com/istricesrl/calabash` ),
non con comandi scritti a mano ogni volta. Se sulla macchina non c'è ( `command -v va.bak.sh` non
trova niente ), **si installa** seguendo le istruzioni di calabash, cioè con il suo script:

    wget https://raw.githubusercontent.com/istricesrl/calabash/master/install.sh && chmod +x ./install.sh && ./install.sh

( da una cartella di lavoro, non dalla radice ). ⚠ Se c'è già ma in `/usr/bin` e `/usr/sbin`, è il
layout vecchio: l'installer copia tutto in `/usr/local`, e i doppioni dividono il lavoro in silenzio,
perché chi chiama per nome prende la copia nuova e chi chiama per percorso assoluto ( monit, un cron )
prende la vecchia. Il layout vecchio interroga anche un sito di versioni dismesso. La migrazione si fa
in una passata sola. Prima la copia di sicurezza delle `va.*` vecchie, poi l'installer, poi via le copie
vecchie che hanno la gemella in `/usr/local`, poi `grep -rnoE '/usr/s?bin/va\.' /etc` per i percorsi
assoluti, da portare su `/usr/local`, e alla fine `monit -t` e `reload`. ⚠ `monit -t` dice *Control file syntax OK* anche quando un `exec` punta a un programma che non c'è più: lo avvisa con `Program does not exist` ma l'allarme poi non parte. Misurato il 12/11/2026: 12 allarmi muti per due ore dopo la rimozione dei doppioni, con la sintassi data per buona. Si conta quella riga, che deve essere zero, e il `grep` su `/etc` va con `--exclude-dir=ssl`: senza, è andato oltre i 120 secondi. Prima di togliere le copie
vecchie si confrontano coi file del repo: misurato il 12/11/2026, su 81 copie 14 erano diverse, ma
erano solo versioni vecchie, e le modifiche locali erano già a monte. ⚠ La verifica non è `calabash
--version`, che non esiste: è `command -v` che risolve in `/usr/local`, e `va.script.check.sh` che
risponde.

Quando uno script non fa quello che serve, **si corregge lo script e si aggiorna il repository di
calabash** ( commit e push ), invece di fare a mano "per questa volta".

## 0. Le particolarità della macchina stanno in `/root/READ.md`

Questa skill è il **metodo**, e vale su qualunque macchina. Quello che invece cambia da macchina a
macchina — a cosa serve, cosa espone, quali decisioni sono già state prese e vanno rispettate —
sta in **`/root/READ.md`**, accanto agli altri file di servizio.

I **file di servizio canonici in `/root`** sono questi, e sono **l'unica eccezione** alla regola
che nella radice di `/root` non si lasciano file: `READ.md` ( fatti della macchina ), `TODO.md`
( rami aperti ), `DONE.md` ( decisioni e perché ), `CHAT.md` ( stato con le persone ), `CLAUDE.md` ( istruzioni ), `root.journal`
( eventi, via `va.log.journal.sh` ). Se uno manca e serve, **si crea lì**, senza chiedere: non è
un file "di comodo". Tutto il resto va nelle cartelle della tabella del punto 0-bis.

⚠ **Si legge prima di concludere che qualcosa è un problema.** Metà dei "problemi" che si trovano
in un giro di diagnosi sono scelte consapevoli di chi amministra la macchina: una versione tenuta
indietro apposta, uno swap che non si mette, un servizio lasciato com'è per non rompere i client.
Riproporle ogni volta è rumore, e fa perdere credibilità alle segnalazioni vere.

Se `/root/READ.md` non c'è, vale la pena proporre di crearlo alla fine del primo giro serio:
è lì che si sedimenta quello che altrimenti si riscopre da capo ogni sessione.

## 0-bis. Dove si scrivono i file: le cartelle canoniche di `/root`

Ogni cosa che si scrive su una macchina ha **un posto solo**, e la sessione dopo la ritrova lì
senza doverla cercare. La radice di `/root` non è un deposito: ci stanno i file di
servizio e le cartelle di questa tabella, nient'altro.

| cosa | dove |
|---|---|
| fatti della macchina e decisioni prese | `/root/READ.md` |
| lavoro aperto | `/root/TODO.md` |
| cosa è stato fatto e perché | `/root/DONE.md` |
| istruzioni per la sessione di amministrazione | `/root/CLAUDE.md` |
| stato delle conversazioni con le persone | `/root/CHAT.md` |
| eventi della macchina, via `va.log.journal.sh` | `/root/root.journal` |
| **un incidente**: rapporto, cronologia, evidenze con lo `stat`, log, output di chkrootkit / rkhunter / scanner | **`/root/incidenti/AAAAMMGG-nome/`**, con la data dell'incidente, non del giorno in cui lo si scopre |
| file tolti dai siti perché sospetti | `/root/quarantena/<sito>/`, percorso originale conservato, non eseguibili, con `MANIFEST.sha256` e `LEGGIMI.txt` |
| siti o versioni dismesse in attesa di essere scaricate | `/root/old.sites/` |
| schede del takeout | `/root/takeout/` ( punto 12 ) |
| il clone di questa skill | `/root/thelinuxnerd/` |
| materiale di lavoro di un giro da conservare, che non è un incidente né una copia di sicurezza | `/root/var/AAAAMMGG-scopo/` |
| copia di sicurezza di una config o di un file prima di riscriverlo | `/var/backups/AAAAMMGG-motivo/`, con `va.bak.sh` |
| takeout di una macchina | `/var/backups/NOME/AAAAMMGG-takeout/` |
| appoggio, prove, output intermedi | la scratchpad della sessione o `/tmp`: **solo cose che si possono perdere** |

⚠ **Un rapporto o un'evidenza non passano mai da `/tmp`.** Si scrivono **subito** nella cartella
canonica, anche lo script che li produce scrive lì, non "in `/tmp` e poi li sposto". Misurato il
03/11/2026: il rapporto d'indagine di un'intrusione ( chkrootkit, rkhunter, clamscan, debsums e il
report finale, con la password del kit dell'attaccante ) è stato scritto in `/tmp/web02-forense.XXXX/`
da un `mktemp -d`, ed è rimasto lì due giorni, a un riavvio dal perderlo, finché l'amministratore non
ha chiesto di metterlo al sicuro. `/tmp` si svuota al riavvio, `systemd-tmpfiles` lo pota, e dopo
un incidente un riavvio è proprio quello che si fa.

⚠ **Una cartella fuori tabella si sistema, non si aggiunge.** Se in `/root` si trova qualcos'altro,
lo si porta al suo posto ( una copia di `authorized_keys` è una copia di sicurezza: `/var/backups` ),
si aggiornano i riferimenti in READ, TODO, DONE e nelle memorie, e se non ha un posto si chiede.

## 1. Prima si misura, e si misura per davvero

La diagnosi a orecchio è l'errore che costa di più, perché porta a intervenire sulla cosa
sbagliata e a lasciare in piedi quella vera. Nel caso che ha dato origine a questa skill il
sintomo *"rifiuta la connessione"* sembrava sicurezza e **non lo era**: era `MaxStartups` col
default `10:30:100` saturato da decine di connessioni ferme in preauth. La prova non è stata
un'impressione, sono stati i numeri — **25.531 tentativi in undici ore da 440 IP distinti**, e 72
connessioni aperte sulla porta 22 in quel momento.

**Si portano numeri, non aggettivi.** "Tanti tentativi" non è una diagnosi; "25.531 al giorno da
440 IP" lo è, e fa capire da sola se serve fail2ban o un cambio di porta.

⚠ **L'assenza di righe nei log non è una prova.** sshd non scrive i drop di `MaxStartups` sotto
`LogLevel INFO`: cercarli e non trovarli non smentisce niente. Prima di concludere *"questa cosa
non succede"*, la domanda da farsi è **"se succedesse, verrebbe loggata?"**. Vale per i log di
apache, di proftpd, del kernel: ognuno tace su qualcosa.

⚠ **Una mail di cron si attribuisce dal mittente e dall'oggetto, non dall'ora.** Il 10/11/2026 una mail delle 06:43 è stata data a un servizio di uptime che girava in quei minuti, e il controllo è stato chiuso come "cron.daily muto". Era cron.daily: parte alle 06:25 e `run-parts --report` spedisce **alla fine** del giro, quindi la mail arriva quando finisce lo script più lento. Se il corpo non è più leggibile, si manda l'output di `run-parts` su un log: `--report` scrive il nome dello script prima del suo output, e il giorno dopo si sa chi parla.

**I comandi di raccolta vanno in una chiamata sola**, con le intestazioni a dividere l'output: in
diagnosi conta doppio, perché i dati servono tutti insieme per essere confrontati. C'è uno script
pronto per la prima passata:

    ~/.claude/skills/sysadmin-thelinuxnerd/scripts/triage.sh

È **in sola lettura**, non tocca niente, e stampa in un colpo: carico, memoria, disco, servizi in
ascolto, accessi riusciti, volume degli attacchi SSH, stato di firewall e fail2ban, modifiche
recenti in `/etc`.

⚠ **Nel primo giro si guarda anche la data di fine supporto della distribuzione**, insieme alle
porte aperte: è un dato di sicurezza, non un debito tecnico. Su una macchina a fine vita `apt`
annunciava **199 aggiornamenti e non ne esisteva nessuno** — il repository di sicurezza rispondeva
404 — e l'ingresso più probabile era proprio un pannello che, lì, non si poteva più aggiornare.

**Prima di mettere un limite si simula sul log vero.** Una soglia "ragionevole" scelta a occhio
è una diagnosi a orecchio: si rifà l'algoritmo del limite ( per `limit_req` un secchio che perde
`rate` al secondo e respinge oltre `burst` ) sulle righe di un giorno normale **e** del giorno
dell'incidente, per due o tre soglie, e si guarda **chi** verrebbe respinto. Misurato il
03/11/2026: a 1-2 r/s per IP il limite colpiva un lettore di feed di un sito partner; a 5 r/s
burst 150 non toccava nessuno il giorno normale. E la stessa simulazione ha detto la cosa più
importante: il sovraccarico da cui si partiva veniva da **50.632 IP distinti**, circa una
richiesta ciascuno, e nessun limite per IP l'avrebbe fermato. **La prima domanda è "quanti IP
distinti ha l'incidente?"**: se sono pochi serve un limite per IP, se sono decine di migliaia
servono una regola sul percorso che costa ( lì era la paginazione profonda ) e la cache.

**La memoria di un processo si misura col Pss, non con l'RSS.** Il 06/11/2026, per dimensionare
`MaxRequestWorkers` di un apache prefork, l'RSS diceva 53 MB a processo e il Pss ( `smaps_rollup` ) 7 MB:
il resto è memoria condivisa, contata una volta per processo. Con l'RSS il tetto sembrava 45 worker, col
Pss era ben sopra 60. ⚠ Il caso peggiore però non è la media di oggi: se nel worker gira mod_php, il
processo può crescere fino al `memory_limit`, e il conto va fatto anche su quello.

**Errori di connessione al database su tutti i siti nello stesso minuto: prima il traffico.** Misurato il
10/11/2026: 976 errori di connessione assente e `Too many connections` in tre minuti, su un web server con
una trentina di siti e un MySQL condiviso a `max_connections 40`. Il database era sano ( carico 0,5,
memoria libera ); le richieste al minuto di **tutti i vhost sommati** passavano da ~125 a ~300, e il di più
era uno scanner commerciale distribuito: 6 IP di due cloud con lo stesso reverse DNS, 332 richieste su 13
siti in 80 secondi. Ogni 404 di un'applicazione che apre il database prima del routing costa una
connessione. La prima ipotesi, le sessioni di lavoro aperte in quei minuti, era sbagliata di un minuto e
mezzo: **l'ora si confronta al secondo**. Il blocco dei singoli IP chiude l'episodio, non la causa: lo
scanner ruota indirizzi, e la domanda vera è il tetto condiviso.

## 2. Prima di toccare una configurazione

1. **Backup datato, con la data nel nome della cartella e non dopo l'estensione**:
   `/var/backups/20260923-maxstartups/etc/ssh/sshd_config`, non `sshd_config.bak-20260923`. La
   copia serve perché il rollback si fa alle due di notte, quando nessuno si ricorda cosa c'era
   prima; la data va nella cartella perché su Linux troppe cose decidono guardando l'estensione
   finale. ⚠ Misurato: `config.php.bak` risponde 403 grazie al `FilesMatch` del `.htaccess`, ma
   `config.php.bak.20260827` risponde **200 col sorgente in chiaro**, password del database
   comprese. Lo stesso suffisso fa sparire un file da `run-parts` e dai glob `*.conf` degli
   `Include`; e al contrario una copia chiamata `vecchio.conf` lasciata accanto all'originale **ci
   finisce dentro**, e la config si carica due volte. Se la macchina ha un suo strumento per le
   copie, lo dice il `READ.md`.
2. **Test di sintassi prima di ricaricare**, sempre: `sshd -t`, `apachectl configtest`,
   `nginx -t`, `fail2ban-client -t`, `visudo -c`, `named-checkconf`. Una config rotta su un
   servizio di rete si paga con la macchina irraggiungibile.
3. **`reload`, non `restart`**, quando il servizio è quello da cui si è connessi. Il reload di
   sshd non butta giù le sessioni aperte; il restart è un rischio che non serve correre.
   ⚠ **Un reload non è sempre gentile.** php-fpm col default `process_control_timeout = 0`
   **uccide le richieste in corso** a ogni reload: il 05/11/2026 ha interrotto un cron che teneva
   un lock dei task per 10 minuti, e il sito ha dato 500 per 9 minuti. Prima di ricaricare un
   servizio che esegue lavoro lungo, si mette il timeout ( `process_control_timeout = 120s` ) e si
   ricarica quando i lock dei job ( `flock` in `/var/lock` ) sono liberi. E le prove "prima/dopo"
   sulle URL più frequenti **escludono gli endpoint di cron e dei task**: chiamarli è eseguirli.
4. **Modifica minima.** Si cambia la riga che risolve il problema misurato, non si riscrive il
   file "già che ci siamo": un file riscritto rende impossibile capire, il mese dopo, quale
   modifica ha causato cosa.

⚠ **Scrivere un file non cambia solo il contenuto.** Tre modi visti di rompere qualcosa senza
toccare una riga di logica:

- **L'ownership.** Uno strumento che gira come root e riscrive il file lo lascia `root:root`: PHP
  non lo legge più ( 500 ), e su una directory apache risponde 403 con un `AH00529` che cita un
  `.htaccess` magari inesistente — il problema vero è lo stat sulla cartella. È andato avanti per
  settimane, centinaia di volte al giorno, prima che qualcuno lo collegasse. Dopo ogni scrittura
  in una document root: `stat -c '%U:%G %a' <file>`.
- **L'inode.** `sed -i` e `git checkout / pull / stash` non riscrivono il file, lo **sostituiscono**:
  un hardlink voluto si spezza in silenzio ( visti 1.115 file condivisi fra due installazioni ).
  Chi scrive sul posto, come `open(path, 'w')`, mantiene l'inode.
- **Il bersaglio.** Uno script di pulizia che fa `find -mtime +N -delete` senza `-name` va bene
  finché punta alla cartella giusta; puntato su una document root, cancella il sito. Prima di
  riusare uno script si legge il comando, non il nome.

⚠ **Non si cade mai fuori dalla macchina.** Quando si tocca sshd, iptables o il firewall, la
sessione già aperta è l'unica rete di sicurezza: si lavora tenendola viva, si verifica subito
dopo che regge ( `who` ), e se l'intervento è davvero rischioso si chiede all'amministratore di
aprire una seconda sessione prima di procedere.

⚠ **"Host key verification failed" non vuol dire chiave cambiata.** Con `BatchMode=yes` lo stesso errore arriva anche per un host che in `known_hosts` non c'è sotto quel nome. Misurato l'11/11/2026: una macchina è rimasta fuori da un giro di aggiornamenti perché "la host key non torna". La chiave però c'era sotto l'IP interno, era la stessa presentata quel giorno, e mancava solo l'alias. Prima di sospettare un'intercettazione: `ssh-keygen -F <nome>` e `ssh-keygen -F <ip>`, poi si confronta l'impronta con `ssh-keyscan <ip> | ssh-keygen -lf -`. Se coincidono si aggiunge l'alias con la chiave già fidata; se è diversa, si ferma tutto e si verifica dalla console del provider.

### Bloccare un IP

**Un IP non è un client.** Il 02/11/2026, in piena emergenza, un IP che mandava 12.750 richieste
al giorno con user-agent AhrefsBot è stato chiuso con un DROP in iptables. Era il server di un
sito partner, e dallo stesso indirizzo passava anche il loro lettore di feed: per **30 ore** quel
sito non ha più letto i nostri feed, e se n'è accorto il cliente, non noi. In più il blocco non
serviva: quell'user-agent prendeva già 403 da nginx.

- **Prima di bloccare si guardano tutti gli user-agent e i percorsi di quell'IP**, non solo
  quello che ha fatto scattare l'allarme, e il suo reverse DNS: un hosting condiviso, un proxy
  aziendale o una NAT portano client diversi.
- **Si blocca nel web server, con un 429 o un 403, non con un DROP.** Il DROP è silenzioso: chi
  lo subisce vede solo timeout, nei log non resta niente, e nessuno collega il disservizio al
  blocco. Un 429 compare nell'access log di chi lo riceve e nel nostro, e si toglie con un reload.
- **Ogni blocco porta data e motivo nel commento**, e si decide subito se è temporaneo: un
  blocco d'emergenza non reso persistente sparisce al riavvio, uno persistente resta per sempre.

### Git non è un sistema di deploy

⚠ **In produzione non ci sta un repository, per nessuna ragione** ( regola fissa,
`memory/nerd-git-mai-in-produzione.md` ). Il codice vive nel repository di sviluppo e arriva in
produzione coi **meccanismi di deploy dell'applicazione**, mai con un `git pull` o un checkout: un
`.git` in produzione è solo superficie d'attacco ( qui sotto, cosa succede quando risponde dal web )
e spazio occupato per niente. Uno `stable/` senza `.git` è giusto, e "versioniamo la produzione per
vedere se si è allontanata" non si propone. Un `.git` trovato in produzione si porta fuori, dopo aver
verificato che la storia sia sul remote ( `0 0` ), in una copia datata in `/var/backups/`. Detto il
12/11/2026, davanti a un censimento che proponeva proprio quello, e a decine di deploy di produzione
messi sotto git una settimana prima.

### Un repository dentro la document root ( sviluppo )

**Misurato il 04/11/2026**: su un web server con tre deploy sotto git, `/.git/HEAD` e `/.git/config`
rispondevano **200**. Nessuna regola li chiudeva perché nessuno ci aveva pensato, e i log dicevano
che altri ci avevano pensato: da sette IP diversi in otto giorni, **l'intero repository scaricato**,
fino a 5,9 GB per volta, con dentro le credenziali del database e migliaia di allegati con dati di
clienti. Si scopre solo cercando nell'access log `"GET /.git/`, e i 200 vanno contati per IP e per byte.

- **Prima di mettere sotto git un deploy si chiude `.git` nel web server, per tutti i siti**: una
  regola globale, non un `.htaccess` per sito, con un **404** e non un 403, per non confermare che c'e':
  `RedirectMatch 404 "(?i)/\.git(/|$|ignore$|attributes$|modules$)"` più un `<DirectoryMatch
  "/\.git(/|$)">` con `Require all denied`. Lo stesso vale per `.svn`, `.hg`, `.env`.
- **La verifica è da fuori**: `curl -o /dev/null -w '%{http_code}' https://<sito>/.git/HEAD` su ogni
  sito, e insieme la home a 200, per sapere che la regola non ha preso troppo.
- **Le credenziali non vanno nel repository.** Un `config` con le password committato le espone a
  chiunque legga il repo, oggi o fra dieci anni, e ruotarle non le toglie dalla storia: prima del primo
  commit si decide quali file restano fuori ( `.gitignore` più un esempio senza valori ).

### Prima di pushare un repository su un remote

**Misurato il 05/11/2026**, su 34 deploy da portare su GitHub: un `.gitignore` messo il giorno prima
non toglie niente dalla storia, e in 11 repository la storia aveva ancora password MySQL vive,
due chiavi private DKIM, 14 fatture e 3 preventivi di clienti finiti in `tmp/`.

- **Si scansionano HEAD e storia** ( `git log --all -p` ) per tre cose: le password vive, confrontate
  coi valori veri e riportate solo come vero/falso; le `PRIVATE KEY-----`; i documenti ( pdf, xls,
  doc, msg ) nelle cartelle temporanee. ⚠ Le chiavi private stanno quasi sempre nei **fixture delle
  librerie** ( tcpdf, i testdata delle API Google ): 8 repository su 8 scartati a torto da un filtro
  troppo stretto. Si tolgono `_external/`, `vendor/`, `tests/` ed `examples/`, e quello che resta si
  guarda: lì c'erano le chiavi DKIM vere in `etc/secret/`.
- **Ripulire la storia senza `git-filter-repo`** ( che vuole git 2.22 o più ): `filter-branch
  --index-filter 'git rm -r --cached --ignore-unmatch …'`, ma **su un clone `--mirror`**, mai nel
  deploy vivo. Nel deploy filter-branch rifiuta se il working tree è sporco, e i contatori e i log che
  il sito riscrive lo sono sempre; e alla fine fa un checkout che **cancella dal disco** i file appena
  tolti dall'indice, cioè la config del sito. Dal mirror: `fetch` in un ref temporaneo, `update-ref`
  del branch, `reset` ( mixed: tocca l'indice, non i file ), poi `reflog expire --expire=now --all` e
  `gc --prune=now`. La prova è doppia: `rev-list --objects --all` non ha più quei percorsi, e
  l'`md5sum` dei file su disco è uguale a prima.
- Prima di tutto si copia l'intero `.git` in un backup datato, e si dice che quella copia **contiene
  ancora i segreti**.
- ⚠ **Il remote può esistere già.** Prima di crearlo si guarda cosa c'è ( `gh repo view`, poi `git ls-remote` ),
  e se ha commit si clona e si scansiona come la storia locale. Misurato il 12/11/2026: due repository
  da creare c'erano già, fatti la mattina da un'altra sessione con una "fotografia" del deploy senza storia.
  Il push della storia ripulita è stato rifiutato ( non fast-forward ), e una delle due fotografie conteneva
  12 CSV con dati dei clienti, che la storia locale aveva appena tolto. Sostituire un remote è un `push --force`:
  lo decide l'amministratore, e il modo auto dell'harness lo ferma comunque ( `[Git Destructive]` ), quindi
  si prepara uno script da lanciare con `!`. ⚠ Un commit sostituito resta raggiungibile per hash sul server
  finché non lo pota: se era pubblico, si dice.

⚠ **Uno script che fallisce dopo aver fatto il lavoro, se lo rilanci, lo rifà.** Il conteggio finale
usciva con 1 ( `while read …; [[ … ]] && echo` sotto `pipefail` ), lo script terminava zitto, e
sembrava fermo all'inizio. Il backup "parziale" è stato cancellato per ripartire, e conteneva la sola
copia della storia originale. **Prima di buttare un intermedio si guarda se il lavoro c'è già**
( `git log`, il file di destinazione ), e sotto `set -e` i conteggi e i controlli finali portano
`|| true`.

Due trappole della shell, viste nello stesso giro:
- `ssh -T git@github.com` **esce sempre con 1**, anche quando l'autenticazione riesce: con `pipefail`
  `ssh … | grep -q Hi` fallisce sempre. Si cattura l'output in una variabile e si confronta quella.
- un `ssh` dentro `while read … done < elenco` **si mangia lo stdin** del ciclo, e il ciclo si ferma al
  primo giro senza errori: `ssh -n`, o il ciclo su un altro descrittore ( `read -u3 … 3< elenco` ).

### Ruotare una password usata da un servizio vivo

**Successo il 04/11/2026**: uno script cambiava la password sul database e poi la scriveva nei file
di configurazione, con un controllo di coerenza **in mezzo**. Il controllo era sbagliato, lo script si
è fermato dopo il cambio e prima della scrittura, e la password nuova esisteva solo nella sua memoria:
**3 minuti e mezzo** di sito fermo, con un utente al lavoro, e una seconda rotazione per rimediare.

- **Fra il cambio sul server e la scrittura nei client non ci sono controlli che possano fermarsi**:
  tutte le verifiche si fanno **prima** ( quanti file, quante occorrenze, che nessun altro la usi ), poi
  il cambio e la scrittura uno dietro l'altro.
- **La password nuova si salva prima di usarla**, in un file leggibile solo da root nella cartella di
  lavoro: se qualcosa si ferma a metà, la si riprende invece di doverla rigenerare.
- **Si verifica l'effetto, non il comando**: login con la nuova, login rifiutato con la vecchia, e
  l'error log del servizio per gli `Access denied` dei minuti successivi.
- **"Che nessun altro la usi" vuol dire su tutte le macchine, non solo su questa.** Un database
  condiviso fra più server ha utenti condivisi: il 04/11/2026 una rotazione ha aggiornato il sito della
  macchina su cui si lavorava, mentre lo stesso utente lo usava anche un deploy su un altro server. Gli
  import di quel deploy sono rimasti fermi **20 ore**, e dall'altra parte la si è letta come una
  possibile intrusione. Prima del cambio si cerca l'utente nelle config di **ogni** client del
  database ( e se non si vedono tutti, si chiede chi altro lo usa ); dopo, si guarda l'error log anche
  di quei client.
- **La password vecchia si sostituisce sulla riga dell'utente, non in tutto il file.** Misurato il
  09/11/2026: in una config applicativa la stessa password compariva **3 volte**, su tre voci server di
  utenti diversi. Una sostituzione globale della stringa avrebbe scritto la password nuova anche sulle
  altre due voci, e le loro connessioni sarebbero cadute senza che nessun controllo sull'utente ruotato se
  ne accorgesse. Prima si conta quante volte compare la vecchia nel file; dopo, un `diff` delle righe che
  non riguardano l'utente deve uscire vuoto.

### Le copie lasciate accanto all'originale si cercano dal web, non dal disco

Il 04/11/2026, mettendo sotto git 39 siti, la scansione delle credenziali ha trovato
`wp-config.php.pre-mysql02` e `120.mysql.php.pre-mysql02`: copie fatte un mese prima, per una
migrazione del database. **Rispondevano 200 col sorgente in chiaro**, e una conteneva una password
SMTP ancora in uso. I log coprivano solo gli ultimi 8 giorni, quindi un download non si poteva
escludere.

- Il suffisso dopo l'estensione vera fa servire il file come testo, e vale per qualunque suffisso:
  `-dist`, `_bkp`, `.old`, `.pre-qualcosa`. Una regola che blocca solo `.bak` non basta.
- Si chiude con un `RedirectMatch 404` globale, che faccia eccezione quando l'estensione finale
  torna `php`/`js`/`css`/`html` ( `config.inc.php` deve restare servito ). Poi si fa una
  controprova sulle home e su un file `.inc.php` vero.
- Per ogni file si verifica con `curl` dal fuori **e** si conta nel corpo della risposta, non nello
  `stat` sul disco: un 200 può essere la pagina di catch-all di un CMS.
- Si confronta la password esposta con quella in uso **senza stamparla**: si conta l'insieme in
  comune. ⚠ Una sostituzione con `sed` che maschera i valori fallisce in silenzio quando la riga
  non ha la forma attesa, e le password finiscono in chiaro nell'output. Misurato il 12/11/2026: un
  `grep` su una config con una pipe `grep | sed` di maschera ha fatto uscire la password del database,
  perché la riga aveva un'assegnazione con una forma che la regex non prevedeva. Una password stampata
  resta nel transcript e va ruotata. **La maschera si fa in Python, che stampa solo nome e lunghezza
  del valore**, oppure non si stampa niente e si conta.
- Le richieste trovate nei log possono essere le proprie: prima di chiamarle download, si
  confronta l'IP con quello pubblico della macchina.
- ⚠ **Dove altro sta la password si cerca con `grep -rlIF -f FILE`, mai con la password nel comando.**
  Gli argomenti di un processo li legge chiunque sulla macchina ( `ps`, `/proc/<pid>/cmdline` ). Misurato
  l'11/11/2026: un `grep -rlF -- <password> /var/www` è rimasto in `ps` per 12 minuti. Si scrive la
  password in un file con `umask 077` nella scratchpad, poi `shred -u`. Prima si misura l'albero
  ( `du --max-depth=2` ): una `var/` da 7,5 GB di log e dump teneva il `grep` sotto timeout. Con `-I` i
  binari si saltano, la cartella grossa si esclude e la si rifà solo con `--include` sui config, e si
  cerca un percorso per volta col tempo stampato. Il file trovato può essere il config **in uso**: un
  blocco di costanti di un plugin tolto tiene la password vecchia anche dopo che le copie sono sparite.
- ⚠ **`pkill -f <stringa>` uccide anche la shell che lo lancia**, se nella stessa riga c'è la stringa
  ( la riga di comando di `bash -c` la contiene ). Misurato l'11/11/2026: exit 144, e il resto della
  riga non è partito. Un processo si ferma per PID ( `pgrep -f` letto prima, in una chiamata a parte ),
  o col trucco della classe: `pkill -f '[g]rep -rlF'`.

### FTP: solo SFTP, mai in chiaro

**Regola fissa dall'11/11/2026**: niente FTP sulla porta 21, solo SFTP. Su FTP utente e password
viaggiano in chiaro. Misurato quel giorno su un web server: **947 login FTP falliti in una
settimana**, e sulla 21 non c'era nessuna jail.

- **Prima si conta chi lo usa**: proftpd scrive in wtmp ( `last -f /var/log/wtmp* | grep ftpd` ),
  e `xferlog` dice cosa trasferisce. In quel caso c'erano 4 utenti; uno solo era attivo, con 1.223
  trasferimenti in sei mesi e l'ultimo quel pomeriggio. **Chiudere la 21 senza preavviso gli rompe
  il lavoro**: la 21 si chiude *dopo* che l'utente è passato a SFTP, e l'avviso lo dà
  l'amministratore, non la sessione.
- **Se sshd è solo a chiave e gli utenti FTP hanno solo una password**, in sshd la password non si
  riaccende. SFTP lo dà proftpd stesso con `mod_sftp`, su un'altra porta, con le stesse
  credenziali, `DefaultRoot ~` e una jail fail2ban che copra anche quella porta: i fallimenti
  finiscono in `SystemLog` col formato del filtro `proftpd`. Se il firewall del cloud non si può
  toccare da dentro, si usa una porta del range passivo già aperto, togliendola da `PassivePorts`.
- ⚠ **proftpd 1.3.6 non legge le host key nel formato OpenSSH nuovo** ( `BEGIN OPENSSH PRIVATE
  KEY` ). `proftpd -t` dice OK, ma al restart scrive *"Wrong passphrase for this key"* e **non apre
  nessuna porta, nemmeno la 21**, mentre systemd dice `active`: quella volta la 21 è rimasta giù 33
  secondi. Si generano chiavi dedicate con `ssh-keygen -m PEM`, e dopo il restart si guarda
  `ss -ltnp`, non `is-active`.
- La porta si verifica **da fuori**, da un'altra macchina; la jail con un login sbagliato vero e
  `fail2ban-regex`, perché da 127.0.0.1 `ignoreip` non conta niente.

## 3. fail2ban si mette sempre

**Su ogni macchina esposta a Internet fail2ban ci va, e ce lo si mette la prima volta che ci si
mette mano.** Non è una valutazione da rifare ogni volta: è il minimo sindacale, e sta nel lato
"si fa da soli" del confine del punto 8 — è additivo, reversibile, e non cambia il modo in cui le
altre persone usano la macchina.

**Perché, misurato il 23/09/2026**: 25.531 tentativi SSH in undici ore da 440 IP distinti. La
chiave publickey teneva benissimo — il rischio non era l'intrusione — ma il traffico da solo
saturava `MaxStartups` e **chiudeva fuori l'amministratore dalla sua macchina**. È questo il danno
che fa il rumore di fondo quando lo si lascia correre: non entra nessuno, e intanto non entri
nemmeno tu.

⚠ **"Tanto ho solo la chiave, le password sono spente" non è un motivo per non metterlo.** Era
esattamente la situazione di quella macchina, e il problema è arrivato lo stesso. Su un'altra
macchina, anche lei solo a chiave, sshd ha contato **202.310 tentativi falliti e 7.620 ban**. È un
ragionamento che torna fuori da solo — anche un agente di raccolta l'ha riproposto, trovando una
macchina senza fail2ban e concludendo che "tanto non serve" — e va riconosciuto per quello che è.

La ricetta, in tre mosse:

    apt-get install -y fail2ban     # su una Debian EOL i pacchetti stanno su archive.debian.org

`/etc/fail2ban/jail.local` — si scrive questo file, non si modificano i `jail.conf` del pacchetto,
che un aggiornamento sovrascrive:

    [DEFAULT]
    ignoreip  = 127.0.0.1/8 ::1
    bantime   = 86400
    findtime  = 600
    maxretry  = 3

    [sshd]
    enabled  = true
    port     = ssh
    logpath  = /var/log/auth.log
    mode     = normal

Poi **la verifica, che non è `is-active`** ( vedi punto 4 ): si conta quante righe vere il filtro
aggancia, e si guarda che la catena sia in piedi.

    fail2ban-regex /var/log/auth.log /etc/fail2ban/filter.d/sshd.conf   # quante righe matcha
    fail2ban-client status sshd                                        # ban in corso
    iptables -L INPUT -n | grep f2b                                    # catena agganciata
    systemctl is-enabled fail2ban                                      # e riparte al boot

⚠ **`ignoreip` resta il solo localhost.** Mettere l'IP di casa è comodo e sbagliato: gli IP
domestici sono dinamici, e domani si esenta uno sconosciuto. Se ci si autobanna, la via d'uscita è
una riga: `fail2ban-client set sshd unbanip <IP>`.

⚠ **Una whitelist va dove il blocco avverrebbe.** Quando un partner è stato bloccato per errore,
la richiesta naturale è "mettilo nell'`ignoreip`". Ma se fail2ban ha solo la jail `sshd`, l'unico
effetto è esentarlo dal ban per brute force SSH: si allenta una protezione senza dargli niente.
L'esenzione va nel meccanismo che l'aveva colpito ( il `geo` del limite di nginx, la regola del
firewall ), e si dice perché non si è messa altrove.

⚠ **`mode = normal` di default.** L'`aggressive` prende anche i `Connection closed by
authenticating user`, ma può bannare un utente legittimo che chiude in preauth: è un
peggioramento del servizio in cambio di più protezione, quindi **lo decide l'amministratore**.

**Non c'è solo sshd.** Se la macchina espone altro che accetta credenziali — proftpd, postfix,
dovecot, un pannello web, i `wp-login.php` di WordPress — le jail corrispondenti si propongono
nello stesso giro, perché il ragionamento è identico ( per WordPress, vedi il punto 6 ).

**Allo stesso titolo, SSH annuncia solo `publickey`.** È l'altra regola fissa:
`PermitRootLogin without-password` ( alias storico di `prohibit-password` ),
`PasswordAuthentication no`, `KbdInteractiveAuthentication no`. Una password si può indovinare,
una chiave no; fail2ban rallenta chi prova, non lo ferma. Si verifica **da fuori**, che è come la
vede chi attacca:

    ssh -v -o PreferredAuthentications=none -o BatchMode=yes root@<host> true 2>&1 | grep 'can continue'

e deve rispondere `publickey`, nient'altro. Da dentro, `sshd -T | grep -E
'passwordauth|kbdinteractive|permitrootlogin'`, che tiene conto anche dei `Match` e degli `Include`.

⚠ **Qui la regola fissa incontra il confine del punto 8**: spegnere le password chiude fuori chi
entra così. Prima si contano gli accessi a password riusciti,
`zgrep -h 'Accepted password' /var/log/auth.log* | awk '{print $9}' | sort | uniq -c`, e con quel
numero in mano il quando lo decide l'amministratore. Il difetto però si segnala per primo, prima
di ogni altra cosa del giro.

## 3-bis. Gli aggiornamenti: paranoia, non fiducia

**Su ogni macchina gli aggiornamenti di sicurezza si applicano da soli, e a ogni giro si verifica
che sia successo davvero.** È la terza regola fissa, insieme a fail2ban e all'SSH solo a chiave:
detta da Fabio il 04/11/2026, *"dev'essere PARANOICO sugli aggiornamenti"*. Paranoico vuol dire
che **non ci si fida di niente che dica "aggiornato"** — né del servizio attivo, né del pannello,
né del conteggio di `apt` — finché non si è visto il numero.

Il perché sta già nel punto 9 di [intrusione.md](references/intrusione.md): l'ingresso più
probabile di una bonifica era un pannello **non più aggiornabile**, su una distribuzione dove `apt`
annunciava 199 aggiornamenti che non esistevano. Una macchina che non si aggiorna non si difende,
e quasi mai lo dice.

**Si installa la prima volta che ci si mette mano**, senza chiedere: è additivo e sta nel lato "si
fa da soli" del punto 8.

    # Debian / Ubuntu
    apt-get install -y unattended-upgrades apt-listchanges needrestart
    dpkg-reconfigure -f noninteractive unattended-upgrades    # scrive 20auto-upgrades

    # RHEL / Alma / Rocky
    dnf install -y dnf-automatic    # upgrade_type = security, apply_updates = yes in automatic.conf
    systemctl enable --now dnf-automatic.timer

`/etc/apt/apt.conf.d/20auto-upgrades` deve dire, **tutte e due**:

    APT::Periodic::Update-Package-Lists "1";
    APT::Periodic::Unattended-Upgrade "1";

Le personalizzazioni ( la mail, le origini ) vanno in un `52unattended-upgrades-local`, non nel
`50unattended-upgrades` del pacchetto, per lo stesso motivo del `jail.local`. La mail dei giri
falliti va **all'amministratore** ( `Unattended-Upgrade::Mail` con `MailReport "only-on-error"` ),
e si verifica che arrivi: un aggiornamento che fallisce in silenzio è il caso "rileva ma non
consegna" del punto 5.

⚠ **Il riavvio automatico lo decide l'amministratore** ( `Automatic-Reboot` resta `false` di
default ): spegne il servizio a chi lo usa. Ma il riavvio pendente **non si lascia correre**: si
segnala a ogni giro, con da quanti giorni aspetta.

### La verifica, che non è `is-active`

Un `unattended-upgrades` installato e acceso non dice niente: può essere spento da
`20auto-upgrades`, fermo su un lock di `dpkg`, bloccato da un conffile che vuole una risposta,
cieco perché `apt-get update` fallisce. A **ogni** giro, non solo al primo, si guardano sei cose —
la prima passata le fa `triage.sh`, sezione AGGIORNAMENTI:

1. **è acceso davvero**: `apt-config dump | grep Periodic`, e il timer `apt-daily-upgrade.timer`;
2. **ha girato di recente e senza errori**: data dell'ultimo giro in
   `/var/log/unattended-upgrades/unattended-upgrades.log`, e le sue righe `ERROR`/`WARNING`. Più di
   due giorni di silenzio è un sintomo, non una buona notizia;
3. **le liste sono fresche e i repository rispondono**: `apt-get update` senza `Err:`, senza
   `404`, senza `Release file ... is not valid yet` o chiavi GPG scadute. Con le liste vecchie il
   conteggio del punto dopo è falso in tutte e due le direzioni;
4. **gli aggiornamenti di sicurezza pendenti sono zero**: `apt-get -s dist-upgrade`, contando a
   parte le righe che vengono da `-security`. ⚠ **Un aggiornamento di sicurezza pendente da più di
   24 ore è un'anomalia**, e si riferisce **per prima**, prima di ogni altra cosa del giro: vuol
   dire che il meccanismo automatico non funziona, e va capito perché;
   ⚠ **i pacchetti che il giro automatico scarta ogni giorno sono il caso peggiore**: il log dice
   *"non viene aggiornato perché un pacchetto correlato non viene aggiornato o a causa di
   apt_preferences"* ( visto su un desktop il 04/11/2026, `libgl1-amber-dri` ), il resto passa, e
   quel pacchetto resta scoperto per sempre senza che nessun conteggio di errori salga. Si
   cercano nel log a ogni giro, e ognuno si capisce: dipendenza nuova da installare a mano, pin,
   hold;
   ⚠ **lo scarto quotidiano può venire dal pin di un repository del fornitore**, e allora il
   problema non è lo scarto: misurato il 04/11/2026 su un server con un pannello di hosting, il
   pannello fissa a priorità 1000 i suoi `nginx` e `proftpd`, la Debian ha un numero di versione
   più alto ( `1.3.8.c+dfsg-4+deb13u3` contro `1.3.8-1+clp`, un'epoca `1:` sui moduli nginx ) e il
   giro automatico li scarta ogni mattina. `apt-cache policy <pacchetto>` lo mostra in una riga.
   La domanda vera è un'altra: quel repository **non sta negli `Origins-Pattern`**, quindi i
   servizi esposti che ne vengono non si aggiornano mai da soli, e la loro versione va confrontata
   a mano coi rilasci di sicurezza ( lì un `proftpd` 1.3.8 senza le lettere `a`–`c` sulla porta 21 );
   ⚠ **lo stesso numero di versione in due build è un pendente falso, e non si chiude forzando**:
   misurato il 04/11/2026 su un server con un pannello di hosting, `sgml-base 1.31+nmu1` esisteva
   su Debian e sul repository del pannello ( pin 1000 ) con due SHA256 diversi. `apt-get -s
   dist-upgrade` mostrava un `Inst` a versione identica, la storia di apt un `Downgrade: (1.31+nmu1,
   1.31+nmu1)`, `apt-get install -y` si rifiutava senza `--allow-downgrades` e il pacchetto restava
   segnalato "da fare a mano" a ogni giro. Si riconosce con `apt-cache show <pacchetto> | grep -E
   '^(Version|SHA256)'`: due righe uguali di `Version`, due `SHA256`. Forzare l'installazione
   riapre solo l'altalena; si sceglie una build con un pin per quel solo pacchetto in
   `/etc/apt/preferences.d/` ( `Package:` + `Pin: release o=Debian` + `Pin-Priority: 1001`, che
   vince sul pin di origine del pannello ) e si verifica che `Candidate` = `Installed` e che il
   conteggio dei pendenti scenda a zero;
   ⚠ **"di sicurezza: 0" conta solo i repository della distribuzione**: i repository di terze
   parti non hanno l'etichetta `-security`, e quello che sta in `Unattended-Upgrade::Package-Blacklist`
   non lo aggiorna mai nessuno. Misurato il 04/11/2026 su un web server con pannello: 0 di sicurezza,
   ma **117 pendenti di PHP** dal repository del pannello, tutti in blacklist ( con nginx, MySQL e il
   pannello stesso ) da un file `52-local`. Quindi a ogni giro si legge la blacklist
   ( `apt-config dump | grep -A9 Package-Blacklist` ) e si contano i pendenti **per origine**:
   ogni voce della blacklist ha chi la aggiorna a mano e quando, scritto in `/root/READ.md`, o è un
   buco. **Il repository Google `cloud-sdk-<distro>` ( `gcloud` ) va negli `Origins-Pattern`, su ogni
   macchina, senza chiedere** ( Fabio, 11/11/2026 ): è un CLI senza servizio che esce ogni settimana, e
   l'avviso "da fare a mano" era solo rumore. Si scrive in un `52unattended-upgrades-local`; `o=` e `l=`
   si leggono dalla riga `release` di `apt-cache policy`, e la verifica è la riga `Allowed origins` di
   `unattended-upgrade --dry-run -d`. ⚠ **Prima si guarda il nome del pacchetto**: Google ha rinominato
   `google-cloud-sdk` in `google-cloud-cli`, e il vecchio è fermo alla 463 ( gennaio 2024 ). Misurato
   l'11/11/2026: due server su tre lo avevano, nessun pendente e nessun avviso, perché quel nome non ha
   versioni nuove. `apt-get -s install google-cloud-cli` deve togliere solo `google-cloud-sdk`. Gli altri
   repository Google ( `google-compute-engine`, l'agente della VM, che è un servizio ) non ci vanno:
   restano a mano. E se `apt-get update` dice *ha modificato il valore "Origin"* sul repository
   `google-cloud-packages-archive-keyring`, è un cambio di nome di Google: `apt-get update
   --allow-releaseinfo-change` una volta. **Il conteggio lo fa `nerd-esclusi.sh`** ( blacklist, hold, terze parti ), che `install.sh`
   registra come hook di `SessionStart`: se ci sono pendenti, **si dice al sistemista umano nella
   prima risposta della sessione** che vanno fatti a mano, quanti e da dove, anche se ha chiesto
   altro. Non si aggiornano da soli: la finestra la decide lui;
5. **i pacchetti trattenuti hanno un motivo scritto**: `apt-mark showhold` e i `kept back`. Ogni
   hold sta in `/root/READ.md` con il perché e la data; un hold senza motivo è un buco aperto da
   qualcuno che non c'è più;
6. **quello che è stato installato è anche in uso**: `/var/run/reboot-required` ( e `.pkgs` ),
   il kernel in esecuzione contro il più recente in `/boot`, e i servizi che girano con librerie
   vecchie ( `needrestart -b`, o i file `(deleted)` che vede `hunt.sh` ). ⚠ **Una patch installata e
   non caricata non è applicata**: un `sshd` o un `php-fpm` partito prima dell'aggiornamento di
   OpenSSL è vulnerabile come prima. I servizi si riavviano da soli quando non tolgono niente a
   nessuno ( un `reload` ); il riavvio della macchina lo decide l'amministratore.

### Fuori dal gestore dei pacchetti, la paranoia raddoppia

`unattended-upgrades` aggiorna solo quello che è passato da `apt`. Tutto il resto **non lo aggiorna
nessuno finché qualcuno non lo scrive**: pannelli ( CloudPanel, Plesk ), WordPress con core,
plugin e temi, `composer`, `pip`, `npm`, `snap`, immagini Docker, binari in `/usr/local/bin`,
repository di terze parti ( PHP di Sury, MariaDB, Node ). Al primo giro su una macchina:

- **si fa l'inventario** di ciò che è installato fuori da `apt`, e per ciascuno **chi lo aggiorna
  e come**: va in `/root/READ.md`. Una riga *"nessuno"* è una risposta accettabile solo se è scritta
  e l'amministratore l'ha letta;
- per WordPress vale il punto 6: con `DISALLOW_FILE_MODS` gli aggiornamenti li fa lo script
  notturno, e **si verifica che giri** ( `wp core check-update`, `wp plugin list --update=available` ).
  ⚠ Misurato il 05/11/2026: l'updater scartava lo stderr di `wp` e leggeva l'output vuoto come
  "gia' aggiornato"; su 4 siti su 35 `wp` andava in fatal col PHP di sistema più vecchio di quello
  del sito, e i siti non si aggiornavano senza che il riepilogo lo dicesse. `wp` si lancia col PHP
  del pool del sito, e un sito che `wp` non carica si conta come **fallito**, non come aggiornato;
- i repository di terze parti si guardano come quello di sicurezza: se la loro chiave scade o il
  repository chiude, `apt` lo dice con un `W:` che nessuno legge.

**Un pacchetto costruito a mano si conserva insieme alla macchina.** Misurato il 10/11/2026: un backport
di PHP fatto in casa, installato su un server il 23/10, andava portato su un secondo server, e i `.deb` non
c'erano più ( la cartella di appoggio era stata tolta come file fuori posto ). Si ricostruiscono dai
pacchetti installati con `dpkg-repack <pacchetto>`, ma **prima** `dpkg -V <pacchetto>` deve uscire pulito,
se no si impacchettano anche i file modificati a mano. La prova che il risultato è lo stesso è l'impronta
del binario che conta ( lì `libphp7.3.so` ) uguale sulle due macchine. I `.deb` poi vanno in
`/var/backups/AAAAMMGG-<pacchetto>-deb/` con `SHA256SUMS`, e il percorso va nel `READ.md`.

### Quello che non si fa da soli

Il passaggio di versione della distribuzione, e quello di un pannello o di un PHP maggiore, **si
preparano** ( punto 9 di `intrusione.md`: l'upgrade simulato in un'area separata ) e li decide
l'amministratore. Ma la **data di fine supporto** si riferisce a ogni giro col conto dei mesi che
restano: sotto i sei mesi, è una voce di sicurezza aperta.

## 4. "active" non è una verifica

`systemctl is-active` dice che il processo gira, **non** che sta facendo il suo lavoro. Un
fail2ban avviato con un filtro che non aggancia niente è indistinguibile, da fuori, da un
fail2ban che sta proteggendo la macchina — e dà la stessa identica falsa tranquillità.

Per ogni cosa messa in piedi, la domanda è: **qual è la prova che funziona?**

| messo in opera | la prova che funziona |
|---|---|
| fail2ban | `fail2ban-regex <log> <filtro>` conta i match sulle righe vere; poi `fail2ban-client status <jail>` e la catena `f2b-*` in `iptables -L INPUT` |
| una direttiva sshd | `sshd -T \| grep <direttiva>`, che stampa il valore **attivo**, non quello scritto nel file. ⚠ Se c'è un blocco `Match`, gli OpenSSH più vecchi non stampano niente senza `-C user=root,host=localhost,addr=127.0.0.1`: un `grep` vuoto non vuol dire "direttiva assente" |
| una regola di firewall | i contatori `pkts/bytes` di `iptables -L -n -v` che salgono |
| un cron | la riga nel log al primo giro utile, non la crontab che lo contiene |
| un file di log nuovo ( `error_log` di un pool FPM, di un'app ) | che **esista e cresca**, scritto dall'utente del processo: misurato il 05/11/2026, 8 pool PHP puntavano in `/var/log/apache2/<sito>/`, dove www-data non entra ( 750 root:adm ), e i fatal sparivano senza un errore. Si prova con `runuser -u <utente>` e si controlla la catena di cartelle, non solo il file |
| la posta di sistema via smarthost | il mittente **di busta** nella riga `<=` del log dell'MTA, che deve stare in un dominio il cui SPF copre lo smarthost. Misurato il 05/11/2026: i server uscivano dallo smarthost giusto, ma con la busta sul nome interno del cloud ( `host.c.<progetto>.internal` ), che non ha SPF, e i rapporti DMARC li davano tutti come falliti. "Consegnata allo smarthost" non vuol dire "accettata dal destinatario" |
| una firma DKIM | `opendkim-testkey -d <dominio> -s <selettore> -vvv` **prima** di consegnare i record da pubblicare, e di nuovo dopo. ⚠ Misurato il 05/11/2026: l'`opendkim-genkey` di Debian 11 ( 2.11.0~beta2 ) scrive nel TXT `h=rsa-sha256`, che non è un valore valido ( RFC 6376 vuole `h=sha256` ): 26 record pubblicati così, `testkey` risponde `unknown hash`, i destinatari scartano la firma, e il giro che accende la firma solo a record trovato restava a 0 domini. Si corregge il `.txt` prima di darlo a chi pubblica |
| un servizio al boot | `systemctl is-enabled`, che è una domanda diversa da `is-active` |
| un `limit_req` di nginx | una raffica di prova da un IP finto che deve prendere 429 dopo il burst, un IP in whitelist che deve passare tutto, **e la riga `limiting requests` nel log**. ⚠ Con `limit_req_log_level warn` e l'`error_log` al livello di default ( `error` ) i blocchi non si vedono: il limite lavora e nessuno lo sa |
| un allarme nuovo | un modo `prova` che lo **dichiara nel testo** del messaggio. ⚠ Forzare la soglia a mano ( `SOGLIA=0` ) manda un allarme vero, indistinguibile da un'emergenza: è successo, e ha richiesto una smentita |
| un allarme di uptime su molti siti | la caduta **di un server intero**, non di un sito solo: deve arrivare **una** mail quando il gruppo ( il deploy, il server ) passa da tutto su a giù, e una quando torna tutto su, col downtime; niente in mezzo. Misurato l'08/11/2026: 41 siti sullo stesso server esterno, tre cadute in un giorno, una mail per sito a noi e al referente del cliente |
| un allarme | il messaggio **ricevuto**: si provoca la condizione una volta e si guarda il telefono, non il log dello script |
| i certificati | `certbot renew --dry-run` che elenca **tutti** quelli attesi; il "success" del timer riguarda solo quelli che ha letto |
| una correzione a uno script che si reinstalla da solo | il giro **dopo** quello atteso: il primo esegue ancora la copia vecchia, che poi installa la nuova |
| uno scanner di malware | un file di prova che deve trovare: zero riscontri può voler dire che non sta guardando. E firme aggiornate: uno scanner che non può scaricarle è teatro, e si spegne **dichiarandolo**. ⚠ Su una distribuzione a fine vita il CDN di ClamAV rifiuta il freshclam vecchio ( "Blocked by CDN", misurato su buster con 0.103 il 03/11/2026 ) e i .deb ufficiali 1.4 vogliono glibc 2.30: si controlla `objdump -T libclamav.so* | grep GLIBC_` **prima** di proporlo ; la via d'uscita senza cambiare ClamAV è **cvdupdate**, lo strumento ufficiale per i mirror, che il CDN non blocca: misurato l'11/11/2026, la 0.103.9 carica le sue firme ( 3.627.817, EICAR trovato ). Su Python 3.7 vuole i wheel di `importlib-metadata` 6.7, `dnspython` 2.3, `packaging` 24.0; le firme si verificano con `sigtool --info` prima di copiarle in `/var/lib/clamav` . **Su ogni macchina con siti si mette la scansione periodica dei webroot** ( Fabio, 11/11/2026 ): `scripts/clamav-firme.sh` e `scripts/clamav-scansione.sh`, in `/usr/local/sbin/` con un cron ciascuno. Incrementale ogni notte sul **ctime** degli ultimi 2 giorni, completa la prima domenica del mese, fuori le copie nostre ( backup, `.git`, log ) e **solo i file di codice** ( php, js, html, svg, script, `.htaccess`, senza estensione ): misurato l'11/11/2026, su un web server l'incrementale di 2 giorni erano 400 mila file, 190 mila immagini, e `clamscan` fa ~3 file/s sui file misti contro ~43 sui php: più di 30 ore contro un'ora. Un tetto `timeout 5h` che, se scatta, lo dice. `clamscan` carica **~1 GB** di firme ( misurato: RSS 997 MB ): lo script salta sotto 1500 MB disponibili e lo dice, invece di mandare la macchina in OOM. Avvisa solo per riscontri o errori, e non sposta niente: la quarantena la decide una persona |
| una regola di auditd | che `audit.log` copra ore, non minuti: in `ls -la /var/log/audit/` gli archivi **timbrati tutti allo stesso minuto** vogliono dire che una regola registra rumore e cancella il resto |
| un backup | il ripristino di prova, qui sotto |
| blocco di percorsi applicativi ( `.htaccess`, WAF ) | **prima** del blocco, i log di accesso: chi li chiama con un `Referer` interno è il gestionale stesso, non uno scanner; **dopo**, la prova da un IP esterno ( l'IP del server stesso passa le eccezioni locali ) con e senza sessione. Il 26/10/2026 il blocco dei `/task/` di un deploy ha fermato la numerazione fatture, chiamata via AJAX; la cliente se n'è accorta 9 giorni dopo. ⚠ Misurato il 09/11/2026: l'eccezione per *chi ha il cookie di sessione* ( `RewriteCond %{HTTP_COOKIE} PHPSESSID=…` ) non è un controllo, perché il cookie lo sceglie il client, e da fuori un `PHPSESSID` inventato faceva girare i task. Si lasciano aperti per nome solo i percorsi che i log mostrano chiamati dal browser, e la condizione si scrive su `%{THE_REQUEST}`, non su `%{REQUEST_URI}`: in un `.htaccess`, dopo la riscrittura interna verso il file, le regole ripassano col percorso nuovo e l'eccezione non vale più. Si prova da fuori con un task che senza parametri non scrive |

Nel caso originario la verifica di fail2ban è stata `fail2ban-regex` sulle ultime 3000 righe di
`auth.log`: **361 agganciate**. Senza quel numero si sarebbe potuto dire soltanto "l'ho
installato".

⚠ **Anche la verifica può mentire, nel verso opposto.** Con `set -o pipefail`, `cmd | grep -q X`
o `grep -m1` esce appena trova, `cmd` muore di SIGPIPE e la pipeline risulta **fallita proprio
quando il match c'è**. Misurato il 12/11/2026: `unattended-upgrade --dry-run -d | grep -m1 'Allowed
origins' | grep -o ...` stampava l'origine giusta e subito dopo "KO: non compare". Negli script con
`pipefail` l'output si salva in un file e si fa il `grep` sul file.

⚠ **Quello che fallisce in silenzio è quello da cui guardarsi**, e ogni riga della tabella nasce da
un caso vero. Sei certificati sono arrivati a scadenza perché le loro conf, importate da una
macchina con un certbot più recente, venivano **saltate senza un errore** mentre il timer
riportava successo per gli altri. Uno scanner costruito su link simbolici ha dato zero riscontri
per settimane: non li seguiva. Uno strumento aggiornato in `/usr/local/bin` lasciando la copia
vecchia in `/usr/bin` va bene per chi lo chiama per nome, ma chi lo chiama per percorso assoluto
( monit, un cron ) continua a usare quella vecchia. E un auditd appena installato copriva **gli ultimi
due o tre minuti**: una regola sulla *lettura* dei flag dei file scattava **~6.900 volte** a ogni
giro della sentinella che doveva proteggere, e sovrascriveva tutto il resto. Si audita quello che
l'attaccante fa, non quello che si guarda.

**Un backup vale il ripristino che si è provato.** Uno mai ripristinato è un'ipotesi. Su una
macchina con decine di siti WordPress il "backup", a guardarlo, erano **solo i dump del database
fatti prima degli aggiornamenti** — niente file, niente `wp-content` — e il collegamento allo
storage esterno era configurato ma **nessun cron lo chiamava**: configurato, mai girato. Sulle
macchine guardate per scrivere questa skill, **nessuna traccia di una prova di ripristino**. Per
ogni backup le domande sono quattro:

| domanda | perché |
|---|---|
| cosa contiene? file **e** database, o solo uno dei due? | un dump senza i file ricostruisce un sito vuoto |
| dove sta? | se sta sulla stessa macchina, muore con lei — e con l'attaccante che la controlla |
| quando è l'ultimo? | la data del file più recente, non la riga del cron |
| quando lo si è ripristinato l'ultima volta, e dove? | è l'unica che dice se funziona |

Se l'ultima risposta è "mai", va nel `TODO.md` come rischio aperto, non come cosa fatta.

⚠ **Un dump dei database è un backup solo se è fedele, completo e controllato.** Misurato il
05/11/2026 su un server di database con 31 basi: l'ultimo dump completo aveva un anno, e lo script
pensato per farlo passava da un export *ripulito* per i cloni di sviluppo ( via gli `AUTO_INCREMENT`,
`DEFINER` riscritti ), non guardava il codice d'uscita di `mysqldump` dentro la pipe e appoggiava
tutto in chiaro in `/tmp`. Quindi: `--single-transaction --routines --triggers --events --hex-blob`,
un file per database, `PIPESTATUS` più la riga finale `-- Dump completed` come prova, impronte in un
MANIFEST da ricontrollare dopo la copia.
- **Una vista rotta ferma tutto il dump di quel database** ( errore 1356 ), e senza un controllo il
  file troncato passa per buono. Al primo giro una base su tre provate era in quello stato. Si segnala
  l'errore e si riesporta con `--force` in un file marcato come forzato: i dati sono salvi e il
  problema non sparisce.
- **Il dump deve seguire il database quando si sposta.** Misurato il 06/11/2026: un database spostato
  su un altro server a inizio ottobre, e il dump notturno ancora puntato sul MySQL locale. Per **un mese**
  `mysqldump` ha dato 1049 dentro una pipe senza `pipefail`, `gzip` ha scritto un file vuoto che passava
  `gzip -t`, e la rotazione ha sostituito ogni notte i dump buoni con quelli vuoti. Il segno c'era: **tutti
  i file della stessa dimensione al byte** ( 386 ). Lo script ora prende server e credenziali dalla config
  dell'applicazione, fallisce con `pipefail`, e pota i vecchi dump solo dopo un dump riuscito.
- **La retention parte solo se ogni database ha i suoi dati**, ma un database forzato i dati li ha. Se
  la retention aspetta un giro senza errori, una vista che resta rotta la blocca per sempre e il disco
  si riempie.
- **Il ripristino di prova su un'altra macchina si ferma sulle viste**, perché gli utenti `DEFINER`
  non esistono lì: le tabelle e i conteggi tornano ( 248 su 248 ), le viste no. Si ripristinano prima
  gli utenti ( il dump di `mysql` ), oppure si prova sul server di origine con un nome di prova.
- **Una cartella copiata a mano nel datadir è un database per `SHOW DATABASES`, ma non per InnoDB.**
  Trovato il 06/11/2026 su un MariaDB 10.3: una copia di file `.frm`/`.ibd` di un altro server, messa
  nel datadir un anno e mezzo prima e di `root:root`, falliva ogni notte nel dump con l'errore 1932
  *doesn't exist in engine*. Nessuno se n'era accorto finché il dump non è diventato severo. Prima si
  controlla che nessun client la usi, poi si fa un `tar` della cartella fuori dal datadir. Il
  `DROP DATABASE` va in tre passi: `chown -R mysql:mysql` ( se no, errore 6 *Permission denied* ),
  `DROP` ( toglie le tabelle registrate e i `.frm`, ma si ferma con l'errore 39 *Directory not empty* ),
  poi si spostano a mano gli `.ibd` rimasti, che InnoDB non conosce, e si rilancia il `DROP`. Gli `.ibd`
  non si spostano mai **prima** del `DROP`: quelli registrati lascerebbero il dizionario sporco.

## 5. Accorgersene: un allarme vale quello che arriva e che viene letto

Le difese servono poco se nessuno se ne accorge quando cedono. Tre modi visti in cui il
monitoraggio c'era e non è servito:

- **Rileva ma non consegna.** Uno script di controllo scriveva solo su file e syslog, e un
  commento spiegava che "da questa macchina posta e Slack non escono": era vero mesi prima, non
  più, e nessuno l'aveva riverificato. In un incidente il controllo ha visto l'infezione **in
  un'ora**; le persone l'hanno saputo **sei ore dopo**, e dall'avviso del plugin del sito, non da
  quello di sistema.
- **Un rimedio d'emergenza che resta.** Per svuotare una coda di 12.540 messaggi ( bounce di
  `www-data` ) la posta di root era stata mandata a `:blackhole:` in `/etc/aliases`; misurato il
  05/11/2026, tre settimane dopo era ancora lì: circa 6 messaggi al giorno di cron e aggiornamenti
  buttati, su una sola macchina della flotta. Si tappa il rubinetto che allaga ( lì `www-data` ),
  non la posta di root; e a ogni giro si guarda dove va root ( `triage.sh` lo dice ), con una
  prova che arriva e la busta nel dominio giusto ( punto 4 ).
- **Dice sempre la stessa cosa.** Un controllo che segnalava 2 file fuori posto il 10 del mese ne
  segnalava 19 il 23: nessuno lo leggeva più, perché "è quello solito". Un allarme noto si
  risolve o si toglie; lasciarlo suonare insegna a ignorare anche quello vero. Una sentinella con la
  lista di riferimento fotografata **un minuto prima** di installare gli strumenti li ha segnalati
  ogni quindici minuti per dodici ore: **un allarme ripetuto si chiude entro la giornata**, e le
  liste si verificano al momento del controllo, non si congelano.
- **Avvisa senza secondo parere.** Misurato il 06/11/2026: un controllo di uptime su due server ha mandato
  **123 mail in 17 ore**, 57 down su 61 visti da un server solo e mai confermati dall'altro, che pure li
  controllava ma non consegnava la sua vista in tempo. La mail parte solo per un down **confermato** da un
  secondo punto di osservazione; quello non confermato va nel registro, e il server rimasto senza secondo
  parere avvisa una volta al giorno. ⚠ Prima di chiamarlo falso positivo si guarda l'access log del sito
  nei minuti del down: lì due episodi su tre erano veri ( zero richieste servite, `MaxRequestWorkers`
  pieno ), e la causa era il server, non il controllo.
- **Costa più di quanto protegge.** AIDE puntato anche sui webroot: **dieci ore al 90% di CPU** su
  una macchina già carica. Una sorveglianza che degrada il servizio prima o poi qualcuno la spegne;
  allo strumento di sistema il perimetro di sistema.
- **Guarda solo i file.** Un account di amministratore rubato è entrato **40 volte da 26 IP
  diversi in cinque settimane** senza toccare un file: invisibile a qualunque controllo di
  integrità. L'ha trovato una guardia sugli **accessi** — IP, paesi, orari nuovi per lo stesso
  account — interrogando il registro dei login del plugin di sicurezza.

⚠ **La segnalazione del cliente è un sensore.** Su una macchina compromessa per **tredici mesi**
l'hanno scoperta tre segnalazioni indipendenti in due giorni — spam nei risultati di Google, un
plugin attivato da nessuno — non quattro livelli di monitoraggio. Si ascoltano anche le ipotesi
tecniche sbagliate: descrivono **dove si vede**.

⚠ **Una baseline rigenerata ogni notte da zero fotografa l'infezione come stato buono.** Il
controllo di integrità si riallinea da solo solo sui percorsi che conosce già; un percorso
comparso dal nulla ( un plugin, un file in `.well-known/` ) si segnala, e lo accetta una persona.
E la baseline deve coprire anche `wp-content/plugins/`: quella che guardava solo il core non ha
visto un plugin malevolo installato.

⚠ **Il disco si riempie di log, non di backup**, e servono due guardie: una per **età** e una per
**dimensione**. Un solo log applicativo è cresciuto di **122 GB in una notte**, e nessuna
retention per età lo avrebbe visto prima del disco pieno.

**La mattina** si guarda poco e sempre lo stesso: gli allarmi arrivati, e quelli che *avrebbero
dovuto* arrivare — un controllo che tace da giorni è un sintomo, non una buona notizia — poi
spazio, ban, accessi riusciti. La prima passata la fa `triage.sh`.

## 6. WordPress dietro un pannello: cosa ha bucato davvero, cosa ha fermato

Dalle cartelle di incidente di una macchina con **37 siti WordPress** su nginx e PHP-FPM, gestiti
da un pannello di hosting ( CloudPanel ), luglio–settembre 2026. È la parte che costa di più
imparare dal vivo.

**Da dove sono entrati.** Nessun brute force: **zero tentativi falliti** nei log dei siti colpiti.

- **Credenziali di amministratore già in mano all'attaccante**, rubate fuori dalla macchina — una
  postazione, un'agenzia. Cambiare la password del sito non basta se la fuga a monte resta aperta.
- **Il pannello stesso.** Il suo pacchetto installa in `/etc/sudoers.d/` una riga che permette a
  **tutti gli utenti** di lanciare come root un suo wrapper: da un utente web compromesso a root,
  e da lì **28 siti su 38** modificati insieme, con lo stesso file del core, uno che nessuno
  controlla, sovrascritto su tutti. ⚠ Un aggiornamento del pacchetto può rimettere quella riga:
  le invarianti di privilegio ( `sudoers.d`, gruppo `sudo`, UID 0, `/etc/ld.so.preload`,
  `PasswordAuthentication` ) si sorvegliano con un controllo che gira, non si sistemano una volta.
  ⚠ Il pannello è superficie anche come codice: su un'altra macchina la sua **pagina di login**
  caricava una libreria JavaScript con un loader accodato che rubava le credenziali a chi le
  digitava, e due webshell stavano nelle cartelle `examples/` di uno strumento incluso. Le sue
  cartelle di esempio, `vendor/` e gli asset statici si guardano per primi.

**Cosa ha fermato e cosa no.** Con l'admin rubato l'attaccante ha provato l'editor dei temi ( 403,
fermato dall'hardening ) e il caricamento di un plugin ( 500 ); poi ha **disattivato il plugin di
sicurezza**, e tre ore dopo ci è riuscito. Quello che dalla bacheca non si spegne è una riga di
`wp-config.php`:

    define( 'DISALLOW_FILE_MODS', true );   // niente installazioni, aggiornamenti né editor da bacheca

Al momento dell'incidente era attivo su **2 siti su 37**. Il prezzo è che gli aggiornamenti si
fanno da `wp-cli`, di notte, con uno script che toglie il blocco, fa un dump del database,
aggiorna, rimette il blocco e riallinea il controllo di integrità. ⚠ Il pannello non lo fa di suo,
e nemmeno il backup: il suo era vuoto, dato per scontato.

**Nascondersi dalla bacheca.** Il plugin malevolo si toglieva dall'elenco con un filtro su
`all_plugins`: invisibile in bacheca **e** a `wp plugin list`, visibile solo nell'opzione
`active_plugins` del database e sul disco. Quindi **l'inventario si fa dal filesystem e dal
database, mai dall'interfaccia del sistema che si sta controllando**. Lo stesso per i file:
webshell in percorsi che sembrano di servizio — cache, cartelle temporanee degli aggiornamenti,
`.well-known/`, un nome esadecimale dentro un plugin vero — e un'intestazione PNG scritta **come
testo** per passare i controlli sui magic byte. `wp core verify-checksums` è necessario e non basta:
un `auto_prepend_file` scritto da root nei `php.ini` ha infettato **tutti i siti insieme** con core,
plugin e webroot perfettamente integri.

**La quarantena batte la disattivazione.** Un plugin per rubare credenziali non si è mai attivato
per un errore dell'attaccante, ma la webshell nella stessa cartella è stata eseguita lo stesso con
una richiesta diretta: un file PHP raggiungibile via HTTP è attivo, che WordPress lo consideri tale
o no. Si sposta fuori dalla document root togliendo ogni permesso — e **prima** si copia tutto in
la cartella dell'incidente, `/root/incidenti/AAAAMMGG-nome/` ( evidenze, log, cosa si è fatto e quando ), perché la relazione si
scrive dopo, e senza quella non si impara niente.

**nginx: quello che va in uno snippet comune a tutti i siti**, non sito per sito, perché la
disciplina del singolo sito è esattamente quello che è mancato:

| blocco | perché |
|---|---|
| niente PHP sotto `wp-content/uploads/` | è il posto preferito per le webshell, e lì non c'è mai PHP legittimo |
| `xmlrpc.php` negato | un brute force che prova centinaia di password in una richiesta, più i pingback |
| `debug.log` negato | un solo sito con `WP_DEBUG` acceso serviva a chiunque **636 KB** di log: 1.400 percorsi assoluti e 600 frammenti SQL |
| `limit_req` su `wp-login.php` | rallenta i tentativi prima ancora che fail2ban li veda |

E fail2ban sui log di nginx, con jail per i tentativi su `wp-login.php`, le scansioni in cerca di
webshell e le ricognizioni. Dopo ogni modifica, `nginx -t` e poi una richiesta vera che deve
prendere il 403 ( punto 4 ).

⚠ **Un sito che arriva da apache porta protezioni che nginx non legge.** Misurato il 12/11/2026,
spostando un sito: la cartella protetta con `.htaccess` + `.htpasswd` su nginx sarebbe stata aperta,
e il `.htpasswd` scaricabile. La basic auth va nel vhost, e con **`location ^~ /cartella/`**: nel vhost
di CloudPanel la regex statica ( `\.(css|js|gz|zip|…)$` ) vince su un prefisso normale, e l'archivio
dentro la cartella uscirebbe senza password. ⚠ E la prova non si fa nel secondo dopo il `reload`:
`systemctl reload nginx` torna prima che i worker vecchi escano, e lì le prime richieste hanno
risposto 206 con una password sbagliata. Pochi secondi dopo, le stesse richieste davano 401.

**Con Varnish in mezzo, il limite per IP va sul backend.** La catena tipica di questi pannelli è
nginx `:443` → Varnish → nginx `:8080` → PHP-FPM. Un `limit_req` sul fronte conta anche le pagine
servite dalla cache, che non costano niente; sul server `:8080` conta solo quelle fuori cache,
cioè quelle che arrivano a PHP e MySQL. Due condizioni:

- l'IP del client si legge da un header che **il fronte riscrive sempre**, come `X-Real-IP
  $remote_addr`, mai da `X-Forwarded-For`, che con `$proxy_add_x_forwarded_for` si porta dietro
  quello che il client ha scritto;
- la porta del backend **non deve essere raggiungibile da fuori** ( `ufw status`, e una prova
  sull'IP pubblico ), altrimenti chiunque si scrive l'header che preferisce.

La whitelist ( il server stesso, che chiama WordPress in loopback; i motori di ricerca; i lettori
di feed dei partner ) si fa con un `geo` sull'header, e i feed conviene esentarli per percorso.

**La posta dei siti: per DMARC conta il From, non la busta.** Misurato il 05/11/2026: con la busta
già riscritta nel dominio del sito ( `sender_canonical` di postfix, SPF pass ), 8 mail in dieci giorni
fallivano DMARC sul dominio dell'agenzia, perché WPForms ( riepilogo settimanale, notifiche ) e
WooCommerce mettono nell'header `From:` l'`admin_email`, che era quello dell'agenzia su 35 siti su 36.
Il pannello e la busta non lo vedono; si cercano con una query sulle opzioni ( `admin_email`,
`woocommerce_email_from_address`, `wpforms_settings` ). Si chiude con un mu-plugin comune che filtra
`wp_mail_from` a priorità `PHP_INT_MAX` ( dopo i plugin ) e tiene l'originale come `Reply-To`. Si prova
**senza spedire niente**: un `wp eval-file` che aggancia `phpmailer_init`, stampa `From` e `Reply-To`
e lancia un'eccezione. ⚠ Se `wp` fallisce con *"Composer detected issues in your platform"*, il PHP a
riga di comando è più vecchio di quello del sito: `php8.3 $(command -v wp)`, e vuol dire che anche gli
script notturni con `wp` su quel sito stanno fallendo.

**Un'impostazione cambiata da `wp-cli` si rilegge da un processo nuovo.** Misurato l'11/11/2026, spegnendo i riepiloghi via mail di un plugin di backup su 15 siti: su una versione vecchia del plugin il setter cambia solo l'oggetto in memoria e non salva ( serve `save()` esplicito ), e nello stesso processo la rilettura diceva *"fatto"*. Il secondo giro, con un `wp eval-file` separato, ha trovato il sito rimasto com'era. Si controlla anche il cron di WordPress ( `_get_cron_array()` ): il cambio di frequenza non sempre toglie l'evento già in coda.

**Un file nuovo e legittimo sotto sorveglianza si aggiunge alla baseline solo col suo percorso.** Un mu-plugin messo su tutta la flotta compare come *"percorso nuovo"* in ogni sito sorvegliato. Rigenerare la baseline intera lo zittisce, ma assolve insieme tutto quello che in quel momento è diverso. Si fa la copia della baseline, si accodano solo le righe `sha256sum` dei file appena messi e si controlla che il confronto non li segnali più.

⚠ **Le chiavi SSH di root sono una superficie.** Su un solo host **57 chiavi autorizzate** ( 15 su un'altra, molte di macchine dismesse ), fra
portatili e telefoni personali, senza un nome né una scadenza: una qualunque di quelle macchine
persa è una porta aperta, ed è uno dei canali più plausibili della fuga di credenziali. Si
contano, ognuna deve avere il proprietario nel commento, e quelle senza si propongono per la
rimozione — che decide l'amministratore, perché toglie l'accesso a qualcuno.

## 7. Quando è davvero un'intrusione

Quando i segni smettono di essere rumore di fondo — un binario che nessun pacchetto dichiara, un
processo che si finge thread del kernel, un `auto_prepend_file` che nessuno ha scritto — il giro
cambia natura, e i primi gesti decidono se si impara qualcosa o si ripulisce di nuovo la settimana
dopo. Il riferimento completo è **`references/intrusione.md`**, nato da una macchina compromessa a
livello root per **tredici mesi** senza che nessuno se ne accorgesse: si apre adesso, non dopo. La
caccia in sola lettura la fa `scripts/hunt.sh`.

⚠ **Non si uccide niente prima di aver bloccato l'uscita e cercato il guardiano.** L'ordine è:
regola di firewall **in uscita** verso chi comanda l'impianto; evidenze copiate nella cartella
dell'incidente ( `/root/incidenti/AAAAMMGG-nome/`, punto 0-bis ), con lo `stat` completo; persistenza disarmata ( timer, service, generatori systemd,
regole udev, cron ); flag immutabili tolti e file rimossi; **per ultimi** i processi. In quel caso,
alla prima uccisione l'impianto è rinato — ed è così che si è trovato lo strato di un anno prima.
Se qualcosa torna, non è un fallimento: è un'informazione.

⚠ **Il lavoro non finisce alla prima cosa trovata.** Quattro strati in una sera, e ogni volta
sembrava finita. Dopo ogni ritrovamento la domanda è *"questo come ci è arrivato?"*, finché la
risposta è "da qui" e non "boh".

⚠ **Un archivio tolto non vuol dire un kit tolto: si cerca anche la sua copia già estratta.** Il
03/11/2026 si è messo in quarantena l'archivio auto-estraente di una backdoor ( tor + dropbear sulla
50022 ) cercando le firme delle webshell PHP; due giorni dopo, una scansione per tipo di file ha
trovato **accanto, in una cartella nascosta, lo stesso kit già estratto**: binari ELF, librerie,
torrc, finiti pure nel primo commit del deploy. Dentro una document root si cercano **i binari ELF
e le cartelle che iniziano con un punto**, non solo il PHP, e ogni pezzo trovato si cerca poi su
tutta la macchina per impronta, dimensione e nome.

⚠ **`XPATH syntax error` in un log MySQL applicativo è l'impronta di una SQL injection error-based**
( `EXTRACTVALUE`/`UPDATEXML`, il valore estratto torna dentro il messaggio d'errore ). Misurato il
12/11/2026 su un sito PHP vecchio: 1.684 richieste con payload in due settimane, e l'unico segno
visibile erano quegli errori nel log dell'applicazione. Per sapere fin dove è arrivato l'attaccante si
legge cosa ha estratto ( `SCHEMATA`, `COLUMNS`, poi le righe ), e si conta l'esposto con `COUNT`, senza
leggere il contenuto. Il contenimento più rapido, finché il codice non si corregge, è una regola nel
vhost che dà 403 ai parametri numerici non numerici e agli apici. Prima di metterla si simula sul log:
lì ha fermato 1.937 attacchi su 1.937, ma ha dato 403 anche a 276 ricerche legittime con l'apostrofo.

**Si cerca per tecnica, non per nome.** Gli indicatori di un attaccante scadono in mesi, i
nascondigli no: eseguibili nelle directory di sistema che nessun pacchetto dichiara ( chiesto a
dpkg **in quel momento**, con usrmerge gestito ), generatori systemd, regole udev, flag immutabili,
`/dev/shm`. Il `ctime` non si falsifica con `touch`, ed è il dato che ricostruisce la cronologia.

**Il sintomo può esistere solo per chi non sei tu.** Un cloaking serve lo spam soltanto ai bot dei
motori di ricerca e a un profilo preciso di visitatori: un sito "che a me risponde bene" non prova
niente. Si prova con lo user-agent del bot, e `http://` separato da `https://`.

**Una sorveglianza nuova si verifica come tutto il resto** ( punto 4 ). Appena installata, lì,
auditd copriva gli ultimi tre minuti e la sentinella ripeteva un falso allarme ogni quindici: **un
controllo nuovo si prova che registri davvero, e un allarme ripetuto si chiude entro la giornata**.
È la differenza fra sorveglianza e teatro. Il confine del punto 8 resta: bloccare l'uscita e
copiare le evidenze si fa da soli; spegnere un sito, togliere accessi e ruotare le credenziali degli
altri lo decide l'amministratore, con i numeri in mano. E quello che non si può ricostruire perché
non era registrato si dice ( punto 11 ).

## 8. Il confine: cosa si fa da soli, cosa decide l'amministratore

Questo è il punto su cui la skill esiste. Quando arriva un **"fai quello che puoi fare"**, non
vuol dire "fai tutto": vuol dire *fai il massimo di quello che non richiede una mia decisione, e
il resto scrivilo*.

**Si fa da soli** quando l'intervento è reversibile, non cambia il modo in cui le altre persone
usano la macchina, e non allenta niente: alzare un limite che ti sta chiudendo fuori, installare
e configurare una protezione, potare file temporanei sotto una soglia già decisa, aggiungere un
controllo.

**Decide l'amministratore** quando l'intervento tocca gli altri o la sicurezza: spostare la porta
di sshd ( entrano anche altre persone ), spegnere o degradare un servizio in uso, togliere chiavi
o credenziali di qualcun altro, qualcosa di non reversibile, qualcosa che costa soldi.

⚠ **Una scorciatoia comoda che indebolisce non si mette in silenzio.** Nel caso originario la
tentazione era aggiungere l'IP di casa all'`ignoreip` di fail2ban per non rischiare di bannarsi:
comodo, ma quell'IP è dinamico e domani è di uno sconosciuto, che si troverebbe esentato dalla
protezione anti-brute-force. È stato lasciato fuori **dicendolo**, insieme al comando per
sbannarsi. Il criterio: se una scelta rende la macchina un po' meno sicura in cambio di comodità,
**la sceglie l'amministratore, sapendolo**.

## 9. Quello che resta si scrive, non si racconta

Un problema trovato e lasciato in chat è un problema perso: la sessione finisce, il contesto si
azzera, e tra un mese nessuno se ne ricorda. Quindi, **prima** di chiudere:

- i rami aperti vanno nel **`TODO.md`** — sui server è `/root/TODO.md`, accanto agli altri file di
  servizio per l'amministrazione della macchina; dentro un progetto è quello del progetto.
  Formato: `- [ ] (urgenza rilevanza impatto) testo`, note nelle righe `--`, aree in `##`.
  Si legge con `~/.claude/bin/todo.py`, **mai con `cat`**; si scrive con Edit ancorato al testo.
- quello che si è capito sulla macchina — com'è fatta, cosa espone, cosa è stato deciso — va in
  **`/root/READ.md`**, che è il posto da cui lo rileggerà la sessione dopo.
- in chat restano **cosa è chiuso e dove sta scritto**, più i rami **come conteggio**, non come
  elenco da rileggere.

## 10. Quello che non si rimette in discussione

Su ogni macchina ci sono cose già decise, e ridiscuterle a ogni giro è rumore. Stanno in
`/root/READ.md` e nella memoria: **si guardano prima di "scoprire" un problema**. Se una cosa è
già stata vista e decisa, si dice in una riga che è una scelta consapevole e si passa oltre.

Vale anche al contrario: se una decisione vecchia ora è **smentita dai numeri**, si porta il
numero, non l'opinione.

## 11. Come si riferisce

Chi legge vuole sapere tre cose, in quest'ordine: **cos'era davvero**, **cos'è stato fatto**,
**cosa resta da decidere**.

- **Prima la risposta alla domanda che è stata fatta**, non il riepilogo di tutto quello che si è
  guardato. Se la domanda era "è un problema di sicurezza?", la prima riga dice sì o no, e perché.
- **Separare il rumore di fondo dalla compromissione.** Venticinquemila tentativi al giorno fanno
  impressione e non sono un'intrusione; dire *"zero login riusciti non-root in 30 giorni,
  `/etc/passwd` fermo al mese scorso, crontab di root vuota"* vale più di qualunque rassicurazione.
  ⚠ **Si dice anche cosa si è controllato e risultava sano**: serve a sapere dove **non** cercare.
- **Percorsi con il numero di riga** ( `/etc/ssh/sshd_config:102` ), comandi per intero, nomi dei
  file di backup. Chi legge deve poter rifare e disfare tutto senza chiedere.
- Niente allarmismo e niente trionfalismo: se una cosa non è stata verificata, si dice che non è
  stata verificata. Dopo un'intrusione vale per la ricostruzione: quando i log non c'erano ( otto
  giorni di retention contro tredici mesi di impianto ), la convergenza di IP, porta, processo,
  orario e firma riprodotta è una prova solida, e **si dichiara per quello che è** — ricostruzione,
  non registrazione.
- **Al cliente il vettore non si racconta**: si dice cosa è stato verificato, cosa deve fare lui e
  cosa non deve toccare. I dettagli in `references/intrusione.md`, punto 11.

## 12. Takeout: salvare una macchina prima di spegnerla

> **Prima si collauda il nuovo, poi si spegne il vecchio.**

Che la macchina si trasferisca o si archivi, l'ordine è **censimento → salvataggio → verifica →
collaudo → spegnimento → dopo**, con `va.takeout.inventory.sh`, `va.takeout.pull.sh` e
`va.takeout.verify.sh`, e un accesso ssh a chiave verso la macchina da salvare. Il takeout va in
`/var/backups/NOME/AAAAMMGG-takeout/` sulla macchina dove lavora Claude e si conserva finché
l'amministratore non decide altrimenti; eliminare la macchina lo decide lui. La procedura completa,
con gli archivi uno per uno e cosa si guarda nell'inventario, è **`references/takeout.md`**: si apre
prima di cominciare.
Per **un sito solo**, su CloudPanel ( `/home/UTENTE/` ) o classico ( `/var/www/SITO/` ), il censimento è
`va.takeout.site.inventory.sh` e il resto non cambia: la procedura e le trappole già incontrate
( backup di CloudPanel, MySQL senza credenziali ) sono in **`references/takeout-sito.md`**.

## 13. Apache: troubleshooting e ottimizzazione

Quando un sito su Apache è giù, lento o risponde 403/500, o quando si dimensionano i worker, il
riferimento è **`references/apache.md`**, e si apre prima di toccare la config. Le tre cose da sapere
subito: **un buco nell'access log è la prova del down** ( Apache scrive la riga a fine richiesta, e
`AH00161` lo scrive una volta sola per vita del processo padre ); **i worker si contano col Pss**, e
con PHP-FPM il rischio di OOM sta nei pool, non in Apache; **`reload`, non `restart`**, e attenzione a
monit che riavvia in silenzio.

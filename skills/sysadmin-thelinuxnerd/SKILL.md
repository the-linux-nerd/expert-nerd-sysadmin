---
name: sysadmin-thelinuxnerd
description: Come si amministra una macchina Linux, nel metodo di TheLinuxNerd. Prima si misura e si quantifica, poi si tocca poco e con backup datato, si testa la config prima di ricaricarla, si verifica che il servizio faccia davvero il suo lavoro e non solo che sia "active", e si separa quello che si fa da soli da quello che deve decidere l'amministratore. Attivare ogni volta che si mette mano a una macchina: sintomi ( "l'ssh mi rifiuta", "il sito è lento", "lo spazio è finito", "non mi arriva la posta" ), domande di sicurezza ( "ci sono problemi?", "siamo sotto attacco?", "è compromessa?" ), interventi su servizi e configurazioni ( sshd, apache, nginx, proftpd, fail2ban, firewall, cron, mysql, certbot ), siti WordPress e pannelli di hosting, sospetta compromissione ( "hanno bucato un sito", "c'è un file strano", "il plugin di sicurezza mi ha avvisato" ), backup e monitoraggio ( "i backup ci sono?", "perché non mi è arrivato l'avviso?" ), controlli di stato e giri di manutenzione. Contiene anche le regole fisse, prima fra tutte che **fail2ban va messo su ogni macchina esposta a Internet** e che **SSH accetta solo chiavi**, senza starci a ragionare ogni volta: attivare quindi anche quando si prepara o si eredita una macchina nuova. Vale pure quando la richiesta sembra una riga sola: è lì che si sbaglia diagnosi.
---

# Amministrazione di sistema, come la fa TheLinuxNerd

Nata il **23/09/2026** su un web server in produzione, dal giro su un brute force SSH:
l'amministratore arriva dicendo *"mi ha rifiutato la connessione ssh due volte prima di lasciarmi
accedere, c'è qualche problema di sicurezza?"*, e la risposta giusta non era né "sì sei sotto
attacco" né "no è tutto a posto".

Il filo è uno solo:

> **Misura prima, cambia poco e in modo reversibile, verifica che funzioni davvero, e scrivi
> quello che resta invece di raccontarlo.**

## 0. Le particolarità della macchina stanno in `/root/READ.md`

Questa skill è il **metodo**, e vale su qualunque macchina. Quello che invece cambia da macchina a
macchina — a cosa serve, cosa espone, quali decisioni sono già state prese e vanno rispettate —
sta in **`/root/READ.md`**, accanto agli altri file di servizio.

⚠ **Si legge prima di concludere che qualcosa è un problema.** Metà dei "problemi" che si trovano
in un giro di diagnosi sono scelte consapevoli di chi amministra la macchina: una versione tenuta
indietro apposta, uno swap che non si mette, un servizio lasciato com'è per non rompere i client.
Riproporle ogni volta è rumore, e fa perdere credibilità alle segnalazioni vere.

Se `/root/READ.md` non c'è, vale la pena proporre di crearlo alla fine del primo giro serio:
è lì che si sedimenta quello che altrimenti si riscopre da capo ogni sessione.

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

**I comandi di raccolta vanno in una chiamata sola**, con le intestazioni a dividere l'output: in
diagnosi conta doppio, perché i dati servono tutti insieme per essere confrontati. C'è uno script
pronto per la prima passata:

    ~/.claude/skills/sysadmin-thelinuxnerd/scripts/triage.sh

È **in sola lettura**, non tocca niente, e stampa in un colpo: carico, memoria, disco, servizi in
ascolto, accessi riusciti, volume degli attacchi SSH, stato di firewall e fail2ban, modifiche
recenti in `/etc`.

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

## 3. fail2ban si mette sempre

**Su ogni macchina esposta a Internet fail2ban ci va, e ce lo si mette la prima volta che ci si
mette mano.** Non è una valutazione da rifare ogni volta: è il minimo sindacale, e sta nel lato
"si fa da soli" del confine del punto 7 — è additivo, reversibile, e non cambia il modo in cui le
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

⚠ **Qui la regola fissa incontra il confine del punto 7**: spegnere le password chiude fuori chi
entra così. Prima si contano gli accessi a password riusciti,
`zgrep -h 'Accepted password' /var/log/auth.log* | awk '{print $9}' | sort | uniq -c`, e con quel
numero in mano il quando lo decide l'amministratore. Il difetto però si segnala per primo, prima
di ogni altra cosa del giro.

## 4. "active" non è una verifica

`systemctl is-active` dice che il processo gira, **non** che sta facendo il suo lavoro. Un
fail2ban avviato con un filtro che non aggancia niente è indistinguibile, da fuori, da un
fail2ban che sta proteggendo la macchina — e dà la stessa identica falsa tranquillità.

Per ogni cosa messa in piedi, la domanda è: **qual è la prova che funziona?**

| messo in opera | la prova che funziona |
|---|---|
| fail2ban | `fail2ban-regex <log> <filtro>` conta i match sulle righe vere; poi `fail2ban-client status <jail>` e la catena `f2b-*` in `iptables -L INPUT` |
| una direttiva sshd | `sshd -T \| grep <direttiva>`, che stampa il valore **attivo**, non quello scritto nel file |
| una regola di firewall | i contatori `pkts/bytes` di `iptables -L -n -v` che salgono |
| un cron | la riga nel log al primo giro utile, non la crontab che lo contiene |
| un servizio al boot | `systemctl is-enabled`, che è una domanda diversa da `is-active` |
| un allarme | il messaggio **ricevuto**: si provoca la condizione una volta e si guarda il telefono, non il log dello script |
| i certificati | `certbot renew --dry-run` che elenca **tutti** quelli attesi; il "success" del timer riguarda solo quelli che ha letto |
| una correzione a uno script che si reinstalla da solo | il giro **dopo** quello atteso: il primo esegue ancora la copia vecchia, che poi installa la nuova |
| uno scanner di malware | un file di prova che deve trovare: zero riscontri può voler dire che non sta guardando |
| un backup | il ripristino di prova, qui sotto |

Nel caso originario la verifica di fail2ban è stata `fail2ban-regex` sulle ultime 3000 righe di
`auth.log`: **361 agganciate**. Senza quel numero si sarebbe potuto dire soltanto "l'ho
installato".

⚠ **Quello che fallisce in silenzio è quello da cui guardarsi**, e ogni riga della tabella nasce da
un caso vero. Sei certificati sono arrivati a scadenza perché le loro conf, importate da una
macchina con un certbot più recente, venivano **saltate senza un errore** mentre il timer
riportava successo per gli altri. Uno scanner costruito su link simbolici ha dato zero riscontri
per settimane: non li seguiva. Uno strumento aggiornato in `/usr/local/bin` lasciando la copia
vecchia in `/usr/bin` va bene per chi lo chiama per nome, ma chi lo chiama per percorso assoluto
( monit, un cron ) continua a usare quella vecchia.

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

## 5. Accorgersene: un allarme vale quello che arriva e che viene letto

Le difese servono poco se nessuno se ne accorge quando cedono. Tre modi visti in cui il
monitoraggio c'era e non è servito:

- **Rileva ma non consegna.** Uno script di controllo scriveva solo su file e syslog, e un
  commento spiegava che "da questa macchina posta e Slack non escono": era vero mesi prima, non
  più, e nessuno l'aveva riverificato. In un incidente il controllo ha visto l'infezione **in
  un'ora**; le persone l'hanno saputo **sei ore dopo**, e dall'avviso del plugin del sito, non da
  quello di sistema.
- **Dice sempre la stessa cosa.** Un controllo che segnalava 2 file fuori posto il 10 del mese ne
  segnalava 19 il 23: nessuno lo leggeva più, perché "è quello solito". Un allarme noto si
  risolve o si toglie; lasciarlo suonare insegna a ignorare anche quello vero.
- **Guarda solo i file.** Un account di amministratore rubato è entrato **40 volte da 26 IP
  diversi in cinque settimane** senza toccare un file: invisibile a qualunque controllo di
  integrità. L'ha trovato una guardia sugli **accessi** — IP, paesi, orari nuovi per lo stesso
  account — interrogando il registro dei login del plugin di sicurezza.

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
testo** per passare i controlli sui magic byte. `wp core verify-checksums` è necessario e non basta.

**La quarantena batte la disattivazione.** Un plugin per rubare credenziali non si è mai attivato
per un errore dell'attaccante, ma la webshell nella stessa cartella è stata eseguita lo stesso con
una richiesta diretta: un file PHP raggiungibile via HTTP è attivo, che WordPress lo consideri tale
o no. Si sposta fuori dalla document root togliendo ogni permesso — e **prima** si copia tutto in
una cartella dell'incidente ( evidenze, log, cosa si è fatto e quando ), perché la relazione si
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

⚠ **Le chiavi SSH di root sono una superficie.** Su un solo host **57 chiavi autorizzate**, fra
portatili e telefoni personali, senza un nome né una scadenza: una qualunque di quelle macchine
persa è una porta aperta, ed è uno dei canali più plausibili della fuga di credenziali. Si
contano, ognuna deve avere il proprietario nel commento, e quelle senza si propongono per la
rimozione — che decide l'amministratore, perché toglie l'accesso a qualcuno.

## 7. Il confine: cosa si fa da soli, cosa decide l'amministratore

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

## 8. Quello che resta si scrive, non si racconta

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

## 9. Quello che non si rimette in discussione

Su ogni macchina ci sono cose già decise, e ridiscuterle a ogni giro è rumore. Stanno in
`/root/READ.md` e nella memoria: **si guardano prima di "scoprire" un problema**. Se una cosa è
già stata vista e decisa, si dice in una riga che è una scelta consapevole e si passa oltre.

Vale anche al contrario: se una decisione vecchia ora è **smentita dai numeri**, si porta il
numero, non l'opinione.

## 10. Come si riferisce

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
  stata verificata.

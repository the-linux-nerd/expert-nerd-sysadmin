---
name: sysadmin-thelinuxnerd
description: Come si amministra una macchina Linux, nel metodo di TheLinuxNerd. Prima si misura e si quantifica, poi si tocca poco e con backup datato, si testa la config prima di ricaricarla, si verifica che il servizio faccia davvero il suo lavoro e non solo che sia "active", e si separa quello che si fa da soli da quello che deve decidere l'amministratore. Attivare ogni volta che si mette mano a una macchina: sintomi ( "l'ssh mi rifiuta", "il sito è lento", "lo spazio è finito", "non mi arriva la posta" ), domande di sicurezza ( "ci sono problemi?", "siamo sotto attacco?", "è compromessa?" ), interventi su servizi e configurazioni ( sshd, apache, proftpd, fail2ban, firewall, cron, mysql ), controlli di stato e giri di manutenzione. Contiene anche le regole fisse, prima fra tutte che **fail2ban va messo su ogni macchina esposta a Internet**, senza starci a ragionare ogni volta: attivare quindi anche quando si prepara o si eredita una macchina nuova. Vale pure quando la richiesta sembra una riga sola: è lì che si sbaglia diagnosi.
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

1. **Backup con la data nel nome**, accanto all'originale: `cp -a sshd_config sshd_config.bak-20260923`.
   Serve perché il rollback si fa alle due di notte, quando nessuno si ricorda cosa c'era prima.
2. **Test di sintassi prima di ricaricare**, sempre: `sshd -t`, `apachectl configtest`,
   `nginx -t`, `fail2ban-client -t`, `visudo -c`, `named-checkconf`. Una config rotta su un
   servizio di rete si paga con la macchina irraggiungibile.
3. **`reload`, non `restart`**, quando il servizio è quello da cui si è connessi. Il reload di
   sshd non butta giù le sessioni aperte; il restart è un rischio che non serve correre.
4. **Modifica minima.** Si cambia la riga che risolve il problema misurato, non si riscrive il
   file "già che ci siamo": un file riscritto rende impossibile capire, il mese dopo, quale
   modifica ha causato cosa.

⚠ **Non si cade mai fuori dalla macchina.** Quando si tocca sshd, iptables o il firewall, la
sessione già aperta è l'unica rete di sicurezza: si lavora tenendola viva, si verifica subito
dopo che regge ( `who` ), e se l'intervento è davvero rischioso si chiede all'amministratore di
aprire una seconda sessione prima di procedere.

## 3. fail2ban si mette sempre

**Su ogni macchina esposta a Internet fail2ban ci va, e ce lo si mette la prima volta che ci si
mette mano.** Non è una valutazione da rifare ogni volta: è il minimo sindacale, e sta nel lato
"si fa da soli" del confine del punto 5 — è additivo, reversibile, e non cambia il modo in cui le
altre persone usano la macchina.

**Perché, misurato il 23/09/2026**: 25.531 tentativi SSH in undici ore da 440 IP distinti. La
chiave publickey teneva benissimo — il rischio non era l'intrusione — ma il traffico da solo
saturava `MaxStartups` e **chiudeva fuori l'amministratore dalla sua macchina**. È questo il danno
che fa il rumore di fondo quando lo si lascia correre: non entra nessuno, e intanto non entri
nemmeno tu.

⚠ **"Tanto ho solo la chiave, le password sono spente" non è un motivo per non metterlo.** Era
esattamente la situazione di quella macchina, e il problema è arrivato lo stesso.

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
dovecot, un pannello web — le jail corrispondenti si propongono nello stesso giro, perché il
ragionamento è identico.

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

Nel caso originario la verifica di fail2ban è stata `fail2ban-regex` sulle ultime 3000 righe di
`auth.log`: **361 agganciate**. Senza quel numero si sarebbe potuto dire soltanto "l'ho
installato".

## 5. Il confine: cosa si fa da soli, cosa decide l'amministratore

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

## 6. Quello che resta si scrive, non si racconta

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

## 7. Quello che non si rimette in discussione

Su ogni macchina ci sono cose già decise, e ridiscuterle a ogni giro è rumore. Stanno in
`/root/READ.md` e nella memoria: **si guardano prima di "scoprire" un problema**. Se una cosa è
già stata vista e decisa, si dice in una riga che è una scelta consapevole e si passa oltre.

Vale anche al contrario: se una decisione vecchia ora è **smentita dai numeri**, si porta il
numero, non l'opinione.

## 8. Come si riferisce

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

# Quando la macchina è davvero compromessa

Riferimento del punto 7 della SKILL.md: si apre quando un'intrusione non è più un'ipotesi. Nasce
da un web server Debian con **sei portali WordPress dietro un pannello di hosting commerciale**,
compromesso a livello root per **tredici mesi** senza che nessuno se ne accorgesse, bonificato nel
settembre 2026, e poi sorvegliato — con una sorveglianza che, appena installata, ha fallito in tre
modi diversi prima di funzionare.

Gli indicatori di quell'attaccante ( nomi di file, IP, domini ) qui non ci sono, e non devono
entrarci: fra sei mesi valgono zero. Quello che resta è **dove si nasconde una cosa e come la si
costringe a farsi vedere**.

## 1. Un'intrusione vera è a strati, e il più vecchio è più vecchio di quanto credi

La forma della cronologia, ricostruita a bonifica finita:

| quando | strato |
|---|---|
| mese 0 | prima compromissione: due componenti "guardiano", **scoperti per ultimi** |
| mese 1 | quattro binari camuffati in `/usr/libexec` e `/usr/lib` |
| mese 12 | impianto nel pannello: furto credenziali dalla pagina di login |
| mese 12, giorni dopo | `auto_prepend_file` malevolo nei `php.ini`, poi `include` di cloaking nei vhost, webshell, payload |
| mese 13 | **la segnalazione**: un cliente vede spam da casinò su Google |

La scoperta è partita **dall'esterno e dal sintomo più stupido** — i risultati di Google — non dai
log, non da un antivirus, non da un allarme.

⚠ **Il lavoro non finisce alla prima cosa trovata.** Nella stessa serata si sono trovati, in
sequenza, il cloaking ( 2 iniezioni ), il vettore nel pannello ( 3 impianti ), l'impianto di
sistema ( 4 famiglie di binari, 12 file ) e infine lo strato di tredici mesi prima. **Ogni volta
sembrava finita.** Dopo ogni ritrovamento la domanda è *"questo come ci è arrivato?"*, e si smette
solo quando la risposta è "da qui", non "boh".

## 2. Su una macchina con un pannello, il pannello è la superficie principale

- La **pagina di login del pannello** caricava una libreria JavaScript con un loader accodato verso
  un CDN dell'attaccante: le credenziali le rubava il pannello stesso, a chiunque le digitasse.
  `ctime` di un anno dopo l'`mtime`, che era falsificato.
- Due webshell nelle cartelle di esempio di uno strumento incluso nel pannello ( `examples/`, e un
  `lndex.php` con la `l` al posto della `i` dentro una cartella di immagini di un tema ). Una
  eseguiva PHP arbitrario passato in POST; l'altra **verificava una firma RSA** prima di eseguire:
  giravano solo i comandi firmati dall'attaccante. Non è ragazzeria.
- Il pacchetto del pannello installa in `/etc/sudoers.d/` un `NOPASSWD: ALL` per il proprio utente
  di servizio: da un file scritto nel pannello a root non c'è alcun passaggio.
- **Zero tentativi SSH falliti sugli utenti di sito.** L'assenza di brute force è un indizio *a
  favore* del furto di credenziali, non della tranquillità.

Quindi le cartelle `examples/`, `vendor/`, `phpmyadmin/` del pannello, i suoi asset statici ( la
pagina di login per prima ) e le sue righe in `sudoers.d` **si guardano per primi, e si sorvegliano
dopo**. E l'inventario non si fa dall'interfaccia dello strumento che si sta controllando: si fa
dal filesystem, dai pacchetti e dal database ( SKILL.md, punto 6 ).

## 3. Come si camuffa un impianto, e qual è il filo che tira

Tecniche viste tutte insieme su una sola macchina:

- **Nomi plausibili in posti plausibili**: librerie con nomi da `libselinux` o `libdbus`, helper
  da `packagekit` o `xdg-desktop-portal`, demoni da sessione GNOME. **Su un server senza
  desktop.** Uno portava il nome e il percorso di un demone systemd vero: **pacchetto non
  installato, 5 MB invece di 50 KB**.
- **`mtime` falsificati** ( al 2020, al 2024 ). Il `ctime` invece non si imposta con `touch`, e su
  quella macchina è il dato che ha ricostruito l'intera cronologia: si guarda sempre `stat` per
  intero. ⚠ **Ma `mtime` più vecchio del `ctime` non è di per sé un'anomalia**: dpkg installa ogni
  file con l'`mtime` della build del pacchetto, quindi *tutti* i file di pacchetto ce l'hanno così.
  È un segnale solo sui file **che nessun pacchetto dichiara**; su quelli, un `mtime` di anni prima
  del `ctime` è una data scritta a mano.
- **Processi travestiti da thread del kernel** ( `watchdog/1`, `migration/1` ): i thread veri
  hanno `PPid 2` e nessun `exe`; questi avevano `PPid 1` e l'`exe` che puntava al binario
  camuffato. Giravano da settimane, visibili in `ps` da sempre, e nessuno li aveva letti.
- **Flag immutabile** ( `chattr +i` ) sui file chiave, perché la rimozione fallisca.
- **Pidfile nascosto in `/dev/shm`**, con un nome da `.dbus-<esadecimale>`.
- **Quattro vie di resurrezione indipendenti**: un **generatore systemd** ( gira a ogni boot, prima
  di tutto il resto ), una **regola udev**, una coppia `.service` + `.timer` che ogni notte
  lanciava un `udevadm trigger` per **riattivare la regola udev**, e i binari che si rilanciavano
  fra loro.

## 4. Come si cerca: le tecniche, non i nomi

Sono otto domande, e valgono su qualunque macchina. Le prime sei, più le invarianti di privilegio,
le fa `scripts/hunt.sh` in sola lettura:

1. processi che si spacciano per thread del kernel ( un `exe` c'è, e il `PPid` non è 2 ), o il cui
   `exe` punta a un file **cancellato** ( `ls -l /proc/<pid>/exe` che finisce con ` (deleted)` );
2. file con flag **immutabile** nelle directory di sistema ( `lsattr` );
3. **generatori systemd** che non appartengono a un pacchetto;
4. **regole udev** e **unità systemd** che non appartengono a un pacchetto;
5. **eseguibili nelle directory di sistema senza pacchetto** — il controllo più produttivo di tutti;
6. file nascosti in `/dev/shm`;
7. connessioni in uscita, **con il processo che le apre** ( vedi il punto 8.4: un IP da solo non
   basta );
8. le firme delle iniezioni già viste **su quella macchina** — che si scrivono nel suo `READ.md`,
   non nella skill.

⚠ Il punto 5 è quello che ha trovato i binari che `rkhunter` non aveva visto. Si fa così:

- l'appartenenza a un pacchetto si chiede a dpkg **al momento del controllo** ( `dpkg -S`, o le
  liste in `/var/lib/dpkg/info/*.list` lette in quel momento ), **mai** confrontandola con una
  lista fotografata prima — vedi il punto 8.2;
- **con la gestione di usrmerge**: `/bin/su` è registrato da dpkg sotto `/bin` anche se oggi vive in
  `/usr/bin`, e senza normalizzare i due prefissi si producono falsi positivi fissi ( `su`,
  `mount`, `umount`, `unix_chkpwd` ); lo stesso per le diversioni in `/var/lib/dpkg/diversions`;
- a valle, `debsums -s` per i binari **di pacchetto** alterati, e il confronto **dimensione attesa
  contro reale**, che è quello che ha smascherato il finto demone da 5 MB.

## 5. Il cloaking: il sintomo esiste solo per chi non sei tu

Le due iniezioni che servivano lo spam:

- **`auto_prepend_file`** con un payload offuscato ( `data:;base64,...` ) in **tutti e otto** i
  `php.ini` delle versioni PHP installate. Un file per versione, `root:root 644`: scritto da root,
  ha infettato **tutti i siti insieme senza toccare un file di WordPress**. ⚠ Core, plugin e webroot
  risultavano **integri**: un controllo di integrità applicativo non l'avrebbe visto mai.
- **`include` nei vhost** che facevano proxy verso il server dell'attaccante **solo** per i bot dei
  motori di ricerca, e **solo** per utenti mobile con referrer da motore di ricerca e
  `Accept-Language` di una lista di paesi. Per tutti gli altri, il sito normale.

Da qui, la parte che manca in ogni checklist:

- un sito "che a me risponde bene" non dice niente. Si prova **con lo user-agent del bot** e **con
  il profilo di lingua e referrer del bersaglio**, e si confrontano le risposte;
- si prova **`http://` separatamente da `https://`**: lo spam era indicizzato sulla versione non
  cifrata, e ce l'ha detto un tecnico esterno, non i nostri controlli;
- una ricerca `site:<dominio>` con le parole dello spam misura l'estensione **prima** di toccare;
- ⚠ **prima la via d'ingresso, poi la bonifica, poi la reindicizzazione.** Pulire per primo vuol
  dire soltanto ripulire di nuovo la settimana dopo.

## 6. L'ordine della bonifica

Quello che ha funzionato, in quest'ordine:

1. **si blocca l'uscita verso i server dell'attaccante** con una regola di firewall **in uscita**,
   prima di ogni altra cosa: l'impianto resta vivo ma sordo, e non riceve l'ordine di reagire;
2. **si copiano le evidenze in una cartella dell'incidente**, con una sottocartella per famiglia
   ( impianto di sistema, backdoor del pannello, config infette, payload decodificato ) e nomi che
   conservano il percorso originale — `_usr_lib_...` — perché dopo qualche giorno "quel file" non si
   sa più dov'era. `stat` completo di ogni file, prima di toccarlo;
3. **si disarma la persistenza prima dei processi**: timer, service, generatori, regola udev, cron;
4. si tolgono i flag immutabili e si rimuovono i file;
5. **solo adesso** si uccidono i processi;
6. si verifica punto per punto, e si **rilegge da capo** con `hunt.sh`.

⚠ **Alla prima uccisione l'impianto si è rigenerato.** È stato l'evento più utile dell'intera
bonifica: ha rivelato lo strato di tredici mesi prima che nessuno stava cercando. **Se dopo la
rimozione qualcosa ritorna, non è un fallimento, è un'informazione**: esiste un guardiano, e lo si
cerca fra i componenti che *non* si sono toccati, ordinandoli per `ctime`.

⚠ **Non si ripulisce un file per volta a impianto vivo.** La sequenza si prepara per intero, poi si
esegue di seguito.

⚠ **Dopo, si ruota tutto quello che il componente compromesso poteva vedere**, non "le password
importanti". In quel caso: admin del pannello, utenti SSH e SFTP dei siti, password dei database e
i file di configurazione che le contengono, **i salt di WordPress** — che chiudono tutte le sessioni
aperte — e gli utenti amministratori dei siti. Le credenziali nuove si consegnano **fuori dalla
macchina**, e il file non resta sul server: trovarlo assente, dopo, è la situazione corretta.

## 7. Il verdetto onesto: quando la ricostruzione non è possibile, si dice

A caccia finita sono rimaste due domande senza risposta — *come sono entrati la prima volta* e *da
quale sito partiva un contatto* — e i motivi sono l'elenco di quello che **non** verrà registrato
quando servirà:

- i log di accesso tenevano **otto giorni**; l'intrusione ne aveva tredici di mesi;
- **nessun log DNS**: il resolver era quello del cloud provider, che non registra. Dato un IP, non si
  risale al nome che era stato chiesto;
- nginx non registrava il tempo di risposta, quindi una connessione in uscita non si correlava a
  una richiesta in entrata;
- i pid muoiono, e con loro `cmdline`, `cwd`, `exe`, `fd`.

Quello che si può ancora fare, e che ha chiuso il caso, è la **convergenza**: IP + porta + processo
+ orario + sito + **riproduzione della firma** — rifare a mano la chiamata sospetta e verificare che
produca esattamente la stessa riga di `ss`. È una prova solida, e **si dichiara per quello che è**:
ricostruzione, non registrazione.

⚠ **La visibilità si aggiusta mentre la si usa.** Lì: retention di `auth.log` portata a 90 giorni, e
un campionatore in sola lettura acceso per trenta minuti quando il dato mancava ( `tcpdump` mirato,
più `ss` ogni 0,2 secondi che fotografa `/proc` del processo appena compare il socket ).

## 8. La sorveglianza nuova ha fallito in tre modi. È il pezzo più prezioso

Quattro livelli installati in ventiquattr'ore: auditd con 18 regole, una sentinella anti-impianto
ogni 15 minuti, un controllo di integrità giornaliero su 2.599 file, AIDE giornaliero. Sembravano
tutti sani. Tre non lo erano.

**8.1. auditd era cieco, e lo accecavamo noi.** Una regola registrava ogni **lettura** dei flag di
un file ( `FS_IOC_GETFLAGS` ), e a farla scattare era **la nostra sentinella**, che ogni quindici
minuti passava `lsattr -R` su mezzo filesystem: **~6.900 eventi a giro**, i 40 MB di `audit.log`
sovrascritti in pochi minuti. Per quattro giorni **la traccia copriva gli ultimi due o tre minuti**:
chi avesse toccato `sudoers` o le chiavi SSH sarebbe stato registrato e cancellato subito dopo. Tolta
la regola sulla lettura ( resta quella sulla **scrittura** del flag, che è la tecnica vera ) e
portata la retention da `8 MB × 5` a `50 MB × 10`, un giro di sentinella è passato da ~2 MB a
**1,3 KB** di audit.
→ **Si audita quello che l'attaccante *fa*, non quello che si guarda.** Il sintomo è gratis:
`ls -la /var/log/audit/` con **tutti gli archivi timbrati allo stesso minuto**.

**8.2. La baseline era stata fotografata un minuto prima di installare gli strumenti.** La
sentinella ha segnalato `aide`, `clamscan`, `freshclam` e compagnia come "eseguibili senza
pacchetto" **ogni quindici minuti per dodici ore**: quaranta righe identiche nel registro. In una
notte un allarme nuovo era già diventato rumore che nessuno legge.
→ Una lista di riferimento congelata invecchia in ore: **si verifica al momento del controllo**. E un
allarme che si ripete identico **si chiude o si toglie entro la giornata**.

**8.3. AIDE puntato anche sui webroot**: dieci ore al 90% di CPU su una macchina già a carico 6,8.
→ Allo strumento di sistema il perimetro di sistema; i webroot si controllano con quello che è nato
per loro. **Una sorveglianza che degrada il servizio prima o poi qualcuno la spegne.**

**8.4. Un IP, da solo, non è un indicatore.** Il controllo sui contatti verso i due indirizzi
dell'attaccante ha suonato due volte, ed **erano falsi positivi**. Quegli indirizzi sono di un CDN
condiviso: risolvendo i **595 domini citati nel codice dei sei siti**, **21 domini legittimi**,
citati da plugin e temi, rispondono esattamente lì. La sorgente vera era un sito con **65 servizi
di ping del 2005** nella configurazione, tutti `http://`, uno dei quali oggi parcheggiato su quel
CDN: WordPress li chiama a ogni pubblicazione, il firewall li blocca in uscita, e il socket resta
in `SYN-SENT` abbastanza a lungo da farsi campionare.
→ **Si fotografa sempre il processo** ( `cmdline`, `exe`, `cwd`, `fd` da `/proc`, finché è vivo: è
il dato che mancherà dopo ), **ma si grida solo con un secondo indizio**. Un `SYN-SENT` verso un
indirizzo già bloccato in uscita è rumore atteso: va nel registro, non in allarme.

**8.5. Uno scanner senza firme è teatro.** ClamAV su una distribuzione a fine vita: l'unica versione
disponibile era fuori supporto, e il CDN delle firme la rifiutava con un cool-down di 24 ore. Acceso,
avrebbe dato un servizio "attivo" e zero riscontri per sempre — il caso peggiore, perché rassicura.
È stato **spento dichiarandolo**, non lasciato in errore ciclico.

## 9. Una distribuzione a fine vita è l'impossibilità di difendersi

Misurato la notte della bonifica: `apt` annunciava **199 aggiornamenti e non ne esisteva nessuno** —
il repository di sicurezza rispondeva 404 su tutti i mirror, e l'archivio storico non aveva ancora
pubblicato quella suite. Il pannello non era aggiornabile perché la versione nuova voleva versioni di
PHP non pubblicate per quella distribuzione. Sistema non patchabile, pannello vulnerabile e non
aggiornabile, **mentre l'ipotesi più probabile sull'ingresso iniziale era proprio una vulnerabilità
del pannello**.

→ **La data di fine supporto della distribuzione è un dato di sicurezza**, e si guarda nel primo
giro insieme alle porte aperte ( SKILL.md, punto 1 ). L'aggiornamento di versione si prepara: lì il
preflight è stato **simulare l'upgrade completo contro i repository veri in un'area separata, senza
toccare il sistema** — 555 pacchetti aggiornati, 113 nuovi, 0 conflitti, e due trappole trovate lì
invece che alle tre di notte.

## 10. La checklist di esposizione uscita dall'audit dopo l'incidente

Trovate su una macchina "normale", ognuna con la prova accanto. L'incidente serve anche a vedere il
resto:

| trovato | perché conta |
|---|---|
| un plugin che autenticava passando **utente e password nella query string** | **~13.200 righe di log** con una password valida in chiaro, e i log sono leggibili dall'utente del sito — cioè da chi compromette quel sito |
| `disable_functions` vuoto su tutti i pool PHP | è la differenza fra "hanno scritto un file" e "hanno eseguito comandi" |
| il database senza `bind-address` | ascolta su tutte le interfacce; lo salva solo il firewall |
| una directory di servizio in `/var/lib` a **777 senza sticky bit** | qualunque utente locale ci scrive |
| un `wp-config.php` a **644** | le credenziali del database leggibili da ogni utente locale |
| **15 chiavi** in `/root/.ssh/authorized_keys`, molte di macchine dismesse | ognuna **è root**; su un'altra macchina erano **57** |
| il range passivo di un FTP aperto nel firewall, con l'FTP spento | avanzo, e superficie |
| plugin disinstallabili lasciati inattivi | codice raggiungibile che nessuno aggiorna |
| sei utenti di sito con shell vera, senza chroot, e SSH che accettava password | **27.242 tentativi falliti** in `btmp`; fail2ban è l'ultima linea, non la prima |

⚠ E il contrario: **un sospetto verificato e scartato si scrive**. La riga di `sudoers` del pannello
sembrava una scala verso gli altri siti; leggendo il codice, i comandi raggiungibili da quel contesto
sono pochi e verificano la proprietà del sito. Scritto con il perché nel `READ.md`, così nessuno lo
rifà da capo il mese dopo.

## 11. La comunicazione, quando c'è un cliente di mezzo

- **Il vettore non si racconta.** Al cliente si dice cosa si è verificato e cosa risponde bene oggi,
  con i numeri. Come sono entrati è un'informazione operativa che non rende nessuno più sicuro e
  aiuta qualcuno a riprovare.
- **Chi risponde al cliente lo decide il titolare del rapporto**, e la risposta è una sola per
  organizzazione anche quando le segnalazioni arrivano da tre persone diverse.
- Si dice invece sempre **cosa deve fare il cliente** ( credenziali cambiate, primo accesso ) e
  **cosa non deve toccare**: un mu-plugin nostro, che il direttore di una delle testate aveva preso
  per malware, era a un clic dall'essere disattivato.
- ⚠ **La segnalazione del cliente è un sensore.** Tre segnalazioni indipendenti in due giorni hanno
  fatto quello che quattro livelli di monitoraggio non avevano fatto in tredici mesi, e una — *"ho
  trovato un plugin attivato che non avevo attivato io"* — era il dato più pesante arrivato quel
  giorno. Si ascoltano anche le ipotesi tecniche sbagliate: *"forse è nel rewrite"*, detto da un
  non tecnico, descriveva **dove si vedeva**, e ha accorciato la ricerca.

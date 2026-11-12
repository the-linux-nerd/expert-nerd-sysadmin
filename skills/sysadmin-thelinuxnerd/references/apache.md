# Apache: troubleshooting e ottimizzazione

Nata il **06/11/2026** da un web server Apache prefork con una ventina di siti, che un controllo di
uptime dava giù a raffiche di qualche minuto. Il ramo raccoglie quello che su Apache si è già pagato
dal vivo; il metodo resta quello della skill: **si misura, si tocca poco, si verifica l'effetto**.

## 1. Prima domanda: giù, lento o rifiutato?

"Il sito non va" sono tre guasti diversi, e si distinguono dai log in pochi minuti:

| sintomo | dove si vede | cosa vuol dire |
|---|---|---|
| **nessuna riga nell'access log**, su tutti i siti, per qualche minuto | conteggio delle richieste al minuto | Apache non accetta: worker finiti, restart in corso, processo fermo |
| righe presenti ma tempi lunghi | `%D` nel `LogFormat` ( se c'è ) | worker occupati da richieste lente, backend ( PHP-FPM, database ) lento |
| righe con 403/500 su un sito solo | access log ed error log del vhost | permessi, `.htaccess`, ModSecurity, PHP |

Il conteggio al minuto è la prima prova, perché un buco nel log è un fatto e un "lento" no:

    cat /var/log/apache2/*/access.log | grep -E '06/Nov/2026:04:1' \
      | awk '{print substr($4,14,5)}' | sort | uniq -c

⚠ **Apache scrive la riga quando la richiesta finisce**, non quando arriva: una richiesta mai
accettata non lascia traccia, una richiesta lunga compare con l'ora d'inizio. Misurato il
06/11/2026: un controllo esterno segnalava 17 siti giù alle 04:17-04:19, e nei log di quei minuti
c'era **una riga sola** su tutti i siti. Il down era vero, non un falso positivo.

⚠ **Prima di chiamare falso positivo un allarme**, si cercano nell'access log del sito le richieste
del controllo stesso ( per user-agent ) nei minuti dell'allarme. Se non ci sono, non le ha servite
nessuno.

## 2. I worker finiti: `AH00161`

    [mpm_prefork:error] AH00161: server reached MaxRequestWorkers setting

- ⚠ **Si scrive una volta sola per vita del processo padre**: dopo la prima, Apache tace anche se
  resta saturo per ore. Un solo `AH00161` nell'error log non vuol dire un solo episodio; un restart
  azzera il conto. Si contano i buchi nell'access log, non le righe di errore.
- La domanda non è "quanti worker", è **chi li tiene occupati**. Si guarda nei minuti prima del buco:
  richieste per IP e per user-agent, e quali vhost hanno richieste lunghe. Misurato il 06/11/2026,
  con 30 worker: nessuna causa da sola, ma insieme i cron applicativi lenti di due siti, un bot su un
  terzo, uno scanner ( 179 richieste in un minuto, solo `.env`, `wp-config`, chiavi di servizio ) e il
  controllo di uptime.
- ⚠ **`ProxyTimeout` lungo verso PHP-FPM tiene il worker Apache per tutta la durata**: con
  `ProxyTimeout 900` una sola richiesta lenta occupa un worker fino a 15 minuti. Le richieste web
  vogliono un timeout corto; i cron lunghi si lanciano da riga di comando, non via HTTP.
- `mod_status` ( `/server-status`, solo da localhost ) dice in tempo reale chi occupa i worker:
  accenderlo **prima** del prossimo episodio, non durante.

## 3. Quanti worker: si calcola, non si sceglie

Il numero giusto viene dalla memoria, e la memoria si misura con il **Pss**, non con l'RSS: i
processi prefork condividono quasi tutto.

    for p in $(pgrep -x apache2); do awk '/^Pss:/{s+=$2} END{print s}' /proc/$p/smaps_rollup; done \
      | sort -n | awk '{a[NR]=$1; t+=$1} END{print "n",NR,"medio",int(t/NR),"KB max",a[NR],"KB"}'

- **Con `mod_php`** ogni processo Apache porta PHP: misurato il 04/10/2026, **151 processi da
  ~160 MB** su 8 GB senza swap, con `MaxRequestWorkers 150`. Un flood li ha riempiti e l'OOM killer
  ha ucciso il database. Lì il tetto compatibile era circa 30.
- **Con PHP-FPM** il processo Apache è leggero ( misurato: Pss medio 7 MB, massimo 13 MB, RSS 53 MB )
  e il rischio si sposta sui pool: `pm.max_children` sommato su tutti i pool, per la memoria del figlio
  più grosso. Lì 76 figli possibili a 100 MB facevano 7,6 GB teorici su 3,9 GB di RAM. **Alzare
  Apache senza guardare FPM sposta il collo di bottiglia nell'OOM.**
- La formula: `MaxRequestWorkers` × Pss massimo + Σ `pm.max_children` × memoria del figlio più grosso
  + database e cache, sotto la RAM **disponibile**, con margine. Se non ci sta, prima si accorciano i
  timeout e si limitano i pool, poi si alza.
- Prefork vs event: con PHP-FPM, `mpm_event` regge molte più connessioni per lo stesso numero di
  processi ( keep-alive fuori dai worker ). Il passaggio tocca tutti i siti e va provato: decide
  l'amministratore.

## 4. Reload, restart e i guardiani

- **`reload` ( graceful ), non `restart`**: il restart tronca le richieste in corso su tutti i siti.
  Misurato il 05/11/2026: un restart durante il lavoro sui vhost, poi nove reload in un quarto d'ora,
  e il controllo di uptime ha visto 21 siti giù per un minuto. Le modifiche ai vhost si raccolgono e
  si ricarica una volta, dopo `apachectl configtest`.
- ⚠ **monit riavvia Apache quando il suo controllo HTTP fallisce**, e lo fa in silenzio dopo il primo
  avviso. Misurato il 05-07/10/2026: un vhost di default che rispondeva 403 a tutti ( `Require all
  denied` ) faceva fallire il controllo su `http://127.0.0.1/`, e Apache veniva riavviato **circa 58
  volte all'ora** per un giorno e mezzo, troncando i ricalcoli lunghi di un gestionale. Prima di
  aggiungere un catch-all che rifiuta, si controlla che il controllo di monit continui ad avere 200
  ( `Require ip 127.0.0.1 ::1` nel catch-all ). Se il pid del padre cambia ogni minuto, si guarda
  `/var/log/monit.log`.
- Un riavvio fatto da monit è anche un sintomo: nell'error log compare come `caught SIGTERM` subito
  dopo il buco. Il guardiano ha ripristinato il servizio, ma la causa resta da trovare.

## 5. 403 e 500 su un sito solo

- **Ownership**: un file riscritto da uno strumento che gira come root resta `root:root`. PHP non lo
  legge ( 500 ); su una directory Apache dà 403 con un `AH00529` che cita un `.htaccess` magari
  inesistente, ma il problema vero è lo stat sulla cartella. `stat -c '%U:%G %a'` dopo ogni scrittura
  nella document root.
- **ModSecurity con OWASP CRS** in anomaly mode a soglia 5: una sola regola CRITICAL basta a dare 403.
  I CMS che salvano HTML, JS o CSS nei campi la fanno scattare per forza. Si legge l'error log del
  vhost filtrando i blocchi veri ( `at ARGS` / `at REQUEST_BODY` ) e scartando il rumore degli scanner;
  si corregge con un'esclusione **mirata** al campo ( `SecRuleUpdateTargetById <id> "!ARGS:/<campo>/"`
  nel file delle esclusioni dopo il CRS ), mai spegnendo la regola per tutti.
- **Un 500 senza traccia dell'applicazione può essere ModSecurity.** Misurato il 09/11/2026 su un web
  server con mod_security2 2.9.3: 176 risposte 500 in tre ore a degli scanner, e nessuna riga nel log
  dell'applicazione. Ogni POST multipart **senza il boundary finale** prende 500 da ModSecurity prima di
  arrivare a PHP ( `Multipart parsing error: Multipart: Final boundary missing`, e nessun `Access denied` ):
  le regole 200002/200003, che dovrebbero dare 400, non scattano. Si riproduce su qualunque sito della
  macchina con un `curl -X POST -H 'Content-Type: multipart/form-data; boundary=x'` e un corpo che non
  chiude con `--x--`. Il 500 non è un buco, perché la richiesta non passa. Prima di cercare il bug
  nell'applicazione si confronta l'ora del 500 con l'error log del vhost. ⚠ ModSecurity non registra
  le richieste da localhost, quindi la prova si fa dall'IP pubblico.
- **`.htaccess` in sottocartella con `RewriteEngine on`** e senza `RewriteOptions Inherit` spegne le
  regole di rewrite della radice, compresi i divieti di sicurezza: si cercano tutti, non solo quello
  del sito che ha il problema.

## 6. Quello che si mette prima di averne bisogno

Durante un incidente si scopre cosa mancava nei log. Su ogni Apache, in un giro tranquillo:

| cosa | perché |
|---|---|
| `%D` ( microsecondi ) nel `LogFormat` | senza, "lento" è un'impressione; con, si ordina per tempo |
| `mod_status` su localhost | chi tiene i worker, nel momento in cui succede |
| una jail fail2ban sui 404 degli scanner con `maxretry` realistico | misurato: uno scanner con 156 richieste in errore non è stato bannato con `maxretry 100` |
| il conteggio dei buchi al minuto nell'access log, nel giro della mattina | `AH00161` tace dopo la prima volta, i buchi no |
| `.git`, `.env` e le copie con suffisso dopo l'estensione chiusi con un 404 globale | vedi i punti sul repository e sulle copie nel `SKILL.md` |

Ogni modifica: copia datata, `apachectl configtest`, `reload`, e la verifica dell'effetto
( `apachectl -t -D DUMP_RUN_CFG`, il valore attivo, una richiesta vera ) come al punto 4 della skill.

## 7. Un down che comincia con un ban di fail2ban

Misurato il 12/11/2026 su un apache prefork ( `MaxRequestWorkers 60`, `Timeout 300` ): tre down di 3-4 minuti in tre giorni, tutti
e tre cominciati **entro 2 secondi da un Ban** del jail sui 404, e finiti solo col restart del guardiano. Prima di ogni ban lo
scanner aveva fatto 123-191 richieste in pochi secondi, quindi molte connessioni in parallelo. Traffico totale, richieste lente
ed errori del database non spiegavano niente. Altri tre ban, nello stesso periodo, non hanno causato nessun down.

L'ipotesi del meccanismo: il REJECT colpisce anche le connessioni **già stabilite**, e così ogni worker che sta servendo lo scanner
resta appeso finché non scade `Timeout`. Con pochi worker basta uno scanner parallelo a riempirli tutti.

- Davanti a un down, si confronta l'ora di inizio **al secondo** con `grep -E '\] (Ban|Unban) ' /var/log/fail2ban.log`.
- ⚠ Nell'access log non si vede: le richieste interrotte dal restart non vengono scritte, quindi la raffica sembra finita
  nel momento in cui comincia il buco.
- La correzione applicata è un'azione di ban che chiude anche i socket già aperti, cioè i worker:
  `actionban = ss -K dst <ip> '( sport = :80 or sport = :443 )'` ( richiede `CONFIG_INET_DIAG_DESTROY=y` ), aggiunta
  al jail con `action = %(action_)s` e `ss-kill` su una riga a sé. Provata con una richiesta lasciata a metà da un indirizzo
  di loopback: con l'azione il server la resetta in 2,6 s, senza aspetta il 408 a 20 s. ⚠ `conntrack -D` non serve:
  cancella lo stato nel firewall ma non chiude il socket, e il worker resta appeso.
- ⚠ Misurato su fail2ban 0.10: `reload <jail>` e anche `reload` **non aggiungono** un'azione nuova ( `get <jail> actions`
  continua a mostrare solo quella vecchia, senza errori ). Serve `reload --restart <jail>`, che ripristina i ban dal database.
  Dopo si controlla sempre `get <jail> actions`.
- L'altra strada era abbassare `Timeout` da 300 verso 60, ma con `proxy_fcgi` vale anche verso PHP-FPM e taglia i cron lunghi.
  Per questo è stata scartata.

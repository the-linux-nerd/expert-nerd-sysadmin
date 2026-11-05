# Takeout di un sito

Nata il **22/10/2026** dall'archiviazione di un sito su un server CloudPanel, prima di spegnerlo.
Vale quando si salva **un sito solo** e la macchina resta accesa; per una macchina intera c'è
`takeout.md`, e l'ordine resta quello: **censimento → salvataggio → verifica → spegnimento → dopo**.

## Dove sta un sito

- **CloudPanel**: `/home/UTENTE/` ( `htdocs/`, `logs/`, `backups/`, `.ssh/` ), vhost nginx in
  `/etc/nginx/sites-enabled/DOMINIO.conf`, pool PHP-FPM in `/etc/php/X.Y/fpm/pool.d/DOMINIO.conf`,
  certificati in `/etc/nginx/ssl-certificates/`, logrotate in `/etc/logrotate.d/`, database e utenti
  MySQL nel sqlite di CloudPanel ( `/home/clp/htdocs/app/data/db.sq3` ). Il sito si trova per utente
  o per dominio.
- **classico**: `/var/www/SITO/`, vhost Apache o nginx, eventuale pool PHP-FPM, certificati certbot.

## Censimento

    va.takeout.site.inventory.sh HOST SITO [CARTELLA]

- Gira sulla macchina che riceve il takeout e raggiunge il server via ssh a chiave; sul server **non
  scrive niente** ( dal 05/11/2026: prima creava `/root/takeout/sito.SITO/`, e quando il sito stava sulla
  stessa macchina della sessione l'hook che vieta file nuovi nella radice di `/root` lo fermava ).
- La cartella di default è `/var/backups/SITO/AAAAMMGG-takeout/`; dentro mette `inventario.md`,
  `scheda.txt`, `atteso.txt` ( gli archivi da produrre ), `meta.txt` e le `.list` dei file.
- ⚠ **Il database può non stare sulla macchina del sito.** Cerca i database in CloudPanel, in
  `wp-config.php`, `.env` e nel `src/config.json` dei deploy glisweb; quelli con un host diverso da
  `localhost` li prova **dalla macchina del sito con le credenziali del sito** ( per glisweb utente e
  password stanno in `src/shadow.json`, non in `config.json` ): quelli che rispondono diventano archivi
  `remoto.HOST.DB.sql.gz`, che `va.takeout.pull.sh` scarica da lì senza che la password lasci la
  macchina ( opzioni passate con `<(...)`, mai sulla riga di comando ). Quelli che non rispondono restano
  avvisi, da salvare a mano se sono ancora in uso. Utenti e grant dei database remoti non si salvano:
  stanno sul server del database.
- Con `HOST` = `127.0.0.1` i nomi DNS si confrontano anche con gli indirizzi che la macchina dichiara
  ( interfacce e IP pubblico dai metadati del cloud ): prima risultavano tutti "altrove".
- Archivi attesi: `home.UTENTE.tar.gz` ( o `var.www.SITO.tar.gz` ), `sito.SITO.config.tar.gz`
  ( vhost, pool, certificati, logrotate, crontab ), un `var.lib.mysql.DB.sql.gz` per database e
  `var.lib.mysql.users.DB.sql.gz` con gli utenti MySQL e i loro grant.
- Esce con 1 se lo spazio non basta o se MySQL non risponde: **non si va avanti con un KO**.
- Nell'inventario si guardano: i nomi DNS che puntano ancora qui ( se il sito è vivo, spegnerlo è
  una decisione dell'amministratore ), la dimensione, gli avvisi.

## Le trappole già incontrate

- **Le copie di backup di CloudPanel** ( `/home/UTENTE/backups` ) restano fuori: spesso pesano più
  del sito. Se l'amministratore le vuole, si aggiungono al pull come percorso extra.
- **MySQL senza credenziali**: gli script usano `--defaults-extra-file=/etc/mysql.conf`, che deve
  avere `[client]` e utente e password validi. Su CloudPanel la password di root sta in
  `clpctl db:show:master-credentials`, una tabella verticale ( `| Host | … |`, una riga per chiave ).
  Si scrive il file **senza mai stampare la password**: si legge la tabella con `awk -F"|"`, si
  scrive `/etc/mysql.conf.nuovo` in umask 077, si prova `select 1`, e solo se riesce si sostituisce
  il vecchio ( copia prima in `/root/` ). La password nel sqlite di CloudPanel è cifrata: non serve.

- **L'utente dell'applicazione non legge tutto il suo database.** Misurato il 05/11/2026 su tre
  deploy: `mysqldump --routines` si ferma su *insufficient privileges to SHOW CREATE FUNCTION* ( 139
  funzioni su un gestionale, 48 routine su un altro, 7 su un terzo ) e lascia un file a metà. Il
  censimento prova prima eventi e routine: quelle illeggibili si saltano **dichiarandolo** negli avvisi,
  e se servono complete il dump si fa **sul server del database** con le sue credenziali di
  amministrazione ( `--defaults-file=/etc/mysql/debian.cnf` su Debian ). Si controlla `-- Dump
  completed` in coda, e che `CREATE TABLE` più `CREATE VIEW` tornino col conteggio di
  `information_schema.tables`. Il file degli utenti a mano deve finire con `-- Grants completed`,
  sennò `verify` lo dà troncato;
- **una vista rotta ferma il dump**: *View ... references invalid table(s) or column(s)* ( 1356 ), visto
  su un deploy il 05/11/2026. `--force` lo farebbe passare saltando la vista in silenzio: su un sito vivo
  non si usa, il KO resta e la vista si corregge o si toglie nel progetto, decisione di chi lo segue. Su
  un sito **dismesso** nessuno la correggerà più: si fa il dump con `--force` e un nome che lo dichiara
  ( `DB.forzato.sql.gz` ), lo si dice nel README dell'archivio e si contano le tabelle contro
  `information_schema` ( visto il 05/11/2026: 248 tabelle su 248, la vista rotta salvata comunque );
- **due server con lo stesso indirizzo, lo stesso database e password diverse**, in un `config.json`
  glisweb: una era vecchia, e solo il server del profilo di produzione entrava. Le credenziali si
  scelgono per server, non per indirizzo, e un database si dà per irraggiungibile solo se non risponde
  con nessuno;
- **il takeout fatto sulla macchina stessa** ( `HOST` = `127.0.0.1` ): il controllo DNS confronta con
  `127.0.0.1` e scrive *"nomi DNS che puntano qui: 0"* anche quando puntano lì. Il DNS si guarda a mano
  contro l'IP pubblico.

## Salvataggio e verifica

    va.takeout.pull.sh HOST CARTELLA [PERCORSI EXTRA]
    va.takeout.verify.sh CARTELLA

Come per la macchina intera: un archivio per voce, si riprende da dove si è fermato, la verifica
controlla che ogni archivio atteso ci sia, si legga fino in fondo e torni con `SHA256SUMS`.

## Dopo

Spegnere il sito, cancellare i file, il database, l'utente MySQL e i record DNS lo decide
l'amministratore, e solo dopo un verify OK. Il takeout si conserva dove dice lui, con una riga nel
README della cartella di archivio.

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

- Gira sulla macchina che riceve il takeout e raggiunge il server via ssh a chiave; sul server scrive
  solo `/root/takeout/sito.SITO/scheda.txt`.
- La cartella di default è `/var/backups/SITO/AAAAMMGG-takeout/`; dentro mette `inventario.md`,
  `atteso.txt` ( gli archivi da produrre ), `meta.txt` e le `.list` dei file.
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

## Salvataggio e verifica

    va.takeout.pull.sh HOST CARTELLA [PERCORSI EXTRA]
    va.takeout.verify.sh CARTELLA

Come per la macchina intera: un archivio per voce, si riprende da dove si è fermato, la verifica
controlla che ogni archivio atteso ci sia, si legga fino in fondo e torni con `SHA256SUMS`.

## Dopo

Spegnere il sito, cancellare i file, il database, l'utente MySQL e i record DNS lo decide
l'amministratore, e solo dopo un verify OK. Il takeout si conserva dove dice lui, con una riga nel
README della cartella di archivio.

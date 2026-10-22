# Takeout di una macchina

Nato il **22/10/2026** dal takeout di una macchina Debian 10 su Google Cloud da dismettere. Un
takeout serve a una di due cose, e la differenza decide l'ordine dei passi:

- **trasferimento**: la macchina rinasce altrove, e il takeout è quello che ci si porta;
- **archiviazione**: la macchina si spegne e basta, il takeout resta per il caso che un giorno
  la si debba ricreare.

> **REGOLA D'ORO: prima si collauda il nuovo, poi si spegne il vecchio.** Nel trasferimento non ci
> sono eccezioni. Nell'archiviazione il "nuovo" non c'è, e il collaudo è la verifica del takeout.

Tutto si fa con gli script di **calabash** ( `va.takeout.*`, in `/usr/local/sbin` ), che girano
**sulla macchina che riceve il takeout** — quella dove lavora Claude — e leggono la vecchia via ssh.
Se uno script non fa quello che serve si corregge lo script e si aggiorna il repository di calabash,
non si fa a mano "per questa volta".

## 0. Prima di cominciare

- **calabash installato** sulla macchina locale ( vedi `SKILL.md`, *calabash* ): senza `va.takeout.*`
  non si comincia.
- **Accesso ssh a chiave** come root verso la macchina da salvare:
  `ssh -o BatchMode=yes root@HOST true`. Se non entra, si chiede all'amministratore di autorizzare
  la chiave: password e scorciatoie no ( e SSH accetta solo chiavi, `SKILL.md` ).
- Decidere **trasferimento o archiviazione**, e il **nome** della macchina: dà il nome alla cartella.

## 1. Censimento

    va.takeout.inventory.sh HOST NOME

È **il primo passo, sempre**, perché decide cosa si salva. Sulla macchina remota scrive soltanto in
`/root/takeout/` — `installed.pkg.txt` ( `dpkg --get-selections` ), `iptables/` ( `iptables-save`,
`ip6tables-save`, `nft` ), `sistema.md` ( versione, cpu e memoria, dischi, mount, fstab, rete, porte,
servizi, timer ) — così finiscono in `root.tar.gz`. In locale crea
`/var/backups/NOME/AAAAMMGG-takeout/` ( `700` ) con `inventario.md`, `atteso.txt` e `meta.txt`.

Dell'inventario si leggono, nell'ordine:

1. **gli avvisi** — script lanciati dai cron che nessun archivio copre, utenti con la home fuori da
   `/home`, file sciolti in `/var/www`, PostgreSQL, Docker, MongoDB ( non coperti: si salvano a mano o
   si estende lo script );
2. **lo spazio** — da salvare ( non compresso ) contro libero in locale. ⚠ **Se è KO lo spazio lo
   libera il sistemista**: non si sceglie un posto di comodo e non si salva a metà;
3. **`/var/backups`** — oltre ai file standard di Debian, cosa c'è e se va salvato ( si decide qui e
   si passa come percorso extra al passo 2 );
4. **i cron** — cosa gira, cosa non viene da un pacchetto;
5. **i nomi DNS** — quali puntano ancora a questa macchina: sono il lavoro del *dopo*;
6. **il cloud** — istanza, zona, progetto, e i comandi per dischi e snapshot.

Il censimento deve bastare a **ricreare la macchina altrove** anche quando il takeout è per
archivio: non si sa mai.

## 2. Salvataggio

    va.takeout.pull.sh HOST CARTELLA [PERCORSO_EXTRA ...]

Gli archivi si producono **in streaming via ssh** direttamente in locale: sulla vecchia non si
scrive niente. Il nome è il percorso con i punti al posto delle barre:

| archivio | cosa contiene |
|---|---|
| `etc.tar.gz` | configurazioni, crontab di sistema, certificati |
| `root.tar.gz` | chiavi di root, `/root/takeout/`, e **tutto Claude**: `~/.claude` ( skill, memorie, impostazioni ), `CLAUDE.md`, `READ.md`, `TODO.md` |
| `home.UTENTE.tar.gz` | una per utente |
| `var.spool.cron.crontabs.tar.gz` | i crontab degli utenti ( `crontab -e` ), che non stanno in `/etc` |
| `var.mail.tar.gz`, `var.vmail.tar.gz` | la posta, se c'è |
| `usr.local.bin.tar.gz`, `usr.local.sbin.tar.gz`, `opt.tar.gz`, `srv.tar.gz` | script e programmi installati a mano |
| `usr.bin.custom.tar.gz`, … | gli eseguibili di `/bin`, `/sbin`, `/usr/bin`, `/usr/sbin` che nessun pacchetto dichiara |
| `var.www.SITO.tar.gz` | uno per sito |
| `var.lib.redis.tar.gz` | i dati di redis, se ci sono |
| `var.lib.mysql.DB.sql.gz` | un dump per database, `--single-transaction --routines --triggers --events`, fedele |
| `var.lib.mysql.users.UTENTE.sql.gz` | `CREATE USER` e `GRANT` di ogni utente MySQL: i dump dei database non li contengono, e senza le applicazioni non entrano |
| `PERCORSO.CON.PUNTI.tar.gz` | i percorsi extra decisi al censimento |

Un archivio già scaricato non si riscarica: dopo un errore si rilancia e riprende. File `600`, e
alla fine `SHA256SUMS`.

⚠ **`/root` è il punto più delicato**: lì sta l'esperienza accumulata da Claude su quella macchina,
che non esiste in nessun'altra copia. La verifica controlla esplicitamente che ci sia.

## 3. Verifica

    va.takeout.verify.sh CARTELLA

Per ogni archivio atteso: presente, leggibile per intero ( `tar -tzf` e la decompressione completa
controllano il CRC di gzip ), completo ( `-- Dump completed` in coda ai dump, `-- Grants completed`
in coda agli utenti, `/root/takeout/` e `/root/.claude` dentro `root.tar.gz` ), poi `SHA256SUMS`.
Exit 1 se qualcosa non va. **Un KO si risolve prima di andare avanti**, non si annota.

La verifica dice che gli archivi sono interi, **non che bastano**: quello lo dice il collaudo.

## 4. Collaudo ( trasferimento )

**Obbligatorio**, ed è un ripristino vero sulla macchina nuova:

    tar -xzpf ARCHIVIO --numeric-owner -C /            # o in una cartella di appoggio, per confrontare
    zcat var.lib.mysql.users.UTENTE.sql.gz | mysql     # prima gli utenti
    zcat var.lib.mysql.DB.sql.gz | mysql               # poi i database ( il dump crea il database )

- ogni sito risponde sulla macchina nuova, provato con l'host giusto **prima** di toccare il DNS
  ( `curl --resolve dominio:443:IP_NUOVO https://dominio/` );
- i database hanno le stesse tabelle e lo stesso numero di righe nelle tabelle principali;
- le applicazioni entrano nel database con i loro utenti;
- i cron girano, la posta parte, i certificati si rinnovano ( `certbot renew --dry-run` );
- solo allora si spostano i DNS, e si guarda che il traffico arrivi davvero sulla nuova.

## 5. Spegnimento

- **archiviazione**: dopo la verifica del passo 3;
- **trasferimento**: dopo il collaudo del passo 4 e un periodo di convivenza, con i DNS già spostati
  e il traffico sulla vecchia a zero ( si guarda l'`access.log` ).

⚠ **Eliminare la macchina è irreversibile e lo decide l'amministratore.** Prima, su un cloud: se
c'è l'autorizzazione si controllano gli snapshot dei dischi ( i comandi sono nell'inventario ), e
si **raccomanda** di tenerne uno per qualche settimana dopo l'eliminazione: costa poco ed è una
rete di sicurezza oltre ai tar. Se non c'è, si propone di farlo.

## 6. Dopo

Dall'inventario, e diverso nei due casi:

- **DNS**: i nomi che puntano ancora qui si spostano ( trasferimento ) o si tolgono ( archiviazione ),
  insieme agli IP statici prenotati sul cloud, che altrimenti si pagano;
- **accessi**: chiavi della vecchia macchina nelle `authorized_keys` altrui, utenti e IP autorizzati
  nei database e nei firewall di altre macchine;
- **monitoraggio e backup remoti** che la cercano ( monit, uptime, job di backup ): si tolgono, o
  arriveranno allarmi falsi;
- **documentazione**: il `READ.md` della macchina che riceve il takeout dice dov'è e cos'è.

## 7. Conservazione

**Indefinita.** Il takeout si cancella solo quando lo decide l'amministratore. ⚠ Si controlla che
nessuna rotazione dei backup tocchi `/var/backups/NOME/`: uno script di pulizia "dei file vecchi"
lanciato su `/var/backups` se lo porterebbe via in silenzio.

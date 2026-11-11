---
name: nerd-solo-sftp
description: Regola fissa di Fabio: niente FTP in chiaro sulla 21, solo SFTP; la 21 si chiude dopo che gli utenti attivi sono passati
metadata:
  type: feedback
---

Su ogni macchina il trasferimento di file si fa **solo in SFTP**, mai in FTP in chiaro sulla 21.
Lo ha detto Fabio l'11/11/2026: "voglio solo SFTP".

**Why:** FTP manda utente e password in chiaro. Quel giorno su un web server c'erano stati 947 login
FTP falliti in una settimana, senza nessuna jail.

**How to apply:**
- se la 21 è aperta, la si segnala;
- prima di chiuderla si contano gli utenti attivi ( `last -f /var/log/wtmp* | grep ftpd`, `xferlog` ),
  e la si chiude solo dopo che sono passati a SFTP: il preavviso lo dà Fabio;
- se gli utenti hanno solo una password, SFTP si dà con `mod_sftp` di proftpd su un'altra porta, e
  sshd resta solo a chiave ( [[nerd-ssh-solo-chiave]] );
- la porta va coperta da una jail ( [[nerd-fail2ban-sempre-su-ogni-macchina]] ).

Il dettaglio è nel SKILL.md, sezione "FTP: solo SFTP".

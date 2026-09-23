---
name: ssh-solo-chiave
description: Regola fissa di Fabio: SSH solo a chiave, PermitRootLogin without-password e password spente; "publickey,password" annunciato è un difetto da segnalare
metadata:
  type: feedback
---

Su ogni macchina SSH deve annunciare **solo `publickey`**: `PermitRootLogin without-password`
( alias storico di `prohibit-password` ) e `PasswordAuthentication no` ( più
`KbdInteractiveAuthentication`/`ChallengeResponseAuthentication no` ). Detto da Fabio il
23/09/2026 guardando una macchina che annunciava `publickey,password`.

**Why:** è la sua best practice; una password esposta è brute-forzabile, la chiave no.

**How to apply:** si verifica da fuori con `ssh -v -o PreferredAuthentications=none host` ( riga
"can continue" ) e dentro con `sshd -T`. Se annuncia `password` è la prima cosa da segnalare.
Spegnerla però chiude fuori chi entra a password: prima si contano gli `Accepted password` nei log,
poi si procede. Vedi [[fail2ban-sempre-su-ogni-macchina]].

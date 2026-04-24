# sudo — faillock bloqueando usuário

## Sintoma

`sudo` pede senha mas rejeita com "Sorry, try again" mesmo com a senha correta. `su -` funciona normalmente (usa senha do root).

## Causa

O `faillock` (PAM) bloqueia o usuário após X tentativas falhas consecutivas de autenticação. Acontece quando algum script/serviço tenta usar `sudo` repetidamente sem sucesso — ex: `tray-restart.sh`, serviços systemd com `ExecStartPre` que falham.

## Fix

```bash
faillock --user $USER --reset
```

## Diagnóstico

```bash
# Ver tentativas falhas e status do lock
faillock --user lukesh

# Ver qual processo causou as falhas
journalctl -b | grep -E "sudo|pam|faillock|authentication failure" | tail -30
```

## Prevenção

Serviços systemd que rodam comandos opcionais devem usar o prefixo `-` para ignorar falhas sem contar como erro de autenticação:

```ini
ExecStartPre=-/usr/bin/pkill kded6   # o "-" ignora falha
```

Scripts que usam `sudo` devem ter `|| true` em comandos opcionais para não causar loop de retry.

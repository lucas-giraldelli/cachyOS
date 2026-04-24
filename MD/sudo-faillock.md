# sudo — faillock bloqueando usuário

## Sintoma

`sudo` pede senha mas rejeita com "Sorry, try again" mesmo com a senha correta. `su -` funciona normalmente (usa senha do root).

## Causa

O `faillock` (PAM) bloqueia o usuário após X tentativas falhas consecutivas de autenticação. Pode ser:

- **Você mesmo** digitando a senha errada várias vezes (caps lock, layout de teclado)
- **Dolphin/polkit** tentando montar dispositivos e falhando na autenticação
- Scripts/serviços que tentam `sudo` repetidamente sem sucesso

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

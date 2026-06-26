# sudo — faillock locking the user out

## Symptom

`sudo` asks for password but rejects it with "Sorry, try again" even when the password is correct. `su -` works fine (uses root's password, not the user's).

## Cause

`faillock` (PAM) locks the user after X consecutive failed authentication attempts. Can be triggered by:

- **Typing the wrong password** multiple times (caps lock, keyboard layout)
- **Dolphin/polkit** failing to authenticate when trying to mount devices
- Scripts or services attempting `sudo` repeatedly without success
- **Running `sudo` through a non-interactive prompt** (e.g. Claude Code's `!`
  bash prompt). `sudo` fails with `a terminal is required to read the password`;
  repeated attempts pile up failures that trip faillock. Run `sudo` in a real
  terminal instead.

## Fix

```bash
faillock --user $USER --reset
```

## Diagnosis

```bash
# Show failed attempts and lock status
faillock --user lukesh

# Find what process caused the failures
journalctl -b | grep -E "sudo|pam|faillock|authentication failure" | tail -30
```

## Prevention

Systemd services running optional commands should use the `-` prefix to ignore failures without counting as auth errors:

```ini
ExecStartPre=-/usr/bin/pkill kded6   # "-" ignores failure
```

Scripts using `sudo` for optional commands should use `|| true` to avoid retry loops.

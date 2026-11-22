# keys-vault

[![CI](https://github.com/fkzys/keys-vault/actions/workflows/ci.yml/badge.svg)](https://github.com/fkzys/keys-vault/actions/workflows/ci.yml)
![License](https://img.shields.io/github/license/fkzys/keys-vault)
[![Spec](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/fkzys/specs/refs/heads/main/version.json&maxAge=300)](https://github.com/fkzys/specs)

File-based encryption for sensitive directories via [gocryptfs](https://github.com/rfjakob/gocryptfs) + gnome Keyring.

Encrypted ciphertext is stored in a hidden directory; plaintext is mounted via FUSE. The passphrase is stored in GNOME Keyring for automatic unlock.

## Docs

- **[notes](docs/notes.md)**
    - [Configuration](docs/notes.md#configuration)
    - [Custom directory](docs/notes.md#custom-directory)
    - [Stale mount recovery](docs/notes.md#stale-mount-recovery)

## Installation

### AUR

```bash
yay -S keys-vault
```

### [gitpkg](https://github.com/fkzys/gitpkg)
```bash
gitpkg install keys-vault
```

### Manual

```bash
git clone https://github.com/fkzys/keys-vault.git
cd keys-vault
sudo make install
```

## Master key recovery

`init` displays the gocryptfs master key once (when run from a terminal). The
master key is the only way to recover the vault if `gocryptfs.conf` is damaged
or the passphrase is lost — gocryptfs cannot show it again afterwards. Save it
somewhere safe (e.g. KeePassXC) when it is printed.

When stdout is not a terminal, gocryptfs suppresses the master key so it cannot
leak into logs; run `init` interactively to capture it.

## Commands

| Command | Description |
|---|---|
| `init` | Create encrypted volume, print master key, store passphrase in keyring |
| `open` | Mount vault; recovers stale mounts; no-op if already mounted or not initialized |
| `close` | Unmount vault; handles stale mounts; no-op if not mounted |
| `status` | Print state: `open` / `locked` / `stale` / `not initialized` |
| `passwd` | Rotate gocryptfs passphrase and update keyring |

### Variables

| Variable | Default | Description |
|---|---|---|
| `PLAIN_DIR` | `~/keys` | Plaintext mount point |
| `CIPHER_DIR` | Derived from `PLAIN_DIR` | Encrypted ciphertext directory |

`CIPHER_DIR` is derived as a hidden directory with `.enc` suffix, like `~/keys` will be `~/.keys.enc`

## Options

| Option | Description |
|---|---|
| `--dir=PATH` | Plaintext mount point (default: `~/keys`) |
| `--cipher-dir=PATH` | Encrypted ciphertext directory (default: derived from `--dir`) |

## Systemd integration

A user service is included for automatic mount on login:

```bash
systemctl --user enable --now keys-vault.service
```

The service mounts on start (`After=gnome-keyring-daemon.service`) and unmounts on stop.

Custom directories configured via `~/.config/keys-vault.conf` are picked up by the service automatically. For per-flag overrides, create a service drop-in:

```bash
systemctl --user edit keys-vault.service
```

```ini
[Service]
ExecStart=
ExecStart=/usr/bin/keys-vault --dir=%h/secure/credentials open
ExecStop=
ExecStop=/usr/bin/keys-vault --dir=%h/secure/credentials close
```

## Dependencies

- [gocryptfs](https://github.com/rfjakob/gocryptfs)
- `secret-tool`
- `fusermount`
-  gnome keyring

## License

AGPL-3.0-or-later

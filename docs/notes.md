# keys-vault

## Configuration

Configuration is read from (in order, later values override earlier):

1. `/etc/keys-vault.conf` — system-wide defaults
2. `$XDG_CONFIG_HOME/keys-vault.conf` (default: `~/.config/keys-vault.conf`) — per-user overrides
3. CLI flags (`--dir`, `--cipher-dir`)

### Custom directory

You can use arg:
```bash
keys-vault --dir=~/secure/credentials init
```

or flag:
```bash
echo 'PLAIN_DIR="${HOME}/secure/credentials"' > ~/.config/keys-vault.conf
keys-vault init
```

## Stale mount recovery

If the gocryptfs process dies (e.g. OOM kill) the FUSE mountpoint becomes stale — it appears in `/proc/mounts` but `stat` fails with "Transport endpoint is not connected".

- **`open`** detects this and force-unmounts before re-mounting
- **`close`** detects stale mounts and force-unmounts them
- **`status`** reports `stale` as a distinct state

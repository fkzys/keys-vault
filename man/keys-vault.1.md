---
title: KEYS-VAULT
section: 1
header: User Commands
footer: keys-vault
---

# NAME

keys-vault — file-based encryption for sensitive directories via gocryptfs + GNOME Keyring

# SYNOPSIS

**keys-vault** [*options*] *command*

# DESCRIPTION

**keys-vault** manages an encrypted gocryptfs volume. The encrypted ciphertext
is stored in a hidden directory; the plaintext is mounted via FUSE. The
passphrase is stored in GNOME Keyring for automatic unlock.

# COMMANDS

**init**
:   Create a new encrypted volume and store the passphrase in GNOME Keyring.
    Offers a choice between a randomly generated passphrase and a user-supplied
    one. Refuses to initialize if the plaintext directory is not empty. Prints
    the gocryptfs master key when run on a terminal.

**open**
:   Mount the vault using the passphrase from GNOME Keyring. Automatically
    recovers stale FUSE mounts. No-op if already mounted or not initialized.

**close**
:   Unmount the vault. Handles stale mounts. No-op if not mounted.

**status**
:   Print the current state: **open**, **locked**, **stale**, or
    **not initialized**.

**passwd**
:   Rotate the gocryptfs passphrase and update the keyring entry.

# OPTIONS

**\-\-dir**=*PATH*
:   Plaintext mount point. Default: **~/keys**.

**\-\-cipher-dir**=*PATH*
:   Encrypted ciphertext directory. Default: derived from **\-\-dir** as a
    hidden directory with **.enc** suffix in the same parent directory
    (e.g., ~/keys → ~/.keys.enc, ~/secure/vault → ~/secure/.vault.enc).

**-h**, **\-\-help**
:   Show usage information.

**\-\-version**
:   Show version.

# CONFIGURATION

Configuration is read from (in order, later values override earlier):

1. **/etc/keys-vault.conf** — system-wide defaults
2. **$XDG_CONFIG_HOME/keys-vault.conf** (default: **~/.config/keys-vault.conf**) — per-user overrides

CLI flags take precedence over configuration files.

Configuration files use **KEY = VALUE** format. Only whitelisted keys are
accepted; unknown keys produce a warning and are ignored. Both **$HOME**,
**${HOME}**, and **~** are expanded in paths. Surrounding quotes (single or
double) are stripped from values. Inline comments (after space-hash) are
stripped.

## Variables

**PLAIN_DIR**
:   Plaintext mount point. Default: **$HOME/keys**.

**CIPHER_DIR**
:   Encrypted ciphertext directory. Default: derived from PLAIN_DIR.

# STALE MOUNT RECOVERY

If the gocryptfs process dies (e.g., OOM kill) the FUSE mountpoint becomes
stale — it appears in */proc/mounts* but *stat*(2) fails with "Transport
endpoint is not connected".

**open** detects this and force-unmounts the stale mountpoint before
re-mounting. **close** also handles stale mounts. **status** reports **stale**
as a distinct state.

# KEYRING

Passphrases are stored in GNOME Keyring via **secret-tool**(1). Each vault
directory gets a unique keyring entry keyed by its resolved plaintext path.

# MASTER KEY

**init** prints the gocryptfs master key once, when output is a terminal. The
master key is the only way to recover the vault if **gocryptfs.conf** is
damaged or the passphrase is lost; it cannot be displayed again afterwards.
Store it in a safe place immediately.

When stdout is not a terminal, gocryptfs suppresses the master key to keep it
out of log files. Run **init** interactively to capture it.

# EXAMPLES

Initialize and open a vault at the default location:

    keys-vault init
    keys-vault open

Use a custom directory:

    keys-vault --dir=~/secure/credentials init
    keys-vault --dir=~/secure/credentials open

Or configure via file:

    echo 'PLAIN_DIR = $HOME/secure/credentials' > ~/.config/keys-vault.conf
    keys-vault init

Check status:

    keys-vault status

# FILES

*/etc/keys-vault.conf*
:   System-wide configuration.

*~/.config/keys-vault.conf*
:   Per-user configuration.

# SEE ALSO

**gocryptfs**(1), **secret-tool**(1), **fusermount**(1)

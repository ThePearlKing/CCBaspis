# Encrypted personal drive

CCSacabam encrypts the complete virtual filesystem before writing it to disk. Directory names, file contents, settings, Trash, and the system log are inside the encrypted envelope. There is no plaintext `/ccsacabam/home` directory to discover after leaving the desktop. Ordinary program writes through the session's `fs`, `io`, and settings APIs go to this drive.

This does not encrypt files that were already on the computer, public OS sources, the installer, or physical startup backups. Importing an existing file copies it into the vault; its original is still present under `/host`. Remove the original yourself if you no longer need it, accounting for any backups outside the computer.

## Format and keys

The `SCV1` envelope consists of a four-byte magic value, 32-byte salt, four-byte big-endian iteration count, 12-byte nonce, ciphertext, and a 32-byte authentication tag. Its plaintext is a serialized map of file paths to contents or directory markers.

* PBKDF2-HMAC-SHA-256 derives a 256-bit master key using 100,000 iterations. Login time depends on the emulator or server. Tests use a smaller count for some fixtures; normal installation does not.
* HMAC derives separate encryption, authentication, and nonce keys from the master key.
* IETF ChaCha20 encrypts the filesystem, starting at block counter 1.
* HMAC-SHA-256 authenticates the complete header and ciphertext before decryption.
* ComputerCraft has no standard cryptographic random generator. The salt combines installation timing and computer identity. Each nonce is a truncated keyed digest of the plaintext digest, time, and a write counter. Including contents avoids relying on a counter surviving a rollback. This is a custom, unaudited construction, not a standardized AEAD implementation.

The implementations are checked against published [ChaCha20](https://www.rfc-editor.org/rfc/rfc8439.html), [HMAC](https://www.rfc-editor.org/rfc/rfc4231.html), and PBKDF2 test values. Matching test vectors is not a security audit. A strong, unique passphrase matters: someone with the encrypted file can try passwords offline.

## Boundaries

The vault provides encryption at rest. It is **not an isolation boundary for hostile Lua programs**. Programs run with the normal powerful ComputerCraft APIs; a malicious program or modified OS can steal an entered password or unlocked data. A Minecraft administrator or emulator host can also inspect or modify the machine. Locking drops key references and clears the in-memory filesystem table, but Lua does not guarantee physical memory zeroization.

The installer checks packaged file hashes for corruption, not the publisher's identity. Obtain it from a trusted source. An attacker who replaces the installer can replace its checks too.

Europa and Chat+ use modem protocols. Their network messages are not encrypted by the vault. Rednet domains and sender IDs are not cryptographic identities. Publish only files intended for other computers to read. Callisto restricts website scripting to a bounded subset of Pistachio without local file commands; it does not run downloaded Lua.

## Saving and recovery

File handles commit buffered writes on `flush` or `close`. Every committed mutation encrypts and writes the whole filesystem. The serialized drive limit is 192 KiB; programs, settings, directory metadata, and Trash count toward it. Keep free physical disk space for a second encrypted copy during saves and additional copies during upgrades.

The safe writer stages a new encrypted image before replacing the previous one. Failed writes restore the prior in-memory contents. At boot, interrupted `.sacabam-old` / `.sacabam-new` vault files are recovered or retained as `.recovery-N` files. A recovery copy may contain older data. Filesystem operations cannot guarantee power-loss atomicity on every host filesystem.

To back up, **lock or exit first**, then copy `/ccsacabam/vault/data.scv` somewhere safe. Preserve the corresponding passphrase separately. To restore, keep a copy of the damaged/current file, replace `data.scv` while CCSacabam is closed, and boot again. Never overwrite your only backup while troubleshooting.

Changing the password re-encrypts the current vault. It does not change old backups: those still use the old password. Installer upgrade backups can contain older encrypted vaults. There is no recovery password, reset mechanism, or back door.

Installation stages files under `/ccsacabam-install-stage` and stores previous installs/startup files under `/ccsacabam-backups`. Ordinary install failures roll back. After a power cut during installation, inspect these locations from CraftOS before retrying; a remaining stage directory is deliberately not deleted automatically. The uninstaller restores original startup programs and keeps the OS folder and encrypted data.

# Build and test

The recorded validation passed **415 checks** on CraftOS-PC 2.8.3 / ComputerCraft 1.112.0: 116 each on advanced, basic, and pocket-sized displays, 24 modem-network checks across host IDs 0 and 1, nine fresh-install checks, six minimum-size setup checks, and 28 focused picker/Customisation checks on color, monochrome, and minimum-size windows. Counts include source-parse checks. Independent Python crypto and disk-plaintext checks also passed. [The machine-readable report](validation.json) includes the installer checksum and individual results.

Build the single-file installer with `python3 tools/build.py`. It normalizes line endings in packaged source, includes each runtime file with a SHA-256 hash, and writes `dist/SHA256SUMS`. The original `chatplus.lua` is retained unchanged in the source checkout.

Run:

```sh
python3 tools/test.py advanced basic pocket network network-zero fresh fresh-basic fresh-encrypted setup setup-basic picker picker-basic picker-small picker-small-basic
```

Requirements: CraftOS-PC on PATH as `craftos`, Python 3, and Python `cryptography`. Each case creates an isolated `/tmp/ccsacabam-...` directory with its own emulator configuration and save. The runner reports that path so failures can be inspected. Results are written to `computer/0/test-results.json`, or `computer/1/test-results.json` when testing a host on computer 0. Nothing is installed into the user's normal CraftOS-PC save.

The basic, advanced, and pocket suites use CraftOS-PC standards mode with extensions disabled. SDL's dummy video driver allows the GUI renderer to run unattended while retaining the real terminal's color capability. CraftOS-PC's headless renderer reports color support even for a configured basic computer, so it is not used to validate monochrome behavior.

Coverage includes:

* All Lua source parses in the actual emulator.
* Installer checksum rejection, preservation of unrelated files/startup programs, rollback on an injected error, upgrades, and uninstall recovery.
* SHA-256, HMAC-SHA-256, PBKDF2, and ChaCha20 vectors. Python `hashlib`, `hmac`, and `cryptography` independently authenticate/decrypt actual drive and Pistachio envelopes.
* Wrong passwords, tampered ciphertext, locked handles, failed writes, interrupted-save recovery, password changes, and encryption on/off conversion.
* A physical-disk scan for a private sentinel and private filename after encrypted operation.
* Ordinary Lua filesystem and `io` writes, settings, `require`, relative paths, binary handles, and background timers.
* Shared app working directories: real shell commands, nested shells, `.`/`..`/`./child`, quoted paths, inherited app launches, independent windows, file dialogs, Files navigation, Pistachio data, local browser links, and migration of stock launchers without overwriting user changes.
* File-picker keyboard/mouse browsing, hidden/type filters, folder creation, cancellation, read-only paths, resizing down to an 18×6 app area, encrypted file selection, overwrite confirmation, and closing the parent window from a dialog.
* Customisation tab colour selection, cancellation, persistence, visible desktop/window changes, separate basic/dark/light profiles, invalid-colour rejection, reset confirmation, failed-save rollback, and minimum-size palette controls.
* Bundled app startup, Editor saving/undo, Settings confirmation, window movement/resizing/minimizing, event routing, small displays, and crash containment.
* Code Editor highlighting and completion for all four languages, Lua API members, multiline lexing, embedded scripts, save/undo/redo, and manual language selection on real windows.
* Files double-click launch of a root-relative Lua path containing spaces, and E opening source in Code Editor.
* Peanut parsing and rejection cases; Pistachio handlers, limits, encryption functions, and Cashew script restrictions.
* Full-screen standalone setup and production 100,000-iteration encryption: passwordless default boot, enabling encryption in Settings, and installing with encryption already enabled.
* Minimum-size 20×10 setup on both basic and advanced terminals: keyboard/mouse navigation, Left/Right between Back and Next, cancellation, failure/retry, and masked password validation.
* Shortcut removal/restoration, preserved application right-click events, contrasting window controls, and the default-OFF Skip typing YES preference.
* Two-computer modem tests with host IDs 1 and 0 for domains, bare computer-ID addresses, actual Callisto rendering, pages, missing-homepage diagnostics/recovery, 404s, traversal rejection, server shutdown, and Chat+ alongside Jupiter. Hosts are launched through real terminals using `..` and `.`, then keep serving after the terminal changes directory. Only these cases enable emulator peripheral extensions to create the test hardware; the OS uses normal ComputerCraft modem APIs.

Terminal snapshots are saved as `snapshot-*.json`. These retain text and foreground/background color rows for inspection. `python3 tools/preview.py snapshot.json output.png` renders them with Pillow, preserving the mosaic subpixels and substituting a host monospace font for ordinary text. Test passwords are public fixtures, never credentials for a real installation.

These are emulator integration tests, not an audit or a claim that every Lua program, peripheral mod, server configuration, or ComputerCraft version works. Minecraft server behavior, network range/chunk loading, performance under server load, and nonstandard peripherals still need in-game testing.

Captured previews: [setup](previews/setup.png), [basic desktop](previews/basic-desktop.png), [Code Editor](previews/code.png), [resize handle](previews/resize-corner.png), [file picker](previews/filepicker.png), and [Customisation](previews/customisation.png).

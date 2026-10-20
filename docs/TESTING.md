# Build and test

The recorded validation passed **323 checks** on CraftOS-PC 2.8.3 / ComputerCraft 1.112.0: 100 each on advanced, basic, and pocket-sized displays, eight modem-network checks, nine fresh-install checks, and six minimum-size setup checks. Counts include source-parse checks. Independent Python crypto and disk-plaintext checks also passed. [The machine-readable report](validation.json) includes the installer checksum and individual results.

Build the single-file installer with `python3 tools/build.py`. It normalizes line endings in packaged source, includes each runtime file with a SHA-256 hash, and writes `dist/SHA256SUMS`. The original `chatplus.lua` is retained unchanged in the source checkout.

Run:

```sh
python3 tools/test.py advanced basic pocket network network-zero fresh fresh-basic fresh-encrypted setup setup-basic
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
* Bundled app startup, Editor saving/undo, Settings confirmation, window movement/resizing/minimizing, event routing, small displays, and crash containment.
* Code Editor highlighting and completion for all four languages, Lua API members, multiline lexing, embedded scripts, save/undo/redo, and manual language selection on real windows.
* Files double-click launch of a root-relative Lua path containing spaces, and E opening source in Code Editor.
* Peanut parsing and rejection cases; Pistachio handlers, limits, encryption functions, and Cashew script restrictions.
* Full-screen standalone setup and production 100,000-iteration encryption: passwordless default boot, enabling encryption in Settings, and installing with encryption already enabled.
* Minimum-size 20×10 setup on both basic and advanced terminals: keyboard/mouse navigation, Left/Right between Back and Next, cancellation, failure/retry, and masked password validation.
* Shortcut removal/restoration, preserved application right-click events, contrasting window controls, and the default-OFF Skip typing YES preference.
* Two-computer modem tests with host IDs 1 and 0 for domains, bare computer-ID addresses, actual Callisto rendering, pages, missing-homepage diagnostics/recovery, 404s, traversal rejection, server shutdown, and Chat+ alongside Jupiter. Only these cases enable emulator peripheral extensions to create the test hardware; the OS uses normal ComputerCraft modem APIs.

Terminal snapshots are saved as `snapshot-*.json`. These retain text and foreground/background color rows for inspection. `python3 tools/preview.py snapshot.json output.png` renders them with Pillow, preserving the mosaic subpixels and substituting a host monospace font for ordinary text. Test passwords are public fixtures, never credentials for a real installation.

These are emulator integration tests, not an audit or a claim that every Lua program, peripheral mod, server configuration, or ComputerCraft version works. Minecraft server behavior, network range/chunk loading, performance under server load, and nonstandard peripherals still need in-game testing.

Captured previews: [setup](previews/setup.png), [basic desktop](previews/basic-desktop.png), [Code Editor](previews/code.png), and [resize handle](previews/resize-corner.png).

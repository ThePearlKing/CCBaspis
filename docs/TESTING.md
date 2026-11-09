# Build and test

The Titan game engine passed **616 checks**: 152 integration checks each on advanced, basic, and pocket-sized displays, nine fresh-install checks, 27 game checks on each of five display sizes, and 16 animation/wallpaper checks. Independent Python crypto and disk-plaintext checks also passed. Titan tests cover gravity and landing, wall and solid-entity blocking, no tunnelling at high speed, one-way platforms, map spawns, tags and touch callbacks, timers, tweens and scene changes, key bindings, mouse picking, camera bounds, both renderers, saves, palette restoration, the advanced-only gate on basic computers, Moonhop played through its coin, enemy, and restart paths, and `titan-demo` typed into a real Terminal window.

The Vault Runner rename passed **234 checks**: 149 advanced integration checks and 85 game checks across advanced, basic, pocket-sized, and minimum-size displays. Independent Python crypto and disk-plaintext checks also passed. [The rename validation report](validation-vault-runner.json) records the current installer checksum and individual results.

The prior full-suite baseline passed **621 checks** on CraftOS-PC 2.8.3 / ComputerCraft 1.112.0: 149 each on advanced, basic, and pocket-sized displays, 24 modem-network checks across host IDs 0 and 1, nine fresh-install checks, six minimum-size setup checks, 28 focused picker/Customisation checks, 32 focused animation/language/wallpaper checks, and 75 game checks across advanced, basic, pocket-sized, and minimum-size windows. Counts include source-parse checks. Independent Python crypto and disk-plaintext checks also passed. [The baseline report](validation.json) retains that earlier installer checksum and its individual results.

Build the single-file installer with `python3 tools/build.py`. It normalizes line endings in packaged source, includes each runtime file with a SHA-256 hash, and writes `dist/SHA256SUMS`. The original `chatplus.lua` is retained unchanged in the source checkout.

Run:

```sh
python3 tools/test.py advanced basic pocket network network-zero fresh fresh-basic fresh-encrypted setup setup-basic picker picker-basic picker-small picker-small-basic
python3 tools/test.py visual visual-basic visual-small visual-small-basic
python3 tools/test.py games games-basic games-pocket games-small games-small-basic
```

Requirements: CraftOS-PC on PATH as `craftos`, Python 3, and Python `cryptography`. Each case creates an isolated `/tmp/ccsacabam-...` directory with its own emulator configuration and save. The runner reports that path so failures can be inspected. Results are written to `computer/0/test-results.json`, or `computer/1/test-results.json` when testing a host on computer 0. Nothing is installed into the user's normal CraftOS-PC save.

The basic, advanced, and pocket suites use CraftOS-PC standards mode with extensions disabled. SDL's dummy video driver allows the GUI renderer to run unattended while retaining the real terminal's color capability. CraftOS-PC's headless renderer reports color support even for a configured basic computer, so it is not used to validate monochrome behavior.

Coverage includes:

* All Lua source parses in the actual emulator.
* Installer checksum rejection, preservation of unrelated files/startup programs, rollback on an injected error, upgrades, and uninstall recovery.
* Advanced render-mode defaults in setup, unattended install and config normalization; basic hardware fallback and explicit display choices. Staging copies only retained personal/custom files alongside the replacement system, so the disk-space check does not count old system files twice. The real upgrade test retains custom files and checks the encrypted drive byte for byte.
* SHA-256, HMAC-SHA-256, PBKDF2, and ChaCha20 vectors. Python `hashlib`, `hmac`, and `cryptography` independently authenticate/decrypt actual drive and Pistachio envelopes.
* Wrong passwords, tampered ciphertext, locked handles, failed writes, interrupted-save recovery, password changes, and encryption on/off conversion.
* A physical-disk scan for a private sentinel and private filename after encrypted operation.
* Ordinary Lua filesystem and `io` writes, settings, `require`, relative paths, binary handles, and background timers.
* Shared app working directories: real shell commands, nested shells, `.`/`..`/`./child`, quoted paths, inherited app launches, independent windows, file dialogs, Files navigation, Pistachio data, local browser links, and migration of stock launchers without overwriting user changes.
* File-picker keyboard/mouse browsing, hidden/type filters, folder creation, cancellation, read-only paths, resizing down to an 18×6 app area, encrypted file selection, overwrite confirmation, and closing the parent window from a dialog.
* Customisation tab colour selection, cancellation, persistence, visible desktop/window changes, separate basic/dark/light profiles, invalid-colour rejection, reset confirmation, failed-save rollback, and minimum-size palette controls.
* All eight wallpaper patterns in basic, color, and subpixel modes; preview/apply/cancel, keyboard and mouse controls, failed-save rollback, persistence, and desktop cache refresh.
* Bundled app startup, Editor saving/undo, Settings confirmation, window movement/resizing/minimizing, event routing, small displays, and crash containment.
* All ten games: collisions, scores, win/loss states, safe Mines openings, one-merge-per-move 2048 rules, all four Sokoban levels solved by search, and complete routes through eight generated Vault Runner mazes. Real game windows test basic/advanced gates, pause/help/restart, resize suspension, timer cleanup, scores, and desktop/pocket/minimum-size displays. Integration tests launch through Apps, Terminal and Files, preserve edited `/Games` launchers on upgrade, and keep completion records inside the encrypted drive. Fresh-install oracles check all ten launchers.
* Vault Runner upgrades replace the old stock launcher, preserve edited launchers, accept their old game ID, and carry forward previous completion records and best scores. The stock-launcher migration also runs inside the encrypted drive integration test.
* Code Editor highlighting and completion for all four languages, Lua API members, multiline lexing, embedded scripts, save/undo/redo, and manual language selection on real windows.
* Files double-click launch of a root-relative Lua path containing spaces, and E opening source in Code Editor.
* Peanut parsing and rejection cases; Pistachio handlers, limits, encryption functions, and Cashew script restrictions.
* Pistachio indexed assignment, bounded arrays, nested-loop indices, render-only frame blocks, and Cashew assignment-target validation. The actual `pmatrix.pist` runs hundreds of frames, including resize to 18×6 and 160×50 content areas. Tests cover color/monochrome drawing, pause, key-repeat handling, speed, timer cleanup, and shell launch from another working directory. Upgrades add its command/source without overwriting edited copies; fresh installs verify both files inside the encrypted drive.
* Full-screen standalone setup and production 100,000-iteration encryption: passwordless default boot, enabling encryption in Settings, and installing with encryption already enabled.
* Minimum-size 20×10 setup on both basic and advanced terminals: keyboard/mouse navigation, Left/Right between Back and Next, cancellation, failure/retry, and masked password validation.
* Shortcut removal/restoration, preserved application right-click events, contrasting window controls, and the default-OFF Skip typing YES preference.
* Two-computer modem tests with host IDs 1 and 0 for domains, bare computer-ID addresses, actual Callisto rendering, pages, missing-homepage diagnostics/recovery, 404s, traversal rejection, server shutdown, and Chat+ alongside Jupiter. Hosts are launched through real terminals using `..` and `.`, then keep serving after the terminal changes directory. Only these cases enable emulator peripheral extensions to create the test hardware; the OS uses normal ComputerCraft modem APIs.

Terminal snapshots are saved as `snapshot-*.json`. These retain text and foreground/background color rows for inspection. `python3 tools/preview.py snapshot.json output.png` renders them with Pillow, preserving the mosaic subpixels and substituting a host monospace font for ordinary text. Test passwords are public fixtures, never credentials for a real installation.

These are emulator integration tests, not an audit or a claim that every Lua program, peripheral mod, server configuration, or ComputerCraft version works. Minecraft server behavior, network range/chunk loading, performance under server load, and nonstandard peripherals still need in-game testing.

Captured previews: [setup](previews/setup.png), [basic desktop](previews/basic-desktop.png), [Code Editor](previews/code.png), [resize handle](previews/resize-corner.png), [file picker](previews/filepicker.png), [Customisation](previews/customisation.png), [pmatrix](previews/pmatrix.png), [monochrome pmatrix](previews/pmatrix-basic.png), [circuit wallpaper](previews/wallpaper-circuit.png), and [waves wallpaper](previews/wallpaper-waves.png).

Game previews: [Vault Runner](previews/vault-runner.png), [Breakout](previews/breakout.png), and the [basic Games launcher](previews/games-basic.png).

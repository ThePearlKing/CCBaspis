# Pistachio Script

Pistachio is CCSacabam's native, interpreted application language. Save a `.pist` file in Programs and open it from Files. From Terminal, run `pistachio /Programs/example.pist`. It has its own parser and runtime; source is never evaluated as Lua. Lua remains available for existing ComputerCraft programs and lower-level APIs.

```text
app "My counter"
let count = 0
banner heading 2 2 (width-2) "COUNTER"
label value 2 5 (width-2) "Count: {count}"
button add 2 7 14 "Add one"
on add
  set count = count + 1
end
```

Tab selects controls, Shift+Tab selects the previous one, and Enter or Space activates a button. Advanced computers also support clicking. Ordinary labels and controls keep the same cell layout across display modes; render mode draws banners in a custom 3×5 pixel font. Basic mode draws those banners as normal text and removes the color dependency.

## Statements and controls

One statement per line. `#` starts a comment outside a string. Strings use double quotes and `\n`, `\r`, `\t`, `\"`, and `\\` escapes. Identifiers use letters, digits, and underscores and cannot begin with a digit. Coordinates are one-based terminal cells; expressions in a coordinate slot must have no spaces, for example `(width-2)`.

| Statement | Meaning |
| --- | --- |
| `app "Title"` | Set the window title |
| `let name = expression` | Initialize a variable during app startup |
| `set name = expression` | Assign a variable during execution |
| `set items[index] = expression` | Assign an array entry or object field (`set data.title = "Hi"` also works) |
| `label id x y width expression` | Text |
| `banner id x y width expression` | Text, or a two-cell-high pixel banner in render mode |
| `button id x y width expression` | Button; activates the handler named `id` |
| `input id x y width variable` | Editable single-line text, bound to a variable |
| `password id x y width variable` | Same input with masked characters |
| `checkbox id x y width variable` | Boolean control |
| `progress id x y width expression` | Progress in the range 0–100 |
| `panel id x y width height` | Filled panel |
| `background "black"` | App background color; takes a color name or ComputerCraft color value |
| `status expression` | Replace the standard footer; `status ""` hides it |
| `text x y foreground background expression` | Draw a clipped horizontal string, with explicit colors |
| `column x y foreground background expression` | Draw a clipped vertical string, one character per row |
| `notify expression` | Desktop notification |
| `load variable "file.peanut"` | Read Peanut data |
| `save variable "file.peanut"` | Write Peanut data |
| `quit` | Close the app |

Put declarations and controls at the top level. Controls are re-evaluated when the window draws, so text and coordinates can depend on variables or window dimensions. Input and checkbox changes dispatch their named handler as well. `let` is for initialization; use `set` inside event handlers.

```text
if advanced
  label hardware 2 10 30 "Color-capable computer"
else
  label hardware 2 10 30 "Basic computer"
end

function increment
  set count = count + 1
end

on add
  call increment
end

every 1
  call increment
end
```

`if expression` supports an optional `else` and closes with `end`. `repeat expression` runs its block that many times (0–1000), with `index` set to the current iteration; nested loops restore the outer index. `function name` defines a parameterless function; `call name` invokes it. `on name` defines a named handler. `every seconds` creates a timer, from 0.1 seconds to one day. Define timers and functions at the top level.

## Drawing and keyboard input

`frame ... end` runs during each redraw. Inside it, `set`, loops, and function calls can calculate coordinates and emit drawing commands. Use timers to advance animation state: redraws also happen when a window is focused, so advancing animation inside a frame would make its speed depend on unrelated events. Drawing clips at the window edges; negative positions are useful for objects entering the screen.

```text
app "Moving text"
let x = 1
background "black"
status ""
every 0.1
  set x = x % max(1, width) + 1
end
frame
  set ink = color and "lime" or "white"
  text x 3 ink "black" "Hello"
end
on key
  if key == "q" or key == "escape"
    quit
  end
end
```

`on key` receives `key`, the ComputerCraft key name, and `held`, whether this is a repeated key-down event. Defining it replaces the app's default Tab/Enter/input key handling; window-manager shortcuts still work. `on char` receives a printable `char` and replaces ordinary text-control character handling. `on resize` runs after the content dimensions change. Controls keep their usual behavior in apps without these handlers. Timers are cancelled when the app closes.

For an editable example, run **`pmatrix`** in Terminal or open **`/Programs/pmatrix.pist`**. Its streams, random characters, per-column speeds, fading colors, pause, resize handling, and controls are all Pistachio code. `pmatrix.lua` only launches the source. This is an original [cmatrix-inspired](https://github.com/abishekvashok/cmatrix) implementation, not a translation of its C source or all command-line options.

* **Space** pauses/resumes; **Up/Down**, **+/−**, or **1–9** adjust speed.
* **C** cycles colors on advanced computers. Basic display mode uses grayscale trails.
* **H** toggles help, **Q/Escape** quits, and **F6** maximizes the window.
* `pmatrix --help` prints controls. No new desktop shortcut is installed.

## Expressions

Program paths and `load`/`save` filenames resolve against the app's working directory, inherited from the launching terminal or Files window. `.` and `..` work, and absolute paths begin with `/`. For example, from `/Programs/demo`, `pistachio ./main.pist` can `load data "./settings.peanut"` and `save data "../result.peanut"`. Changing another terminal's directory does not move a running program's files.

Numbers, strings, `true`, `false`, `null`, parentheses, field access (`data.title`), and array indexing (`data.items[1]`) are supported. Operators are `+ - * / %`, string concatenation `..`, comparisons `== != < > <= >=`, and short-circuiting `and or not`. Arithmetic and comparisons follow Lua value types. Quoted strings interpolate `{variable}` values; use `..` for other expressions.

Built-in values:

* `advanced`: the terminal's hardware color capability.
* `color`: the selected display mode supports color.
* `render`: the selected mode is render mode.
* `width`, `height`: current app content dimensions, excluding the window frame.

Functions: `str`, `num` (invalid input becomes 0), `len`, `min`, `max`, `abs`, `floor`, `round`, `upper`, `lower`, `slice(text, first, last)` (one-based, inclusive, negative indices count from the end), `random(low, high)` (inclusive integers), `array(count, fill)` (0–4096 scalar entries, default fill 0), `peanut(text)` to parse data, and `encode(value)` to serialize it. Random numbers are for effects/games, not encryption. Use Peanut for structured literals:

```text
let profile = peanut("{name = \"Traveller\", scores = [10,20]}")
label who 2 3 30 profile.name
```

## Encryption functions

`seal(text, password)` returns authenticated, password-encrypted text. `unseal(envelope, password)` verifies and decrypts it. Both are available to native programs even when drive encryption is OFF. Passwords must contain 12–256 characters; messages can be up to 32 KiB. Key derivation takes time; the desktop continues processing events while it runs.

```text
let note = ""
let passphrase = ""
input noteField 2 3 (width-2) note
password passField 2 5 (width-2) passphrase
button saveNote 2 7 16 "Seal and save"
on saveNote
  set envelope = seal(note, passphrase)
  save envelope "/Documents/note.peanut"
  set note = ""
  set passphrase = ""
end
```

To reopen: `load envelope "/Documents/note.peanut"`, then `set note = unseal(envelope, passphrase)`. A wrong password or altered envelope raises an error; it never returns unauthenticated plaintext. The complete interactive example is `Programs/sealed-note.pist`.

Save only the envelope if you want confidentiality with drive encryption off. Do not embed real passwords in source, save the password variable, or write decrypted text to a plain drive. A masked input only hides characters on screen. Read [security details](SECURITY.md).

## Limits and web pages

Source is limited to 128 KiB; strings to 128 KiB; block nesting to 32. Each initialization, event, timer, or layout gets a 10,000-operation budget. Array construction charges one operation per entry. Indexed assignments use integer indices 1–4096 or field names up to 256 characters, with at most 4096 entries per modified object. An app error is reported in Tasks and the personal-drive log. This is a small application language, not a C compiler or a complete general-purpose ecosystem.

Cashew pages can embed Pistachio, but website scripts cannot load/save files, invoke encryption functions, or run Lua. See [Europa and Cashew](EUROPA.md).

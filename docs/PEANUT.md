# Peanut

Peanut is a data format and Lua library. JSON is accepted, with three additions: `#` or `//` line comments, unquoted identifier keys with `=` or `:`, and trailing commas. It does not execute code.

```text
{
  # A perfectly ordinary nut-based configuration.
  title = "Workshop",
  public = true,
  colors = ["cyan", "blue",],
  optional = null,
}
```

```lua
local peanut = require("peanut")
local profile = peanut.decode('{name="Traveller", scores=[10,20]}')
print(profile.name)
assert(peanut.write("/Documents/profile.peanut", profile))
local restored, why = peanut.read("/Documents/profile.peanut")
assert(restored, why)
print(peanut.encode(restored, true)) -- pretty JSON-compatible output
```

`decode` / `parse` raise an error for malformed input. `encode` / `stringify` raise for unsupported values. `read(path)` returns the parsed value or `nil, error`; a valid document can be `false`, so check `value ~= nil` if you accept scalar documents. `write(path, value)` returns success or `nil, error`.

`peanut.null` represents null; Lua `nil` cannot occupy an array slot. Use `peanut.array({})` for an empty array; an ordinary empty table encodes as `{}`. Nonempty arrays must have consecutive integer keys starting at 1. Objects have string keys. Cycles, duplicate object keys, mixed/holey arrays, unsupported values, and nonfinite numbers are rejected. Unicode escapes and surrogate pairs decode to UTF-8 bytes; a ComputerCraft font may not display every character.

Input is limited to 1 MiB and nesting to 64 levels. The personal drive's smaller capacity still applies to files saved there. Peanut itself does not encrypt; it uses the session filesystem. Native Pistachio can encrypt a string with `seal` before saving it as Peanut.

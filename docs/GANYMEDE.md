# Ganymede

Io does I/O. Ganymede does UI. The other moons have been assigned networking duties.

Ganymede is a small library for normal Lua programs. It draws into the current terminal, including a CCSacabam window, and chooses a monochrome or color theme from terminal capabilities.

```lua
local g = require("ganymede")
local form = g.form("My Lua app")
form.label("heading", 2, 3, 30, "Who should we greet?")
form.input("name", 2, 5, 25, "Traveller")
form.label("answer", 2, 9, 35, "")
form.button("hello", 2, 7, 15, "Say hello", function()
  form.set("answer", "Hello, " .. form.get("name") .. "!")
end)
form.run()
```

Methods use dot calls. `label`, `button`, `input`, `password`, and `checkbox` take `(id, x, y, width, value[, callback])`. `password` masks a text field; it does not encrypt its value. `checkbox` takes a boolean. Callbacks receive `(form, widget)`. Buttons dispatch on activation; inputs on edits; checkboxes after toggling. `form.get(id)` and `form.set(id, value)` access values, and `form.close()` ends the loop.

`form.run()` handles Tab / Shift+Tab, Enter / Space, editing, and mouse clicks. F4 closes the surrounding window. A custom `form.theme` can return `bg`, `panel`, `text`, `muted`, `accent`, and `onAccent` colors. `g.text(x,y,value,fg,bg,width)` provides clipped text drawing. The included `Programs/ganymede-demo.lua` is a working counter.

Layout uses terminal cells. Choose widths from `term.getSize()` when targeting small windows. Apps remain normal Lua and can use ComputerCraft's own `window`, `paintutils`, peripheral, HTTP, and modem APIs as well.

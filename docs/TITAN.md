# Titan

Titan is CCSacabam's 2D game engine for ordinary Lua programs. It is named after Saturn's largest moon. It handles the parts that are tedious to write again for each game: the frame loop, sprites, tile maps, physics and collisions, cameras, scenes, timers, particles, input, sound, and saving. You write the game rules.

```lua
local titan = require("titan")
local game = titan.new{title = "Tiny", fps = 20}

game.sprite("hero", {" 4 ", "444", "1 1"})        -- blit colour digits; space is clear
game.define("hero", {sprite = "hero", gravity = 120, update = function(e, dt, g)
  e.vx = (g.down("left") and -30 or 0) + (g.down("right") and 30 or 0)
  if g.pressed("jump") and e.onGround then e.vy = -45 end
end})

game.scene("play", {
  enter = function(g)
    g.map{tile = 3, rows = {
      "                    ",
      "  @        ====     ",
      "####################",
    }, legend = {["#"] = {solid = true, color = colors.gray},
                 ["="] = {oneway = true, color = colors.brown},
                 ["@"] = {spawn = "hero"}}}
    g.follow(g.first("hero"))
  end,
  draw = function(g) g.write(1, 1, "Arrows move, Space jumps", colors.white) end,
})
game.run("play")
```

Run **`titan-demo`** in Terminal for Moonhop, a two-level scrolling platformer with coins, enemies, one-way platforms, particles, and a saved best score. Its source is `Programs/titan-demo.lua`, about 120 lines.

## Advanced first, basic by design

On an **advanced computer**, Titan draws full-colour **2×3 subpixel graphics** by default. A 51×19 terminal becomes a 102×57-pixel screen, and `g.palette` can redefine any of the 16 colours.

**Basic computers are opt-in.** A game without `basic = true` shows *ADVANCED COMPUTER ONLY* on a basic computer and does not start. To support basic computers, set `basic = true` and design that version yourself. In basic computers `g.mode` is `"cell"`: one pixel is one terminal cell, colours appear as grays, and entity `char` glyphs replace sprites. Moonhop shows the pattern: it picks a tile size of `3` or `1` from `g.mode`, gives each entity a glyph (`@`, `*`, `x`), and keeps the night-sky palette for advanced computers.

| | Advanced (default) | Basic (`basic = true`) |
| --- | --- | --- |
| `g.mode` | `"pixel"` | `"cell"` |
| Pixel per cell | 2×3 | 1×1 |
| Colours | 16, redefinable with `g.palette` | grays |
| Sprites | drawn | drawn as blocks, or `char` glyph |

`mode = "cell"` forces the cell renderer on an advanced computer, for chunky text-style games.

## Creating a game

`titan.new{...}` options: `fps` (default 20), `title`, `basic`, `mode`, `background` colour, `minCols`/`minRows` (smaller windows show *Window too small* and pause), `target` (any terminal object, such as a monitor), `side` (monitor side for `monitor_touch`), and `scale` (monitor text scale). `titan.run{update=..., draw=...}` is a one-scene shortcut.

`g.width`/`g.height` are pixels; `g.cols`/`g.rows` are cells. World coordinates start at `(0, 0)`, the top-left pixel of the world.

## Scenes

`g.scene(name, {enter, update, draw, background, leave, event, resize, paused, keep})` then `g.go(name, ...)`. Arguments to `go` reach `enter(g, ...)`. Changing scene clears entities, timers, tweens, particles, the map, and the camera unless the scene sets `keep = true`. `update(g, dt)` runs every frame. `background(g)` draws behind the map; `draw(g)` draws on top, for HUDs. `g.run(name)` starts the loop; `g.quit()` ends it. Closing the window (F4) or terminating also ends it. Colours and the palette are restored.

## Entities

`g.define(name, template)` registers a template; `g.spawn(name, overrides)` or `g.spawn{...}` creates an entity. Fields:

* Position and size: `x, y, w, h` (size defaults to the sprite's), `vx, vy`, `z` draw order.
* Look: `sprite` (sprite or animation name), `flip`, `flipY`, `color` (a plain rectangle), `char`/`fg`/`bg` (glyph), `visible`, or `draw(e, g)` for custom drawing.
* Physics: `gravity`, `maxFall`, `friction`, `drag`, `bounce`, `collide = false` (pass through tiles), `solid` (blocks other movers), `oneway`.
* Behaviour: `update(e, dt, g)`, `init(e, g)`, `touch(e, other, g)` with optional `touches = "tag"`, `hitWall`, `hitFloor`, `hitCeiling`, `fell` (dropped out of the map), `life` (seconds before removal), and `removed`.

Methods: `e.destroy()`, `e.is(tag)`, `e.tag(tag, on)`, `e.play(animation)`, `e.center()`. `e.onGround` is set by physics. `tags = {"enemy"}` adds tags; the template name is always a tag.

Queries: `g.find(tag)`, `g.first(tag)`, `g.count(tag)`, `g.at(x, y, tag)`, `g.overlapping(e, tag)`, `titan.overlap(a, b)`. `g.move(e, dx, dy)` moves with collision and returns the blocking boxes. Fast movement is substepped so bodies do not pass through walls.

## Tile maps

`g.map{tile = size, rows = {...} or "path/level.txt", legend = {...}, edge = false}`. Each legend entry may have `solid`, `oneway` (can be jumped through from below), `color`, `sprite`/`image`, `char`/`fg`, any custom fields, and `spawn` (a template name, or `function(x, y, tx, ty)`), which replaces that tile with `under` (default space). The map's sides and top are solid unless `edge = false`; the bottom is open, so things can fall out.

The map (`g.tiles`) has `get`, `set`, `info`, `find(char)`, `toTile(x, y)`, `fromTile(tx, ty)`, `width`, and `height`. `g.solidAt(x, y)` tests a point. Level files are plain text, so Editor and Code Editor can edit them.

## Drawing

World-space: `g.pixel`, `g.rect`, `g.outline`, `g.line`, `g.circle(x, y, r, c, filled)`, `g.image(name, x, y, flip)`, `g.text(x, y, text, fg, bg)`. The same functions under `g.screen.*` ignore the camera. `g.write(col, row, text, fg, bg)` and `g.center(row, text, fg, bg)` place text on terminal cells; a missing `bg` keeps the colour underneath.

Sprites: `g.sprite(name, rows[, palette])` uses blit digits `0`–`f` with space or `.` transparent, matching the `paint` program's `.nfp` format. `g.sprite(name, "/Pictures/hero.nfp")` loads a file. A palette such as `{R = colors.red}` maps other characters. `g.animation(name, {"frame1", "frame2"}, fps, loop)` makes an animation usable as a `sprite`.

## Camera, effects, time

`g.follow(e, {lerp = 0.2, bounds = true})`, or set `g.camera.x/y` directly. `g.shake(amount, seconds)`. `g.burst(x, y, {count, color or {colours}, speed, life, gravity})` emits particles. `g.after(seconds, fn)` and `g.every(seconds, fn)` return timers with `cancel()`. `g.tween(object, seconds, {x = 10}, "out", done)` uses `linear`, `in`, `out`, or `inout`. `g.time`, `g.frame`, and `g.dt` are available. `g.paused = true` freezes the world.

## Input

`g.down(name)` means held; `g.pressed(name)` means pressed this frame and ignores key repeat. Names are ComputerCraft key names (`"a"`, `"space"`, `"leftShift"`) or bindings. Defaults: `left`, `right`, `up`, `down`, `jump` (Space/Up/W), and `action` (Enter/Space/E). `g.bind("fire", {"x", "leftCtrl"})` adds one. `g.mouse` has `x, y` (world), `sx, sy` (screen pixels), `col, row`, `button`, `down`; `g.clicked(button)` covers clicks and monitor touches.

## Works with the rest of ComputerCraft

* **Plain CraftOS:** Titan has no CCSacabam dependencies. Copy `/rom/modules/main/titan.lua` (as seen inside CCSacabam) next to your game on any CC: Tweaked computer and `require("titan")` works.
* **CCSacabam windows:** resizing, F6 maximise, F4 close, and the encrypted drive all work. `g.save(path, table)` / `g.load(path, default)` use normal `fs`, so saves follow the drive's encryption setting.
* **Monitors:** `titan.new{target = peripheral.wrap("top"), side = "top", scale = 0.5}`. Touches become clicks.
* **Networking:** `g.on("rednet_message", fn)` or `g.on("modem_message", fn)` receives any event, so multiplayer can use rednet or Europa.
* **Speakers:** `g.sound(instrument, volume, pitch)` uses an attached speaker and is silent without one.
* **Other libraries:** a program can use a Ganymede form as a title or settings screen and then start Titan. Peanut files and plain-text level files can supply map data.

## Limits

Titan runs in Lua on the ComputerCraft machine. A full 51×19 screen redraws about 1,000 cells each frame. Keep entity counts in the low hundreds; touch checks compare every pair. Held keys rely on `key_up` events. CCSacabam sends these to the focused window, so a key can stay held if focus changes mid-press. There is no audio mixing beyond the speaker's own notes.

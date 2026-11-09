-- Moonhop: a Titan engine demo. A scrolling platformer in about 120 lines.
-- Arrows/WASD move, Space/Up jumps, R restarts, Q quits. Works on basic and
-- advanced computers, in CCSacabam windows, plain CraftOS and monitors.
local titan = require('titan')
-- basic=true: this game also ships a hand-designed basic-computer version
-- (the 'not px' glyphs below). Leave it out to make a game advanced-only.
local game = titan.new{title='Moonhop', fps=20, minCols=20, minRows=8, basic=true}
local px = game.mode == 'pixel'
local T = px and 3 or 1 -- tile size in pixels: 3x3 subpixels, or one cell

local levels = {
{ "                                                            ",
  "                                                            ",
  "                                              C C           ",
  "                    C C C                   =====           ",
  "                   =======        C                     F   ",
  "           C                   #######         E     ######",
  "         =====       E                    ##########  ######",
  "  @          #########       C          ###########   ######",
  "#######     ##########     #####    ^^  ###########  #######",
  "#######^^^^^##########^^^^^#####^^^^##################^#######",
  "############################################################",
},
{ "                                                            ",
  "                                C                           ",
  "                C             =====          C C C        F ",
  "             =======                   E   =======      ####",
  "        C                  E        ######             #####",
  "  @   =====     #####    #####                ===     ######",
  "####           #######  #######  ^^^       E        ########",
  "####^^^^^^^^^^^#######^^#######^^#####^^#########^^#########",
  "############################################################",
},
}

local legend = {
  ['#'] = {solid=true, color=colors.gray, char=not px and '#' or nil, fg=colors.lightGray},
  ['='] = {oneway=true, color=colors.brown, char=not px and '=' or nil, fg=colors.orange},
  ['^'] = {spike=true, color=px and nil or colors.black, char=not px and '^' or nil, fg=colors.red,
           sprite=px and titan.image({' e ', 'eee', 'eee'}) or nil},
  ['@'] = {spawn='player'}, ['C'] = {spawn='coin'}, ['E'] = {spawn='crawler'}, ['F'] = {spawn='flag'},
}

game.sprite('hero1', px and {' 4 ', '444', '1 1'} or {'4'})
game.sprite('hero2', px and {' 4 ', '444', ' 1 '} or {'4'})
game.animation('walk', {'hero1', 'hero2'}, 8)
game.sprite('coin', px and {' 4 ', '4 4', ' 4 '} or {'4'})
game.sprite('crawl1', px and {'eee', 'e0e', 'e e'} or {'e'})
game.sprite('crawl2', px and {'eee', 'e0e', ' e '} or {'e'})
game.animation('crawl', {'crawl1', 'crawl2'}, 5)
game.sprite('flag', px and {'5d ', '5dd', '5  '} or {'5'})

local state = {score=0, level=1, best=game.load('/.system/moonhop.tbl', {best=0}).best}

game.define('player', {sprite='hero1', gravity=40*T, maxFall=20*T, z=2, char=not px and '@' or nil,
  update=function(e, dt, g)
    local speed = 9*T
    if g.down('left') then e.vx = -speed; e.flip = true
    elseif g.down('right') then e.vx = speed; e.flip = false
    else e.vx = 0 end
    if g.pressed('jump') and e.onGround then e.vy = -14*T; g.sound('bit', 1, 18) end
    e.play(e.vx ~= 0 and 'walk' or 'hero1')
    local tx, ty = g.tiles.toTile(e.x + e.w/2, e.y + e.h - .1)
    local under = g.tiles.info(tx, ty)
    if under and under.spike then g.go('over', 'Spiked!') end
  end,
  fell=function(e, g) g.go('over', 'Fell off the moon.') end,
  touch=function(e, o, g)
    if o.is('coin') then
      o.destroy(); state.score = state.score + 10
      g.burst(o.x + 1, o.y + 1, {color=colors.yellow, count=6, speed=6*T, life=.4}); g.sound('chime', 1, 20)
    elseif o.is('crawler') then
      if e.vy > 0 and e.y + e.h - o.y < T then
        o.destroy(); e.vy = -10*T; state.score = state.score + 25
        g.burst(o.x + 1, o.y + 1, {color={colors.red, colors.orange}, count=10, speed=8*T}); g.shake(1, .2)
      else g.go('over', 'A crawler got you.') end
    elseif o.is('flag') then
      if state.level < #levels then state.level = state.level + 1; g.go('play')
      else g.go('over', 'You cleared every level!', true) end
    end
  end})
game.define('coin', {sprite='coin', char=not px and '*' or nil, fg=colors.yellow})
game.define('crawler', {sprite='crawl', gravity=40*T, vx=-3*T, z=1, char=not px and 'x' or nil, fg=colors.red,
  hitWall=function(e) e.vx = e.flip and -3*T or 3*T; e.flip = not e.flip end,
  update=function(e, dt, g)
    -- Turn round at ledges instead of walking off them.
    local ahead = e.vx > 0 and e.x + e.w + .5 or e.x - .5
    if e.onGround and not g.solidAt(ahead, e.y + e.h + .5) then e.vx = -e.vx; e.flip = not e.flip end
  end})
game.define('flag', {sprite='flag', char=not px and 'F' or nil, fg=colors.lime})

local function hud(g)
  g.write(1, 1, ' Moonhop  L' .. state.level .. '  ' .. state.score .. '  Best ' .. state.best .. string.rep(' ', g.cols),
    colors.black, colors.lightGray)
end

game.scene('play', {
  enter=function(g)
    -- Advanced: repaint blue as a deep night sky. Basic keeps plain black.
    if px and g.palette(colors.blue, 0x0c1030) then g.background = colors.blue else g.background = colors.black end
    g.map{tile=T, rows=levels[state.level], legend=legend}
    g.follow(g.first('player'))
    -- A few drifting stars, drawn behind everything.
    g.stars = {}
    for i = 1, px and 30 or 0 do g.stars[i] = {x=math.random(0, 400), y=math.random(0, 60)} end
  end,
  background=function(g)
    for _, s in ipairs(g.stars or {}) do g.screen.pixel((s.x - g.camera.x/4) % g.width, s.y % g.height, colors.gray) end
  end,
  update=function(g) if g.pressed('r') then state.score = 0; state.level = 1; g.go('play') end
    if g.pressed('q') then g.quit() end end,
  draw=hud,
})

game.scene('over', {
  enter=function(g, why, won)
    if state.score > state.best then state.best = state.score; g.save('/.system/moonhop.tbl', {best=state.best}) end
    g.message, g.won = why, won
  end,
  update=function(g)
    if g.pressed('r') or g.pressed('action') then state.score = 0; state.level = 1; g.go('play') end
    if g.pressed('q') then g.quit() end
  end,
  draw=function(g)
    hud(g)
    local mid = math.floor(g.rows/2)
    g.center(mid - 1, g.won and 'YOU WIN' or 'GAME OVER', g.won and colors.lime or colors.red)
    g.center(mid, g.message or '', colors.white)
    g.center(mid + 2, 'R / Enter: again   Q: quit', colors.lightGray)
  end,
})

game.run('play')

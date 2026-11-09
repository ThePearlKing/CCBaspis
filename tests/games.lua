local native=term.current(); local w,h=native.getSize()
local view=window.create(native,1,1,w-2,h-4,false)
local cache={}; local function module(name)
  if not cache[name] then cache[name]=assert(loadfile('/src/'..name..'.lua'))() end
  return cache[name]
end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function first(low) return low end
local results,failures={},0
local function test(name,fn)
  term.redirect(view)
  os.queueEvent('games_test_yield'); os.pullEvent('games_test_yield')
  local ok,err=pcall(fn); term.redirect(native)
  if not ok then failures=failures+1 end
  results[#results+1]={name=name,ok=ok,error=not ok and tostring(err) or nil}
end
local Config=module('system/config'); local config=Config.normalize({},Config.capabilities())
local storage=module('system/storage'); local catalog=module('system/game_catalog')
test('Render is the advanced default; basic and explicit choices are retained',function()
  eq(Config.normalize({},{color=true,blit=true}).mode,'render')
  eq(Config.normalize({},{color=false,blit=true}).mode,'basic')
  eq(Config.normalize({},{color=true,blit=false}).mode,'color')
  for _,mode in ipairs({'basic','color','render'}) do eq(Config.normalize({mode=mode},{color=true,blit=true}).mode,mode) end
end)
test('Snake grows, rejects reversals and ends on wall/self collisions',function()
  local s=module('system/games/snake').new(first); s.food={x=9,y=4}; s.key('left'); s.tick(.3)
  eq(s.body[1].x,9); eq(#s.body,4); eq(s.score,10)
  for i=1,20 do s.tick(.3) end; eq(s.result,'lose')
  s=module('system/games/snake').new(first)
  s.body={{x=3,y=3},{x=3,y=4},{x=4,y=4},{x=4,y=3},{x=5,y=3}}; s.tick(.3); eq(s.result,'lose')
end)
test('Pong paddles stay on court, bounce the ball, and first to seven wins',function()
  local s=module('system/games/pong').new(first)
  for i=1,20 do s.key('up') end; eq(s.player,2)
  s.x,s.y,s.vx,s.vy=2.1,2,-6,0; s.tick(.1); assert(s.vx>0)
  s.left=6; s.x,s.y,s.vx=18.9,1,6; s.tick(.1); eq(s.result,'win'); eq(s.score,7)
  s=module('system/games/pong').new(first); s.right=6; s.x,s.vx=.1,-6; s.tick(.1); eq(s.result,'lose')
end)
test('Blocks clears completed rows, rotates legally and detects top-out',function()
  local s=module('system/games/blocks').new(first)
  for x=1,10 do if x<4 or x>7 then s.board[12][x]=1 end end
  s.key('space'); eq(s.lines,1); assert(s.score>=100)
  s.key('up'); for _,p in ipairs(s.shape) do assert(s.x+p[1]>=1 and s.x+p[1]<=10) end
  for i=1,40 do s.key('space') end; eq(s.result,'lose')
end)
test('Mines guarantees a safe opening, honours flags and detects wins/losses',function()
  local s=module('system/games/mines').new(first); s.key('f'); s.key('enter'); assert(not s.started)
  s.key('f'); s.key('enter'); assert(s.started and s.score>0 and s.result~='lose')
  local count=0; for i in pairs(s.bombs) do count=count+1; assert(i~=1 and i~=2 and i~=9 and i~=10) end; eq(count,10)
  for y=1,8 do for x=1,8 do if not s.bombs[(y-1)*8+x] then s.reveal(x,y) end end end
  eq(s.result,'win'); eq(s.score,54)
  s=module('system/games/mines').new(first); s.started=true; s.bombs[2]=true
  s.reveal(2,1); eq(s.result,'lose')
end)
test('2048 merges once per move, keeps no-op boards unchanged and detects endings',function()
  local s=module('system/games/merge').new(first); s.cells={2,2,2,2}; s.key('left')
  eq(s.cells[1],4); eq(s.cells[2],4); eq(s.cells[3],2); eq(s.score,8)
  s.cells={[1]=2}; s.key('left'); assert(s.cells[2]==nil and s.cells[5]==nil)
  s.cells={2,4,2,4,4,2,4,2,2,4,2,4,4,2,4,2}; s.key('left'); eq(s.result,'lose')
  s=module('system/games/merge').new(first); s.cells={1024,1024}; s.key('left'); eq(s.result,'win')
end)
test('Lights Out has a solvable board and awards a win when every light is off',function()
  local s=module('system/games/lights').new(first); s.key('enter'); eq(s.result,'win'); eq(s.moves,1)
  s=module('system/games/lights').new(first); s.key('left'); s.key('enter'); assert(not s.result)
end)
local function sokobanSolution(s)
  local function signature(x,y,crates)
    local ids={}; for id in pairs(crates) do ids[#ids+1]=id end; table.sort(ids)
    return x..':'..y..':'..table.concat(ids,',')
  end
  local queue={{x=s.x,y=s.y,crates=s.crates,path={}}}; local visited={[signature(s.x,s.y,s.crates)]=true}; local pos=1
  while pos<=#queue do
    local node=queue[pos]; pos=pos+1; local won=true
    for goal in pairs(s.goals) do if not node.crates[goal] then won=false end end
    if won then return node.path end
    for _,d in ipairs({{1,0,'right'},{-1,0,'left'},{0,1,'down'},{0,-1,'up'}}) do
      local x,y=node.x+d[1],node.y+d[2]; local id=y*16+x; local beyond=(y+d[2])*16+x+d[1]
      if not s.walls[id] and not (node.crates[id] and (s.walls[beyond] or node.crates[beyond])) then
        local crates={}; for k,v in pairs(node.crates) do crates[k]=v end
        if crates[id] then crates[id]=nil; crates[beyond]=true end
        local sig=signature(x,y,crates)
        if not visited[sig] then
          visited[sig]=true; local path={}; for i,key in ipairs(node.path) do path[i]=key end; path[#path+1]=d[3]
          queue[#queue+1]={x=x,y=y,crates=crates,path=path}
        end
      end
    end
    assert(#queue<100000,'Sokoban search exceeded bounds')
  end
  error('Unsolvable Sokoban level '..s.level)
end
test('All four Sokoban levels are solvable; pushing, undo and progression work',function()
  local s=module('system/games/sokoban').new(); local x=s.x; s.key('right'); s.key('z'); eq(s.x,x); eq(s.moves,0)
  for level=1,4 do
    eq(s.level,level); local solution=sokobanSolution(s)
    for _,key in ipairs(solution) do s.key(key) end
    assert(s.cleared,'Level was not cleared'); if level<4 then s.key('enter') end
  end
  eq(s.result,'win'); eq(s.score,400)
end)
test('Memory prevents duplicate flips and completes all eight pairs',function()
  local s=module('system/games/memory').new(first); s.key('enter'); s.key('enter'); eq(#s.flipped,1)
  s.flipped={}
  for value=65,72 do
    for i,card in ipairs(s.cards) do if card==string.char(value) then s.cursor=i; s.key('enter') end end
  end
  eq(s.result,'win'); eq(s.turns,8); eq(s.score,8)
end)
test('Breakout launches, bounces, breaks bricks and handles last brick/last life',function()
  local s=module('system/games/breakout').new(); local y=s.y; s.tick(.1); eq(s.y,y); s.key('space'); s.tick(.1); assert(s.y<y)
  s.x,s.y,s.vx,s.vy=s.paddle,43.9,0,24; s.tick(.1); assert(s.vy<0)
  for _,brick in ipairs(s.bricks) do brick.alive=false end
  s.bricks[1].alive=true; s.remaining=1; s.x,s.y,s.vx,s.vy=5,8,0,-24; s.tick(.1); eq(s.result,'win')
  s=module('system/games/breakout').new(); s.ready=false; s.lives=1; s.x,s.y,s.vx,s.vy=2,49,0,24; s.tick(.1); eq(s.result,'lose')
end)
local function mazePath(s,tx,ty)
  local start={math.floor(s.x),math.floor(s.y)}; local queue={{x=start[1],y=start[2],path={}}}; local seen={[start[1]..':'..start[2]]=true}; local pos=1
  while pos<=#queue do local p=queue[pos]; pos=pos+1
    if p.x==tx and p.y==ty then return p.path end
    for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
      local x,y=p.x+d[1],p.y+d[2]; local id=x..':'..y
      if s.map[y] and s.map[y][x]==0 and not seen[id] then
        local path={}; for i,v in ipairs(p.path) do path[i]=v end; path[#path+1]=d
        seen[id]=true; queue[#queue+1]={x=x,y=y,path=path}
      end
    end
  end
  error('Unreachable treasure/exit')
end
test('3D mazes have reachable treasures/exits, solid walls and a complete playable win path',function()
  for seed=1,8 do
    math.randomseed(seed); local s=module('system/games/vaultrunner').new()
    s.move(-.4,0); s.move(-.4,0); assert(s.x>=2.18 and not s.solid(s.x,s.y))
    s.x,s.y=2.5,2.5
    local targets={}; for _,p in ipairs(s.crystals) do targets[#targets+1]=p end; targets[#targets+1]=s.exit
    for _,target in ipairs(targets) do
      for _,d in ipairs(mazePath(s,math.floor(target.x),math.floor(target.y))) do for i=1,4 do s.move(d[1]*.25,d[2]*.25) end end
    end
    eq(s.collected,6); eq(s.result,'win')
    for angle=0,6,.2 do local dist,side,u=s.ray(math.cos(angle),math.sin(angle)); assert(dist>0 and dist<30 and (side==0 or side==1) and u>=0 and u<1) end
  end
end)
local exits,states={},{}; local notices={}; local launched
local api={ui=module('system/ui'),pixels=module('system/pixels'),caps=Config.capabilities(),home='games-fixture',storage=storage,
  config=function() return config end,theme=function() return Config.theme(config) end,setTitle=function() end,
  onExit=function(fn) exits[#exits+1]=fn end,notify=function(v) notices[#notices+1]=v end,
  launch=function(_,id) launched=id end}
api.load=function(name)
  local value=module(name)
  if name:match('^system/games/') then return {new=function() local s=value.new(first); states[name]=s; return s end} end
  return value
end
local function snapshot(name)
  local vw,vh=view.getSize(); local lines={}
  for y=1,vh do local text,fg,bg=view.getLine(y); lines[y]={text=text,fg=fg,bg=bg} end
  local text=textutils.serializeJSON({width=vw,height=vh,lines=lines})
  if name then assert(storage.write('/snapshot-'..name..'.json',text)) end
  return text
end
local co,lastTimer; local active={}; local startTimer,cancelTimer=os.startTimer,os.cancelTimer
os.startTimer=function(delay) local id=startTimer(delay); active[id]=true; lastTimer=id; return id end
os.cancelTimer=function(id) active[id]=nil; return cancelTimer(id) end
local function event(...)
  local ok,err=coroutine.resume(co,...); assert(ok,err)
end
local function start(id) co=coroutine.create(function() module('apps/games')(api,id) end); event() end
local function tick() local id=lastTimer; active[id]=nil; event('timer',id) end
local function finish(kind)
  event(kind or 'sacabam_close'); eq(coroutine.status(co),'dead'); assert(next(active)==nil,'Game leaked a timer')
end
test('Games launcher lists ten titles, labels advanced-only games and launches selection',function()
  start(); snapshot('games'); event('key',keys['end'],false)
  local text=snapshot(); assert(text:find('ADVANCED',1,true) and text:find('COMPUTER',1,true) and text:find('ONLY',1,true))
  event('key',keys.enter,false); eq(launched,'vaultrunner'); finish()
end)
test('Every game opens on real hardware, with basic gating and a small-window prompt',function()
  local vw,vh=view.getSize()
  for _,entry in ipairs(catalog) do
    states['system/games/'..entry.id]=nil; start(entry.id)
    if entry.advanced and not native.isColor() then
      assert(not states['system/games/'..entry.id],'Advanced game was loaded on a basic computer')
      assert(snapshot():find('ADVANCED',1,true)); event('key',keys.enter,false); eq(coroutine.status(co),'dead')
    else
      if vw<entry.w or vh<entry.h then assert(snapshot():find('Window too small',1,true))
      else
        if entry.timed then for i=1,4 do tick() end end
        snapshot(entry.id); event('key',keys.h,false); event('key',keys.h,false)
        if entry.id=='vaultrunner' then
          local before=snapshot(); event('key',keys.right,false); assert(snapshot()~=before,'Turning did not change the 3D view')
          before=snapshot(); event('key',keys.m,false); assert(snapshot()~=before,'Map did not open'); snapshot('vaultrunner-map')
        end
      end
      finish()
    end
  end
end)
test('Timed games pause, restart, resize safely and clean up timers on every exit route',function()
  view.reposition(1,1,49,18)
  for _,entry in ipairs(catalog) do if entry.timed and (not entry.advanced or native.isColor()) then
    start(entry.id); tick(); event('key',keys.p,false); local before=snapshot(); assert(next(active)==nil)
    event('timer',-1); eq(snapshot(),before); event('key',keys.p,false); assert(next(active))
    event('key',keys.r,false); assert(not states['system/games/'..entry.id].result)
    view.reposition(1,1,18,6); event('term_resize'); assert(next(active)==nil)
    view.reposition(1,1,49,18); event('term_resize'); assert(next(active)); finish('terminate')
    start(entry.id); for _,fn in ipairs(exits) do fn() end; assert(next(active)==nil)
  end end
  view.reposition(1,1,w-2,h-4)
end)
test('Completed games save records once and restart without duplicate records',function()
  view.reposition(1,1,49,18); start('lights'); event('key',keys.enter,false)
  local records=storage.load('/games-fixture/.system/game-records.tbl'); eq(records.lights.wins,1); eq(records.lights.plays,1)
  event('term_resize'); eq(storage.load('/games-fixture/.system/game-records.tbl').lights.plays,1)
  event('key',keys.r,false); event('key',keys.enter,false); eq(storage.load('/games-fixture/.system/game-records.tbl').lights.wins,2)
  finish(); view.reposition(1,1,w-2,h-4)
end)
test('Renamed game replaces only the stock launcher and preserves edited launchers',function()
  local root='/rename-fixture'; fs.makeDir(root)
  fs.copy('/src/examples',root..'/examples'); fs.copy('/src/games',root..'/games')
  local old="-- Crumb Raider / ADVANCED COMPUTER ONLY\nassert(ccsacabam,'Run this game inside CCSacabam').launch('games','crumb')\n"
  assert(storage.write(root..'/home/Games/crumb.lua',old))
  local programs=module('system/programs'); local crypto=module('system/crypto')
  programs.update(root,storage,crypto)
  assert(not fs.exists(root..'/home/Games/crumb.lua'))
  eq(storage.read(root..'/home/Games/vaultrunner.lua'),storage.read('/src/games/vaultrunner.lua'))
  local edited=old..'-- my changes\n'
  assert(storage.write(root..'/home/Games/crumb.lua',edited))
  programs.update(root,storage,crypto); eq(storage.read(root..'/home/Games/crumb.lua'),edited)
end)
test('Old game links open Vault Runner and prior completion records carry forward',function()
  view.reposition(1,1,49,18)
  local path='/games-fixture/.system/game-records.tbl'
  local records=storage.load(path,{}); records.crumb={wins=2,plays=3,best=5000}
  assert(storage.save(path,records)); start('crumb')
  assert(snapshot():find('Vault Runner',1,true))
  if native.isColor() then
    assert(snapshot():find('Best 5000',1,true))
    local s=states['system/games/vaultrunner']; s.x,s.y=s.exit.x,s.exit.y; s.collected=6; s.collect()
    event('term_resize'); local updated=storage.load(path)
    eq(updated.vaultrunner.wins,3); eq(updated.vaultrunner.plays,4); eq(updated.vaultrunner.best,5000)
    eq(updated.lights.wins,2)
  else assert(snapshot():find('ADVANCED COMPUTER ONLY',1,true)) end
  finish(); view.reposition(1,1,w-2,h-4)
end)
local Titan=module('system/titan')
local function titanGame(opts) view.reposition(1,1,30,10); opts=opts or {}; opts.target=view; return Titan.new(opts) end
test('Titan: gravity lands bodies on solid tiles and walls stop sideways movement',function()
  local g=titanGame({mode='pixel'}); eq(g.width,60); eq(g.height,30)
  g.map{tile=3,rows={'#....#','#....#','#....#','######'},legend={['#']={solid=true,color=colors.gray}}}
  local e=g.spawn{x=4,y=0,w=2,h=2,gravity=60}; g.flush()
  for i=1,40 do g.step(.05) end
  eq(e.y,7); assert(e.onGround,'Body did not report ground'); eq(e.vy,0)
  e.vx=200; g.step(.05); eq(e.x,13); e.vx=-200; g.step(.05); eq(e.x,3)
end)
test('Titan: one-way platforms catch falls but allow jumping through from below',function()
  local g=titanGame({mode='pixel'})
  g.map{tile=3,rows={'....','====','....','....','####'},legend={['#']={solid=true},['=']={oneway=true}}}
  local e=g.spawn{x=3,y=7,w=2,h=2,gravity=60}; g.flush()
  e.vy=-100; g.step(.1); assert(e.y<3,'Jump was blocked by a one-way platform'); eq(e.y,0)
  for i=1,30 do g.step(.05) end; eq(e.y,1); assert(e.onGround)
  assert(g.solidAt(4,4),'solidAt misses one-way tiles'); assert(not g.solidAt(4,7))
end)
test('Titan: fast bodies do not tunnel and solid entities block movers',function()
  local g=titanGame({mode='pixel'})
  g.map{tile=3,rows={'#..........#'},legend={['#']={solid=true}},edge=false}
  local e=g.spawn{x=4,y=0,w=2,h=3}; g.flush(); g.move(e,500,0); eq(e.x,31)
  local wall=g.spawn{x=10,y=0,w=2,h=3,solid=true}; g.flush(); e.x=4; g.move(e,50,0); eq(e.x,8)
end)
test('Titan: templates, map spawns, tags, touch callbacks and destruction',function()
  local g=titanGame({mode='cell'}); local touched=0
  g.define('coin',{w=1,h=1,tags={'pickup'}})
  g.define('hero',{w=1,h=1,touches='pickup',touch=function(e,o) touched=touched+1; o.destroy() end})
  local m=g.map{tile=1,rows={'.@C.C'},legend={['@']={spawn='hero'},['C']={spawn='coin'}}}
  eq(#m.spawned,3); eq(m.get(3,1),' '); eq(g.count('coin'),2); assert(g.first('coin').is('pickup'))
  local hero=g.first('hero'); hero.x=2; g.step(.05); eq(touched,1); eq(g.count('coin'),1)
  hero.x=4; g.step(.05); eq(touched,2); eq(g.count('coin'),0); eq(#g.entities,1)
end)
test('Titan: timers, repeating timers, tweens and scene changes from callbacks',function()
  local g=titanGame(); local log={}; local obj={x=0}
  g.scene('a',{enter=function(g) g.after(.2,function() log[#log+1]='after' end)
    g.every(.1,function() log[#log+1]='every' end); g.tween(obj,.5,{x=10},'linear')
    g.after(.6,function() g.go('b','arg') end) end})
  g.scene('b',{enter=function(g,v) log[#log+1]='b:'..v end})
  g.go('a'); for i=1,5 do g.step(.1) end
  assert(math.abs(obj.x-10)<1e-6,'Tween ended at '..obj.x); local seen=false; for _,v in ipairs(log) do if v=='after' then seen=true end end; assert(seen); local count=0; for _,v in ipairs(log) do if v=='every' then count=count+1 end end; eq(count,5)
  g.step(.15); eq(g.sceneName,'b'); eq(log[#log],'b:arg'); local n=#log; g.step(1); eq(#log,n)
end)
test('Titan: bindings, pressed-once input, mouse picking and camera bounds',function()
  local g=titanGame({mode='pixel'})
  g.event('key',keys.a,false); assert(g.down('left') and g.pressed('left')); g.step(.05)
  assert(g.down('left') and not g.pressed('left')); g.event('key_up',keys.a); assert(not g.down('left'))
  g.bind('fire','x'); g.event('key',keys.x,false); assert(g.pressed('fire'))
  g.map{tile=3,rows={string.rep('.',40),string.rep('.',40)}}
  local e=g.spawn{x=110,y=0,w=2,h=2}; g.follow(e); g.step(.05); eq(g.camera.x,60); eq(g.camera.y,0)
  g.event('mouse_click',1,2,1); assert(g.clicked(1)); eq(g.mouse.x,62.5); eq(g.mouse.y,1); eq(g.at(111,1),e); eq(g.at(1,1),nil)
end)
test('Titan: pixel and cell renderers draw sprites, text and transparency',function()
  local g=titanGame({mode='pixel',background=colors.blue})
  g.sprite('box',{'e.','ee'}); local e=g.spawn{x=0,y=0,sprite='box'}; g.flush(); eq(e.w,2); eq(e.h,2)
  g.render(); eq(g.pixelAt(0,0),colors.red); eq(g.pixelAt(1,0),colors.blue); eq(g.pixelAt(1,1),colors.red)
  local text,fg,bg=view.getLine(1); eq(text:byte(1)>=128,true); eq(bg:sub(2,2),'b')
  g.scene('hud',{keep=true,draw=function(g) g.write(5,2,'Hi',colors.yellow) end}); g.go('hud'); g.render()
  text,fg=view.getLine(2); eq(text:sub(5,6),'Hi'); eq(fg:sub(5,5),'4')
  local c=titanGame({mode='cell'}); c.spawn{x=3,y=2,w=1,h=1,color=colors.lime}; c.flush(); c.render()
  text,fg,bg=view.getLine(3); eq(bg:sub(4,4),'5'); eq(c.width,30)
end)
test('Titan: saves and loads tables, quits cleanly on close and plays without a speaker',function()
  local g=titanGame({basic=true}); assert(g.save('/titan-save.tbl',{best=42})); eq(g.load('/titan-save.tbl').best,42)
  eq(g.load('/missing-titan.tbl',7),7); g.sound('bit')
  co=coroutine.create(function() g.run() end); event(); tick(); assert(g.running); event('sacabam_close'); eq(coroutine.status(co),'dead')
  assert(next(active)==nil,'Titan leaked a timer')
end)
test('Titan: advanced graphics by default; basic computers need an opted-in basic design',function()
  local g=titanGame()
  if native.isColor() then
    eq(g.mode,'pixel'); assert(g.supported)
    local before={view.getPaletteColour(colors.blue)}; assert(g.palette(colors.blue,0x102030))
    assert(view.getPaletteColour(colors.blue)~=before[1] or select(3,view.getPaletteColour(colors.blue))~=before[3])
    co=coroutine.create(function() g.run() end); event(); tick(); event('sacabam_close'); eq(coroutine.status(co),'dead')
    local r,gg,b=view.getPaletteColour(colors.blue); eq(r,before[1]); eq(gg,before[2]); eq(b,before[3])
  else
    eq(g.mode,'cell'); assert(not g.supported); assert(not g.palette(colors.blue,0x102030))
    co=coroutine.create(function() g.run() end); event(); assert(snapshot():find('ADVANCED COMPUTER ONLY',1,true))
    assert(next(active)==nil,'Unsupported game started a timer'); event('key',keys.q,false); eq(coroutine.status(co),'dead')
    local opted=titanGame({basic=true}); assert(opted.supported); eq(opted.mode,'cell')
  end
end)
test('Titan demo: Moonhop runs, scrolls, collects coins, and restarts after death',function()
  view.reposition(1,1,math.min(45,w-2),math.min(14,h-4))
  local captured
  local real=Titan.new
  local fake={new=function(opts) opts.target=view; captured=real(opts); return captured end}
  for k,v in pairs(Titan) do if k~='new' then fake[k]=v end end
  local env=setmetatable({require=function(name) assert(name=='titan'); return fake end},{__index=_ENV})
  local demo=assert(loadfile('/src/examples/titan-demo.lua','t',env))
  co=coroutine.create(demo); event()
  local vw,vh=view.getSize()
  if vw<20 or vh<8 then
    tick(); assert(snapshot():find('Window too small',1,true)); finish('terminate'); view.reposition(1,1,w-2,h-4); return
  end
  for i=1,10 do tick() end
  local g=captured; eq(g.sceneName,'play'); local hero=g.first('player'); assert(hero.onGround,'Hero did not land')
  local startX=hero.x; event('key',keys.right,false); for i=1,8 do tick() end; event('key_up',keys.right)
  assert(hero.x>startX,'Hero did not walk'); snapshot('titan-demo')
  local coin=g.first('coin'); hero.x,hero.y=coin.x,coin.y; tick(); assert(not coin.alive,'Coin was not collected')
  local crawler=g.first('crawler'); hero.x,hero.y,hero.vy=crawler.x,crawler.y,0; tick(); eq(g.sceneName,'over')
  assert(snapshot():find('GAME OVER',1,true)); event('key',keys.r,false); tick(); eq(g.sceneName,'play')
  finish('terminate'); view.reposition(1,1,w-2,h-4)
end)
os.startTimer,os.cancelTimer=startTimer,cancelTimer
assert(storage.write('/test-results.json',textutils.serializeJSON({complete=true,tests=results,failures=failures,color=native.isColor(),host=_HOST})))
os.shutdown()

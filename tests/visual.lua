-- Animation/language/wallpaper tests on actual basic and advanced terminals.
local native=term.current(); local w,h=native.getSize()
local view=window.create(native,1,1,w-2,h-4,false)
local cache={}; local function module(name)
  if not cache[name] then cache[name]=assert(loadfile('/src/'..name..'.lua'))() end
  return cache[name]
end
local Config=module('system/config'); local P=module('system/pistachio'); local Peanut=module('system/peanut')
local config=Config.normalize({},Config.capabilities()); local storage=module('system/storage')
local exits={}; local title,message; local saved=0
local api={ui=module('system/ui'),storage=storage,load=module,caps=Config.capabilities(),
  config=function() return config end,theme=function() return Config.theme(config) end,
  resolve=function(path) return path end,keyDown=function() return false end,
  setTitle=function(value) title=value end,notify=function(value) message=value end,
  onExit=function(fn) exits[#exits+1]=fn end,saveConfig=function() saved=saved+1; return true end}
local function snapshot(name)
  local lines={}; local vw,vh=view.getSize()
  for y=1,vh do local text,fg,bg=view.getLine(y); lines[y]={text=text,fg=fg,bg=bg} end
  local data=textutils.serializeJSON({width=vw,height=vh,lines=lines})
  if name then assert(storage.write('/snapshot-'..name..'.json',data)) end
  return data
end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function rejects(fn) assert(not pcall(fn),'Expected rejection') end
local results,failures={},0
local function test(name,fn)
  term.redirect(view)
  local ok,err=pcall(fn); term.redirect(native)
  if not ok then failures=failures+1 end
  results[#results+1]={name=name,ok=ok,error=not ok and tostring(err) or nil}
end
test('Pistachio mutable arrays, object fields and nested loop indices',function()
  local state=P.runtime(P.parse([[
let data = peanut("{items=[0,0], title=\"before\"}")
let n = 0
repeat 2
  set data.items[index] = index * 10
  repeat 3
    set n = n + 1
  end
  set data.items[index] = data.items[index] + 1
end
set data.title = "after"
let empty = array(0, 0)
let flags = array(3, false)
]]),api,Peanut)
  state.initialize(); eq(state.vars.n,6); eq(state.vars.data.items[1],11); eq(state.vars.data.items[2],21)
  eq(state.vars.data.title,'after'); eq(Peanut.encode(state.vars.empty),'[]'); eq(Peanut.encode(state.vars.flags),'[false,false,false]')
end)
test('Pistachio arrays/coordinates stay bounded and web assignment targets are checked',function()
  for _,source in ipairs({'let x = array(4097, 0)','let x = array(3.5, 0)',
    'let x = array(2, 0)\nset x[0] = 1','let x = array(2, 0)\nset x[4097] = 1',
    'set null.x = 1','let x = random(8, 1)'}) do
    rejects(function() P.runtime(P.parse(source),api,Peanut).initialize() end)
  end
  local C=module('system/cashew')
  rejects(function() C.safeScript(P.parse('set data[seal("x", "password")] = 1')) end)
  rejects(function() C.safeScript(P.parse('frame\ntext 1 1 "white" "black" "x"\nend')) end)
  assert(C.safeScript(P.parse('let x = array(3, 0)\nset x[1] = random(1, 9)')))
  local state=P.runtime(P.parse('text (1/0) 1 "white" "black" "x"'),api,Peanut)
  state.initialize(); rejects(state.layout)
end)
test('Frame code only runs during drawing and resets the default footer/background',function()
  local state=P.runtime(P.parse('let n = 0\nframe\nset n = n + 1\nbackground "black"\nstatus ""\ntext 1 1 "white" "black" str(n)\nend'),api,Peanut)
  state.initialize(); eq(state.vars.n,0); eq(state.layout()[1].value,'1'); eq(state.layout()[1].value,'2')
  eq(state.background,colors.black); eq(state.status,'')
end)
local source=assert(storage.read('/src/examples/pmatrix.pist'))
test('pmatrix runs hundreds of bounded frames, pauses, changes speed and resizes',function()
  local state=P.runtime(P.parse(source),api,Peanut); state.initialize()
  for frame=1,320 do state.tick(state.timers[1]); assert(#state.layout()>0) end
  state.vars.key='space'; state.vars.held=false; state.dispatch('key')
  local head=state.vars.heads[1]; state.tick(state.timers[1]); eq(state.vars.heads[1],head)
  state.vars.char='9'; state.dispatch('char'); eq(state.vars.speed,9)
  state.vars.key='down'; state.dispatch('key'); eq(state.vars.speed,8)
  state.vars.held=true; state.vars.key='space'; state.dispatch('key'); assert(state.vars.paused)
  state.vars.held=false; state.dispatch('key'); assert(not state.vars.paused)
  for _,size in ipairs({{18,6},{160,50},{w-2,h-4}}) do
    view.reposition(1,1,size[1],size[2]); state.dispatch('resize')
    for frame=1,12 do state.tick(state.timers[1]); state.layout() end
  end
  state.vars.key='q'; state.dispatch('key'); assert(state.quit)
end)
local co,lastTimer; local active={}; local startTimer,cancelTimer=os.startTimer,os.cancelTimer
os.startTimer=function(delay) local id=startTimer(delay); active[id]=true; lastTimer=id; return id end
os.cancelTimer=function(id) active[id]=nil; return cancelTimer(id) end
local function event(...)
  local ok,err=coroutine.resume(co,...); assert(ok,err)
end
local function start()
  view.reposition(1,1,w-2,h-4)
  co=coroutine.create(function() module('apps/pistachio')(api,'/src/examples/pmatrix.pist') end); event()
end
local function tick() local id=lastTimer; active[id]=nil; event('timer',id) end
test('Real Pistachio window animates, clips trails and uses color/monochrome ink',function()
  start(); eq(title,'pmatrix')
  local found={}; local vw,vh=view.getSize()
  for frame=1,20 do
    tick()
    for y=1,vh do
      local text,fg,bg=view.getLine(y); eq(bg,string.rep('f',vw))
      for i=1,#text do if text:sub(i,i)~=' ' then found[fg:sub(i,i)]=true end end
    end
  end
  local before=snapshot(); tick(); assert(before~=snapshot(),'Rain did not move')
  assert(found['0'],'Missing bright heads')
  if native.isColor() then assert(found['5'] or found['d'],'Missing green rain')
  else for color in pairs(found) do assert(color=='0' or color=='7' or color=='8','Non-monochrome ink') end end
  snapshot('pmatrix')
  event('key',keys.space,false); before=snapshot(); tick(); eq(snapshot(),before)
  event('key',keys.h,false); event('char','9'); assert(view.getLine(vh):find('Speed 9/9',1,true))
  event('key',keys.c,false); event('key',keys.h,false); event('key',keys.space,false)
  view.reposition(1,1,18,6); event('term_resize'); tick(); snapshot('pmatrix-small')
  event('key',keys.q,false); eq(coroutine.status(co),'dead'); assert(next(active)==nil,'Timer leaked on quit')
end)
test('Window close, termination and forced cleanup cancel animation timers',function()
  for _,kind in ipairs({'sacabam_close','terminate','forced'}) do
    start()
    if kind=='forced' then for _,fn in ipairs(exits) do fn() end
    else event(kind); eq(coroutine.status(co),'dead') end
    assert(next(active)==nil,'Timer leaked on '..kind)
  end
  view.reposition(1,1,w-2,h-4)
end)
test('All eight wallpapers render distinctly in basic, color and subpixel modes',function()
  local W=module('system/wallpaper'); local Pixels=module('system/pixels')
  local vw,vh=view.getSize()
  for _,mode in ipairs({'basic','color','render'}) do
    local seen={}
    for _,name in ipairs(Config.wallpaperPatterns) do
      local c=Config.normalize({mode=mode,wallpaperPattern=name}, {color=true,blit=true})
      W.draw(W.build(c,Config.theme(c),vw,vh,Pixels),Pixels,1,1)
      local data=snapshot(); assert(not seen[data],mode..' duplicates '..name); seen[data]=true
      if mode==(native.isColor() and 'render' or 'basic') then snapshot('wallpaper-'..name) end
    end
  end
  eq(Config.normalize({wallpaperPattern='invalid'},api.caps).wallpaperPattern,native.isColor() and 'mountains' or 'dots')
end)
test('Wallpaper chooser previews, cancels, applies, enables wallpaper and rolls back errors',function()
  local custom=module('apps/customisation')(api); local original=config.wallpaperPattern
  custom.draw(); custom.event('char','w'); custom.draw()
  custom.event('key',keys.right); custom.draw(); custom.event('key',keys.f5); eq(config.wallpaperPattern,original)
  custom.event('char','w'); custom.event('key',keys.right); custom.draw()
  config.wallpaper=false; custom.event('key',keys.enter); assert(config.wallpaper and saved>0)
  assert(config.wallpaperPattern~=original); local chosen=config.wallpaperPattern
  local save=api.saveConfig; api.saveConfig=function() return nil,'injected failure' end
  custom.event('char','w'); custom.event('key',keys.right); custom.event('key',keys.enter)
  eq(config.wallpaperPattern,chosen); eq(message,'injected failure'); assert(custom.editing)
  api.saveConfig=save; custom.event('key',keys.f5); custom.draw()
  local vw,vh=view.getSize(); custom.event('mouse_click',1,2,vh-1); custom.draw()
  custom.event('mouse_click',1,vw,4); custom.event('mouse_click',1,1,vh-1); assert(not custom.editing)
end)
os.startTimer,os.cancelTimer=startTimer,cancelTimer
assert(storage.write('/test-results.json',textutils.serializeJSON({complete=true,tests=results,failures=failures,color=native.isColor(),host=_HOST})))
os.shutdown()

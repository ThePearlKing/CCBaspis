-- Focused picker interactions, including an 18x6 minimum app content area.
local native=term.current(); local w,h=native.getSize()
local view=window.create(native,1,1,w-2,h-4,false)
local cache={}; local function module(name)
  if not cache[name] then cache[name]=assert(loadfile('/src/'..name..'.lua'))() end
  return cache[name]
end
local Config=module('system/config'); local config=Config.normalize({},Config.capabilities())
local paths=module('system/paths').context('/picker-fixture'); local closed,message
local api={ui=module('system/ui'),storage=module('system/storage'),load=module,home='picker-fixture',
  dir=paths.dir,resolve=paths.resolve,theme=function() return Config.theme(config) end,
  config=function() return config end,keyDown=function() return false end,
  notify=function(value) message=value end,deferClose=function() closed=true end}
api.saveConfig=function() config=Config.normalize(config,Config.capabilities()); return true end
local function write(path,text) assert(api.storage.write(path,text)) end
fs.makeDir('/picker-fixture/alpha'); fs.makeDir('/picker-fixture/zeta')
write('/picker-fixture/alpha/inner.txt','inside'); write('/picker-fixture/note.txt','original')
write('/picker-fixture/drawing.sketch','drawing'); write('/picker-fixture/.hidden.lua','private')
local co,result
local function event(...)
  term.redirect(view); local ok,value=coroutine.resume(co,...); term.redirect(native)
  assert(ok,value); if coroutine.status(co)=='dead' then result=value end
end
local function start(options)
  result,closed,message=nil,false,nil
  co=coroutine.create(function() return api.ui.filePicker(api,options) end); event()
end
local function key(k)
  event('key',k,false); if coroutine.status(co)~='dead' then event('key_up',k) end
end
local function ctrl(k)
  event('key',keys.leftCtrl,false); key(k)
  if coroutine.status(co)~='dead' then event('key_up',keys.leftCtrl) end
end
local function text(value) for c in value:gmatch('.') do event('char',c) end end
local function done(path) assert(coroutine.status(co)=='dead','Picker is still open'); assert(result==path,tostring(result)..' ~= '..tostring(path)) end
local results,failures={},0
local function test(name,fn)
  local ok,err=pcall(fn); term.redirect(native)
  if not ok then failures=failures+1 end
  results[#results+1]={name=name,ok=ok,error=not ok and tostring(err) or nil}
end
test('Keyboard browsing opens nested files and selects parent folders',function()
  start({path='/picker-fixture',mode='open'}); text('alpha'); key(keys.enter)
  text('inner'); key(keys.enter); done('/picker-fixture/alpha/inner.txt')
  start({path='/picker-fixture/alpha',mode='folder'}); key(keys.backspace); key(keys.enter); done('/picker-fixture')
  assert(api.dir()=='/picker-fixture')
end)
test('Save picker creates a folder and returns a filename without writing it',function()
  start({mode='save',path='/picker-fixture/untitled.txt'})
  ctrl(keys.n); text('made'); key(keys.enter); key(keys.tab); ctrl(keys.a)
  event('paste','./answer.txt'); key(keys.enter); done('/picker-fixture/made/answer.txt')
  assert(fs.isDir('/picker-fixture/made') and not fs.exists(result))
end)
test('Filters and hidden files can be toggled with the keyboard',function()
  start({path='/picker-fixture',extensions={'sketch'}}); text('drawing'); key(keys.enter); done('/picker-fixture/drawing.sketch')
  start({path='/picker-fixture',extensions={'sketch'}}); ctrl(keys.f); ctrl(keys.h)
  text('.hidden'); key(keys.enter); done('/picker-fixture/.hidden.lua')
end)
test('Invalid locations and read-only saves stay open; cancellation leaves files intact',function()
  start({path='/picker-fixture'}); ctrl(keys.l); event('paste','./missing'); key(keys.enter)
  assert(message and coroutine.status(co)=='suspended'); key(keys.f5); done(nil)
  start({mode='save',path='/rom/new.lua'}); key(keys.enter)
  assert(message:find('read%-only') and coroutine.status(co)=='suspended'); key(keys.f5); done(nil)
  assert(api.storage.read('/picker-fixture/note.txt')=='original')
end)
test('Mouse browsing ignores right-click and opens folders/files with double-click',function()
  start({path='/picker-fixture'})
  event('mouse_click',2,2,4); assert(view.getLine(2):find('picker%-fixture'))
  event('mouse_click',1,2,4); event('mouse_click',1,2,4)
  event('mouse_click',1,2,4); event('mouse_click',1,2,4); done('/picker-fixture/alpha/inner.txt')
end)
test('Picker resizes, scrolls, and forwards a window-close request',function()
  for i=1,18 do write('/picker-fixture/list/item'..string.format('%02d',i)..'.txt','item') end
  start({path='/picker-fixture/list'}); key(keys['end']); event('term_resize'); key(keys.enter)
  done('/picker-fixture/list/item18.txt')
  start({mode='save',path='/picker-fixture/untitled.txt'})
  view.reposition(1,1,18,6); event('term_resize')
  local x,y=view.getCursorPos(); assert(x>=1 and x<=18 and y>=1 and y<=6)
  event('sacabam_close'); done(nil); assert(closed)
  view.reposition(1,1,w-2,h-4)
end)
test('Customisation palette remains usable at the minimum window size',function()
  term.redirect(view)
  local custom=module('apps/customisation')(api)
  custom.draw(); custom.event('key',keys.enter); custom.draw()
  for i=1,15 do custom.event('key',keys.left) end
  custom.event('key',keys.right); custom.draw()
  custom.event('key',keys.enter); custom.draw()
  assert(api.theme().desktop==colors.orange)
  custom.event('key',keys.enter); custom.event('key',keys.right); custom.event('key',keys.f5)
  assert(api.theme().desktop==colors.orange)
  term.redirect(native)
end)
start({mode='open',path='/picker-fixture'})
local lines={}; local vw,vh=view.getSize()
for y=1,vh do local text,fg,bg=view.getLine(y); lines[y]={text=text,fg=fg,bg=bg} end
write('/snapshot-picker.json',textutils.serializeJSON({width=vw,height=vh,lines=lines})); key(keys.f5)
write('/test-results.json',textutils.serializeJSON({complete=true,tests=results,failures=failures,color=native.isColor(),host=_HOST}))
os.shutdown()

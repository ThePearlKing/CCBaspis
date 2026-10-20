-- Real standalone installer prompts and first boot, using production KDF cost.
local results,failures={},0; local native=term.current(); local w,h=native.getSize()
local observed=window.create(native,1,1,w,h,false); local password='first boot production passphrase'
local function test(name,fn)
  local ok,err=pcall(fn); if not ok then failures=failures+1 end
  results[#results+1]={name=name,ok=ok,error=not ok and tostring(err) or nil}
  local f=assert(fs.open('/test-results.json','w')); f.write(textutils.serializeJSON({tests=results,failures=failures,complete=false})); f.close()
end
local function contains(value)
  for y=1,h do if observed.getLine(y):find(value,1,true) then return true end end
end
local function waitFor(value)
  local deadline=os.clock()+60
  while not contains(value) do assert(os.clock()<deadline,'Timed out waiting for '..value); sleep(.05) end
end
local function key(k) os.queueEvent('key',k,false); os.queueEvent('key_up',k) end
local function enter(value) os.queueEvent('paste',value); key(keys.enter) end
local function typeText(value) for c in value:gmatch('.') do os.queueEvent('char',c) end end
local function readFile(path) local f=assert(fs.open(path,'rb')); local data=f.readAll(); f.close(); return data end
test('Standalone installer supports interactive display and encryption choices',function()
  term.redirect(observed)
  parallel.waitForAll(function() assert(shell.run('/src/dist/ccsacabam-installer.lua')) end,function()
    if native.isColor() then waitFor('Choose 1, 2, or 3:'); enter('3') end
    waitFor('Enable encryption?'); enter('')
    waitFor('Press Enter to install'); enter('')
  end)
  term.redirect(native)
  assert(fs.exists('/ccsacabam/boot.lua'))
  local config=textutils.unserialize(readFile('/ccsacabam/config/display.tbl'))
  assert(config.encrypt==false,'New installations must default to encryption OFF')
  assert(config.mode==(native.isColor() and 'render' or 'basic'))
end)
test('First boot creates a login with encryption off, then Settings enables encryption',function()
  term.redirect(observed)
  parallel.waitForAll(function() assert(shell.run('/ccsacabam/boot.lua')) end,function()
    waitFor('Create your personal drive'); enter(password)
    waitFor('Confirm your passphrase'); enter(password)
    waitFor('F1 Apps')
    local raw=readFile('/ccsacabam/vault/data.scv')
    assert(raw:sub(1,4)=='SCP1' and raw:find('Documents',1,true),'Default drive is not plain')
    key(keys.f1); typeText('Settings'); key(keys.enter); sleep(.15)
    typeText('7'); sleep(.15); typeText('YES'); key(keys.enter); sleep(.25)
    assert(readFile('/ccsacabam/vault/data.scv'):sub(1,4)=='SCV1','Settings did not enable encryption')
    key(keys.f9); sleep(.1); key(keys.enter); waitFor('Unlock your personal'); enter(password)
    waitFor('F1 Apps'); key(keys.f10); sleep(.1); key(keys.enter)
  end)
  term.redirect(native)
end)
test('First boot uses production PBKDF2 cost and installs examples privately',function()
  local C=assert(loadfile('/ccsacabam/system/crypto.lua'))()
  local raw=readFile('/ccsacabam/vault/data.scv')
  assert(C.number(raw,37)==100000)
  assert(not raw:find('sealed-note.pist',1,true)); assert(not fs.exists('/ccsacabam/home'))
  local f=assert(fs.open('/fresh-oracle.json','w')); f.write(textutils.serializeJSON({password=password})); f.close()
end)
local final={complete=true,tests=results,failures=failures,color=native.isColor(),host=_HOST}
local f=assert(fs.open('/test-results.json','w')); f.write(textutils.serializeJSON(final)); f.close(); os.shutdown()

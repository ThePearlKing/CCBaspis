-- Standalone setup wizard and real boot, using production encryption cost.
local case=...; local encryptedInstall=case=='fresh-encrypted'
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
local function waitUntil(fn,label)
  local deadline=os.clock()+90
  while not fn() do assert(os.clock()<deadline,'Timed out waiting for '..label); sleep(.05) end
end
local function waitFor(value) waitUntil(function() return contains(value) end,value) end
local function key(k) os.queueEvent('key',k,false); os.queueEvent('key_up',k) end
local function enter(value) os.queueEvent('paste',value); key(keys.enter) end
local function typeText(value) for c in value:gmatch('.') do os.queueEvent('char',c) end end
local function readFile(path) local f=assert(fs.open(path,'rb')); local data=f.readAll(); f.close(); return data end
local function dump(name)
  local lines={}; for y=1,h do local text,fg,bg=observed.getLine(y); lines[y]={text=text,fg=fg,bg=bg} end
  local f=assert(fs.open('/snapshot-'..name..'.json','w')); f.write(textutils.serializeJSON({width=w,height=h,lines=lines})); f.close()
end
test('Standalone TUI selects display and privacy; no password when encryption is off',function()
  term.redirect(observed)
  parallel.waitForAll(function() assert(shell.run('/src/dist/ccsacabam-installer.lua')) end,function()
    waitFor('Welcome'); dump('setup-welcome'); key(keys.enter)
    waitFor('computer detected'); if native.isColor() then key(keys.down); sleep(.1) end
    dump('setup-display'); key(keys.enter)
    waitFor('Off / no password'); dump('setup-privacy')
    if encryptedInstall then
      key(keys.down); key(keys.enter); waitFor('Confirm password')
      enter(password); enter(password)
    else key(keys.enter) end
    waitFor('Ready to install'); dump('setup-review'); key(keys.enter)
    waitFor('Installation complete'); dump('setup-done'); key(keys.enter)
  end)
  term.redirect(native)
  assert(fs.exists('/ccsacabam/boot.lua'))
  local config=textutils.unserialize(readFile('/ccsacabam/config/display.tbl'))
  assert(config.encrypt==encryptedInstall,'Unexpected installer encryption setting')
  assert(config.mode==(native.isColor() and 'render' or 'basic'))
  assert(readFile('/ccsacabam/vault/data.scv'):sub(1,4)==(encryptedInstall and 'SCV1' or 'SCP2'))
end)
test('Plain boot skips login; enabling encryption creates a password and allows lock/unlock',function()
  term.redirect(observed)
  parallel.waitForAll(function() assert(shell.run('/ccsacabam/boot.lua')) end,function()
    if encryptedInstall then waitFor('Unlock your personal'); enter(password) end
    waitUntil(function()
      assert(not contains('Create your personal drive'),'Unexpected login on plain drive')
      if not encryptedInstall then assert(not contains('Unlock your personal'),'Plain drive asked for password') end
      return contains(' Apps    ')
    end,'desktop')
    if not encryptedInstall then
      local raw=readFile('/ccsacabam/vault/data.scv')
      assert(raw:sub(1,4)=='SCP2' and raw:find('Documents',1,true),'Default drive is not plain')
      key(keys.f9); sleep(.1); assert(not contains('Enter: lock'),'Plain drive tried to lock')
      key(keys.f1); typeText('Settings'); key(keys.enter); sleep(.15)
      typeText('7'); waitFor('type YES'); typeText('YES'); key(keys.enter)
      waitFor('Create encryption password'); enter(password)
      waitFor('Confirm encryption password'); enter(password)
      waitUntil(function() return readFile('/ccsacabam/vault/data.scv'):sub(1,4)=='SCV1' end,'encrypted drive')
      waitFor('Encryption enabled.')
    end
    key(keys.f9); sleep(.1); key(keys.enter); waitFor('Unlock your personal'); enter(password)
    waitFor(' Apps    '); key(keys.f10); sleep(.1); key(keys.enter)
  end)
  term.redirect(native)
end)
test('Production PBKDF2 cost and examples stored only inside encrypted drive',function()
  local C=assert(loadfile('/ccsacabam/system/crypto.lua'))()
  local raw=readFile('/ccsacabam/vault/data.scv')
  assert(C.number(raw,37)==100000)
  assert(not raw:find('sealed-note.pist',1,true)); assert(not fs.exists('/ccsacabam/home'))
  local f=assert(fs.open('/fresh-oracle.json','w')); f.write(textutils.serializeJSON({password=password})); f.close()
end)
local final={complete=true,tests=results,failures=failures,color=native.isColor(),host=_HOST}
local f=assert(fs.open('/test-results.json','w')); f.write(textutils.serializeJSON(final)); f.close(); os.shutdown()

-- Exercise setup navigation at normal and minimum terminal sizes.
local native=term.current(); local w,h=native.getSize(); local observed=window.create(native,1,1,w,h,false)
local setup=assert(loadfile('/src/tools/setup.lua'))(); local results,failures={},0
local package={files={['test.lua']={data='-- fixture'}}}; local options,calls
local function test(name,fn)
  local ok,err=pcall(fn); term.redirect(native)
  if not ok then failures=failures+1 end
  results[#results+1]={name=name,ok=ok,error=not ok and tostring(err) or nil}
end
local function contains(value)
  for y=1,h do if observed.getLine(y):find(value,1,true) then return true end end
end
local function waitFor(value)
  local deadline=os.clock()+10
  while not contains(value) do assert(os.clock()<deadline,'Timed out waiting for '..value); sleep(.05) end
end
local function key(k) os.queueEvent('key',k,false); os.queueEvent('key_up',k) end
local function enter(value) os.queueEvent('paste',value); key(keys.enter) end
local function run(controller,install)
  calls=0; options=nil; term.redirect(observed)
  local value
  parallel.waitForAll(function()
    value=setup.run(package,{target='/setup-fixture',install=function(_,opts)
      calls=calls+1; options={mode=opts.mode,encrypt=opts.encrypt,password=opts.password,initialize=opts.initialize}
      if install then install(opts) end
      opts.progress('Installing files',1,1,'test.lua')
      return {backup='/backup'}
    end})
  end,controller)
  term.redirect(native); return value
end
test('F5 cancels setup before any installation',function()
  assert(not run(function() waitFor('Welcome'); key(keys.f5) end)); assert(calls==0)
end)
test('Default plain setup, Back navigation, and retry after an error',function()
  assert(run(function()
    waitFor('Welcome')
    if native.isColor() then os.queueEvent('mouse_click',1,w-5,h-2) else key(keys.enter) end
    waitFor('Display'); key(keys.left); waitFor('> Back <'); key(keys.right); waitFor('> Next <')
    key(keys.enter); waitFor('Privacy'); key(keys.backspace)
    waitFor('Display'); key(keys.enter); waitFor('Privacy'); key(keys.enter)
    waitFor('Ready to install'); key(keys.pageDown); key(keys.enter)
    waitFor('Installation stopp'); key(keys.enter)
    waitFor('Ready to install'); key(keys.enter)
    waitFor('Installation comp'); key(keys.enter)
  end,function() if calls==1 then error('Injected disk error') end end))
  assert(calls==2 and options.encrypt==false and options.password=='')
end)
test('Encryption validates masked password and confirmation on a small screen',function()
  assert(run(function()
    waitFor('Welcome'); key(keys.enter); waitFor('Display'); key(keys.enter)
    waitFor('Privacy'); key(keys.down); key(keys.enter); waitFor('Password')
    enter('short'); enter('short'); waitFor('Use at least 12')
    key(keys.up); enter(' password'); enter(' different'); waitFor('Passwords do not')
    key(keys.up)
    for _=1,30 do key(keys.backspace) end
    enter('setup test passphrase')
    for _=1,30 do key(keys.backspace) end
    os.queueEvent('paste','setup test passphrase'); sleep(.1)
    assert(not contains('setup test passphrase'),'Password visible on screen')
    local x,y=observed.getCursorPos(); assert(y<h-2 and x>=4,'Password cursor not in input field')
    key(keys.enter); waitFor('Ready to install'); key(keys.enter)
    waitFor('Installation comp'); key(keys.enter)
  end))
  assert(options.encrypt and options.password=='setup test passphrase' and options.initialize)
end)
local f=assert(fs.open('/test-results.json','w'))
f.write(textutils.serializeJSON({complete=true,tests=results,failures=failures,color=native.isColor(),host=_HOST})); f.close(); os.shutdown()

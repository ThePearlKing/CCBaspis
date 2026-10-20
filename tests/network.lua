local tests,failures={},0
local hostID=os.getComputerID()==0 and 1 or 0
local domain=hostID==0 and 'eater.com' or 'test.cc'
local function test(name,fn)
  local ok,err=pcall(fn); if not ok then failures=failures+1 end
  tests[#tests+1]={name=name,ok=ok,error=not ok and tostring(err) or nil}
  local h=assert(fs.open('/test-results.json','w')); h.write(textutils.serializeJSON({complete=false,tests=tests,failures=failures})); h.close()
end
local E=assert(loadfile('/ccsacabam/system/europa.lua'))()
test('Two computers connect through emulated modems',function()
  assert(periphemu.create('left','modem',734291)); assert(E.open())
  if hostID==1 then assert(periphemu.create('1','computer')); peripheral.call('1','turnOn') end
  local deadline=os.clock()+30; local id
  repeat id=rednet.lookup(E.protocol,domain); if not id then sleep(.25) end until id or os.clock()>deadline
  assert(id==hostID,'Host did not publish '..domain)
end)
test('Europa resolves a domain and fetches a Cashew page',function()
  local response,why=E.fetch('europa://'..domain); assert(response,why)
  assert(response.status==200 and response.server==hostID and response.mime=='text/cashew')
  assert(response.body:find('HELLO, EUROPA',1,true))
end)
test('Numeric computer addresses fetch linked pages',function()
  local response,why=E.fetch('europa://'..hostID..'/about.cashew'); assert(response,why)
  assert(response.status==200 and response.body:find('Cashew',1,true))
end)
test('Bare computer ID resolves the hosted homepage',function()
  local response,why=E.fetch('europa://'..hostID); assert(response,why)
  assert(response.status==200 and response.server==hostID and response.mime=='text/cashew')
  assert(response.url=='europa://'..hostID..'/index.cashew')
end)
test('Relative shell hosting retains its folder after the launching terminal changes directory',function()
  rednet.send(hostID,{kind='status'},'ccsacabam.test.control')
  local sender,status=rednet.receive('ccsacabam.test.control',5)
  assert(sender==hostID and status.folder:find('Folder: /Sites/welcome',1,true))
  local response,why=E.fetch('europa://'..hostID); assert(response,why); assert(response.status==200)
end)
test('Callisto renders the remote welcome page by domain and computer ID',function()
  local function module(name) return assert(loadfile('/ccsacabam/'..name..'.lua'))() end
  local vault=module('system/vault').new(module('system/crypto'),module('system/storage'),'/ccsacabam/vault/data.scv')
  assert(vault.create(nil,nil,nil,false))
  local env=module('system/session').environment(vault.filesystem('/ccsacabam/home'),_ENV)
  local cache={}
  local function cached(name)
    if not cache[name] then cache[name]=assert(env.loadfile('/ccsacabam/'..name..'.lua'))() end
    return cache[name]
  end
  local config=module('system/config'); local caps=config.capabilities()
  local kernel=cached('system/kernel').new({root='/ccsacabam',load=cached,configModule=config,
    config=config.normalize({mode='color'},caps),caps=caps,target=term.current(),shell=shell,isEncrypted=vault.isEncrypted})
  for _,address in ipairs({'europa://'..domain,'europa://'..hostID}) do
    local id=kernel.launch('browser',address); local timer=os.startTimer(15)
    while true do
      local p=assert(kernel.get(id)); assert(p.state=='running',p.error)
      if p.title=='Callisto - Your first site' then
        local found=false
        for y=1,p.h-2 do if p.win.getLine(y):find('HELLO, EUROPA',1,true) then found=true end end
        assert(found,'Remote page heading was not rendered'); break
      end
      local event={os.pullEventRaw()}
      assert(not (event[1]=='timer' and event[2]==timer),'Browser did not load '..address..': '..p.title)
      kernel.step(event)
    end
    os.cancelTimer(timer); kernel.remove(id)
  end
  vault.lock()
end)
test('Missing pages return 404 over a real modem',function()
  local response,why=E.fetch('europa://'..hostID..'/missing.cashew'); assert(response,why); assert(response.status==404)
  assert(response.body:find('/missing.cashew',1,true),'Missing path was not identified')
  rednet.send(hostID,{kind='status'},'ccsacabam.test.control')
  local sender,status=rednet.receive('ccsacabam.test.control',5)
  assert(sender==hostID and status.request:find('404 /missing.cashew',1,true),'Jupiter did not show the failed request')
end)
test('Jupiter rejects a raw traversal request',function()
  rednet.send(hostID,{kind='request',id='traversal',path='/../.settings'},E.protocol)
  local deadline=os.clock()+5; local reply
  repeat
    local sender,packet=rednet.receive(E.protocol,1)
    if sender==hostID and type(packet)=='table' and packet.id=='traversal' then reply=packet end
  until reply or os.clock()>deadline
  assert(reply and reply.status==400)
end)
test('Unmodified Chat+ runs beside Jupiter and accepts a chat client',function()
  local deadline=os.clock()+15; local id
  repeat id=rednet.lookup('chat','test-room'); if not id then sleep(.25) end until id or os.clock()>deadline
  assert(id==hostID,'Chat+ room was not hosted')
  -- Chat+ advertises its two protocols in sequence. Wait for both before
  -- logging in, rather than sending during its second hostname lookup.
  repeat id=rednet.lookup('chatplus','test-room'); if not id then sleep(.25) end until id or os.clock()>deadline
  assert(id==hostID,'Chat+ was not ready')
  rednet.send(hostID,{sType='login',nUserID=24680,sUsername='Tester',bChatPlus=true},'chat')
  local deadline=os.clock()+5; local joined=false
  repeat
    local sender,message=rednet.receive('chat',1)
    if sender==hostID and type(message)=='table' then
      if message.sType=='text' and message.sText:find('Tester has joined',1,true) then joined=true end
      if message.sType=='ping to client' then rednet.send(hostID,{sType='pong to server',nUserID=24680},'chat') end
    end
  until joined or os.clock()>deadline
  assert(joined,'Chat+ did not accept login')
  local response,why=E.fetch('europa://'..domain); assert(response,why); assert(response.status==200)
  rednet.send(hostID,{sType='logout',nUserID=24680},'chat')
end)
test('Hosted apps keep Chat+ settings encrypted',function()
  rednet.send(hostID,{kind='status'},'ccsacabam.test.control')
  local sender,status=rednet.receive('ccsacabam.test.control',5)
  assert(sender==hostID and status.server=='running' and status.chat=='running')
  assert(status.private and status.encrypted,'Chat+ settings were not present and encrypted: '..tostring(status.terminal))
end)
test('Jupiter flags a missing homepage; restoring it fixes both addresses without restart',function()
  rednet.send(hostID,'hide-home','ccsacabam.test.control')
  local sender,status=rednet.receive('ccsacabam.test.control',5)
  assert(sender==hostID and status.home:find('MISSING index.cashew',1,true))
  for _,address in ipairs({'europa://'..domain,'europa://'..hostID}) do
    local response,why=E.fetch(address); assert(response,why)
    assert(response.status==404 and response.body:find('/index.cashew',1,true))
  end
  rednet.send(hostID,'restore-home','ccsacabam.test.control')
  sender,status=rednet.receive('ccsacabam.test.control',5)
  assert(sender==hostID and status.home:find('ready',1,true))
  local response,why=E.fetch('europa://'..domain); assert(response,why); assert(response.status==200)
end)
test('Closing Jupiter unregisters its domain',function()
  rednet.send(hostID,'close-server','ccsacabam.test.control')
  local sender,message=rednet.receive('ccsacabam.test.control',5); assert(sender==hostID and message=='closed')
  assert(not rednet.lookup(E.protocol,domain))
end)
rednet.send(hostID,'stop','ccsacabam.test.control')
local h=assert(fs.open('/test-results.json','w')); h.write(textutils.serializeJSON({complete=true,tests=tests,failures=failures,color=term.isColor(),host=_HOST})); h.close()
os.shutdown()

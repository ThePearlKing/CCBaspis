local tests,failures={},0
local function test(name,fn)
  local ok,err=pcall(fn); if not ok then failures=failures+1 end
  tests[#tests+1]={name=name,ok=ok,error=not ok and tostring(err) or nil}
  local h=assert(fs.open('/test-results.json','w')); h.write(textutils.serializeJSON({complete=false,tests=tests,failures=failures})); h.close()
end
local E=assert(loadfile('/src/system/europa.lua'))()
test('Two computers connect through emulated modems',function()
  assert(periphemu.create('left','modem',734291)); assert(E.open())
  assert(periphemu.create('1','computer')); peripheral.call('1','turnOn')
  local deadline=os.clock()+30; local id
  repeat id=rednet.lookup(E.protocol,'test.cc'); if not id then sleep(.25) end until id or os.clock()>deadline
  assert(id==1,'Second computer did not host test.cc')
end)
test('Europa resolves a domain and fetches a Cashew page',function()
  local response,why=E.fetch('europa://test.cc/'); assert(response,why)
  assert(response.status==200 and response.server==1 and response.mime=='text/cashew')
  assert(response.body:find('HELLO, EUROPA',1,true))
end)
test('Numeric computer addresses fetch linked pages',function()
  local response,why=E.fetch('europa://1/about.cashew'); assert(response,why)
  assert(response.status==200 and response.body:find('Cashew',1,true))
end)
test('Missing pages return 404 over a real modem',function()
  local response,why=E.fetch('europa://1/missing.cashew'); assert(response,why); assert(response.status==404)
end)
test('Jupiter rejects a raw traversal request',function()
  rednet.send(1,{kind='request',id='traversal',path='/../.settings'},E.protocol)
  local deadline=os.clock()+5; local reply
  repeat
    local sender,packet=rednet.receive(E.protocol,1)
    if sender==1 and type(packet)=='table' and packet.id=='traversal' then reply=packet end
  until reply or os.clock()>deadline
  assert(reply and reply.status==400)
end)
test('Unmodified Chat+ runs beside Jupiter and accepts a chat client',function()
  local deadline=os.clock()+15; local id
  repeat id=rednet.lookup('chat','test-room'); if not id then sleep(.25) end until id or os.clock()>deadline
  assert(id==1,'Chat+ room was not hosted')
  -- Chat+ advertises its two protocols in sequence. Wait for both before
  -- logging in, rather than sending during its second hostname lookup.
  repeat id=rednet.lookup('chatplus','test-room'); if not id then sleep(.25) end until id or os.clock()>deadline
  assert(id==1,'Chat+ was not ready')
  rednet.send(1,{sType='login',nUserID=24680,sUsername='Tester',bChatPlus=true},'chat')
  local deadline=os.clock()+5; local joined=false
  repeat
    local sender,message=rednet.receive('chat',1)
    if sender==1 and type(message)=='table' then
      if message.sType=='text' and message.sText:find('Tester has joined',1,true) then joined=true end
      if message.sType=='ping to client' then rednet.send(1,{sType='pong to server',nUserID=24680},'chat') end
    end
  until joined or os.clock()>deadline
  assert(joined,'Chat+ did not accept login')
  local response,why=E.fetch('europa://test.cc/'); assert(response,why); assert(response.status==200)
  rednet.send(1,{sType='logout',nUserID=24680},'chat')
end)
test('Hosted apps keep Chat+ settings encrypted',function()
  rednet.send(1,{kind='status'},'ccsacabam.test.control')
  local sender,status=rednet.receive('ccsacabam.test.control',5)
  assert(sender==1 and status.server=='running' and status.chat=='running')
  assert(status.private and status.encrypted,'Chat+ settings were not present and encrypted: '..tostring(status.terminal))
end)
test('Closing Jupiter unregisters its domain',function()
  rednet.send(1,'close-server','ccsacabam.test.control')
  local sender,message=rednet.receive('ccsacabam.test.control',5); assert(sender==1 and message=='closed')
  assert(not rednet.lookup(E.protocol,'test.cc'))
end)
rednet.send(1,'stop','ccsacabam.test.control')
local h=assert(fs.open('/test-results.json','w')); h.write(textutils.serializeJSON({complete=true,tests=tests,failures=failures,color=term.isColor(),host=_HOST})); h.close()
os.shutdown()

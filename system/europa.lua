-- Europa: small request/response networking over normal ComputerCraft Rednet.
local E={protocol='ccsacabam.europa.v1',maxBody=32768}
local hosts={}; local serial=0
function E.open()
  if not peripheral or not rednet then return nil,'Rednet is unavailable.' end
  local found=false
  for _,name in ipairs(peripheral.getNames()) do
    if (peripheral.hasType and peripheral.hasType(name,'modem')) or peripheral.getType(name)=='modem' then
      if not rednet.isOpen(name) then rednet.open(name) end
      found=true
    end
  end
  return found or nil,not found and 'Attach a modem to use Europa.' or nil
end
function E.path(path)
  assert(type(path)=='string' and #path<=256,'Invalid page path')
  path=path:match('^[^?#]*')
  path=path:gsub('%%(%x%x)',function(n) return string.char(tonumber(n,16)) end)
  assert(not path:find('[%%%c\\]'),'Invalid path encoding')
  for part in path:gmatch('[^/]+') do assert(part~='..' and part~='.' and part:sub(1,1)~='.', 'Private or parent paths cannot be served') end
  if path=='' or path:sub(-1)=='/' then path=path..'index.cashew' end
  return '/'..fs.combine('',path)
end
function E.address(address,base)
  assert(type(address)=='string' and #address<=512,'Invalid address')
  address=address:match('^%s*(.-)%s*$')
  if address:sub(1,7)=='file://' then return {localFile=address:sub(8),url=address} end
  if address:sub(1,9)=='europa://' then address=address:sub(10)
  elseif address:find('://',1,true) then error('Use europa://domain/path or europa://123/path',0)
  elseif base and not address:match('^[%w.-]+/') and not address:match('^[%w.-]+$') then
    local original=E.address(base)
    if address:sub(1,1)=='/' then return E.address('europa://'..original.host..address) end
    return E.address('europa://'..original.host..'/'..fs.combine(fs.getDir(original.path),address))
  end
  local host,path=address:match('^([^/]+)(/.*)$')
  if not host then host,path=address,'/' end
  assert(host:match('^[%w.-]+$') and #host<=63,'Invalid domain or computer ID')
  host=host:lower(); path=E.path(path)
  local id=tonumber(host)
  if id then assert(id>=0 and id%1==0 and id<2147483648,'Invalid computer ID') end
  return {host=host,id=id,path=path,url='europa://'..host..path}
end
function E.relative(link,current)
  if link:find('://',1,true) then return link end
  if not current or current=='about:home' then return 'europa://'..link end
  local parsed=E.address(current)
  if parsed.localFile then return 'file://'..fs.combine(fs.getDir(parsed.localFile),link) end
  return 'europa://'..parsed.host..(link:sub(1,1)=='/' and link or '/'..fs.combine(fs.getDir(parsed.path),link))
end
function E.serve(root,path)
  local ok,normalized=pcall(E.path,path)
  if not ok then return {status=400,body='Invalid page path.',mime='text/plain'} end
  local file=fs.combine(root,normalized:sub(2))
  if not fs.exists(file) or fs.isDir(file) then
    return {status=404,body='Page not found: '..normalized..'\nThe host has no file at this path in its published folder.',mime='text/plain'}
  end
  local mime=file:match('%.cashew$') and 'text/cashew' or file:match('%.pist$') and 'text/pistachio'
    or file:match('%.peanut$') and 'application/peanut' or file:match('%.txt$') and 'text/plain'
  if not mime then return {status=403,body='This file type is not published.',mime='text/plain'} end
  if fs.getSize(file)>E.maxBody then return {status=413,body='Page exceeds 32 KiB.',mime='text/plain'} end
  local h,err=fs.open(file,'r'); if not h then return {status=500,body='Cannot read page.',mime='text/plain'} end
  local body=h.readAll(); h.close()
  return {status=200,body=body,mime=mime}
end
function E.start(domain,root)
  domain=domain:lower()
  assert(domain:match('^[a-z0-9][a-z0-9.-]*$') and #domain<=63 and not tonumber(domain),'Choose a domain like workshop.cc')
  assert(fs.isDir(root),'Site folder does not exist')
  assert(not next(hosts),'A Jupiter server is already running on this computer')
  assert(E.open())
  rednet.host(E.protocol,domain)
  local host={domain=domain,root=root,requests=0,clients={},active=true}
  hosts[domain]=host
  function host.stop()
    if not host.active then return end
    host.active=false; hosts[domain]=nil; rednet.unhost(E.protocol)
  end
  function host.receive(sender,packet,protocol)
    if protocol~=E.protocol or type(packet)~='table' or packet.kind~='request' then return end
    if type(packet.id)~='string' or #packet.id>80 or type(packet.path)~='string' or #packet.path>256 then return end
    local now=math.floor(os.clock()); local client=host.clients[sender]
    if not client or client.time~=now then client={time=now,count=0}; host.clients[sender]=client end
    client.count=client.count+1; if client.count>10 then return end
    local reply=E.serve(root,packet.path); reply.kind='response'; reply.id=packet.id
    host.lastPath=packet.path:gsub('[%c]','?'); host.lastStatus=reply.status
    rednet.send(sender,reply,E.protocol); host.requests=host.requests+1
    -- Bound the rate-limit cache even on a busy public network.
    for id,entry in pairs(host.clients) do if entry.time<now-5 then host.clients[id]=nil end end
  end
  return host
end
function E.fetch(address)
  local parsed=E.address(address)
  if parsed.localFile then
    local file=parsed.localFile
    if not fs.exists(file) or fs.isDir(file) then return nil,'Local page not found.' end
    if fs.getSize(file)>E.maxBody then return nil,'Page exceeds 32 KiB.' end
    local h,err=fs.open(file,'r'); if not h then return nil,err end
    local body=h.readAll(); h.close()
    return {status=200,body=body,mime=file:match('%.pist$') and 'text/pistachio' or file:match('%.cashew$') and 'text/cashew' or 'text/plain',url=parsed.url}
  end
  local localHost=hosts[parsed.host]
  if parsed.id==os.getComputerID() then for _,h in pairs(hosts) do localHost=h end end
  if localHost then local reply=E.serve(localHost.root,parsed.path); reply.url=parsed.url; return reply end
  local opened,why=E.open(); if not opened then return nil,why end
  local id=parsed.id or rednet.lookup(E.protocol,parsed.host)
  if not id then return nil,'Domain not found. The host must be online and in modem range.' end
  serial=serial+1
  local request=tostring(os.getComputerID())..':'..tostring(os.clock())..':'..serial
  if not rednet.send(id,{kind='request',id=request,path=parsed.path},E.protocol) then return nil,'Modem is not open.' end
  local timer=os.startTimer(5)
  while true do
    local e,a,b,c=os.pullEventRaw()
    if e=='sacabam_close' or e=='terminate' then os.cancelTimer(timer); return nil,'Cancelled.',true
    elseif e=='timer' and a==timer then return nil,'Server did not respond within five seconds.'
    elseif e=='rednet_message' and a==id and c==E.protocol and type(b)=='table' and b.kind=='response' and b.id==request then
      if type(b.body)=='string' and #b.body<=E.maxBody and type(b.status)=='number'
        and (b.mime=='text/cashew' or b.mime=='text/pistachio' or b.mime=='text/plain' or b.mime=='application/peanut') then
        os.cancelTimer(timer); return {status=b.status,body=b.body,mime=b.mime,url=parsed.url,server=id}
      end
    end
  end
end
return E

-- A real second emulator computer, running the normal CCSacabam scheduler.
local physical=fs
local function mod(name) return assert(loadfile('/ccsacabam/'..name..'.lua'))() end
assert(periphemu.create('left','modem',734291))
local V=mod('system/vault'); V.iterations=10000
local vault=V.new(mod('system/crypto'),mod('system/storage'),'/ccsacabam/vault/data.scv')
assert(vault.create('network fixture password','network test',mod('system/login').progress,true))
local vfs=vault.filesystem('/ccsacabam/home')
vfs.copy('/ccsacabam/sites/welcome','/Sites/welcome')
vfs.copy('/ccsacabam/chatplus.lua','/Programs/chatplus.lua')
local env=mod('system/session').environment(vfs,_ENV); local cache={}
local function cached(name)
  if not cache[name] then cache[name]=assert(env.loadfile('/ccsacabam/'..name..'.lua'))() end
  return cache[name]
end
local Config=mod('system/config'); local caps=Config.capabilities()
local kernel=cached('system/kernel').new({root='/ccsacabam',load=cached,configModule=Config,
  config=Config.normalize({mode='color',welcome=false},caps),caps=caps,target=term.current(),shell=shell,
  isEncrypted=vault.isEncrypted})
local server=kernel.launch('server','test.cc','/Sites/welcome')
kernel.step({'key',keys.enter,false}); kernel.step({'key_up',keys.enter})
local chat=kernel.launch('terminal')
for c in ('chatplus host test-room'):gmatch('.') do kernel.step({'char',c}) end
kernel.step({'key',keys.enter,false}); kernel.step({'key_up',keys.enter})
parallel.waitForAny(function() kernel.run() end,function()
  while true do
    local sender,message,protocol=rednet.receive('ccsacabam.test.control')
    if type(message)=='table' and message.kind=='status' then
      local h=physical.open(vault.path,'rb'); local raw=h.readAll(); h.close()
      local lines={}; local p=kernel.get(chat)
      for y=1,p.h-2 do lines[#lines+1]=p.win.getLine(y) end
      rednet.send(sender,{server=kernel.get(server).state,chat=kernel.get(chat).state,
        terminal=table.concat(lines,'\n'),
        private=vfs.exists('/.chatplus') and not physical.exists('/.chatplus'),
        encrypted=raw:sub(1,4)=='SCV1' and not raw:find('server.cfg',1,true)},protocol)
    elseif message=='close-server' then kernel.requestClose(kernel.get(server)); rednet.send(sender,'closed',protocol)
    elseif message=='stop' then return end
  end
end)
vault.lock(); os.shutdown()

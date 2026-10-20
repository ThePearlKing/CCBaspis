-- A real second emulator computer, running the normal CCSacabam scheduler.
local physical=fs
local domain=os.getComputerID()==0 and 'eater.com' or 'test.cc'
local function mod(name) return assert(loadfile('/ccsacabam/'..name..'.lua'))() end
assert(periphemu.create('left','modem',734291))
local V=mod('system/vault'); V.iterations=10000
local vault=V.new(mod('system/crypto'),mod('system/storage'),'/ccsacabam/vault/data.scv')
assert(vault.create('network fixture password','network test',mod('system/login').progress,true))
local vfs=vault.filesystem('/ccsacabam/home')
vfs.copy('/ccsacabam/sites/welcome','/Sites/welcome')
vfs.copy('/ccsacabam/chatplus.lua','/Programs/chatplus.lua')
vfs.copy('/ccsacabam/examples/europa.lua','/Programs/europa.lua')
local env=mod('system/session').environment(vfs,_ENV); local cache={}
local function cached(name)
  if not cache[name] then cache[name]=assert(env.loadfile('/ccsacabam/'..name..'.lua'))() end
  return cache[name]
end
local Config=mod('system/config'); local caps=Config.capabilities()
local kernel=cached('system/kernel').new({root='/ccsacabam',load=cached,configModule=Config,
  config=Config.normalize({mode='color',welcome=false},caps),caps=caps,target=term.current(),shell=shell,
  isEncrypted=vault.isEncrypted})
env.ccsacabam={launch=kernel.launch,forShell=kernel.forShell}
local function command(value)
  kernel.step({'paste',value}); kernel.step({'key',keys.enter,false}); kernel.step({'key_up',keys.enter})
end
local launcher=kernel.launch('terminal')
vfs.makeDir('/Sites/welcome/nested')
command(os.getComputerID()==0 and 'cd /Sites/welcome' or 'cd /Sites/welcome/nested')
command('europa host '..domain..(os.getComputerID()==0 and ' .' or ' ..'))
local server=kernel.focus
assert(kernel.get(server).app=='server','Shell did not launch Jupiter')
kernel.focusTask(launcher); command('cd /Pictures'); kernel.focusTask(server)
kernel.step({'key',keys.enter,false}); kernel.step({'key_up',keys.enter})
local chat=kernel.launch('terminal')
for c in ('chatplus host test-room'):gmatch('.') do kernel.step({'char',c}) end
kernel.step({'key',keys.enter,false}); kernel.step({'key_up',keys.enter})
if os.getComputerID()==0 then assert(periphemu.create('1','computer')); peripheral.call('1','turnOn') end
parallel.waitForAny(function() kernel.run() end,function()
  while true do
    local sender,message,protocol=rednet.receive('ccsacabam.test.control')
    if type(message)=='table' and message.kind=='status' then
      local h=physical.open(vault.path,'rb'); local raw=h.readAll(); h.close()
      local lines={}; local p=kernel.get(chat)
      for y=1,p.h-2 do lines[#lines+1]=p.win.getLine(y) end
      rednet.send(sender,{server=kernel.get(server).state,chat=kernel.get(chat).state,
        home=kernel.get(server).win.getLine(10),request=kernel.get(server).win.getLine(11),
        folder=kernel.get(server).win.getLine(5),
        terminal=table.concat(lines,'\n'),
        private=vfs.exists('/.chatplus') and not physical.exists('/.chatplus'),
        encrypted=raw:sub(1,4)=='SCV1' and not raw:find('server.cfg',1,true)},protocol)
    elseif message=='hide-home' or message=='restore-home' then
      local index,backup='/Sites/welcome/index.cashew','/Sites/welcome/index.saved'
      if message=='hide-home' then vfs.move(index,backup) else vfs.move(backup,index) end
      kernel.step({'sacabam_theme',server})
      rednet.send(sender,{home=kernel.get(server).win.getLine(10)},protocol)
    elseif message=='close-server' then kernel.requestClose(kernel.get(server)); rednet.send(sender,'closed',protocol)
    elseif message=='stop' then return end
  end
end)
vault.lock(); os.shutdown()

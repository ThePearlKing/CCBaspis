-- Entry point: login, encrypted personal drive, then the desktop session.
local args={...}
local root=fs.getDir(shell.getRunningProgram())
local original=term.current()
local originalDir=shell.dir()
local physicalEnv=_ENV
local activeVault
local function main()
  local function physicalModule(name) return assert(loadfile(fs.combine(root,name..".lua"),"t",physicalEnv))() end
  assert(window and window.create and term.blit and bit32 and fs.exists('/rom/modules/main/cc/require.lua'),"CCSacabam needs modern CC: Tweaked with blit, window, bit32 and cc.require.")
  local configModule=physicalModule("system/config")
  local storage=physicalModule("system/storage")
  local caps=configModule.capabilities(original)
  assert(caps.width>=20 and caps.height>=10,"Display must be at least 20 columns by 10 rows.")
  fs.makeDir(fs.combine(root,"vault"))
  fs.makeDir(fs.combine(root,"config"))
  local vault=physicalModule("system/vault").new(physicalModule("system/crypto"),storage,fs.combine(root,"vault/data.scv"))
  activeVault=vault
  vault.recoverPending()
  local login=physicalModule("system/login")
  local session=physicalModule("system/session")
  local defaults=storage.load(fs.combine(root,"config/display.tbl"),{})
  while login.unlock(vault,defaults) do
    local function desktop()
      local env=session.environment(vault.filesystem(fs.combine(root,"home")),physicalEnv)
      local cache={}
      local function module(name)
        if not cache[name] then cache[name]=assert(env.loadfile(fs.combine(root,name..".lua")))() end
        return cache[name]
      end
      local config=configModule.normalize(module("system/storage").load(fs.combine(root,"home/.system/settings.tbl"),defaults),caps)
      if args[1]=="--basic" then config.mode="basic" end
      if not env.fs.exists(fs.combine(root,"home/.examples-installed")) then
        for _,name in ipairs(fs.list(fs.combine(root,"examples"))) do
          local destination=fs.combine(root,"home/Programs/"..name)
          if not env.fs.exists(destination) then env.fs.copy(fs.combine(root,"examples/"..name),destination) end
        end
        local chat=fs.combine(root,"home/Programs/chatplus.lua")
        if not env.fs.exists(chat) then env.fs.copy(fs.combine(root,"chatplus.lua"),chat) end
        if not env.fs.exists("/Sites/welcome") then env.fs.copy(fs.combine(root,"sites/welcome"),"/Sites/welcome") end
        assert(module("system/storage").write(fs.combine(root,"home/.examples-installed"),"1"))
      end
      module('system/programs').update(root,module('system/storage'),module('system/crypto'))
      local ctx={root=root,load=module,config=config,configModule=configModule,caps=caps,target=original,shell=shell,
        password=login.password,isEncrypted=vault.isEncrypted,
        setEncryption=function(enabled,password,entropy) return vault.setEncryption(enabled,password,entropy,login.progress) end,
        cryptoProgress=login.progress,
        changePassword=function(password,entropy) return vault.changePassword(password,entropy,login.progress) end}
      local kernel=module("system/kernel").new(ctx)
      env.ccsacabam={launch=kernel.launch,forShell=kernel.forShell,version=configModule.version}
      if config.welcome then kernel.launch("help") end
      return kernel.run()
    end
    local ok,action=pcall(desktop)
    vault.lock()
    if collectgarbage then pcall(collectgarbage,"collect") end
    term.redirect(original)
    if not ok then error(action,0) end
    if action=="reboot" then os.reboot() elseif action=="shutdown" then os.shutdown()
    elseif action~="lock" then return end
  end
end
local ok,err=pcall(main)
if activeVault then activeVault.lock(); activeVault=nil end
term.redirect(original)
term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.setCursorBlink(false)
term.clear(); term.setCursorPos(1,1)
if fs.exists(originalDir) and fs.isDir(originalDir) then shell.setDir(originalDir) end
if not ok then
  print("CCSacabam could not continue:")
  printError(tostring(err))
  print("The personal drive is closed.")
  print("Try: "..fs.combine(root,"boot.lua").." --basic")
  return false
end
print("CCSacabam closed. Personal drive signed out.")
return true

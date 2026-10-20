-- A normal CraftOS program environment routed through the encrypted filesystem.
-- This is compatibility plumbing, not a security sandbox for untrusted Lua.
local M={}
local hostLoad=load
function M.environment(vfs,parent)
  local env={fs=vfs}
  setmetatable(env,{__index=parent})
  env._G=env
  env.load=function(chunk,name,mode,target) return hostLoad(chunk,name,mode or "t",target or env) end
  env.loadstring=function(chunk,name) return env.load(chunk,name) end
  env.loadfile=function(path,mode,target)
    if type(mode)=="table" then target,mode=mode,nil end
    local h,err=vfs.open(path,"r"); if not h then return nil,err end
    local code=h.readAll(); h.close()
    return env.load(code,"@/"..path,mode or "t",target or env)
  end
  env.dofile=function(path) return assert(env.loadfile(path))() end
  env.os={}; for k,v in pairs(parent.os) do env.os[k]=v end
  env.os.run=function(target,path,...)
    setmetatable(target,{__index=env})
    target._G=env
    local fn,err=env.loadfile(path,"t",target)
    if not fn then printError(err); return false end
    local ok,result=pcall(fn,...)
    if not ok then printError(result) end
    return ok
  end
  env.os.loadAPI=function(path)
    local target={}; setmetatable(target,{__index=env})
    local fn=env.loadfile(path,"t",target)
    if not fn then return false end
    local ok=pcall(fn)
    if ok then env[vfs.getName(path):gsub("%.lua$","")]=target end
    return ok
  end
  env.os.unloadAPI=function(name) env[name]=nil end
  -- These ROM APIs close over fs: reload them so they use the encrypted drive.
  for _,name in ipairs({"io","settings","paintutils","help"}) do
    local apiEnv=setmetatable({},{__index=env})
    local chunk=env.loadfile("/rom/apis/"..name..".lua","t",apiEnv)
    if chunk then chunk(); env[name]=apiEnv end
  end
  for _,name in ipairs(parent.settings.getNames()) do
    local value=parent.settings.get(name)
    if value~=nil then env.settings.set(name,value) end
  end
  env.settings.load("/.settings")
  local make=env.dofile("/rom/modules/main/cc/require.lua").make
  env.require,env.package=make(env,"/")
  return env
end
return M

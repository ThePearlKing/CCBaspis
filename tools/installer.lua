-- Shared installer engine, embedded verbatim in the standalone distribution.
local I={target='/ccsacabam',stage='/ccsacabam-install-stage'}
local function readFile(path)
  local h,err=fs.open(path,'r'); assert(h,err); local data=h.readAll(); h.close(); return data
end
local function writeFile(path,data)
  fs.makeDir(fs.getDir(path)); local h,err=fs.open(path,'w'); assert(h,err)
  local ok,why=pcall(h.write,data); h.close(); assert(ok,why)
  assert(readFile(path)==data,'Write verification failed: '..path)
end
local function size(path)
  if not fs.exists(path) then return 0 end
  if not fs.isDir(path) then return fs.getSize(path) end
  local n=0; for _,name in ipairs(fs.list(path)) do n=n+size(fs.combine(path,name)) end; return n
end
function I.validate(package)
  assert(type(package)=='table' and type(package.files)=='table','Invalid package')
  local cryptoFile=assert(package.files['system/crypto.lua'],'Missing crypto module')
  local crypto=assert(load(cryptoFile.data,'@crypto','t',_ENV))()
  local total=0
  for path,file in pairs(package.files) do
    assert(type(path)=='string' and path~='' and fs.combine('',path)==path and path:sub(1,1)~='/' and not path:find('%.%.'),'Invalid package path')
    assert(type(file.data)=='string' and crypto.hex(crypto.sha256(file.data))==file.sha256,'Package checksum mismatch: '..path)
    if path:match('%.lua$') then assert(load(file.data,'@'..path,'t',_ENV)) end
    total=total+#file.data
  end
  for _,name in ipairs({'boot.lua','system/kernel.lua','system/vault.lua','system/session.lua','apps/terminal.lua','uninstall.lua','chatplus.lua'}) do
    assert(package.files[name],'Incomplete package: '..name)
  end
  return total
end
function I.install(package,options)
  options=options or {}; local total=I.validate(package)
  local target,stage=I.target,I.stage
  assert(not fs.isReadOnly('/'),'Root filesystem is read-only')
  assert(not fs.exists(stage),'An interrupted install exists at '..stage..'. Inspect it before trying again.')
  local exists=fs.exists(target)
  assert(not exists or (fs.isDir(target) and fs.exists(target..'/.ccsacabam')),'Existing /ccsacabam is not an owned installation; choose a different source folder.')
  local oldInfo=exists and fs.exists(target..'/config/install.tbl') and textutils.unserialize(readFile(target..'/config/install.tbl')) or {}
  local free=fs.getFreeSpace('/')
  assert(type(free)~='number' or free>=total+size(target)+8192,'Not enough space for a staged install and backup')
  local n=1; local backup
  repeat backup='/ccsacabam-backups/install-'..n; n=n+1 until not fs.exists(backup)
  local startupRestore=oldInfo and oldInfo.startupRestore or {}
  local movedStartup={}; local movedOld,movedNew,wroteStartup=false,false,false
  local loader='-- CCSacabam managed startup\nif not shell.run("/ccsacabam/boot.lua") then print("CCSacabam failed; CraftOS remains available.") end\n'
  local ok,err=pcall(function()
    fs.makeDir(backup)
    if exists then fs.copy(target,stage) else fs.makeDir(stage) end
    for _,dir in ipairs({'system','apps','examples','sites'}) do
      if fs.exists(stage..'/'..dir) then fs.delete(stage..'/'..dir) end
    end
    for path,file in pairs(package.files) do
      local dest=fs.combine(stage,path)
      if fs.exists(dest) then fs.delete(dest) end
      writeFile(dest,file.data)
    end
    writeFile(stage..'/.ccsacabam',package.version or '1.0.0')
    local mode=options.mode or (term.isColor() and 'color' or 'basic')
    if not term.isColor() then mode='basic' end
    assert(mode=='basic' or mode=='color' or mode=='render','Unknown display mode')
    writeFile(stage..'/config/display.tbl',textutils.serialize({mode=mode,welcome=true,encrypt=options.encrypt==true}))
    for _,path in ipairs({'/startup.lua','/startup'}) do
      if fs.exists(path) and not startupRestore[path] and not (path=='/startup.lua' and not fs.isDir(path) and readFile(path):find('CCSacabam managed startup',1,true)) then
        startupRestore[path]=backup..'/'..fs.getName(path)
      end
    end
    writeFile(stage..'/config/install.tbl',textutils.serialize({version=package.version,backup=backup,startupRestore=startupRestore}))
    if exists then fs.move(target,backup..'/previous'); movedOld=true end
    fs.move(stage,target); movedNew=true
    for _,path in ipairs({'/startup.lua','/startup'}) do
      if fs.exists(path) then
        local dest=backup..'/'..fs.getName(path); fs.move(path,dest); movedStartup[#movedStartup+1]={from=path,to=dest}
      end
    end
    -- Mark before writing so a partially written loader is also rolled back.
    wroteStartup=true; writeFile('/startup.lua',loader)
  end)
  if not ok then
    local rollbackErrors={}
    local function undo(fn) local good,why=pcall(fn); if not good then rollbackErrors[#rollbackErrors+1]=tostring(why) end end
    if wroteStartup and fs.exists('/startup.lua') then undo(function() fs.delete('/startup.lua') end) end
    for i=#movedStartup,1,-1 do local item=movedStartup[i]; undo(function() fs.move(item.to,item.from) end) end
    if movedNew and fs.exists(target) then undo(function() fs.delete(target) end) end
    if movedOld then undo(function() fs.move(backup..'/previous',target) end) end
    if fs.exists(stage) then undo(function() fs.delete(stage) end) end
    if #rollbackErrors>0 then error(tostring(err)..'\nRollback needs attention: '..table.concat(rollbackErrors,'; ')..'\nBackups: '..backup,0) end
    error(tostring(err)..'\nPrevious installation and startup restored.',0)
  end
  return {target=target,backup=backup,bytes=total}
end
function I.run(package,args)
  assert(bit32 and window and term.blit and fs.exists('/rom/modules/main/cc/require.lua'),'CCSacabam needs modern CC: Tweaked with cc.require.')
  local w,h=term.getSize(); assert(w>=20 and h>=10,'Display must be at least 20x10.')
  local mode=term.isColor() and 'color' or 'basic'; local encrypt=false
  if args and args[1]=='--yes' then mode=args[2] or mode; encrypt=args[3]=='--encrypt'
  else
    term.setBackgroundColor(colors.black); term.setTextColor(colors.white); term.clear(); term.setCursorPos(1,1)
    print('CCSacabam installer\n')
    print('Installs to /ccsacabam. Existing files are preserved.')
    print('Existing startup programs are backed up.')
    print('Create your personal drive and passphrase at first boot.\n')
    if term.isColor() then
      print('Display mode:')
      print('1 Basic: monochrome, keyboard controls')
      print('2 Color: mouse and keyboard (default)')
      print('3 Render: color + portable subpixel graphics')
      write('Choose 1, 2, or 3: '); local choice=read()
      mode=choice=='1' and 'basic' or choice=='3' and 'render' or 'color'
    else print('Basic computer detected: monochrome mode.') end
    if not fs.exists(I.target..'/vault/data.scv') then
      print('\nEncryption is OFF by default.')
      print('Fine to leave off on a private computer.')
      print('On a shared server, try encryption: it is the main security feature for saved files.')
      print('Without it, login still works, but files are readable outside CCSacabam.')
      write('Enable encryption? [y/N]: '); local choice=read():lower()
      encrypt=choice=='y' or choice=='yes'
    else print('The existing drive keeps its encryption setting.') end
    write('\nPress Enter to install, or type cancel: ')
    if read()~='' then print('Cancelled.'); return false end
  end
  print('Checking package and staging files...')
  local ok,result=pcall(I.install,package,{mode=mode,encrypt=encrypt})
  if not ok then printError(result); return false end
  print('CCSacabam installed. Backup: '..result.backup)
  print('Run /ccsacabam/boot.lua or reboot to sign in.')
  return true
end
return I

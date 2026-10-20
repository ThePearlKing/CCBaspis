-- Detach autostart without deleting the encrypted drive or installation.
local args={...}; local root=fs.getDir(shell.getRunningProgram())
local function readFile(path) local h=assert(fs.open(path,'r')); local data=h.readAll(); h.close(); return data end
local info=textutils.unserialize(readFile(fs.combine(root,'config/install.tbl'))) or {}
local loader='/startup.lua'
if fs.exists(loader) and (fs.isDir(loader) or not readFile(loader):find('CCSacabam managed startup',1,true)) then
  error('Startup was changed after installation. Restore it manually from the backup; no files changed.',0)
end
for path,backup in pairs(info.startupRestore or {}) do
  assert(fs.exists(backup),'Missing startup backup: '..backup)
  assert(path=='/startup.lua' or not fs.exists(path),'Startup destination already exists: '..path)
end
if args[1]~='--yes' then
  print('Disable CCSacabam autostart and restore previous startup?')
  print('The OS and encrypted drive will be kept. Type REMOVE to continue.')
  if read()~='REMOVE' then return end
end
local saved
if fs.exists(loader) then saved=readFile(loader); fs.delete(loader) end
local restored={}
local ok,err=pcall(function()
  for path,backup in pairs(info.startupRestore or {}) do fs.copy(backup,path); restored[#restored+1]=path end
end)
if not ok then
  for _,path in ipairs(restored) do fs.delete(path) end
  if saved then local h=assert(fs.open(loader,'w')); h.write(saved); h.close() end
  error('Could not restore startup: '..tostring(err),0)
end
print('Autostart disabled. The encrypted drive and CCSacabam files are preserved.')
print('Run '..fs.combine(root,'boot.lua')..' to open CCSacabam manually.')

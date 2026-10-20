-- Local/offline installer. Use dist/ccsacabam-installer.lua for a single file.
local args={...}; local dir=fs.getDir(shell.getRunningProgram())
local manifest=assert(loadfile(fs.combine(dir,'manifest.lua')))()
local package={version=manifest.version,files={}}
for path,hash in pairs(manifest.files) do
  local file,err=fs.open(fs.combine(dir,path),'r'); assert(file,err)
  package.files[path]={sha256=hash,data=file.readAll():gsub('\r\n','\n'):gsub('\r','\n')}; file.close()
end
local installer=assert(loadfile(fs.combine(dir,'tools/installer.lua')))()
return installer.run(package,args)

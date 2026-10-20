-- Add/refresh shipped commands after an upgrade without replacing user edits.
local M={}
local bundled={'pistachio.lua','europa.lua','pmatrix.lua','pmatrix.pist','games.lua'}
local legacy={
  ['pistachio.lua']='70badd04b0c3bdb0e7568a6afaf5e984e1fd06723ddc3e10947877940eef97f8',
  ['europa.lua']='26e0c24b08490d6cfe4cafd29179052fdc70d584b2d7cd26c8fd543dc069d815',
}
function M.update(root,storage,crypto)
  local record=fs.combine(root,'home/.system/bundled-commands.tbl')
  local previous=storage.load(record,{})
  local nextHashes={}; local changed=false
  local files={}
  for _,name in ipairs(bundled) do files[#files+1]={name,'examples/'..name,'Programs/'..name} end
  local games=fs.combine(root,'games')
  if fs.isDir(games) then
    for _,name in ipairs(fs.list(games)) do
      if not fs.isDir(fs.combine(games,name)) then files[#files+1]={'Games/'..name,'games/'..name,'Games/'..name} end
    end
  end
  for _,entry in ipairs(files) do
    local name=entry[1]
    local oldHash=legacy[name]
    local source=assert(storage.read(fs.combine(root,entry[2])))
    local hash=crypto.hex(crypto.sha256(source))
    local destination=fs.combine(root,'home/'..entry[3])
    local current=storage.read(destination)
    local currentHash=current and crypto.hex(crypto.sha256(current))
    if not fs.exists(destination) or (currentHash and (currentHash==oldHash or currentHash==previous[name])) then
      if current~=source then assert(storage.write(destination,source)) end
    end
    nextHashes[name]=hash
    if previous[name]~=hash then changed=true end
  end
  if changed then assert(storage.save(record,nextHashes)) end
end
return M

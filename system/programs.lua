-- Add/refresh shipped commands after an upgrade without replacing user edits.
local M={}
local bundled={'pistachio.lua','europa.lua','pmatrix.lua','pmatrix.pist'}
local legacy={
  ['pistachio.lua']='70badd04b0c3bdb0e7568a6afaf5e984e1fd06723ddc3e10947877940eef97f8',
  ['europa.lua']='26e0c24b08490d6cfe4cafd29179052fdc70d584b2d7cd26c8fd543dc069d815',
}
function M.update(root,storage,crypto)
  local record=fs.combine(root,'home/.system/bundled-commands.tbl')
  local previous=storage.load(record,{})
  local nextHashes={}; local changed=false
  for _,name in ipairs(bundled) do
    local oldHash=legacy[name]
    local source=assert(storage.read(fs.combine(root,'examples/'..name)))
    local hash=crypto.hex(crypto.sha256(source))
    local destination=fs.combine(root,'home/Programs/'..name)
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

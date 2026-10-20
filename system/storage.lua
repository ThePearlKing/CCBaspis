-- File writes keep the previous contents until the replacement is ready.
local M = {}
function M.read(path)
  local h, err = fs.open(path, "rb")
  if not h then return nil, err or ("Cannot read " .. path) end
  local ok, value = pcall(h.readAll)
  h.close()
  if not ok then return nil, value end
  return value or ""
end
function M.write(path, value)
  if fs.exists(path) and fs.isDir(path) then return nil,"Path is a directory: " .. path end
  if fs.isReadOnly(path) then return nil, "Read-only path: " .. path end
  local temp, backup = path .. ".sacabam-new", path .. ".sacabam-old"
  if fs.exists(temp) or fs.exists(backup) then
    return nil, "Recovery files exist beside " .. path .. "; inspect them first."
  end
  local moved = false
  local ok, err = pcall(function()
    fs.makeDir(fs.getDir(path))
    local h, why = fs.open(temp, "wb")
    assert(h, why or "Cannot create temporary file")
    local wrote, failure = pcall(h.write, value)
    h.close()
    assert(wrote, failure)
    assert(M.read(temp) == value, "Write verification failed")
    if fs.exists(path) then fs.move(path, backup); moved = true end
    fs.move(temp, path)
    if moved then fs.delete(backup) end
  end)
  if not ok then
    if moved and not fs.exists(path) and fs.exists(backup) then pcall(fs.move, backup, path) end
    if fs.exists(temp) then pcall(fs.delete, temp) end
    return nil, tostring(err)
  end
  return true
end
function M.load(path, fallback)
  local raw = M.read(path)
  if not raw then return fallback end
  local ok, result = pcall(textutils.unserialize, raw)
  if ok and type(result) == "table" then return result end
  return fallback
end
function M.save(path, value) return M.write(path, textutils.serialize(value)) end
function M.unique(dir, name)
  local path, n = fs.combine(dir, name), 1
  while fs.exists(path) do n = n + 1; path = fs.combine(dir, name .. "-" .. n) end
  return path
end
function M.within(path, root)
  path, root = fs.combine("/", path), fs.combine("/", root)
  return path == root or path:sub(1, #root + 1) == root .. "/"
end
function M.name(name)
  return type(name) == "string" and name ~= "" and name ~= "." and name ~= ".."
    and not name:find("[/\\%c]")
end
return M

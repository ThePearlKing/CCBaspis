-- Working directories belong to a window or shell, never to the shared fs API.
local M={}
function M.resolve(path,base)
  assert(type(path)=='string','Path must be a string')
  path=path:gsub('\\','/')
  local parts={}
  local function append(value)
    for part in value:gmatch('[^/]+') do
      if part=='..' then table.remove(parts)
      elseif part~='.' then parts[#parts+1]=part end
    end
  end
  if path:sub(1,1)~='/' then append((base or '/'):gsub('\\','/')) end
  append(path)
  return '/'..table.concat(parts,'/')
end
function M.context(directory)
  local cwd=M.resolve(directory or '/')
  local context={}
  function context.dir() return cwd end
  function context.resolve(path,base) return M.resolve(path,base or cwd) end
  function context.setDir(path)
    local resolved=context.resolve(path)
    assert(fs.isDir(resolved),'Not a directory: '..resolved)
    cwd=resolved
  end
  return context
end
return M

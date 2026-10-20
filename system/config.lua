local M = {}
M.version = "1.0.0"
function M.capabilities(target)
  target = target or term.current()
  local w, h = target.getSize()
  return { color = target.isColor(), blit = type(target.blit) == "function",
    width = w, height = h, turtle = turtle ~= nil, pocket = pocket ~= nil,
    http = http ~= nil, host = _HOST or os.version() }
end
function M.normalize(c, caps)
  c = type(c) == "table" and c or {}
  local mode = c.mode
  if not caps.color then mode = "basic"
  elseif mode ~= "basic" and mode ~= "color" and mode ~= "render" then mode = "color" end
  if mode == "render" and not caps.blit then mode = "color" end
  local hidden={}
  if type(c.hiddenShortcuts)=="table" then
    for id,value in pairs(c.hiddenShortcuts) do if type(id)=="string" and value==true then hidden[id]=true end end
  end
  return { mode = mode, theme = c.theme == "light" and "light" or "dark",
    wallpaper = c.wallpaper ~= false, clock24 = c.clock24 ~= false,
    welcome = c.welcome ~= false, version = M.version, hiddenShortcuts=hidden,
    skipTypedConfirmation = c.skipTypedConfirmation == true }
end
function M.theme(config)
  if config.mode == "basic" then
    return { bg = colors.black, panel = colors.black, text = colors.white,
      muted = colors.white, accent = colors.white, onAccent = colors.black,
      border = colors.white, desktop = colors.black, danger = colors.white,
      frame=colors.black,frameText=colors.white,inactiveFrame=colors.black,inactiveFrameText=colors.white }
  end
  if config.theme == "light" then
    return { bg = colors.white, panel = colors.lightGray, text = colors.black,
      muted = colors.gray, accent = colors.blue, onAccent = colors.white,
      border = colors.gray, desktop = colors.cyan, danger = colors.red,
      frame=colors.gray,frameText=colors.white,inactiveFrame=colors.lightGray,inactiveFrameText=colors.black }
  end
  return { bg = colors.black, panel = colors.gray, text = colors.white,
    muted = colors.lightGray, accent = colors.cyan, onAccent = colors.black,
    border = colors.gray, desktop = colors.blue, danger = colors.red,
    frame=colors.lightGray,frameText=colors.black,inactiveFrame=colors.gray,inactiveFrameText=colors.white }
end
return M

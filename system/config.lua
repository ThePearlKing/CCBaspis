local M = {}
M.version = "1.0.0"
M.colorFields={
  {'desktop','Desktop background'},{'desktopText','Desktop labels'},
  {'wallpaperFar','Wallpaper back'},{'wallpaperNear','Wallpaper front'},
  {'bar','Desktop bars'},{'barText','Desktop bar text'},
  {'bg','Window background'},{'panel','Panels / toolbars'},{'text','Text'},
  {'muted','Secondary text'},{'accent','Selection / accents'},{'onAccent','Selected text'},
  {'border','Dividers'},{'danger','Errors'},{'folder','Folder names'},
  {'frame','Active window border'},{'frameText','Active border text'},
  {'inactiveFrame','Inactive border'},{'inactiveFrameText','Inactive border text'},
  {'title','Active title bar'},{'titleText','Active title text'},
  {'inactiveTitle','Inactive title bar'},{'inactiveTitleText','Inactive title text'},
  {'minimize','Minimise button'},{'maximize','Maximise button'},{'close','Close button'},
  {'controlText','Min/max symbols'},{'closeText','Close symbol'},
  {'resize','Active resize grip'},{'resizeInactive','Inactive resize grip'},{'resizeText','Resize symbol'},
}
M.colorNames={'White','Orange','Magenta','Light blue','Yellow','Lime','Pink','Gray','Light gray','Cyan','Purple','Blue','Brown','Green','Red','Black'}
function M.profile(c) return c.mode=='basic' and 'basic' or c.theme=='light' and 'light' or 'dark' end
local function validColor(value)
  if type(value)~='number' then return false end
  for i=0,15 do if value==2^i then return true end end
  return false
end
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
  local custom={}
  for _,profile in ipairs({'dark','light','basic'}) do
    custom[profile]={}
    local source=type(c.customColors)=='table' and c.customColors[profile]
    if type(source)=='table' then
      for _,field in ipairs(M.colorFields) do if validColor(source[field[1]]) then custom[profile][field[1]]=source[field[1]] end end
    end
  end
  return { mode = mode, theme = c.theme == "light" and "light" or "dark",
    wallpaper = c.wallpaper ~= false, clock24 = c.clock24 ~= false,
    welcome = c.welcome ~= false, version = M.version, hiddenShortcuts=hidden,
    skipTypedConfirmation = c.skipTypedConfirmation == true,customColors=custom }
end
local function defaults(config)
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
function M.theme(config)
  local t=defaults(config); local mono=config.mode=='basic'
  t.desktopText=t.text; t.wallpaperFar=mono and t.muted or colors.cyan; t.wallpaperNear=colors.black
  t.bar=mono and t.bg or t.accent; t.barText=mono and t.text or t.onAccent
  t.folder=mono and t.text or colors.yellow
  t.title=mono and t.accent or t.frame; t.titleText=mono and t.onAccent or t.frameText
  t.inactiveTitle,t.inactiveTitleText=t.inactiveFrame,t.inactiveFrameText
  t.minimize=mono and t.title or colors.yellow; t.maximize=mono and t.title or colors.lime; t.close=mono and t.title or colors.red
  t.controlText=mono and t.titleText or colors.black; t.closeText=mono and t.titleText or colors.white
  t.resize=mono and t.bg or colors.gray; t.resizeInactive=mono and t.bg or colors.black; t.resizeText=colors.white
  local custom=config.customColors and config.customColors[M.profile(config)] or {}
  for _,field in ipairs(M.colorFields) do if validColor(custom[field[1]]) then t[field[1]]=custom[field[1]] end end
  return t
end
return M

-- Cached desktop textures: cell patterns everywhere, subpixels in render mode.
local M={}
local function sample(name,x,y,w,h)
  if name=='mountains' then
    if y>h*.78+math.sin(x/10+2)*2 then return 2,'#' end
    if y>h*.56+math.sin(x/7)*2+math.sin(x/3) then return 1,':' end
  elseif name=='dots' then
    if math.floor(y)%2==0 and math.floor(x)%4==(math.floor(y/2)%2)*2 then return 1,'.' end
  elseif name=='grid' then
    local vertical=math.floor(x)%8==0; local horizontal=math.floor(y)%4==0
    if vertical or horizontal then return 1,vertical and (horizontal and '+' or '|') or '-' end
  elseif name=='diagonal' then
    if (math.floor(x)+math.floor(y)*2)%8<2 then return 1,'/' end
  elseif name=='checker' then
    if (math.floor(x/4)+math.floor(y/2))%2==0 then return 1,':' end
  elseif name=='waves' then
    local wave=(y+math.sin(x/5)*2)%6
    if wave<1 then return 1,'~' elseif wave>3 and wave<3.6 then return 2,'.' end
  elseif name=='stars' then
    local hash=(math.floor(x)*73+math.floor(y)*151+math.floor(x)*math.floor(y)*19)%127
    if hash<3 then return 1,'+' elseif hash<9 then return 2,'.' end
  elseif name=='circuit' then
    local xx,yy=math.floor(x)%12,math.floor(y)%6
    if xx==2 and yy<=3 then return 1,yy==3 and '+' or '|'
    elseif yy==3 and xx>=2 and xx<=9 then return 1,xx==9 and 'o' or '-'
    elseif xx==9 and yy==4 then return 2,'|' end
  end
  return 0,' '
end
function M.build(config,t,w,h,pixels)
  local name=config.wallpaperPattern or (config.mode=='basic' and 'dots' or 'mountains')
  if config.mode=='render' then
    local canvas=pixels.new(w*2,h*3,t.desktop)
    for y=1,canvas.h do for x=1,canvas.w do
      local level=sample(name,x/2,y/3,w,h)
      if level>0 then canvas.set(x,y,level==1 and t.wallpaperFar or t.wallpaperNear) end
    end end
    return {canvas=canvas}
  end
  local rows={}
  for y=1,h do
    local text,fg={},{}
    for x=1,w do
      local level,glyph=sample(name,x,y,w,h); text[x]=glyph
      fg[x]=colors.toBlit(level==2 and t.wallpaperNear or t.wallpaperFar)
    end
    rows[y]={table.concat(text),table.concat(fg),string.rep(colors.toBlit(t.desktop),w)}
  end
  return {rows=rows}
end
function M.draw(image,pixels,x,y)
  if image.canvas then pixels.draw(image.canvas,term,x,y)
  else for i,row in ipairs(image.rows) do term.setCursorPos(x,y+i-1); term.blit(row[1],row[2],row[3]) end end
end
return M

local M={}
local shapes={{{0,0},{1,0},{2,0},{3,0}},{{0,0},{1,0},{0,1},{1,1}},{{0,0},{1,0},{2,0},{1,1}},
  {{1,0},{2,0},{0,1},{1,1}},{{0,0},{1,0},{1,1},{2,1}},{{0,0},{0,1},{1,1},{2,1}},{{2,0},{0,1},{1,1},{2,1}}}
local inks={colors.cyan,colors.yellow,colors.purple,colors.lime,colors.red,colors.blue,colors.orange}
function M.new(random)
  random=random or math.random
  local s={board={},score=0,lines=0,elapsed=0,next=random(1,7)}
  for y=1,12 do s.board[y]={} end
  local function fits(shape,x,y)
    for _,p in ipairs(shape) do local xx,yy=x+p[1],y+p[2]
      if xx<1 or xx>10 or yy>12 or (yy>=1 and s.board[yy][xx]) then return false end
    end
    return true
  end
  local function spawn()
    s.kind=s.next; s.next=random(1,7); s.shape={}
    for i,p in ipairs(shapes[s.kind]) do s.shape[i]={p[1],p[2]} end
    s.x,s.y=4,1
    if not fits(s.shape,s.x,s.y) then s.result='lose'; s.message=s.lines..' lines cleared' end
  end
  local function lock()
    for _,p in ipairs(s.shape) do s.board[s.y+p[2]][s.x+p[1]]=s.kind end
    local count=0; local y=12
    while y>=1 do
      local full=true; for x=1,10 do if not s.board[y][x] then full=false end end
      if full then table.remove(s.board,y); table.insert(s.board,1,{}); count=count+1 else y=y-1 end
    end
    s.lines=s.lines+count; s.score=s.score+({0,100,300,500,800})[count+1]; spawn()
  end
  function s.drop()
    if s.result then return end
    if fits(s.shape,s.x,s.y+1) then s.y=s.y+1 else lock() end
  end
  function s.key(key)
    if s.result then return end
    local dx=key=='left' and -1 or key=='right' and 1 or 0
    if dx~=0 and fits(s.shape,s.x+dx,s.y) then s.x=s.x+dx
    elseif key=='down' then s.drop()
    elseif key=='space' then while fits(s.shape,s.x,s.y+1) do s.y=s.y+1; s.score=s.score+1 end; lock()
    elseif key=='up' and s.kind~=2 then
      local rotated={}; local size=s.kind==1 and 4 or 3
      for i,p in ipairs(s.shape) do rotated[i]={size-1-p[2],p[1]} end
      for _,kick in ipairs({0,-1,1,-2,2}) do if fits(rotated,s.x+kick,s.y) then s.shape=rotated; s.x=s.x+kick; break end end
    end
  end
  function s.tick(dt)
    s.elapsed=s.elapsed+dt; local delay=math.max(.12,.7-s.lines*.025)
    if s.elapsed>=delay then s.elapsed=s.elapsed-delay; s.drop() end
  end
  function s.draw(c)
    for y=1,12 do
      c.text(1,y,'|'); c.text(12,y,'|')
      for x=1,10 do local kind=s.board[y][x]; c.text(x+1,y,kind and '#' or '.',kind and c.color and inks[kind] or kind and colors.white or colors.gray) end
    end
    for _,p in ipairs(s.shape) do if s.y+p[2]>=1 then c.text(s.x+p[1]+1,s.y+p[2],'#',c.color and inks[s.kind] or colors.white) end end
    c.text(14,1,'Next'); for _,p in ipairs(shapes[s.next]) do c.text(14+p[1],3+p[2],'#',c.color and inks[s.next] or colors.white) end
    if c.w>=20 then c.text(14,7,'Lines'); c.text(14,8,tostring(s.lines)) end
  end
  spawn(); return s
end
return M

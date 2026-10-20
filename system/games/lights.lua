local M={}
function M.new(random)
  random=random or math.random
  local s={cells={},x=3,y=3,moves=0,score=0}
  for i=1,25 do s.cells[i]=false end
  local function flip(x,y)
    for _,d in ipairs({{0,0},{-1,0},{1,0},{0,-1},{0,1}}) do
      local xx,yy=x+d[1],y+d[2]
      if xx>=1 and xx<=5 and yy>=1 and yy<=5 then local i=(yy-1)*5+xx; s.cells[i]=not s.cells[i] end
    end
  end
  for y=1,5 do for x=1,5 do if random(0,1)==1 then flip(x,y) end end end
  local any=false; for _,on in ipairs(s.cells) do any=any or on end; if not any then flip(3,3) end
  function s.key(key)
    if s.result then return end
    if key=='left' then s.x=math.max(1,s.x-1) elseif key=='right' then s.x=math.min(5,s.x+1)
    elseif key=='up' then s.y=math.max(1,s.y-1) elseif key=='down' then s.y=math.min(5,s.y+1)
    elseif key=='space' or key=='enter' then
      flip(s.x,s.y); s.moves=s.moves+1; local lit=false
      for _,on in ipairs(s.cells) do lit=lit or on end
      if not lit then s.result='win'; s.score=math.max(1,1000-s.moves); s.message=s.moves..' switches.' end
    end
  end
  function s.mouse(button,x,y,c)
    local ox=math.floor((c.w-15)/2)+1; local xx=math.floor((x-ox)/3)+1
    if button==1 and xx>=1 and xx<=5 and y>=1 and y<=5 then s.x,s.y=xx,y; s.key('enter') end
  end
  function s.draw(c)
    local ox=math.floor((c.w-15)/2)+1
    for y=1,5 do for x=1,5 do
      local on=s.cells[(y-1)*5+x]; local selected=x==s.x and y==s.y
      c.cell(ox+(x-1)*3,y,(selected and '[' or ' ')..(on and '*' or '.')..(selected and ']' or ' '),selected)
    end end
    c.text(ox,7,'Moves '..s.moves)
  end
  return s
end
return M

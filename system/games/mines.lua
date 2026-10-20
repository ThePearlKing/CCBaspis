local M={}
function M.new(random)
  random=random or math.random
  local s={bombs={},open={},flags={},x=1,y=1,score=0,started=false}
  local function id(x,y) return (y-1)*8+x end
  local function neighbours(x,y,fn)
    for yy=math.max(1,y-1),math.min(8,y+1) do for xx=math.max(1,x-1),math.min(8,x+1) do if xx~=x or yy~=y then fn(xx,yy,id(xx,yy)) end end end
  end
  function s.count(x,y) local count=0; neighbours(x,y,function(_,_,i) if s.bombs[i] then count=count+1 end end); return count end
  function s.reveal(x,y)
    if s.result or s.flags[id(x,y)] or s.open[id(x,y)] then return end
    if not s.started then
      local cells={}; for yy=1,8 do for xx=1,8 do if math.abs(xx-x)>1 or math.abs(yy-y)>1 then cells[#cells+1]=id(xx,yy) end end end
      for _=1,10 do s.bombs[table.remove(cells,random(1,#cells))]=true end; s.started=true
    end
    if s.bombs[id(x,y)] then s.result='lose'; s.message='That one was a mine.'; return end
    local todo={{x,y}}
    while #todo>0 do
      local p=table.remove(todo); local i=id(p[1],p[2])
      if not s.open[i] and not s.flags[i] then
        s.open[i]=true; s.score=s.score+1
        if s.count(p[1],p[2])==0 then neighbours(p[1],p[2],function(xx,yy,j) if not s.open[j] then todo[#todo+1]={xx,yy} end end) end
      end
    end
    if s.score==54 then s.result='win'; s.message='Every safe square cleared.' end
  end
  function s.key(key,held)
    if key=='left' then s.x=math.max(1,s.x-1) elseif key=='right' then s.x=math.min(8,s.x+1)
    elseif key=='up' then s.y=math.max(1,s.y-1) elseif key=='down' then s.y=math.min(8,s.y+1)
    elseif key=='enter' or key=='space' then s.reveal(s.x,s.y)
    elseif key=='f' and not held and not s.open[id(s.x,s.y)] then local i=id(s.x,s.y); s.flags[i]=not s.flags[i] end
  end
  function s.mouse(button,x,y,c)
    local ox=math.floor((c.w-16)/2)+1; local xx=math.floor((x-ox)/2)+1
    if xx>=1 and xx<=8 and y>=1 and y<=8 then s.x,s.y=xx,y; s.key(button==2 and 'f' or 'enter') end
  end
  function s.draw(c)
    local ox=math.floor((c.w-16)/2)+1; local flags=0
    for y=1,8 do for x=1,8 do
      local i=id(x,y); local mark=s.flags[i] and 'F' or '#'
      if s.flags[i] then flags=flags+1 end
      if s.open[i] then local n=s.count(x,y); mark=n==0 and '.' or tostring(n) end
      if s.result=='lose' and s.bombs[i] then mark='*' end
      c.cell(ox+(x-1)*2,y,mark..' ',x==s.x and y==s.y)
    end end
    c.text(ox,9,'Flags '..flags..'/10')
  end
  return s
end
return M

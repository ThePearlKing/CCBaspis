local M={}
function M.new(random)
  random=random or math.random
  local s={body={{x=8,y=4},{x=7,y=4},{x=6,y=4}},dx=1,dy=0,nextX=1,nextY=0,score=0,elapsed=0}
  local function fruit()
    local free={}
    for y=1,8 do for x=1,16 do
      local occupied=false; for _,p in ipairs(s.body) do if p.x==x and p.y==y then occupied=true end end
      if not occupied then free[#free+1]={x=x,y=y} end
    end end
    if #free==0 then s.result='win'; s.message='The entire board is snake.' else s.food=free[random(1,#free)] end
  end
  fruit()
  function s.key(key)
    local d=({up={0,-1},w={0,-1},down={0,1},s={0,1},left={-1,0},a={-1,0},right={1,0},d={1,0}})[key]
    if d and not (d[1]==-s.dx and d[2]==-s.dy) then s.nextX,s.nextY=d[1],d[2] end
  end
  function s.tick(dt)
    if s.result then return end
    s.elapsed=s.elapsed+dt; local delay=math.max(.09,.22-s.score*.002)
    if s.elapsed<delay then return end; s.elapsed=s.elapsed-delay
    s.dx,s.dy=s.nextX,s.nextY
    local head={x=s.body[1].x+s.dx,y=s.body[1].y+s.dy}
    local grows=head.x==s.food.x and head.y==s.food.y
    local hit=head.x<1 or head.x>16 or head.y<1 or head.y>8
    for i=1,#s.body-(grows and 0 or 1) do local p=s.body[i]; if p.x==head.x and p.y==head.y then hit=true end end
    if hit then s.result='lose'; s.message='Tail: '..#s.body..' cells'; return end
    table.insert(s.body,1,head)
    if grows then s.score=s.score+10; fruit() else table.remove(s.body) end
  end
  function s.draw(c)
    local ox=math.floor((c.w-16)/2)+1
    for y=1,8 do c.text(ox,y,string.rep('.',16),colors.gray) end
    c.text(ox+s.food.x-1,s.food.y,'*',c.color and colors.red or colors.white)
    for i,p in ipairs(s.body) do c.text(ox+p.x-1,p.y,i==1 and '@' or 'o',c.color and colors.lime or colors.white) end
  end
  return s
end
return M

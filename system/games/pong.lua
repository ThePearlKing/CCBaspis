local M={}
function M.new(random)
  random=random or math.random
  local s={player=4,computer=4,x=9,y=4,vx=6,vy=3,left=0,right=0,score=0}
  local function serve(direction) s.x,s.y=9,4; s.vx=6*direction; s.vy=random(0,1)==0 and -3 or 3 end
  function s.key(key)
    if key=='up' or key=='w' then s.player=math.max(2,s.player-1)
    elseif key=='down' or key=='s' then s.player=math.min(7,s.player+1) end
  end
  function s.tick(dt)
    if s.result then return end
    s.computer=math.max(2,math.min(7,s.computer+math.max(-2.7*dt,math.min(2.7*dt,s.y-s.computer))))
    local old=s.x; s.x=s.x+s.vx*dt; s.y=s.y+s.vy*dt
    if s.y<1 then s.y=2-s.y; s.vy=math.abs(s.vy) elseif s.y>8 then s.y=16-s.y; s.vy=-math.abs(s.vy) end
    if old>=2 and s.x<=2 and math.abs(s.y-s.player)<=1.6 then
      s.x=2; s.vx=math.min(12,math.abs(s.vx)+.3); s.vy=(s.y-s.player)*4
    elseif old<=17 and s.x>=17 and math.abs(s.y-s.computer)<=1.6 then
      s.x=17; s.vx=-math.min(12,math.abs(s.vx)+.3); s.vy=(s.y-s.computer)*4
    end
    if s.x<0 then s.right=s.right+1; serve(1)
    elseif s.x>19 then s.left=s.left+1; s.score=s.left; serve(-1) end
    if s.left==7 or s.right==7 then s.result=s.left==7 and 'win' or 'lose'; s.message=s.left..' : '..s.right end
  end
  function s.draw(c)
    local ox=math.floor((c.w-18)/2)
    for y=1,8 do c.text(ox+9,y,':',colors.gray) end
    for dy=-1,1 do c.text(ox+1,s.player+dy,'|'); c.text(ox+18,math.floor(s.computer+.5)+dy,'|') end
    c.text(ox+math.max(1,math.min(18,math.floor(s.x+.5))),math.max(1,math.min(8,math.floor(s.y+.5))),'O',c.color and colors.yellow or colors.white)
    c.text(ox+5,9,s.left..'   :   '..s.right)
  end
  return s
end
return M

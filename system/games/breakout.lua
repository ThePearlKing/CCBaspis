local M={}
function M.new()
  local s={paddle=40,x=40,y=42,vx=12,vy=-24,ready=true,lives=3,score=0,bricks={},remaining=32}
  for row=1,4 do for col=1,8 do s.bricks[#s.bricks+1]={x=1+(col-1)*10,y=4+(row-1)*4,row=row,alive=true} end end
  function s.key(key)
    if key=='left' or key=='a' then s.paddle=math.max(7,s.paddle-5)
    elseif key=='right' or key=='d' then s.paddle=math.min(73,s.paddle+5)
    elseif key=='space' or key=='enter' then s.ready=false end
    if s.ready then s.x=s.paddle end
  end
  function s.mouse(button,x,_,c) if button==1 then s.paddle=math.max(7,math.min(73,x/c.w*80)); if s.ready then s.x=s.paddle end end end
  function s.tick(dt)
    if s.ready or s.result then return end
    local steps=math.ceil(math.max(math.abs(s.vx),math.abs(s.vy))*dt/.7)
    for _=1,steps do
      local ox,oy=s.x,s.y; s.x=s.x+s.vx*dt/steps; s.y=s.y+s.vy*dt/steps
      if s.x<1 then s.x=1; s.vx=math.abs(s.vx) elseif s.x>79 then s.x=79; s.vx=-math.abs(s.vx) end
      if s.y<1 then s.y=1; s.vy=math.abs(s.vy) end
      if s.vy>0 and oy<=44 and s.y>=44 and math.abs(s.x-s.paddle)<=8 then
        s.y=44; s.vy=-math.abs(s.vy); s.vx=(s.x-s.paddle)*3
      end
      for _,b in ipairs(s.bricks) do
        if b.alive and s.x>=b.x-1 and s.x<=b.x+8 and s.y>=b.y-1 and s.y<=b.y+3 then
          b.alive=false; s.remaining=s.remaining-1; s.score=s.score+10
          if (ox<b.x-1 or ox>b.x+8) and oy>=b.y-1 and oy<=b.y+3 then s.vx=-s.vx else s.vy=-s.vy end
          if s.remaining==0 then s.result='win'; s.message='No bricks left standing.'; return end
          break
        end
      end
      if s.y>49 then
        s.lives=s.lives-1; s.ready=true; s.x,s.y=s.paddle,42; s.vx,s.vy=12,-24
        if s.lives==0 then s.result='lose'; s.message=s.remaining..' bricks survived.' end
        return
      end
    end
  end
  function s.draw(c)
    local b=c.pixels.new(c.w*2,c.h*3,colors.black)
    local function rect(x,y,w,h,color)
      local x1,y1=math.floor(x/80*b.w)+1,math.floor(y/48*b.h)+1
      local x2,y2=math.floor((x+w)/80*b.w),math.floor((y+h)/48*b.h)
      b.rect(x1,y1,math.max(1,x2-x1+1),math.max(1,y2-y1+1),color)
    end
    for _,brick in ipairs(s.bricks) do if brick.alive then rect(brick.x,brick.y,8,3,({colors.red,colors.orange,colors.lime,colors.cyan})[brick.row]) end end
    rect(s.paddle-7,45,14,2,colors.white); rect(s.x-1,s.y-1,2,2,colors.yellow)
    c.drawPixels(b)
    c.text(1,1,'Balls '..s.lives..(s.ready and ' | Space: launch' or ''))
  end
  return s
end
return M

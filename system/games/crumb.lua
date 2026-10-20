-- Crumb Raider: perspective raycasting, depth-tested sprites and a carved maze.
local M={}
function M.new(random)
  random=random or math.random
  local s={map={},x=2.5,y=2.5,angle=0,crumbs={},collected=0,score=0,time=0,showMap=false,size=15}
  for y=1,15 do s.map[y]={}; for x=1,15 do s.map[y][x]=1 end end
  local stack={{2,2}}; s.map[2][2]=0
  while #stack>0 do
    local p=stack[#stack]; local options={}
    for _,d in ipairs({{2,0},{0,2},{-2,0},{0,-2}}) do
      local x,y=p[1]+d[1],p[2]+d[2]
      if x>=2 and x<=14 and y>=2 and y<=14 and s.map[y][x]==1 then options[#options+1]={x,y} end
    end
    if #options==0 then table.remove(stack)
    else local n=options[random(1,#options)]; s.map[(p[2]+n[2])/2][(p[1]+n[1])/2]=0; s.map[n[2]][n[1]]=0; stack[#stack+1]=n end
  end
  s.angle=s.map[2][3]==0 and 0 or math.pi/2
  -- Breadth-first order gives reachable, well-spaced treasures and a distant exit.
  local queue={{2,2}}; local visited={['2:2']=true}; local cursor=1
  while cursor<=#queue do
    local p=queue[cursor]; cursor=cursor+1
    for _,d in ipairs({{1,0},{0,1},{-1,0},{0,-1}}) do
      local x,y=p[1]+d[1],p[2]+d[2]; local id=x..':'..y
      if s.map[y] and s.map[y][x]==0 and not visited[id] then visited[id]=true; queue[#queue+1]={x,y} end
    end
  end
  local last=queue[#queue]; s.exit={x=last[1]+.5,y=last[2]+.5,exit=true}
  for i=1,6 do local p=queue[math.floor(i*(#queue-2)/7)+2]; s.crumbs[i]={x=p[1]+.5,y=p[2]+.5} end
  function s.solid(x,y) return not s.map[math.floor(y)] or s.map[math.floor(y)][math.floor(x)]~=0 end
  local function walkable(x,y)
    for _,dx in ipairs({-.18,.18}) do for _,dy in ipairs({-.18,.18}) do if s.solid(x+dx,y+dy) then return false end end end
    return true
  end
  function s.collect()
    for _,crumb in ipairs(s.crumbs) do
      if not crumb.taken and (crumb.x-s.x)^2+(crumb.y-s.y)^2<.23 then crumb.taken=true; s.collected=s.collected+1; s.score=s.score+100 end
    end
    if s.collected==6 and (s.exit.x-s.x)^2+(s.exit.y-s.y)^2<.23 then
      s.result='win'; s.score=s.score+math.max(0,1000-math.floor(s.time)); s.message='Six crumbs. One clean getaway.'
    end
  end
  function s.move(dx,dy)
    if s.result then return end
    if walkable(s.x+dx,s.y) then s.x=s.x+dx end
    if walkable(s.x,s.y+dy) then s.y=s.y+dy end
    s.collect()
  end
  function s.key(key,held)
    if s.result then return end
    if key=='left' or key=='a' then s.angle=(s.angle-.17)%(math.pi*2)
    elseif key=='right' or key=='d' then s.angle=(s.angle+.17)%(math.pi*2)
    elseif key=='up' or key=='w' then s.move(math.cos(s.angle)*.3,math.sin(s.angle)*.3)
    elseif key=='down' or key=='s' then s.move(-math.cos(s.angle)*.3,-math.sin(s.angle)*.3)
    elseif key=='z' then s.move(math.sin(s.angle)*.3,-math.cos(s.angle)*.3)
    elseif key=='x' then s.move(-math.sin(s.angle)*.3,math.cos(s.angle)*.3)
    elseif key=='m' and not held then s.showMap=not s.showMap end
  end
  function s.tick(dt) if not s.result then s.time=s.time+dt end end
  function s.ray(dx,dy)
    local mx,my=math.floor(s.x),math.floor(s.y)
    local deltaX,deltaY=dx==0 and math.huge or math.abs(1/dx),dy==0 and math.huge or math.abs(1/dy)
    local stepX,stepY=dx<0 and -1 or 1,dy<0 and -1 or 1
    local sideX=(dx<0 and s.x-mx or mx+1-s.x)*deltaX
    local sideY=(dy<0 and s.y-my or my+1-s.y)*deltaY
    local side,dist
    for _=1,64 do
      if sideX<sideY then mx=mx+stepX; dist=sideX; sideX=sideX+deltaX; side=0
      else my=my+stepY; dist=sideY; sideY=sideY+deltaY; side=1 end
      if not s.map[my] or s.map[my][mx]~=0 then
        local hit=side==0 and s.y+dist*dy or s.x+dist*dx
        return math.max(.05,dist),side,hit%1
      end
    end
    return 64,0,0
  end
  function s.draw(c)
    local pw,ph=c.w*2,c.h*3; local b=c.pixels.new(pw,ph,colors.black)
    if s.showMap then
      local scale=math.max(1,math.floor(math.min(pw/15,(ph-3)/15))); local ox=math.floor((pw-15*scale)/2)
      for y=1,15 do for x=1,15 do b.rect(ox+(x-1)*scale+1,(y-1)*scale+1,scale,scale,s.map[y][x]==1 and colors.gray or colors.black) end end
      local function dot(p,color) b.rect(ox+(math.floor(p.x)-1)*scale+1,(math.floor(p.y)-1)*scale+1,scale,scale,color) end
      for _,crumb in ipairs(s.crumbs) do if not crumb.taken then dot(crumb,colors.yellow) end end
      dot(s.exit,colors.lime); dot(s,colors.white)
    else
      local dirX,dirY=math.cos(s.angle),math.sin(s.angle); local planeX,planeY=-dirY*.66,dirX*.66
      local depth={}
      for x=1,pw do
        local camera=(x-.5)*2/pw-1
        local dist,side,u=s.ray(dirX+planeX*camera,dirY+planeY*camera); depth[x]=dist
        local height=ph/dist; local top=ph/2-height/2
        for y=1,ph do
          local ink
          if y<top then ink=y<ph*.28 and colors.blue or colors.black
          elseif y>top+height then ink=(y%3==0) and colors.gray or colors.black
          else
            local mortar=math.floor(u*12)%6==0 or math.floor((y-top)/height*12)%4==0
            ink=mortar and colors.black or dist>6 and colors.gray or side==1 and colors.brown or colors.orange
          end
          b.set(x,y,ink)
        end
      end
      local sprites={s.exit}; for _,crumb in ipairs(s.crumbs) do if not crumb.taken then sprites[#sprites+1]=crumb end end
      table.sort(sprites,function(a,d) return (a.x-s.x)^2+(a.y-s.y)^2>(d.x-s.x)^2+(d.y-s.y)^2 end)
      local inverse=1/(planeX*dirY-dirX*planeY)
      for _,sprite in ipairs(sprites) do
        local rx,ry=sprite.x-s.x,sprite.y-s.y
        local tx=inverse*(dirY*rx-dirX*ry); local ty=inverse*(-planeY*rx+planeX*ry)
        if ty>.1 then
          local size=math.min(ph,ph/ty*.3); local sx=pw/2*(1+tx/ty); local sy=ph/2+ph/ty*.15
          for x=math.max(1,math.floor(sx-size)),math.min(pw,math.ceil(sx+size)) do
            if ty<depth[x] then for y=math.max(1,math.floor(sy-size)),math.min(ph,math.ceil(sy+size)) do
              if math.abs(x-sx)+math.abs(y-sy)<=size then
                b.set(x,y,sprite.exit and (s.collected==6 and colors.lime or colors.green) or colors.yellow)
              end
            end end
          end
        end
      end
    end
    c.drawPixels(b); c.text(1,c.h,'Crumbs '..s.collected..'/6  '..(s.collected==6 and 'Find green exit' or 'M map'))
  end
  return s
end
return M

-- Titan: a 2D game engine for ComputerCraft.
-- Standalone: works inside CCSacabam windows, in plain CraftOS (copy this file
-- next to your program or into /rom-less module paths), and on monitors.
-- Saturn's biggest moon. It got the heavy lifting.
local T={version='1.0'}
local floor,ceil,max,min,abs,sqrt=math.floor,math.ceil,math.max,math.min,math.abs,math.sqrt
local unpack=table.unpack or unpack
local DIGITS='0123456789abcdef'
local HEX,FROMHEX={},{}
for i=0,15 do local c=DIGITS:sub(i+1,i+1); HEX[2^i]=c; FROMHEX[c]=2^i end
local CHAR={}; for bits=0,31 do CHAR[bits]=string.char(128+bits) end
local EPS=1e-6

-- Small helpers games tend to need.
function T.clamp(v,lo,hi) return v<lo and lo or v>hi and hi or v end
function T.lerp(a,b,t) return a+(b-a)*t end
function T.sign(v) return v>0 and 1 or v<0 and -1 or 0 end
function T.dist(ax,ay,bx,by) local dx,dy=bx-ax,by-ay; return sqrt(dx*dx+dy*dy) end
function T.overlap(a,b)
  return a.x<b.x+b.w and b.x<a.x+a.w and a.y<b.y+b.h and b.y<a.y+a.h
end
T.ease={
  linear=function(t) return t end,
  ['in']=function(t) return t*t end,
  out=function(t) return 1-(1-t)*(1-t) end,
  inout=function(t) return t<.5 and 2*t*t or 1-((-2*t+2)^2)/2 end,
}

-- Images. Rows are strings; each character is a palette key. Default palette
-- uses blit digits 0-f (the same as paint / .nfp files); space and . are clear.
local function parseImage(rows,palette)
  local img={w=0,h=#rows,px={}}
  for y,row in ipairs(rows) do
    img.px[y]={}; img.w=max(img.w,#row)
    for x=1,#row do
      local ch=row:sub(x,x); local c
      if palette and palette[ch]~=nil then c=palette[ch] or nil
      elseif ch~=' ' and ch~='.' then c=FROMHEX[ch:lower()] end
      img.px[y][x]=c
    end
  end
  return img
end
T.image=parseImage
function T.loadImage(path,palette)
  local h=fs.open(path,'r'); if not h then return nil,'Cannot open '..tostring(path) end
  local rows={}; local line=h.readLine()
  while line do rows[#rows+1]=line; line=h.readLine() end
  h.close(); return parseImage(rows,palette)
end
local function readLines(path)
  local h=fs.open(path,'r'); if not h then error('Cannot open '..tostring(path),3) end
  local rows={}; local line=h.readLine()
  while line do rows[#rows+1]=line; line=h.readLine() end
  h.close(); return rows
end

function T.new(def)
  def=def or {}
  local g={entities={},camera={x=0,y=0},mouse={x=0,y=0,col=0,row=0,down=false},
    time=0,frame=0,running=false,paused=false,background=def.background or colors.black}
  local target=def.target or term.current()
  g.target=target; g.side=def.side; g.fps=def.fps or 20
  if def.scale and target.setTextScale then target.setTextScale(def.scale) end
  local color=target.isColor and target.isColor()
  -- Advanced computers get full 2x3 subpixel colour graphics by default.
  -- Basic computers are opt-in: a game sets basic=true and designs its
  -- one-cell-per-pixel version itself (check g.mode=='cell').
  g.supported=color or def.basic==true
  local mode=def.mode or (color and 'pixel' or 'cell')
  g.mode=mode; g.color=color
  local sx,sy=1,1; if mode=='pixel' then sx,sy=2,3 end
  g.sx,g.sy=sx,sy
  local buf,cover={}, {}
  local held,pressed,clicked={}, {}, {}
  local binds={left={'left','a'},right={'right','d'},up={'up','w'},down={'down','s'},
    jump={'space','up','w'},action={'enter','space','e'}}
  local sprites,anims,templates,scenes={}, {}, {}, {}
  local scene,sceneName
  local timers,tweens,particles,handlers={}, {}, {}, {}
  local pending={}; local nextId=0
  local shake={time=0,amount=0}; local follow
  local map

  -- Display ---------------------------------------------------------------
  function g.resize()
    local cols,rows=target.getSize()
    g.cols,g.rows=cols,rows; g.width,g.height=cols*sx,rows*sy
    buf={}; cover={}
    g.tooSmall=(def.minCols and cols<def.minCols) or (def.minRows and rows<def.minRows) or false
    if scene and scene.resize then scene.resize(g) end
  end
  g.resize()

  -- Input -------------------------------------------------------------------
  function g.bind(action,list) binds[action]=type(list)=='table' and list or {list} end
  local function any(set,name)
    if set[name] then return true end
    local list=binds[name]; if not list then return false end
    for _,k in ipairs(list) do if set[k] then return true end end
    return false
  end
  function g.down(name) return any(held,name) end
  function g.pressed(name) return any(pressed,name) end
  function g.clicked(button) return clicked[button or 1]==true end
  local function setMouse(col,row,button,down)
    local m=g.mouse
    m.col,m.row=col,row
    m.x=(col-1)*sx+(sx-1)/2+g.camera.x; m.y=(row-1)*sy+(sy-1)/2+g.camera.y
    m.sx,m.sy=m.x-g.camera.x,m.y-g.camera.y
    if button then m.button=button end
    if down~=nil then m.down=down end
  end

  -- Assets -----------------------------------------------------------------
  function g.sprite(name,rows,palette)
    if type(rows)=='string' then sprites[name]=assert(T.loadImage(rows,palette))
    elseif rows.px then sprites[name]=rows
    else sprites[name]=parseImage(rows,palette) end
    return sprites[name]
  end
  function g.animation(name,frames,fps,loop) anims[name]={frames=frames,fps=fps or 6,loop=loop~=false}; return anims[name] end
  local function imageFor(e)
    local name=e.sprite; if not name then return end
    local a=anims[name]
    if a then
      local i=floor(((g.time-(e.animStart or 0))*a.fps))
      i=a.loop and (i%#a.frames)+1 or min(i+1,#a.frames)
      name=a.frames[i]
    end
    return type(name)=='table' and name or sprites[name]
  end

  -- Drawing (world coordinates: (0,0) is the top-left pixel of the world) --
  local ox,oy=0,0 -- current offset; camera for world drawing, 0 for screen
  local function plot(x,y,c)
    if not c then return end
    x,y=floor(x-ox),floor(y-oy)
    if x>=0 and y>=0 and x<g.width and y<g.height then buf[y*g.width+x+1]=c end
  end
  local draw={}
  function draw.pixel(x,y,c) plot(x,y,c) end
  function draw.rect(x,y,w,h,c)
    local x1,y1=max(0,floor(x-ox)),max(0,floor(y-oy))
    local x2,y2=min(g.width,floor(x-ox+w))-1,min(g.height,floor(y-oy+h))-1
    local W=g.width
    for yy=y1,y2 do local base=yy*W+1 for xx=x1,x2 do buf[base+xx]=c end end
  end
  function draw.outline(x,y,w,h,c)
    draw.rect(x,y,w,1,c); draw.rect(x,y+h-1,w,1,c); draw.rect(x,y,1,h,c); draw.rect(x+w-1,y,1,h,c)
  end
  function draw.line(x1,y1,x2,y2,c)
    x1,y1,x2,y2=floor(x1),floor(y1),floor(x2),floor(y2)
    local dx,dy=abs(x2-x1),-abs(y2-y1); local stx,sty=x1<x2 and 1 or -1,y1<y2 and 1 or -1; local err=dx+dy
    while true do
      plot(x1,y1,c); if x1==x2 and y1==y2 then return end
      local e2=2*err
      if e2>=dy then err=err+dy; x1=x1+stx end
      if e2<=dx then err=err+dx; y1=y1+sty end
    end
  end
  function draw.circle(cx,cy,r,c,filled)
    for y=-r,r do for x=-r,r do
      local d=x*x+y*y
      if d<=r*r+r and (filled~=false or d>=(r-1)*(r-1)+(r-1)) then plot(cx+x,cy+y,c) end
    end end
  end
  function draw.image(img,x,y,flip,flipY)
    if type(img)~='table' then img=sprites[img] end
    if not img then return end
    for yy=1,img.h do
      local row=img.px[flipY and img.h-yy+1 or yy]
      for xx=1,img.w do
        local c=row[flip and img.w-xx+1 or xx]
        if c then plot(x+xx-1,y+yy-1,c) end
      end
    end
  end
  -- Text sits on terminal cells. x,y are pixels; it snaps to the cell there.
  function draw.text(x,y,text,fg,bg)
    local col,row=floor((x-ox)/sx)+1,floor((y-oy)/sy)+1
    g.write(col,row,text,fg,bg)
  end
  function g.write(col,row,text,fg,bg)
    text=tostring(text)
    if row<1 or row>g.rows then return end
    for i=1,#text do
      local c=col+i-1
      if c>=1 and c<=g.cols then cover[(row-1)*g.cols+c]={text:sub(i,i),fg or colors.white,bg} end
    end
  end
  function g.center(row,text,fg,bg) text=tostring(text); g.write(floor((g.cols-#text)/2)+1,row,text,fg,bg) end
  for k,fn in pairs(draw) do g[k]=fn end
  g.screen={}
  for k,fn in pairs(draw) do
    g.screen[k]=function(...) local px,py=ox,oy; ox,oy=0,0; fn(...); ox,oy=px,py end
  end
  g.screen.write=g.write; g.screen.center=g.center

  -- Tile maps ---------------------------------------------------------------
  function g.map(spec)
    local m={tile=spec.tile or 3,legend=spec.legend or {},grid={},spawned={},edge=spec.edge}
    local rows=spec.rows
    if type(rows)=='string' then rows=readLines(rows) end
    m.cols,m.rows=0,#rows
    for _,r in ipairs(rows) do m.cols=max(m.cols,#r) end
    m.width,m.height=m.cols*m.tile,m.rows*m.tile
    for y=1,m.rows do m.grid[y]={} for x=1,m.cols do m.grid[y][x]=rows[y]:sub(x,x) end end
    function m.get(tx,ty) local r=m.grid[ty]; return r and r[tx] end
    function m.set(tx,ty,ch) if m.grid[ty] and tx>=1 and tx<=m.cols then m.grid[ty][tx]=ch end end
    function m.info(tx,ty) local ch=m.get(tx,ty); return ch and m.legend[ch] end
    function m.toTile(x,y) return floor(x/m.tile)+1,floor(y/m.tile)+1 end
    function m.fromTile(tx,ty) return (tx-1)*m.tile,(ty-1)*m.tile end
    function m.find(ch)
      local out={}
      for y=1,m.rows do for x=1,m.cols do if m.grid[y][x]==ch then out[#out+1]={x=x,y=y} end end end
      return out
    end
    map=m; g.tiles=m
    -- Legend entries can create entities: a template name or a function.
    for y=1,m.rows do for x=1,m.cols do
      local info=m.legend[m.grid[y][x]]
      if info and info.spawn then
        local px,py=m.fromTile(x,y)
        local e
        if type(info.spawn)=='function' then e=info.spawn(px,py,x,y)
        else e=g.spawn(info.spawn,{x=px,y=py}) end
        m.grid[y][x]=info.under or ' '
        if e then m.spawned[#m.spawned+1]=e end
      end
    end end
    return m
  end
  local function tileBlocks(info,dir,e,top)
    if not info then return false end
    if info.solid then return true end
    -- One-way platforms stop things falling onto them, not jumping through.
    return info.oneway and dir=='down' and e.y+e.h-EPS<=top
  end
  -- Returns the boxes blocking e at (x,y), for a move in dir.
  local function blockers(e,x,y,dir)
    local out={}
    if map and e.collide~=false then
      local t=map.tile
      local tx1,ty1=floor(x/t)+1,floor(y/t)+1
      local tx2,ty2=floor((x+e.w-EPS)/t)+1,floor((y+e.h-EPS)/t)+1
      for ty=ty1,ty2 do for tx=tx1,tx2 do
        local info
        if tx<1 or ty<1 or tx>map.cols or ty>map.rows then info=map.edge~=false and (map.legend.edge or {solid=true}) or nil
        else info=map.legend[map.grid[ty][tx]] end
        if info and ty>map.rows and not info.floor then info=nil end -- fall out of the bottom
        if tileBlocks(info,dir,e,(ty-1)*t) then out[#out+1]={x=(tx-1)*t,y=(ty-1)*t,w=t,h=t,tile=info,tx=tx,ty=ty} end
      end end
    end
    if e.collide~=false then
      for _,o in ipairs(g.entities) do
        if o~=e and o.alive and o.solid and o.x<x+e.w and x<o.x+o.w and o.y<y+e.h and y<o.y+o.h then
          if not o.oneway or (dir=='down' and e.y+e.h-EPS<=o.y) then out[#out+1]=o end
        end
      end
    end
    return out
  end
  -- True when (x,y) is inside a solid or one-way tile, or a solid entity.
  function g.solidAt(x,y)
    if map then
      local tx,ty=floor(x/map.tile)+1,floor(y/map.tile)+1
      local info=map.legend[map.get(tx,ty) or '']
      if info and (info.solid or info.oneway) then return true end
    end
    for _,o in ipairs(g.entities) do
      if o.alive and o.solid and x>=o.x and x<o.x+o.w and y>=o.y and y<o.y+o.h then return true end
    end
    return false
  end
  -- Move e by (dx,dy), stopping at solid tiles and solid entities.
  -- Returns hitX, hitY (the blocking box or false).
  function g.move(e,dx,dy)
    local step=map and map.tile*.5 or 1
    local n=max(1,ceil(max(abs(dx),abs(dy))/step))
    local hitX,hitY=false,false
    for _=1,n do
      if dx~=0 and not hitX then
        local nx=e.x+dx/n
        local list=blockers(e,nx,e.y,dx>0 and 'right' or 'left')
        if #list>0 then
          for _,b in ipairs(list) do
            if dx>0 then nx=min(nx,b.x-e.w) else nx=max(nx,b.x+b.w) end
          end
          hitX=list[1]
        end
        e.x=nx
      end
      if dy~=0 and not hitY then
        local ny=e.y+dy/n
        local list=blockers(e,e.x,ny,dy>0 and 'down' or 'up')
        if #list>0 then
          for _,b in ipairs(list) do
            if dy>0 then ny=min(ny,b.y-e.h) else ny=max(ny,b.y+b.h) end
          end
          hitY=list[1]
        end
        e.y=ny
      end
    end
    return hitX,hitY
  end

  -- Entities ----------------------------------------------------------------
  function g.define(name,template) templates[name]=template; return template end
  function g.spawn(kind,props)
    local e={}
    if type(kind)=='string' then
      local tpl=templates[kind]; if not tpl then error('Unknown entity template: '..kind,2) end
      for k,v in pairs(tpl) do e[k]=v end; e.kind=kind
    elseif type(kind)=='table' then props=kind end
    for k,v in pairs(props or {}) do e[k]=v end
    nextId=nextId+1; e.id=nextId; e.alive=true
    e.x,e.y,e.vx,e.vy=e.x or 0,e.y or 0,e.vx or 0,e.vy or 0
    local img=imageFor(e)
    e.w,e.h=e.w or (img and img.w) or sx,e.h or (img and img.h) or sy
    local tags={}
    if e.kind then tags[e.kind]=true end
    for _,t in ipairs(type(e.tags)=='table' and e.tags or {e.tags}) do tags[t]=true end
    e.tags=tags; e.animStart=g.time
    function e.is(tag) return tags[tag]==true end
    function e.tag(tag,on) tags[tag]=on~=false or nil end
    function e.destroy() e.alive=false end
    function e.play(name) if e.sprite~=name then e.sprite=name; e.animStart=g.time end end
    function e.center() return e.x+e.w/2,e.y+e.h/2 end
    pending[#pending+1]=e
    if e.init then e.init(e,g) end
    return e
  end
  local function flush()
    if #pending>0 then
      for _,e in ipairs(pending) do if e.alive then g.entities[#g.entities+1]=e end end
      pending={}
    end
    local j=1
    for i=1,#g.entities do local e=g.entities[i]
      if e.alive then g.entities[j]=e; j=j+1 elseif e.removed then e.removed(e,g) end
    end
    for i=#g.entities,j,-1 do g.entities[i]=nil end
  end
  g.flush=flush
  function g.find(tag)
    local out={}
    for _,list in ipairs({g.entities,pending}) do
      for _,e in ipairs(list) do if e.alive and (not tag or e.tags[tag]) then out[#out+1]=e end end
    end
    return out
  end
  function g.first(tag) return g.find(tag)[1] end
  function g.count(tag) return #g.find(tag) end
  function g.at(x,y,tag)
    for i=#g.entities,1,-1 do local e=g.entities[i]
      if e.alive and (not tag or e.tags[tag]) and x>=e.x and x<e.x+e.w and y>=e.y and y<e.y+e.h then return e end
    end
  end
  function g.overlapping(e,tag)
    local out={}
    for _,o in ipairs(g.entities) do
      if o~=e and o.alive and (not tag or o.tags[tag]) and T.overlap(e,o) then out[#out+1]=o end
    end
    return out
  end

  -- Time --------------------------------------------------------------------
  local function addTimer(t) timers[#timers+1]=t; function t.cancel() t.dead=true end; return t end
  function g.after(delay,fn) return addTimer({left=delay,fn=fn}) end
  function g.every(delay,fn) return addTimer({left=delay,every=delay,fn=fn}) end
  function g.tween(obj,time,goal,ease,done)
    local tw={obj=obj,time=max(time,EPS),t=0,goal=goal,from={},ease=T.ease[ease or 'out'] or ease,done=done}
    for k,v in pairs(goal) do tw.from[k]=obj[k] end
    tweens[#tweens+1]=tw; function tw.cancel() tw.dead=true end; return tw
  end
  function g.burst(x,y,opts)
    opts=opts or {}
    for _=1,opts.count or 8 do
      local a=math.random()*math.pi*2; local s=(opts.speed or 20)*(.4+math.random()*.6)
      particles[#particles+1]={x=x,y=y,vx=math.cos(a)*s,vy=math.sin(a)*s,life=opts.life or .6,
        color=type(opts.color)=='table' and opts.color[math.random(#opts.color)] or opts.color or colors.white,
        gravity=opts.gravity or 0}
    end
  end
  function g.shake(amount,time) shake.amount,shake.time=amount or 2,time or .3 end
  function g.follow(e,opts) follow=e and {e=e,lerp=(opts and opts.lerp) or 1,bounds=not opts or opts.bounds~=false} or nil end

  -- Sound: any attached speaker; silent when there is none.
  function g.sound(instrument,volume,pitch)
    if g.speaker==nil then g.speaker=peripheral and peripheral.find and peripheral.find('speaker') or false end
    if g.speaker then pcall(g.speaker.playNote,instrument or 'bit',volume or 1,pitch or 12) end
  end

  -- Saving: plain Lua tables through fs (encrypted drive inside CCSacabam).
  function g.save(path,data)
    local h,err=fs.open(path,'w'); if not h then return nil,err end
    h.write(textutils.serialize(data)); h.close(); return true
  end
  function g.load(path,default)
    local h=fs.open(path,'r'); if not h then return default end
    local data=textutils.unserialize(h.readAll()); h.close()
    if data==nil then return default end
    return data
  end

  -- Scenes ------------------------------------------------------------------
  function g.scene(name,s) scenes[name]=s; return s end
  function g.clear()
    for _,e in ipairs(g.entities) do e.alive=false end
    for _,e in ipairs(pending) do e.alive=false end
    g.entities={}; pending={}; timers={}; tweens={}; particles={}
    map=nil; g.tiles=nil; follow=nil; g.camera.x,g.camera.y=0,0
  end
  function g.go(name,...)
    local nextScene=scenes[name]; if not nextScene then error('Unknown scene: '..tostring(name),2) end
    if scene and scene.leave then scene.leave(g) end
    if not nextScene.keep then g.clear() end
    scene,sceneName=nextScene,name; g.sceneName=name
    if scene.enter then scene.enter(g,...) end
  end
  function g.on(event,fn) handlers[event]=handlers[event] or {}; table.insert(handlers[event],fn) end
  if def.update or def.draw or def.enter then
    g.scene('main',{enter=def.enter,update=def.update,draw=def.draw,background=def.backdrop,event=def.event})
  end

  -- Simulation --------------------------------------------------------------
  local function physics(e,dt)
    if e.gravity then e.vy=min(e.vy+e.gravity*dt,e.maxFall or 200) end
    if e.friction and e.onGround ~= false then
      local f=e.friction*dt
      if abs(e.vx)<=f then e.vx=0 else e.vx=e.vx-T.sign(e.vx)*f end
    end
    if e.drag then local k=max(0,1-e.drag*dt); e.vx,e.vy=e.vx*k,e.vy*k end
    if e.vx==0 and e.vy==0 then if e.gravity then e.onGround=#blockers(e,e.x,e.y+.01,'down')>0 end return end
    if map or e.collide then
      local hx,hy=g.move(e,e.vx*dt,e.vy*dt)
      e.onGround=hy and e.vy>0 or false
      if hx then if e.bounce then e.vx=-e.vx*e.bounce else e.vx=0 end; if e.hitWall then e.hitWall(e,hx,g) end end
      if hy then
        if e.bounce then e.vy=-e.vy*e.bounce else e.vy=0 end
        if e.hitFloor and e.onGround then e.hitFloor(e,hy,g) elseif e.hitCeiling and not e.onGround then e.hitCeiling(e,hy,g) end
      end
    else e.x,e.y=e.x+e.vx*dt,e.y+e.vy*dt end
    if map and e.y>map.height+(e.fallOut or 4*map.tile) and e.fell then e.fell(e,g) end
  end
  function g.step(dt)
    if g.tooSmall then pressed={}; clicked={}; return end
    g.dt=dt
    if not g.paused then
      g.time=g.time+dt; g.frame=g.frame+1
      flush()
      if scene and scene.update then scene.update(g,dt) end
      for _,e in ipairs(g.entities) do
        if e.alive then
          if e.update then e.update(e,dt,g) end
          if e.alive then physics(e,dt) end
          if e.life then e.life=e.life-dt; if e.life<=0 then e.alive=false end end
        end
      end
      for _,e in ipairs(g.entities) do
        if e.alive and e.touch then
          for _,o in ipairs(g.entities) do
            if o~=e and o.alive and e.alive and (not e.touches or o.tags[e.touches]) and T.overlap(e,o) then e.touch(e,o,g) end
          end
        end
      end
      for i=#timers,1,-1 do local t=timers[i]
        if t and not t.dead then
          t.left=t.left-dt
          if t.left<=0 then
            t.fn(g)
            if t.every and not t.dead then t.left=t.left+t.every else t.dead=true end
          end
        end
      end
      for i=#timers,1,-1 do if timers[i] and timers[i].dead then table.remove(timers,i) end end
      for i=#tweens,1,-1 do local tw=tweens[i]
        if tw and not tw.dead then
          tw.t=min(tw.time,tw.t+dt); local k=tw.ease(tw.t/tw.time)
          for key,v in pairs(tw.goal) do tw.obj[key]=tw.from[key]+(v-tw.from[key])*k end
          if tw.t>=tw.time then tw.dead=true; if tw.done then tw.done(tw.obj,g) end end
        end
        if tw and tw.dead and tweens[i]==tw then table.remove(tweens,i) end
      end
      for i=#particles,1,-1 do local p=particles[i]
        p.life=p.life-dt; p.vy=p.vy+p.gravity*dt; p.x,p.y=p.x+p.vx*dt,p.y+p.vy*dt
        if p.life<=0 then table.remove(particles,i) end
      end
      flush()
      if follow then
        local e=follow.e
        local tx,ty=e.x+e.w/2-g.width/2,e.y+e.h/2-g.height/2
        g.camera.x=g.camera.x+(tx-g.camera.x)*min(1,follow.lerp)
        g.camera.y=g.camera.y+(ty-g.camera.y)*min(1,follow.lerp)
        if follow.bounds and map then
          g.camera.x=T.clamp(g.camera.x,0,max(0,map.width-g.width))
          g.camera.y=T.clamp(g.camera.y,0,max(0,map.height-g.height))
        end
      end
      if shake.time>0 then shake.time=shake.time-dt end
    elseif scene and scene.paused then scene.paused(g,dt) end
    pressed={}; clicked={}
  end

  -- Rendering ---------------------------------------------------------------
  local function drawMap(m)
    local t=m.tile
    local tx1,ty1=max(1,floor(g.camera.x/t)+1),max(1,floor(g.camera.y/t)+1)
    local tx2,ty2=min(m.cols,floor((g.camera.x+g.width)/t)+1),min(m.rows,floor((g.camera.y+g.height)/t)+1)
    for ty=ty1,ty2 do for tx=tx1,tx2 do
      local info=m.legend[m.grid[ty][tx]]
      if info then
        local x,y=(tx-1)*t,(ty-1)*t
        if info.image or info.sprite then draw.image(info.image or info.sprite,x,y)
        elseif info.color then draw.rect(x,y,t,t,info.color) end
        if info.char then draw.text(x,y,info.char,info.fg,info.color) end
      end
    end end
  end
  local function compose()
    local W=g.width
    cover={}
    local cx,cy=floor(g.camera.x+.5),floor(g.camera.y+.5)
    if shake.time>0 then cx=cx+math.random(-shake.amount,shake.amount); cy=cy+math.random(-shake.amount,shake.amount) end
    ox,oy=0,0
    draw.rect(0,0,W,g.height,g.background)
    if scene and scene.background then scene.background(g) end
    ox,oy=cx,cy
    if map then drawMap(map) end
    local order={}
    for i,e in ipairs(g.entities) do if e.alive and e.visible~=false then order[#order+1]=e end end
    table.sort(order,function(a,b) return (a.z or 0)<(b.z or 0) or ((a.z or 0)==(b.z or 0) and a.id<b.id) end)
    for _,e in ipairs(order) do
      if e.draw then e.draw(e,g)
      else
        local x,y=floor(e.x+.5),floor(e.y+.5)
        -- In cell mode a glyph is clearer than a one-cell block of colour.
        local glyph=e.char and (g.mode=='cell' or not (e.sprite or e.color))
        local img=not glyph and imageFor(e)
        if img then draw.image(img,x,y,e.flip,e.flipY)
        elseif e.color and not glyph then draw.rect(x,y,e.w,e.h,e.color) end
        if glyph then draw.text(x,y,e.char,e.fg or e.color or colors.white,e.bg) end
      end
    end
    for _,p in ipairs(particles) do plot(p.x,p.y,p.color) end
    if scene and scene.draw then scene.draw(g) end
    ox,oy=0,0
    if g.tooSmall then
      draw.rect(0,0,W,g.height,colors.black); cover={}
      g.write(1,1,'Window too small',colors.white,colors.black)
      g.write(1,2,'Needs '..(def.minCols or g.cols)..'x'..(def.minRows or g.rows),colors.white,colors.black)
    end
  end
  -- Two most common colours become background/foreground for each cell.
  local function encode(a,b,c,d,e,f)
    if a==b and b==c and c==d and d==e and e==f then return ' ',f,f end
    local cols={a,b,c,d,e,f}; local count={}
    local first,second
    for i=1,6 do local v=cols[i]; count[v]=(count[v] or 0)+1 end
    for v,n in pairs(count) do
      if not first or n>count[first] or (n==count[first] and v<first) then second=first; first=v
      elseif not second or n>count[second] or (n==count[second] and v<second) then second=v end
    end
    local bg,fg=first,second or first
    if f==fg then bg,fg=fg,bg end
    local bits=0
    if a==fg then bits=bits+1 end; if b==fg then bits=bits+2 end; if c==fg then bits=bits+4 end
    if d==fg then bits=bits+8 end; if e==fg then bits=bits+16 end
    return CHAR[bits],fg,bg
  end
  function g.render()
    compose()
    local W,bgc=g.width,g.background
    for row=1,g.rows do
      local text,fgs,bgs={}, {}, {}
      local y=(row-1)*sy
      for col=1,g.cols do
        local ch,fg,bg
        if sx==1 then ch,fg,bg=' ',bgc,buf[y*W+col] or bgc
        else
          local i=y*W+(col-1)*2+1
          ch,fg,bg=encode(buf[i] or bgc,buf[i+1] or bgc,buf[i+W] or bgc,buf[i+W+1] or bgc,buf[i+2*W] or bgc,buf[i+2*W+1] or bgc)
        end
        local o=cover[(row-1)*g.cols+col]
        if o then ch,fg=o[1],o[2]; if o[3] then bg=o[3] end end
        text[col],fgs[col],bgs[col]=ch,HEX[fg] or '0',HEX[bg] or 'f'
      end
      target.setCursorPos(1,row)
      target.blit(table.concat(text),table.concat(fgs),table.concat(bgs))
    end
  end
  -- Read back what the screen shows, for tests and tools.
  function g.pixelAt(x,y) return buf[floor(y)*g.width+floor(x)+1] or g.background end

  -- Events and the main loop ------------------------------------------------
  function g.event(name,a,b,c,...)
    if name=='key' then
      local k=keys.getName(a); if k then held[k]=true; if not b then pressed[k]=true end end
    elseif name=='key_up' then local k=keys.getName(a); if k then held[k]=nil end
    elseif name=='mouse_click' then setMouse(b,c,a,true); clicked[a]=true
    elseif name=='mouse_drag' then setMouse(b,c,a,true)
    elseif name=='mouse_up' then setMouse(b,c,a,false)
    elseif name=='monitor_touch' and (not g.side or a==g.side) then setMouse(b,c,1,false); clicked[1]=true
    elseif name=='term_resize' or (name=='monitor_resize' and (not g.side or a==g.side)) then g.resize()
    elseif name=='terminate' or name=='sacabam_close' then g.quit() end
    if scene and scene.event then scene.event(g,name,a,b,c,...) end
    for _,fn in ipairs(handlers[name] or {}) do fn(g,a,b,c,...) end
  end
  function g.quit() g.running=false end
  -- Custom colours on advanced computers: g.palette(colors.red,0xff8040).
  -- Every changed colour is restored when the game ends.
  local savedPalette={}
  function g.palette(c,r,gr,b)
    if not (color and target.setPaletteColour) then return false end
    if not savedPalette[c] then savedPalette[c]={target.getPaletteColour(c)} end
    if gr then target.setPaletteColour(c,r,gr,b) else target.setPaletteColour(c,r) end
    return true
  end
  function g.restorePalette()
    for c,v in pairs(savedPalette) do target.setPaletteColour(c,v[1],v[2],v[3]) end
    savedPalette={}
  end
  local function advancedOnly()
    target.setBackgroundColor(colors.black); target.setTextColor(colors.white); target.clear()
    local lines={def.title or 'This game','ADVANCED COMPUTER ONLY','Needs an advanced','computer. Q / Enter','closes.'}
    for i,line in ipairs(lines) do target.setCursorPos(1,i); target.write(line) end
    while true do
      local e,k=os.pullEventRaw()
      if e=='sacabam_close' or e=='terminate' or (e=='key' and (k==keys.q or k==keys.enter or k==keys.escape)) then break end
    end
    target.clear(); target.setCursorPos(1,1)
  end
  function g.run(first,...)
    if not g.supported then return advancedOnly() end
    if first then g.go(first,...) elseif not scene and scenes.main then g.go('main') end
    g.running=true
    local frameTime=1/g.fps
    local last=os.epoch and os.epoch('utc') or os.clock()*1000
    local timer=os.startTimer(0)
    local ok,err=pcall(function()
      while g.running do
        local ev={os.pullEventRaw()}
        if ev[1]=='timer' and ev[2]==timer then
          local now=os.epoch and os.epoch('utc') or os.clock()*1000
          local dt=(now-last)/1000; last=now
          -- Fixed minimum step keeps physics steady; slow frames catch up (capped).
          g.step(max(frameTime,min(dt,.25))); if g.running then g.render() end
          timer=os.startTimer(frameTime)
        else g.event(unpack(ev)) end
      end
    end)
    os.cancelTimer(timer)
    if scene and scene.leave then pcall(scene.leave,g) end
    g.restorePalette()
    target.setBackgroundColor(colors.black); target.setTextColor(colors.white)
    target.clear(); target.setCursorPos(1,1)
    if not ok then error(err,0) end
  end
  return g
end
function T.run(def) local g=T.new(def); g.run(); return g end
return T

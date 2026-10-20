return function(api,path)
  local ui,pixels=api.ui,api.pixels
  local hex='0123456789abcdef'; local color=colors.cyan; local cx,cy=1,1
  local canvas=pixels.new(80,39,colors.black); local dirty=false; local demo=false; local angle=0
  local timer; local last; local message='Arrows move; Space draws'
  local function serialize()
    local rows={}
    for y=1,canvas.h do local row={}
      for x=1,canvas.w do local n=0; local c=canvas.data[y][x]; while c>1 do c=c/2; n=n+1 end; row[x]=hex:sub(n+1,n+1) end
      rows[y]=table.concat(row)
    end
    return {format='ccsacabam-sketch-1',width=canvas.w,height=canvas.h,rows=rows}
  end
  local function open(file)
    file=api.resolve(file)
    local peanut=api.load('system/peanut'); local data,err=peanut.read(file)
    assert(data,err); assert(data.format=='ccsacabam-sketch-1','Not a CCSacabam sketch')
    assert(type(data.width)=='number' and data.width>=1 and data.width<=160 and data.width%1==0,'Invalid width')
    assert(type(data.height)=='number' and data.height>=1 and data.height<=90 and data.height%1==0,'Invalid height')
    local fresh=pixels.new(data.width,data.height,colors.black)
    for y=1,fresh.h do
      local row=data.rows[y]; assert(type(row)=='string' and #row==fresh.w and not row:find('[^0-9a-f]'),'Invalid pixels')
      for x=1,fresh.w do fresh.set(x,y,2^tonumber(row:sub(x,x),16)) end
    end
    canvas=fresh; path=file; dirty=false; cx,cy=1,1
  end
  if path then open(path) end
  local function discard() return not dirty or ui.confirm(api,'Discard unsaved drawing?') end
  local function save()
    local file=ui.filePicker(api,{mode='save',title='Save sketch',path=path or api.resolve('untitled.sketch'),extensions={'sketch'}})
    if not file then return end
    file=api.resolve(file)
    if file~=path and fs.exists(file) and not ui.confirm(api,'Replace existing sketch?') then return end
    local ok,err=api.load('system/peanut').write(file,serialize())
    if ok then path=file; dirty=false; api.notify(api.isEncrypted() and 'Sketch saved in encrypted drive.' or 'Sketch saved in personal drive.') else api.notify(err) end
  end
  local function cube(w,h)
    local b=pixels.new(w,h,colors.black); local points={}; local scale=math.min(w,h)*0.29
    local vertices={{-1,-1,-1},{1,-1,-1},{1,1,-1},{-1,1,-1},{-1,-1,1},{1,-1,1},{1,1,1},{-1,1,1}}
    for i,v in ipairs(vertices) do
      local x=v[1]*math.cos(angle)-v[3]*math.sin(angle); local z=v[1]*math.sin(angle)+v[3]*math.cos(angle)
      local y=v[2]*math.cos(angle*.7)-z*math.sin(angle*.7); z=v[2]*math.sin(angle*.7)+z*math.cos(angle*.7)
      local f=3/(z+4); points[i]={math.floor(w/2+x*scale*f),math.floor(h/2+y*scale*f)}
    end
    for _,edge in ipairs({{1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},{1,5},{2,6},{3,7},{4,8}}) do
      local a,bp=points[edge[1]],points[edge[2]]; b.line(a[1],a[2],bp[1],bp[2],api.config().mode=='basic' and colors.white or colors.cyan)
    end
    return b
  end
  local function draw()
    local t=api.theme(); local w,h=term.getSize(); ui.clear(t)
    ui.bar(1,' Save  Open  New  3D demo',t)
    local display=demo and cube(w*2,math.max(3,(h-4)*3)) or canvas
    if api.config().mode~='basic' then pixels.draw(display,term,1,3,w,h-4)
    else
      for yy=1,math.min(h-4,math.ceil(display.h/3)) do
        for xx=1,math.min(w,math.ceil(display.w/2)) do
          local on=false
          for dy=0,2 do for dx=0,1 do local row=display.data[(yy-1)*3+dy+1]; if row and row[(xx-1)*2+dx+1] and row[(xx-1)*2+dx+1]~=colors.black then on=true end end end
          ui.text(xx,yy+2,on and '#' or ' ',t.text,t.bg)
        end
      end
    end
    for i=0,15 do
      if api.config().mode=='basic' then if i<2 then ui.text(1+i*4,2,i==0 and ' ink' or 'wipe',t.text,t.panel,4) end
      else ui.text(i*2+1,2,color==2^i and '<>' or '  ',i==15 and colors.white or colors.black,2^i,2) end
    end
    ui.text(1,h-1,'S save O open N new D demo [ ] color',t.text,t.panel,w)
    ui.text(1,h,message,t.muted,t.panel,w)
    if not demo then
      term.setCursorPos(math.ceil(cx/2),math.ceil(cy/3)+2); term.setCursorBlink(true)
    end
    api.setTitle('Sketch'..(dirty and ' *' or '')..(demo and ' / 3D' or ''))
  end
  local function command(cmd)
    if cmd=='s' then save()
    elseif cmd=='o' and discard() then
      local file=ui.filePicker(api,{mode='open',title='Open sketch',path=path or api.dir(),extensions={'sketch'}})
      if file then open(file) end
    elseif cmd=='n' and discard() then canvas=pixels.new(80,39,colors.black); dirty=false
    elseif cmd=='d' then demo=not demo; if demo then timer=os.startTimer(.1) elseif timer then os.cancelTimer(timer); timer=nil end
    elseif cmd=='[' then color=color/2; if color<1 then color=32768 end
    elseif cmd==']' then color=color*2; if color>32768 then color=1 end end
  end
  while true do
    draw(); local e,a,b,c=os.pullEventRaw()
    if e=='sacabam_close' or e=='terminate' then if discard() then if timer then os.cancelTimer(timer) end; return end
    elseif e=='timer' and a==timer and demo then angle=angle+.07; timer=os.startTimer(.1)
    elseif e=='char' then local ok,err=pcall(command,a:lower()); if not ok then api.notify(err) end
    elseif e=='key' and not demo then
      local w,h=term.getSize()
      if a==keys.left then cx=math.max(1,cx-1) elseif a==keys.right then cx=math.min(canvas.w,w*2,cx+1)
      elseif a==keys.up then cy=math.max(1,cy-1) elseif a==keys.down then cy=math.min(canvas.h,(h-4)*3,cy+1)
      elseif a==keys.space then canvas.set(cx,cy,api.config().mode=='basic' and colors.white or color); dirty=true
      elseif a==keys.backspace then canvas.set(cx,cy,colors.black); dirty=true end
      message='Pixel '..cx..', '..cy..' | Space ink / Backspace erase'
    elseif e=='mouse_up' then last=nil
    elseif e=='mouse_click' or e=='mouse_drag' then
      local _,h=term.getSize()
      if c==1 and e=='mouse_click' then
        local cmd=b<=6 and 's' or b<=12 and 'o' or b<=17 and 'n' or 'd'
        local ok,err=pcall(command,cmd); if not ok then api.notify(err) end
      elseif c==2 then color=2^math.min(15,math.floor((b-1)/2))
      elseif c>=3 and c<=h-2 and not demo then
        cx,cy=math.min(canvas.w,(b-1)*2+1),math.min(canvas.h,(c-3)*3+1)
        local ink=a==2 and colors.black or color
        if last then canvas.line(last[1],last[2],cx,cy,ink) end
        canvas.rect(cx,cy,2,3,ink); last={cx,cy}; dirty=true
      end
    end
  end
end

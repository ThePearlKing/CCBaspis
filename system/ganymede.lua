-- Ganymede: the portable UI toolkit. Draws into the current program's window.
local G={version='1.0'}
function G.theme()
  if term.isColor() then return {bg=colors.black,panel=colors.gray,text=colors.white,muted=colors.lightGray,accent=colors.cyan,onAccent=colors.black} end
  return {bg=colors.black,panel=colors.black,text=colors.white,muted=colors.white,accent=colors.white,onAccent=colors.black}
end
function G.text(x,y,value,fg,bg,width)
  local w,h=term.getSize(); if y<1 or y>h or x>w then return end
  value=tostring(value or ''); if x<1 then value=value:sub(2-x); x=1 end
  local n=math.max(0,math.min(width or #value,w-x+1)); value=value:sub(1,n)
  if width then value=value..string.rep(' ',n-#value) end
  term.setTextColor(fg or colors.white); term.setBackgroundColor(bg or colors.black)
  term.setCursorPos(x,y); term.write(value)
end
function G.control(v,t,active)
  local text=tostring(v.value==nil and '' or v.value)
  if v.kind=='button' then
    local inner=math.max(0,v.w-2); text=text:sub(1,inner)
    local pad=math.floor((inner-#text)/2)
    text=(active and '>' or '[')..string.rep(' ',pad)..text..string.rep(' ',inner-#text-pad)..(active and '<' or ']')
  elseif v.kind=='checkbox' then text=(v.value and '[x] ' or '[ ] ')..v.id
  elseif v.kind=='input' then text=text:sub(-math.max(1,v.w)) end
  G.text(v.x,v.y,text,active and t.onAccent or t.text,active and t.accent or t.panel,v.w)
end
function G.form(title)
  local form={title=title or 'Ganymede',widgets={},focus=1,closed=false,theme=G.theme}
  local function add(kind,id,x,y,width,value,callback)
    local v={kind=kind,id=id,x=x,y=y,w=width,value=value,callback=callback}
    form.widgets[#form.widgets+1]=v; return v
  end
  function form.label(id,x,y,width,text) return add('label',id,x,y,width,text) end
  function form.button(id,x,y,width,text,fn) return add('button',id,x,y,width,text,fn) end
  function form.input(id,x,y,width,text,fn) return add('input',id,x,y,width,text or '',fn) end
  function form.checkbox(id,x,y,width,value,fn) return add('checkbox',id,x,y,width,value or false,fn) end
  function form.get(id) for _,v in ipairs(form.widgets) do if v.id==id then return v.value end end end
  function form.set(id,value) for _,v in ipairs(form.widgets) do if v.id==id then v.value=value; return end end end
  function form.close() form.closed=true end
  function form.run()
    local shift=false
    while not form.closed do
      local t=form.theme(); local w,h=term.getSize(); local controls={}
      term.setBackgroundColor(t.bg); term.setTextColor(t.text); term.clear(); term.setCursorBlink(false)
      G.text(1,1,form.title,t.onAccent,t.accent,w)
      for _,v in ipairs(form.widgets) do
        if v.kind=='label' then G.text(v.x,v.y,v.value,t.text,t.bg,v.w)
        else controls[#controls+1]=v; G.control(v,t,#controls==form.focus) end
      end
      G.text(1,h,'Tab select | Enter activate',t.muted,t.panel,w)
      local e,a,b,c=os.pullEventRaw(); local v=controls[form.focus]
      local function click(item)
        if not item then return end
        if item.kind=='checkbox' then item.value=not item.value end
        if item.kind~='input' and item.callback then item.callback(form,item) end
      end
      if e=='terminate' or e=='sacabam_close' then return
      elseif e=='key_up' and (a==keys.leftShift or a==keys.rightShift) then shift=false
      elseif e=='key' then
        if a==keys.leftShift or a==keys.rightShift then shift=true
        elseif a==keys.tab then form.focus=((form.focus-1+(shift and -1 or 1))%math.max(1,#controls))+1
        elseif a==keys.enter or (a==keys.space and v and v.kind~='input') then click(v)
        elseif a==keys.backspace and v and v.kind=='input' then v.value=tostring(v.value):sub(1,-2); if v.callback then v.callback(form,v) end end
      elseif (e=='char' or e=='paste') and v and v.kind=='input' then
        v.value=(tostring(v.value)..a:gsub('[%c]','')):sub(1,4096); if v.callback then v.callback(form,v) end
      elseif e=='mouse_click' then
        for i,item in ipairs(controls) do if b>=item.x and b<item.x+item.w and c==item.y then form.focus=i; click(item); break end end
      end
    end
  end
  return form
end
return G

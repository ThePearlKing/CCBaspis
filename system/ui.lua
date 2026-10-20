local M = {}
function M.text(x, y, value, fg, bg, width)
  local w, h = term.getSize()
  if y < 1 or y > h or x > w then return end
  value = tostring(value or "")
  if x < 1 then value = value:sub(2-x); x = 1 end
  local n = math.max(0, math.min(width or #value, w-x+1))
  value = value:sub(1,n)
  if width then value = value .. string.rep(" ", n-#value) end
  if fg then term.setTextColor(fg) end
  if bg then term.setBackgroundColor(bg) end
  term.setCursorPos(x,y); term.write(value)
end
function M.fill(x,y,w,h,bg)
  for row=y,y+h-1 do M.text(x,row,"",nil,bg,w) end
end
function M.clear(t)
  term.setBackgroundColor(t.bg); term.setTextColor(t.text); term.clear(); term.setCursorBlink(false)
end
function M.bar(y, text, t)
  M.text(1,y,text,t.onAccent,t.accent,(term.getSize()))
end
function M.wrap(value,width)
  local out = {}; width = math.max(1,width)
  for line in (tostring(value) .. "\n"):gmatch("(.-)\n") do
    if line == "" then out[#out+1] = "" end
    while #line > 0 do
      local cut = math.min(#line,width)
      if #line > width then
        local last = line:sub(1,width):match("^.*() ")
        if last and last > width/2 then cut = last end
      end
      out[#out+1] = line:sub(1,cut)
      line = line:sub(cut+1)
    end
  end
  return out
end
function M.prompt(api, label, initial)
  local value = initial or ""
  while true do
    local t, w, h = api.theme(), term.getSize()
    local lines=M.wrap(label,math.max(1,w-2)); local count=math.min(#lines,h-2)
    M.fill(1,h-count-1,w,count+2,t.panel)
    for i=1,count do M.text(2,h-count-2+i,lines[i],t.text,t.panel,w-2) end
    M.text(2,h-1,"> " .. value:sub(-math.max(1,w-5)),t.text,t.bg,w-2)
    M.text(2,h,"Enter: accept   F5: cancel",t.muted,t.panel,w-2)
    local e,a = os.pullEventRaw()
    if e == "char" or e == "paste" then value = value .. a:gsub("[%c]", ""):sub(1,512-#value)
    elseif e == "key" then
      if a == keys.enter then return value
      elseif a == keys.f5 then return nil
      elseif a == keys.backspace then value = value:sub(1,-2) end
    elseif e == "sacabam_close" or e == "terminate" then return nil end
  end
end
function M.confirm(api, label)
  if api.config and api.config().skipTypedConfirmation then
    local selected=1
    while true do
      local t,w,h=api.theme(),term.getSize()
      local lines=M.wrap(label,math.max(1,w-2)); local count=math.min(#lines,h-2)
      M.fill(1,h-count-1,w,count+2,t.panel)
      for i=1,count do M.text(2,h-count-2+i,lines[i],t.text,t.panel,w-2) end
      local split=math.floor(w/2)
      M.text(1,h-1,selected==1 and '> Confirm' or '  Confirm',selected==1 and t.onAccent or t.text,selected==1 and t.accent or t.panel,split)
      M.text(split+1,h-1,selected==2 and '> Cancel' or '  Cancel',selected==2 and t.onAccent or t.text,selected==2 and t.accent or t.panel,w-split)
      M.text(1,h,'Enter: select / F5: cancel',t.muted,t.panel,w)
      local e,a,b,c=os.pullEventRaw()
      if e=='key' then
        if a==keys.enter then return selected==1
        elseif a==keys.f5 then return false
        elseif a==keys.tab or a==keys.left or a==keys.right then selected=3-selected end
      elseif e=='mouse_click' and a==1 and c==h-1 then return b<=split
      elseif e=='sacabam_close' or e=='terminate' then return false end
    end
  end
  return (M.prompt(api, label .. " (type YES)") or ""):upper() == "YES"
end
function M.filePicker(api,options)
  local path,reason=api.load('system/filepicker').choose(api,options)
  if reason=='close' and api.deferClose then api.deferClose() end
  return path
end
function M.message(api, value)
  api.notify(tostring(value))
end
return M

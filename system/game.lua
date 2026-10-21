-- Shared window lifecycle, pause/help, restart and private-drive records.
local M={}
function M.run(api,entry)
  local ui=api.ui; local w,h=term.getSize()
  if entry.advanced and not api.caps.color then
    ui.clear(api.theme())
    local lines=ui.wrap(entry.name..'\nADVANCED COMPUTER ONLY\nThis game needs the advanced display.\nQ / Enter to close.',w)
    for y,line in ipairs(lines) do if y<=h then ui.text(1,y,line,api.theme().text,api.theme().bg,w) end end
    while true do
      local e,k=os.pullEventRaw()
      if e=='sacabam_close' or e=='terminate' or (e=='key' and (k==keys.q or k==keys.escape or k==keys.enter)) then return end
    end
  end
  local factory=api.load('system/games/'..entry.id)
  local game=factory.new(); local paused,help=false,false; local timer
  local recordPath='/'..fs.combine(api.home,'.system/game-records.tbl')
  local records=api.storage.load(recordPath,{})
  if type(records)~='table' then records={} end
  local recorded=false
  local function record()
    if not game.result or recorded then return end
    recorded=true
    -- Reload so two windows finishing games cannot overwrite each other's scores.
    local current=api.storage.load(recordPath,{})
    if type(current)~='table' then current={} end
    local old=current[entry.id] or (entry.legacyId and current[entry.legacyId]); if type(old)~='table' then old={} end
    current[entry.id]={plays=(tonumber(old.plays) or 0)+1,wins=(tonumber(old.wins) or 0)+(game.result=='win' and 1 or 0),
      best=math.max(tonumber(old.best) or 0,tonumber(game.score) or 0)}
    local ok,err=api.storage.save(recordPath,current)
    if ok then records=current else api.notify('Could not save game record: '..tostring(err)) end
  end
  local function stop() if timer then os.cancelTimer(timer); timer=nil end end
  api.onExit(stop)
  local function overlay(text)
    local lines=ui.wrap(text,math.max(1,w-4)); local start=math.max(2,math.floor((h-#lines)/2))
    ui.fill(2,start-1,w-2,math.min(#lines+2,h-start),colors.black)
    for i,line in ipairs(lines) do if start+i-1<h then ui.text(3,start+i-1,line,colors.white,colors.black,w-4) end end
  end
  while true do
    w,h=term.getSize(); local enough=w>=entry.w and h>=entry.h
    local c={w=w,h=h-2,ui=ui,pixels=api.pixels,color=api.caps.color and api.config().mode~='basic'}
    c.text=function(x,y,text,fg,bg,width) ui.text(x,y+1,text,fg or colors.white,bg or colors.black,width) end
    c.cell=function(x,y,text,active)
      c.text(x,y,text,active and colors.black or colors.white,active and colors.white or colors.black)
    end
    c.drawPixels=function(canvas) api.pixels.draw(canvas,term,1,2,w,h-2) end
    ui.clear({bg=colors.black,text=colors.white}); api.setTitle(entry.name)
    if enough then game.draw(c) else
      ui.text(1,2,'Window too small',colors.white,colors.black,w)
      ui.text(1,3,'Needs '..entry.w..' x '..entry.h,colors.white,colors.black,w)
      ui.text(1,4,'F6: maximise',colors.white,colors.black,w)
    end
    local old=records[entry.id] or (entry.legacyId and records[entry.legacyId]); local best=type(old)=='table' and tonumber(old.best) or 0
    ui.text(1,1,entry.name..'  '..tostring(game.score or 0)..(w>=36 and '  Best '..tostring(best or 0) or ''),colors.white,colors.gray,w)
    ui.text(1,h,'P pause H help R new Q quit',colors.white,colors.black,w)
    if enough then
      if help then overlay(entry.help..'\nH returns. P pauses. R restarts. Q closes.')
      elseif game.result then overlay((game.result=='win' and 'You win!' or 'Game over')..'\n'..(game.message or '')..'\nR plays again. Q closes.')
      elseif paused then overlay('Paused\nP resumes.') end
    end
    record()
    if entry.timed and enough and not paused and not help and not game.result then
      if not timer then timer=os.startTimer(.1) end
    else stop() end
    local e,a,b,d=os.pullEventRaw()
    if e=='sacabam_close' or e=='terminate' or (e=='key' and (a==keys.q or a==keys.escape)) then stop(); return
    elseif e=='key' then
      local name=keys.getName(a)
      if name=='h' and not b then help=not help
      elseif name=='p' and not b then paused=not paused
      elseif name=='r' and not b then stop(); game=factory.new(); recorded=false; help=false; paused=false
      elseif enough and not paused and not help and not game.result then game.key(name,b==true) end
    elseif e=='timer' and a==timer then timer=nil; if enough and not paused and not help and not game.result then game.tick(.1) end
    elseif (e=='mouse_click' or e=='mouse_drag') and enough and not paused and not help and not game.result and game.mouse then
      game.mouse(a,b,d-1,c)
    end
  end
end
return M

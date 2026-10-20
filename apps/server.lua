return function(api,domain,root)
  local ui=api.ui; local E=api.load('system/europa'); local server
  domain=domain or 'computer-'..os.getComputerID()..'.cc'
  root=api.resolve(root or '/Sites/welcome'); local message='Offline. Choose a domain and site folder.'
  local function chooseFolder()
    local value=ui.prompt(api,'Published folder',root)
    if value then root=api.resolve(value) end
  end
  local function hasHome()
    local path=fs.combine(root,'index.cashew')
    return fs.exists(path) and not fs.isDir(path)
  end
  local function stop() if server then server.stop(); server=nil end end
  api.onExit(stop)
  local function start()
    if server then stop(); message='Server stopped.'; return end
    server=E.start(domain,root); message='Serving europa://'..domain..'/ and computer #'..os.getComputerID()
    if not hasHome() then message='Online; save index.cashew in this folder.' end
  end
  while true do
    local t=api.theme(); local w,h=term.getSize(); ui.clear(t); ui.bar(1,' Jupiter / Europa web server',t)
    ui.text(2,3,'Domain: '..domain,t.text,t.bg,w-2)
    ui.text(2,5,'Folder: '..root,t.text,t.bg,w-2)
    ui.text(2,7,server and '[ Stop server ]' or '[ Start server ]',t.onAccent,t.accent,18)
    ui.text(2,9,'Requests: '..(server and server.requests or 0),t.text,t.bg,w-2)
    local home=hasHome()
    ui.text(2,10,home and 'Home: index.cashew / ready' or 'Home: MISSING index.cashew',home and t.muted or t.danger,t.bg,w-2)
    ui.text(2,11,server and server.lastPath and (server.lastStatus..' '..server.lastPath) or 'No requests yet.',t.muted,t.bg,w-2)
    ui.text(1,h-1,message,t.text,t.panel,w)
    ui.text(1,h,'Enter start/stop | D domain | R folder',t.muted,t.panel,w)
    local e,a,b,c=os.pullEventRaw()
    if e=='sacabam_close' or e=='terminate' then stop(); return end
    local ok,err=pcall(function()
      if e=='rednet_message' and server then server.receive(a,b,c)
      elseif e=='key' and a==keys.enter then start()
      elseif e=='char' then
        if a=='d' and not server then domain=ui.prompt(api,'Domain name',domain) or domain
        elseif a=='r' and not server then chooseFolder() end
      elseif e=='mouse_click' then
        if c==3 and not server then domain=ui.prompt(api,'Domain name',domain) or domain
        elseif c==5 and not server then chooseFolder()
        elseif c==7 then start() end
      end
    end)
    if not ok then message=tostring(err); api.notify(err) end
  end
end

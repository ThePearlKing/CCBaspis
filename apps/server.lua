return function(api,domain,root)
  local ui=api.ui; local E=api.load('system/europa'); local server
  domain=domain or 'computer-'..os.getComputerID()..'.cc'
  root=root or '/Sites/welcome'; local message='Offline. Choose a domain and site folder.'
  local function stop() if server then server.stop(); server=nil end end
  api.onExit(stop)
  local function start()
    if server then stop(); message='Server stopped.'; return end
    server=E.start(domain,root); message='Serving europa://'..domain..'/ and computer #'..os.getComputerID()
  end
  while true do
    local t=api.theme(); local w,h=term.getSize(); ui.clear(t); ui.bar(1,' Jupiter / Europa web server',t)
    ui.text(2,3,'Domain: '..domain,t.text,t.bg,w-2)
    ui.text(2,5,'Folder: '..root,t.text,t.bg,w-2)
    ui.text(2,7,server and '[ Stop server ]' or '[ Start server ]',t.onAccent,t.accent,18)
    ui.text(2,9,'Requests: '..(server and server.requests or 0),t.text,t.bg,w-2)
    ui.text(2,10,'Home page: index.cashew',t.muted,t.bg,w-2)
    ui.text(1,h-1,message,t.text,t.panel,w)
    ui.text(1,h,'Enter start/stop | D domain | R folder',t.muted,t.panel,w)
    local e,a,b,c=os.pullEventRaw()
    if e=='sacabam_close' or e=='terminate' then stop(); return end
    local ok,err=pcall(function()
      if e=='rednet_message' and server then server.receive(a,b,c)
      elseif e=='key' and a==keys.enter then start()
      elseif e=='char' then
        if a=='d' and not server then domain=ui.prompt(api,'Domain name',domain) or domain
        elseif a=='r' and not server then root=ui.prompt(api,'Published folder',root) or root end
      elseif e=='mouse_click' then
        if c==3 and not server then domain=ui.prompt(api,'Domain name',domain) or domain
        elseif c==5 and not server then root=ui.prompt(api,'Published folder',root) or root
        elseif c==7 then start() end
      end
    end)
    if not ok then message=tostring(err); api.notify(err) end
  end
end

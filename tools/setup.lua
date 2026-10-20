-- Full-screen setup wizard. Embedded in the offline installer; no downloads.
local S={}
function S.run(package,installer)
  local native=term.current(); local color=native.isColor()
  local oldFG,oldBG=native.getTextColor(),native.getBackgroundColor()
  local page,focus,scroll='welcome','next',0
  local options={mode=color and 'color' or 'basic',encrypt=false,initialize=true}
  local password,confirmation,entropy='','',{}
  local problem,progress,result,controls,hits,rows
  local ensure=true; local shift=false; local finished=false; local cancelled=false
  local existing=fs.exists(installer.target..'/vault/data.scv')
  if existing then
    local file=fs.open(installer.target..'/vault/data.scv','rb')
    if file then options.encrypt=file.read(4)=='SCV1'; file.close() end
  end
  local bytes,count=0,0
  for _,file in pairs(package.files) do bytes=bytes+#file.data; count=count+1 end
  local names={welcome='Welcome',display='Display',privacy='Privacy',password='Password',review='Ready to install',
    installing='Installing',done='Installation complete',error='Installation stopped'}
  local descriptions={basic='Monochrome windows and keyboard navigation.',color='Color windows with mouse and keyboard controls.',
    render='Color, subpixel graphics and custom banner fonts.'}
  local function palette()
    return color and {bg=colors.black,panel=colors.gray,text=colors.white,muted=colors.lightGray,
      accent=colors.cyan,onAccent=colors.black,button=colors.lime,onButton=colors.black,danger=colors.red}
      or {bg=colors.black,panel=colors.black,text=colors.white,muted=colors.white,
      accent=colors.white,onAccent=colors.black,button=colors.white,onButton=colors.black,danger=colors.white}
  end
  local function pages()
    local list={'welcome','display','privacy'}
    if options.encrypt and not existing then list[#list+1]='password' end
    list[#list+1]='review'; return list
  end
  local function position()
    for i,id in ipairs(pages()) do if id==page then return i end end
    return #pages()
  end
  local function change(id)
    page=id; scroll=0; problem=nil; ensure=true
    focus=id=='display' and options.mode or id=='privacy' and not existing and (options.encrypt and 'on' or 'off')
      or id=='password' and 'password' or 'next'
  end
  local function draw()
    term.redirect(native)
    local w,h=native.getSize(); local t=palette()
    native.setBackgroundColor(t.bg); native.setTextColor(t.text); native.clear(); native.setCursorBlink(false)
    local function text(x,y,value,fg,bg,width)
      if y<1 or y>h or x>w then return end
      value=tostring(value or ''); width=math.max(0,math.min(width or #value,w-x+1))
      native.setCursorPos(math.max(1,x),y); native.setTextColor(fg or t.text); native.setBackgroundColor(bg or t.bg)
      native.write(value:sub(1,width)..string.rep(' ',math.max(0,width-#value)))
    end
    text(1,1,' CCSacabam / Setup',t.onAccent,t.accent,w)
    if page~='installing' then text(w-2,1,' X ',color and colors.white or t.onAccent,t.danger,3) end
    text(2,3,names[page],t.text,t.bg,w-2)
    if w>=40 and page~='installing' and page~='done' and page~='error' then
      text(w-12,3,'Step '..position()..' of '..#pages(),t.muted,t.bg,12)
    end
    if h>=14 then text(2,4,string.rep('-',w-2),t.panel,t.bg,w-2) end
    local start=h>=14 and 6 or 4; local finish=h-4; local visible=math.max(1,finish-start+1)
    rows,controls,hits={},{},{}
    local width=math.max(1,w-4)
    local function line(value,muted)
      value=tostring(value or '')
      if value=='' then rows[#rows+1]={text=''} end
      for part in (value..'\n'):gmatch('(.-)\n') do
        while #part>0 do
          local n=math.min(#part,width)
          if #part>width then local cut=part:sub(1,width):match('^.*() '); if cut and cut>width/2 then n=cut end end
          rows[#rows+1]={text=part:sub(1,n),muted=muted}; part=part:sub(n+1)
        end
      end
    end
    local function option(id,label,selected)
      rows[#rows+1]={id=id,text=(selected and '(*) ' or '( ) ')..label,selected=selected}
      controls[#controls+1]=id
    end
    if page=='welcome' then
      line('Windows, Lua programs and a desktop made for ComputerCraft.')
      line(''); line('We will set up your display and personal drive.')
      line('Your files stay in place. Existing startup programs are backed up.',true)
    elseif page=='display' then
      line(color and 'Advanced computer detected' or 'Basic computer detected',true); line('')
      option('basic','Basic / monochrome',options.mode=='basic')
      if color then option('color','Color desktop',options.mode=='color'); option('render','Render / subpixels',options.mode=='render') end
      line(''); line(descriptions[options.mode],true)
      if not color then line('This computer uses keyboard controls. All core apps are available.',true) end
    elseif page=='privacy' then
      if existing then
        line('Your personal drive is already set up.'); line('')
        line(options.encrypt and 'Encryption: ON / password protected' or 'Encryption: OFF / no password')
        line('The upgrade keeps your files and encryption setting. Change it later in Settings.',true)
      else
        option('off','Off / no password',not options.encrypt)
        option('on','On / encrypted files',options.encrypt)
        line(''); line('Fine to leave off on a private computer.')
        line('On a shared server, try encryption: it is the main security feature for saved files.',true)
        line(options.encrypt and 'You will create a password next.' or 'Boot straight into your desktop. Files remain readable outside the OS.',true)
      end
    elseif page=='password' then
      line('Protect your encrypted drive.'); line('Use 12+ characters. Keep it safe.',true); line('')
      line('Password',true); rows[#rows+1]={id='password',field=true,text=string.rep('*',math.min(#password,width-2))}; controls[#controls+1]='password'
      line('Confirm password',true); rows[#rows+1]={id='confirmation',field=true,text=string.rep('*',math.min(#confirmation,width-2))}; controls[#controls+1]='confirmation'
      line('There is no password reset.',true)
    elseif page=='review' then
      line('Display: '..options.mode)
      line('Encryption: '..(options.encrypt and 'ON' or 'OFF'))
      line(options.encrypt and 'Login: password protected' or 'Login: none / straight to desktop')
      line(''); line('Install: '..installer.target,true)
      line(count..' files / '..math.ceil(bytes/1024)..' KiB',true)
      local free=fs.getFreeSpace('/'); line('Free disk: '..(type(free)=='number' and math.floor(free/1024)..' KiB' or tostring(free)),true)
      line('Startup will be backed up. '..(existing and 'Your personal drive will be kept.' or 'Your existing files will be kept.'),true)
    elseif page=='installing' then
      line(progress.phase); line('')
      local bar=math.max(2,width-7); local n=math.floor(bar*progress.percent/100)
      line('['..string.rep('=',n)..string.rep(' ',bar-n)..'] '..progress.percent..'%')
      line(''); line(progress.detail,true); line('Please leave the computer running.',true)
    elseif page=='done' then
      line('CCSacabam is ready.'); line('')
      line(options.encrypt and 'Your drive is encrypted.' or 'No password. Straight to the desktop.')
      line('Run /ccsacabam/boot.lua or reboot.',true)
      line(''); line('Startup backup:',true); line(result.backup,true)
    elseif page=='error' then
      line('Setup could not finish.'); line(''); line(tostring(problem)); line('')
      line('Your existing drive was not intentionally erased. Review the error before retrying.',true)
    end
    if page~='installing' then
      if page~='done' then controls[#controls+1]='back' end
      controls[#controls+1]='next'
    end
    if ensure then
      for i,row in ipairs(rows) do if row.id==focus then
        if i<=scroll then scroll=i-1 elseif i>scroll+visible then scroll=i-visible end
      end end
      ensure=false
    end
    scroll=math.max(0,math.min(scroll,math.max(0,#rows-visible)))
    local cursor
    for i=1,visible do
      local row=rows[scroll+i]
      if row then
        local active=row.id==focus
        local bg=active and t.accent or row.field and t.panel or t.bg
        text(3,start+i-1,row.field and (' '..row.text) or row.text,active and t.onAccent or row.muted and t.muted or t.text,bg,width)
        if row.id then hits[#hits+1]={id=row.id,x=3,y=start+i-1,w=width} end
        if active and row.field then cursor={math.min(w-1,4+#row.text),start+i-1} end
      end
    end
    if #rows>visible then text(w,finish,scroll+visible<#rows and 'v' or '^',t.muted) end
    if problem and page~='error' then text(2,h-3,problem,t.text,t.danger,w-2) end
    if page~='installing' then
      local back=page=='welcome' and 'Exit' or page=='error' and 'Exit' or 'Back'
      local next=page=='review' and (existing and 'Upgrade' or 'Install') or page=='done' and 'Finish' or page=='error' and 'Retry' or page=='welcome' and 'Begin' or 'Next'
      local function button(id,label,x,bw,primary)
        local value=(focus==id and '>' or '[')..' '..label..' '..(focus==id and '<' or ']')
        text(x,h-2,value,primary and t.onButton or t.text,primary and t.button or t.panel,bw)
        hits[#hits+1]={id=id,x=x,y=h-2,w=bw}
      end
      if page~='done' then button('back',back,2,math.min(10,w-12),false) end
      button('next',next,w-math.min(13,w-10),math.min(12,w-10),true)
    end
    text(1,h,page=='installing' and ' Installing - please wait' or (w>=40 and ' Arrows select | Enter next | Tab | F5 exit' or 'Enter next / F5 exit'),t.muted,t.panel,w)
    if cursor then native.setCursorPos(cursor[1],cursor[2]); native.setCursorBlink(true) end
  end
  local function update(phase,done,total,detail)
    local ranges={['Checking package']={0,20},['Preparing installation']={20,5},['Installing files']={25,50},
      ['Preparing personal drive']={75,20},['Finishing installation']={95,5}}
    local range=ranges[phase] or {0,100}
    local nextProgress={phase=phase,detail=detail or '',percent=math.floor(range[1]+range[2]*(total>0 and done/total or 0))}
    local changed=not progress or progress.phase~=phase or progress.detail~=nextProgress.detail or progress.percent~=nextProgress.percent
    progress=nextProgress; if changed then draw() end
    os.queueEvent('ccsacabam_setup_tick')
    while true do local e=os.pullEventRaw(); if e=='ccsacabam_setup_tick' then break elseif e=='term_resize' then draw() end end
  end
  local function activate(id)
    if id=='basic' or id=='color' or id=='render' then options.mode=id; focus=id; ensure=true; return end
    if id=='off' or id=='on' then options.encrypt=id=='on'; focus=id; ensure=true; return end
    if id=='password' or id=='confirmation' then focus=id; ensure=true; return end
    if id=='back' then
      if page=='welcome' or page=='error' then cancelled=true; finished=true
      else change(pages()[math.max(1,position()-1)]) end
    elseif id=='next' then
      if page=='done' then finished=true; return end
      if page=='error' then change(options.encrypt and not existing and 'password' or 'review'); return end
      if page=='password' then
        if #password<12 then problem='Use at least 12 characters.'; return end
        if password~=confirmation then problem='Passwords do not match.'; return end
      end
      if page=='review' then
        page='installing'; options.password=password; options.entropy=table.concat(entropy,':'); options.progress=update
        progress={phase='Starting setup',percent=0,detail='Preparing your computer'}; draw()
        local ok,value=pcall(installer.install,package,options)
        options.password,options.entropy,options.progress=nil,nil,nil; password,confirmation,entropy='','',{}
        if ok then result=value; change('done') else change('error'); problem=tostring(value) end
      else change(pages()[position()+1]) end
    end
  end
  local ok,err=pcall(function()
    while not finished do
      draw(); local e,a,b,c=os.pullEventRaw()
      if e=='terminate' or (e=='key' and a==keys.f5) then cancelled=page~='done'; finished=true
      elseif e=='key_up' and (a==keys.leftShift or a==keys.rightShift) then shift=false
      elseif e=='key' then
        if a==keys.leftShift or a==keys.rightShift then shift=true
        elseif a==keys.tab or a==keys.up or a==keys.down then
          local index=1; for i,id in ipairs(controls) do if id==focus then index=i end end
          local direction=(a==keys.up or (a==keys.tab and shift)) and -1 or 1
          focus=controls[(index-1+direction)%#controls+1]; ensure=true
          if a~=keys.tab and (page=='display' or page=='privacy') and focus~='back' and focus~='next' then activate(focus) end
        elseif a==keys.enter then
          if focus=='basic' or focus=='color' or focus=='render' or focus=='off' or focus=='on' then activate(focus) end
          activate(focus=='back' and 'back' or focus=='password' and 'confirmation' or 'next')
        elseif a==keys.space and page~='password' then activate(focus)
        elseif a==keys.backspace then
          if focus=='password' then password=password:sub(1,-2)
          elseif focus=='confirmation' then confirmation=confirmation:sub(1,-2)
          elseif page~='password' then activate('back') end
        elseif a==keys.pageDown then scroll=scroll+5 elseif a==keys.pageUp then scroll=scroll-5 end
      elseif (e=='char' or e=='paste') and page=='password' and (focus=='password' or focus=='confirmation') then
        a=a:gsub('[%c]',''); entropy[#entropy+1]=tostring(os.epoch and os.epoch('utc') or os.clock())
        if focus=='password' then password=(password..a):sub(1,256) else confirmation=(confirmation..a):sub(1,256) end
        problem=nil
      elseif e=='mouse_click' and color and a==1 then
        if c==1 and b>=select(1,native.getSize())-2 then cancelled=page~='done'; finished=true
        else for _,hit in ipairs(hits) do if c==hit.y and b>=hit.x and b<hit.x+hit.w then activate(hit.id); break end end end
      elseif e=='mouse_scroll' then scroll=scroll+a*2 end
    end
  end)
  password,confirmation,options.password='','',nil
  native.setCursorBlink(false); native.setTextColor(oldFG); native.setBackgroundColor(oldBG)
  native.clear(); native.setCursorPos(1,1)
  if not ok then error(err,0) end
  if cancelled then print('Setup cancelled.'); return false end
  print('CCSacabam installed. Run /ccsacabam/boot.lua or reboot.'); return true
end
return S

-- Settings tab: keep the controls readable even with a low-contrast user theme.
return function(api)
  local ui=api.ui; local config=api.load('system/config')
  local self={editing=false}; local selected,offset,color=1,0,1; local rows=1
  local neutral=config.theme({mode='basic'})
  local confirmApi={}; for k,v in pairs(api) do confirmApi[k]=v end
  confirmApi.theme=function() return neutral end
  local function index(value) for n=1,16 do if 2^(n-1)==value then return n end end return 1 end
  local function store(key,value)
    local c=api.config(); local profile=config.profile(c); local previous=c.customColors
    local nextColors={}; for k,v in pairs(previous or {}) do nextColors[k]=v end
    local changed={}; for k,v in pairs(nextColors[profile] or {}) do changed[k]=v end
    if key then changed[key]=value else changed={} end
    nextColors[profile]=changed; c.customColors=nextColors
    local ok,err=api.saveConfig()
    if not ok then api.config().customColors=previous; api.notify(err); return false end
    return true
  end
  local function begin()
    self.editing=true; color=index(api.theme()[config.colorFields[selected][1]])
  end
  local function apply()
    if store(config.colorFields[selected][1],2^(color-1)) then self.editing=false end
  end
  local function swatch(x,y,width,n,active,label)
    local value=2^(n-1)
    local r,g,b=term.getPaletteColor(value)
    local fg=(r+g+b)/3>.5 and colors.black or colors.white
    ui.text(x,y,label or ((active and '>' or ' ')..string.format('%x',n-1)..(active and '<' or ' ')),fg,value,width)
  end
  function self.draw()
    local w,h=term.getSize(); local t=api.theme()
    ui.fill(1,3,w,h-2,neutral.bg)
    if self.editing then
      local field=config.colorFields[selected]
      ui.text(1,3,field[2],neutral.text,neutral.bg,w)
      if h>=10 then
        local cell=math.floor(w/4)
        for n=1,16 do swatch(1+((n-1)%4)*cell,4+math.floor((n-1)/4),cell,n,n==color) end
        if h>=12 then
          local preview={}; for k,v in pairs(t) do preview[k]=v end
          preview[field[1]]=2^(color-1)
          ui.text(1,8,' Title   - + X ',preview.titleText,preview.title,w)
          ui.text(1,9,' Sample text ',preview.text,preview.bg,w)
          ui.text(1,10,' Selected item ',preview.onAccent,preview.accent,w)
        end
        ui.text(1,h-2,config.colorNames[color],neutral.text,neutral.bg,w)
      else
        swatch(1,4,w,color,true,'< '..config.colorNames[color]..' >')
        if h>=8 then ui.text(1,5,config.colorNames[color],neutral.text,neutral.bg,w) end
      end
      local split=math.floor(w/2)
      ui.text(1,h-1,'[Apply]',neutral.onAccent,neutral.accent,split)
      ui.text(split+1,h-1,'[Cancel]',neutral.text,neutral.panel,w-split)
      ui.text(1,h,'Arrows / Enter / F5',neutral.text,neutral.bg,w)
    else
      rows=math.max(1,h-5)
      if selected<=offset then offset=selected-1 elseif selected>offset+rows then offset=selected-rows end
      for row=1,rows do
        local n=offset+row; local field=config.colorFields[n]
        if field then
          ui.text(1,row+2,(n==selected and '> ' or '  ')..field[2],n==selected and neutral.onAccent or neutral.text,
            n==selected and neutral.accent or neutral.bg,w-3)
          swatch(w-2,row+2,3,index(t[field[1]]),false)
        end
      end
      ui.text(1,h-2,config.colorNames[index(t[config.colorFields[selected][1]])]..' / '..config.profile(api.config()),neutral.text,neutral.bg,w)
      ui.text(1,h-1,' Sample [selected] ',t.text,t.bg,w)
      ui.text(9,h-1,'[selected]',t.onAccent,t.accent,math.min(10,w-8))
      ui.text(1,h,'Enter edit  R reset',neutral.text,neutral.bg,w)
    end
  end
  function self.event(e,a,b,c)
    local w,h=term.getSize()
    if self.editing then
      if e=='key' then
        if a==keys.f5 or a==keys.escape then self.editing=false
        elseif a==keys.enter then apply()
        elseif a==keys.left then color=math.max(1,color-1)
        elseif a==keys.right then color=math.min(16,color+1)
        elseif a==keys.up then color=math.max(1,color-(h>=10 and 4 or 1))
        elseif a==keys.down then color=math.min(16,color+(h>=10 and 4 or 1)) end
      elseif e=='mouse_click' and a==1 then
        if c==h-1 then if b<=math.floor(w/2) then apply() else self.editing=false end
        elseif h>=10 and c>=4 and c<=7 then
          color=math.min(16,(c-4)*4+math.min(4,math.floor((b-1)/math.floor(w/4))+1))
        elseif h<10 and c==4 then color=math.max(1,math.min(16,color+(b<=math.floor(w/2) and -1 or 1))) end
      elseif e=='mouse_scroll' then color=math.max(1,math.min(16,color+a)) end
    elseif e=='key' then
      if a==keys.up then selected=math.max(1,selected-1)
      elseif a==keys.down then selected=math.min(#config.colorFields,selected+1)
      elseif a==keys.pageUp then selected=math.max(1,selected-rows)
      elseif a==keys.pageDown then selected=math.min(#config.colorFields,selected+rows)
      elseif a==keys.home then selected=1
      elseif a==keys['end'] then selected=#config.colorFields
      elseif a==keys.enter then begin() end
    elseif e=='char' and a:lower()=='r' then
      if ui.confirm(confirmApi,'Reset '..config.profile(api.config())..' colours?') then store() end
    elseif e=='mouse_click' and a==1 and c>=3 and c<3+rows and config.colorFields[offset+c-2] then
      selected=offset+c-2; begin()
    elseif e=='mouse_scroll' then selected=math.max(1,math.min(#config.colorFields,selected+a)) end
  end
  return self
end

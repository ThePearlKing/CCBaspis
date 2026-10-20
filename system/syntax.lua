-- Editor lexing/completion only. Buffer contents are never executed.
local S={}
local function words(text)
  local out={}; for word in text:gmatch('%S+') do out[word]=true end; return out
end
local keywords={
  lua=words('and break do else elseif end false for function goto if in local nil not or repeat return then true until while'),
  peanut=words('true false null'),
  pistachio=words('app let set if else end repeat on every function call quit notify load save label banner button input password checkbox progress panel frame background status text column and or not true false null'),
  cashew=words('cashew html head body main div title h1 h2 p pre a button input label br hr script'),
}
local builtins={
  lua=words('assert error ipairs next pairs pcall print printError read require select tonumber tostring type unpack write xpcall'),
  peanut={},
  pistachio=words('advanced color render width height index key held char str num len min max abs floor round upper lower peanut encode seal unseal array random slice'),
  cashew=words('title href id name value type'),
}
local modules=words('fs term os math string table textutils shell colors colours keys http rednet peripheral paintutils window turtle pocket vector settings parallel bit32')
local libraries={peanut='decode parse encode stringify read write array null',ganymede='form',europa='address relative path serve'}
function S.language(path)
  local ext=tostring(path or ''):lower():match('%.([%w]+)$')
  return ({lua='lua',peanut='peanut',json='peanut',pist='pistachio',pistachio='pistachio',cashew='cashew'})[ext]
end
function S.line(line,language,previous)
  local state={}; for k,v in pairs(previous or {}) do state[k]=v end
  local out={}; local i=1
  local function mark(last,kind)
    last=math.min(last,#line)
    for n=i,last do out[n]=kind end; i=last+1
  end
  while i<=#line do
    local c=line:sub(i,i); local rest=line:sub(i); local lang=state.script and 'pistachio' or language
    if state.block then
      local a,b=line:find(state.block,i,true)
      mark(b or #line,state.blockKind); if a then state.block,state.blockKind=nil,nil end
    elseif state.quote then
      local j=i
      while j<=#line do
        local ch=line:sub(j,j)
        if ch=='\\' and lang~='cashew' then j=j+2
        elseif ch==state.quote then j=j+1; state.quote=nil; break else j=j+1 end
      end
      mark(j-1,'s')
    elseif language=='cashew' and rest:sub(1,9)=='</script>' then
      state.script=nil; state.tag=true; state.closing=true; state.tagName=true; mark(i+1,'o')
    elseif language=='cashew' and not state.script and rest:sub(1,4)=='<!--' then
      state.block='-->'; state.blockKind='c'; mark(i+3,'c')
    elseif language=='cashew' and not state.script and c=='<' then
      state.tag=true; state.closing=rest:sub(1,2)=='</'; state.tagName=true
      mark(i+(state.closing and 1 or 0),'o')
    elseif language=='cashew' and state.tag then
      if c=='>' then
        state.tag=nil; if state.nextScript then state.script=true end
        state.nextScript=nil; mark(i,'o')
      elseif c=='"' or c=="'" then state.quote=c; mark(i,'s')
      elseif c:match('[%a_]') then
        local word=rest:match('^[%w_-]+')
        if state.tagName then
          state.nextScript=word:lower()=='script' and not state.closing; state.tagName=nil
          mark(i+#word-1,'k')
        else mark(i+#word-1,'b') end
      else mark(i,c:match('%s') and 't' or 'o') end
    elseif language=='cashew' and not state.script then
      local entity=rest:match('^&[%w#]+;'); local variable=rest:match('^{[%w_]+}')
      if entity or variable then mark(i+#(entity or variable)-1,'b') else mark(i,'t') end
    elseif lang=='lua' and rest:sub(1,2)=='--' then
      local equal=rest:match('^%-%-%[(=*)%[')
      if equal then state.block=']'..equal..']'; state.blockKind='c'; mark(i+#equal+3,'c')
      else mark(#line,'c') end
    elseif (lang=='pistachio' or lang=='peanut') and (c=='#' or (lang=='peanut' and rest:sub(1,2)=='//')) then mark(#line,'c')
    elseif lang=='lua' and rest:match('^%[=*%[') then
      local equal=rest:match('^%[(=*)%['); state.block=']'..equal..']'; state.blockKind='s'; mark(i+#equal+1,'s')
    elseif c=='"' or (lang=='lua' and c=="'") then state.quote=c; mark(i,'s')
    elseif c:match('%d') or (c=='.' and rest:sub(2,2):match('%d')) then
      local number=rest:match('^0[xX][%x]+') or rest:match('^%d*%.?%d+[eE][+-]?%d+') or rest:match('^%d*%.?%d+')
      mark(i+#number-1,'n')
    elseif c:match('[%a_]') then
      local word=rest:match('^[%a_][%w_]*')
      local kind=keywords[lang][word] and 'k' or builtins[lang][word] and 'b' or 't'
      if lang=='lua' and (modules[word] or libraries[word]) then kind='b' end
      if lang=='peanut' and line:sub(i+#word):match('^%s*[:=]') then kind='b' end
      mark(i+#word-1,kind)
    else mark(i,c:match('[%s]') and 't' or 'o') end
  end
  return table.concat(out),state
end
function S.document(lines,language)
  local result={styles={},before={}}; local state={}
  for i,line in ipairs(lines) do
    result.before[i]=state; result.styles[i],state=S.line(line,language,state)
  end
  return result
end
function S.complete(lines,language,x,y,document)
  local before=lines[y]:sub(1,x-1)
  local _,state=S.line(before,language,document.before[y])
  if state.quote or state.block then return {},'' end
  local styles=document.styles[y]
  if styles:sub(x-1,x-1)=='c' then return {},'' end
  local prefix=before:match('([%a_][%w_%.]*)$') or ''
  local active=state.script and 'pistachio' or language
  if language=='cashew' and not state.script and not state.tag then return {},'' end
  local pool={}
  if active=='lua' then
    local module=prefix:match('^([%a_][%w_]*)%.')
    if module then
      if modules[module] then
        local value=_ENV[module]
        if type(value)=='table' then
          for key in pairs(value) do if type(key)=='string' and key:match('^[%a_][%w_]*$') then pool[module..'.'..key]=true end end
        end
      elseif libraries[module] then for key in libraries[module]:gmatch('%S+') do pool[module..'.'..key]=true end end
    else
      for key in pairs(modules) do pool[key]=true end
      for key in pairs(libraries) do pool[key]=true end
    end
  end
  for key in pairs(keywords[active]) do pool[key]=true end
  for key in pairs(builtins[active]) do pool[key]=true end
  if active~='cashew' then
    for row,line in ipairs(lines) do
      local pos=1
      while true do
        local a,b,word=line:find('([%a_][%w_]*)',pos); if not a then break end
        local kind=document.styles[row]:sub(a,a)
        if kind~='c' and kind~='s' then pool[word]=true end
        pos=b+1
      end
    end
  end
  local out={}
  for word in pairs(pool) do if word~=prefix and word:sub(1,#prefix)==prefix then out[#out+1]=word end end
  table.sort(out); while #out>32 do table.remove(out) end
  return out,prefix
end
return S

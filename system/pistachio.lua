-- Pistachio Script: parsed application language, never evaluated as Lua.
local P={version='1.0'}
local function fail(line,message) error('Pistachio line '..tostring(line)..': '..message,0) end
local function tokens(source,line)
  local out={}; local i=1
  while i<=#source do
    local c=source:sub(i,i)
    if c:match('%s') then i=i+1
    elseif c=='"' then
      local value={}; i=i+1; local closed=false
      while i<=#source do
        c=source:sub(i,i); i=i+1
        if c=='"' then closed=true; break
        elseif c=='\\' then
          c=source:sub(i,i); i=i+1
          local map={n='\n',t='\t',r='\r',['"']='"',['\\']='\\'}
          if not map[c] then fail(line,'Unknown string escape') end
          value[#value+1]=map[c]
        else value[#value+1]=c end
      end
      if not closed then fail(line,'Unclosed string') end
      out[#out+1]={kind='string',value=table.concat(value)}
    elseif c:match('%d') or (c=='.' and source:sub(i+1,i+1):match('%d')) then
      local number=source:match('^(%d*%.?%d+[eE][+-]?%d+)',i) or source:match('^(%d*%.?%d+)',i)
      out[#out+1]={kind='number',value=tonumber(number)}; i=i+#number
    elseif c:match('[%a_]') then
      local name=source:match('^([%a_][%w_]*)',i)
      out[#out+1]={kind='name',value=name}; i=i+#name
    else
      local pair=source:sub(i,i+1)
      if pair=='==' or pair=='!=' or pair=='<=' or pair=='>=' or pair=='..' then c=pair; i=i+1 end
      if not ({['+']=true,['-']=true,['*']=true,['/']=true,['%']=true,['(']=true,[')']=true,
        ['<']=true,['>']=true,['==']=true,['!=']=true,['<=']=true,['>=']=true,['..']=true,
        [',']=true,['.']=true,['[']=true,[']']=true})[c] then fail(line,'Unexpected character '..c) end
      out[#out+1]={kind='symbol',value=c}; i=i+1
    end
  end
  out[#out+1]={kind='end',value=''}; return out
end
local precedence={['or']=1,['and']=2,['==']=3,['!=']=3,['<']=3,['>']=3,['<=']=3,['>=']=3,['..']=4,['+']=5,['-']=5,['*']=6,['/']=6,['%']=6}
function P.expression(source,line)
  line=line or 0; local list=tokens(source,line); local pos=1; local expression
  local function take(value)
    if list[pos].value~=value then fail(line,"Expected '"..value.."'") end
    pos=pos+1
  end
  local function atom()
    local t=list[pos]; pos=pos+1; local node
    if t.kind=='number' or t.kind=='string' then node={tag='literal',value=t.value}
    elseif t.value=='true' or t.value=='false' then node={tag='literal',value=t.value=='true'}
    elseif t.value=='not' or t.value=='-' then node={tag='unary',op=t.value,child=expression(7)}
    elseif t.value=='(' then node=expression(1); take(')')
    elseif t.kind=='name' then
      if list[pos].value=='(' then
        pos=pos+1; local args={}
        if list[pos].value~=')' then
          repeat
            args[#args+1]=expression(1)
            if list[pos].value~=',' then break end
            pos=pos+1
          until false
        end
        take(')'); node={tag='call',name=t.value,args=args}
      else node={tag='variable',name=t.value} end
    else fail(line,'Expected an expression') end
    while list[pos].value=='.' or list[pos].value=='[' do
      if list[pos].value=='.' then
        pos=pos+1; local key=list[pos]; if key.kind~='name' then fail(line,'Expected field name') end
        pos=pos+1; node={tag='index',object=node,key={tag='literal',value=key.value}}
      else pos=pos+1; local key=expression(1); take(']'); node={tag='index',object=node,key=key} end
    end
    return node
  end
  expression=function(min)
    local left=atom()
    while precedence[list[pos].value] and precedence[list[pos].value]>=min do
      local op=list[pos].value; pos=pos+1
      left={tag='binary',op=op,left=left,right=expression(precedence[op]+1)}
    end
    return left
  end
  local node=expression(1)
  if list[pos].kind~='end' then fail(line,'Unexpected expression suffix') end
  return node
end
local function strip(line)
  local quoted,escaped=false,false
  for i=1,#line do local c=line:sub(i,i)
    if quoted then
      if escaped then escaped=false elseif c=='\\' then escaped=true elseif c=='"' then quoted=false end
    elseif c=='"' then quoted=true elseif c=='#' then return line:sub(1,i-1) end
  end
  return line
end
function P.parse(source)
  assert(#source<=131072,'Pistachio source exceeds 128 KiB')
  local rows={}
  for line in (source..'\n'):gmatch('(.-)\n') do rows[#rows+1]=strip(line):match('^%s*(.-)%s*$') end
  local pos=1; local block
  block=function(depth)
    if depth>32 then fail(pos,'Block nesting exceeds 32') end
    local nodes={}
    while pos<=#rows do
      local raw=rows[pos]; local line=pos; pos=pos+1
      if raw=='end' or raw=='else' then return nodes,raw end
      if raw~='' then
        local op,rest=raw:match('^(%w+)%s*(.*)$')
        if not op then fail(line,'Expected a statement') end
        local node={op=op,line=line}
        local function expr(s) return P.expression(s,line) end
        if op=='if' or op=='repeat' or op=='on' or op=='every' or op=='function' then
          if op=='on' or op=='function' then
            if not rest:match('^[%a_][%w_]*$') then fail(line,'Expected handler name') end
            node.name=rest
          else node.value=expr(rest) end
          local stop; node.body,stop=block(depth+1)
          if stop=='else' and op=='if' then node.other,stop=block(depth+1) end
          if stop~='end' then fail(line,'Missing end for '..op) end
        elseif op=='let' or op=='set' then
          node.name,rest=rest:match('^([%a_][%w_]*)%s*=%s*(.+)$')
          if not node.name then fail(line,'Use '..op..' name = expression') end
          node.value=expr(rest)
        elseif op=='label' or op=='button' or op=='input' or op=='password' or op=='checkbox' or op=='progress' or op=='banner' then
          local id,x,y,w,text=rest:match('^([%a_][%w_]*)%s+(%S+)%s+(%S+)%s+(%S+)%s+(.+)$')
          if not id then fail(line,'Use '..op..' id x y width expression') end
          node.name,node.x,node.y,node.width,node.value=id,expr(x),expr(y),expr(w),expr(text)
          if op=='input' or op=='password' or op=='checkbox' then
            if not text:match('^[%a_][%w_]*$') then fail(line,op..' needs a variable name') end
            node.bind=text
          end
        elseif op=='panel' then
          local id,x,y,w,h=rest:match('^([%a_][%w_]*)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)$')
          if not id then fail(line,'Use panel id x y width height') end
          node.name,node.x,node.y,node.width,node.height=id,expr(x),expr(y),expr(w),expr(h)
        elseif op=='load' then
          node.name,rest=rest:match('^([%a_][%w_]*)%s+(.+)$')
          if not node.name then fail(line,'Use load variable "path.peanut"') end
          node.value=expr(rest)
        elseif op=='save' then
          local name,path=rest:match('^([%a_][%w_]*)%s+(.+)$')
          if not name then fail(line,'Use save variable "path.peanut"') end
          node.name,node.value=name,expr(path)
        elseif op=='app' or op=='notify' then node.value=expr(rest)
        elseif op=='call' then
          if not rest:match('^[%a_][%w_]*$') then fail(line,'Expected function name') end; node.name=rest
        elseif op=='quit' then if rest~='' then fail(line,'quit takes no arguments') end
        else fail(line,'Unknown statement: '..op) end
        nodes[#nodes+1]=node
      end
    end
    return nodes,nil
  end
  local nodes,stop=block(0); if stop then fail(pos-1,'Unexpected '..stop) end
  return nodes
end
function P.runtime(ast,api,peanut)
  local state={vars={},handlers={},timers={},widgets={},quit=false,title='Pistachio',budget=10000,focus=1}
  local function bounded(value)
    assert(type(value)~='string' or #value<=131072,'String exceeds 128 KiB')
    return value
  end
  local builtins={str=tostring,num=function(v) return tonumber(v) or 0 end,len=function(v) return #v end,
    min=math.min,max=math.max,abs=math.abs,floor=math.floor,round=function(n) return math.floor(n+0.5) end,
    peanut=peanut.decode,encode=peanut.encode,upper=string.upper,lower=string.lower}
  local box
  local function crypto()
    assert(api.load,'Encryption functions are available only to native programs')
    if not box then box=api.load('system/seal').new(api.load('system/crypto'),api.cryptoProgress) end
    return box
  end
  builtins.seal=function(text,passphrase) return crypto().seal(text,passphrase) end
  builtins.unseal=function(data,passphrase) return crypto().unseal(data,passphrase) end
  local eval
  eval=function(n)
    state.budget=state.budget-1; assert(state.budget>=0,'Expression limit reached')
    if n.tag=='literal' then
      if type(n.value)=='string' then
        local size=0
        return bounded((n.value:gsub('{([%a_][%w_]*)}',function(k)
          local v=state.vars[k]; local part=v==nil and '{'..k..'}' or tostring(v)
          size=size+#part; assert(size<=131072,'String exceeds 128 KiB'); return part
        end)))
      end
      return n.value
    elseif n.tag=='variable' then
      if n.name=='advanced' then return api.caps.color elseif n.name=='color' then return api.config().mode~='basic'
      elseif n.name=='render' then return api.config().mode=='render'
      elseif n.name=='width' then return (term.getSize()) elseif n.name=='height' then local _,h=term.getSize(); return h
      elseif n.name=='null' then return peanut.null end
      if state.vars[n.name]==nil then error('Unknown variable: '..n.name,0) end
      return state.vars[n.name]
    elseif n.tag=='index' then return assert(eval(n.object),'Missing object')[eval(n.key)]
    elseif n.tag=='unary' then
      if n.op=='not' then return not eval(n.child) else return -eval(n.child) end
    elseif n.tag=='call' then
      local fn=builtins[n.name]; if not fn then error('Unknown function: '..n.name,0) end
      local args={}; for i,v in ipairs(n.args) do args[i]=eval(v) end; return bounded(fn((table.unpack or unpack)(args)))
    elseif n.tag=='binary' then
      local a=eval(n.left)
      if n.op=='and' then return a and eval(n.right) elseif n.op=='or' then return a or eval(n.right) end
      local b=eval(n.right); local op=n.op
      if op=='+' then return a+b elseif op=='-' then return a-b elseif op=='*' then return a*b
      elseif op=='/' then assert(b~=0,'Division by zero'); return a/b elseif op=='%' then assert(b~=0,'Division by zero'); return a%b
      elseif op=='..' then a,b=tostring(a),tostring(b); assert(#a+#b<=131072,'String exceeds 128 KiB'); return a..b
      elseif op=='==' then return a==b elseif op=='!=' then return a~=b
      elseif op=='<' then return a<b elseif op=='>' then return a>b elseif op=='<=' then return a<=b elseif op=='>=' then return a>=b end
    end
  end
  state.eval=eval
  local visual={label=true,button=true,input=true,password=true,checkbox=true,progress=true,banner=true,panel=true}
  local run
  run=function(nodes,phase)
    for _,n in ipairs(nodes) do
      state.budget=state.budget-1; if state.budget<0 then fail(n.line,'Instruction limit reached') end
      local ok,err=pcall(function()
        if n.op=='if' then run(eval(n.value) and n.body or n.other or {},phase)
        elseif n.op=='repeat' then
          local count=math.floor(tonumber(eval(n.value)) or -1); assert(count>=0 and count<=1000,'repeat range is 0..1000')
          for i=1,count do state.vars.index=i; run(n.body,phase) end
        elseif visual[n.op] then
          if phase=='render' then
            local widget={kind=n.op,id=n.name,x=math.floor(eval(n.x)),y=math.floor(eval(n.y)),w=math.floor(eval(n.width)),bind=n.bind}
            if n.op=='panel' then widget.h=math.floor(eval(n.height)) else widget.value=eval(n.value) end
            state.widgets[#state.widgets+1]=widget
          end
        elseif n.op=='on' or n.op=='function' then if phase=='init' then state.handlers[n.name]=n.body end
        elseif n.op=='every' then
          if phase=='init' then
            local interval=tonumber(eval(n.value)); assert(interval and interval>=0.1 and interval<=86400,'Timer interval must be 0.1..86400 seconds')
            state.timers[#state.timers+1]={interval=interval,body=n.body}
          end
        elseif phase~='render' then
          if n.op=='let' then
            if phase=='init' then state.vars[n.name]=eval(n.value) end
          elseif n.op=='set' then state.vars[n.name]=eval(n.value)
          elseif n.op=='app' then state.title=tostring(eval(n.value))
          elseif n.op=='notify' then api.notify(tostring(eval(n.value)))
          elseif n.op=='call' then assert(state.handlers[n.name],'Unknown function: '..n.name); run(state.handlers[n.name],phase)
          elseif n.op=='load' then local value,why=peanut.read(api.resolve(tostring(eval(n.value)))); assert(value~=nil,why); state.vars[n.name]=value
          elseif n.op=='save' then assert(peanut.write(api.resolve(tostring(eval(n.value))),state.vars[n.name]))
          elseif n.op=='quit' then state.quit=true end
        end
      end)
      if not ok then fail(n.line,tostring(err)) end
    end
  end
  function state.initialize() state.budget=10000; run(ast,'init') end
  function state.layout() state.budget=10000; state.widgets={}; run(ast,'render'); return state.widgets end
  function state.dispatch(name) state.budget=10000; if state.handlers[name] then run(state.handlers[name],'event') end end
  function state.tick(timer) state.budget=10000; run(timer.body,'event') end
  return state
end
return P

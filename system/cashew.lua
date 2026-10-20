-- Cashew: a deliberately small HTML-like document format with Pistachio events.
local C={}
local allowed={cashew=true,html=true,head=true,body=true,main=true,div=true,title=true,h1=true,h2=true,p=true,
  pre=true,a=true,button=true,input=true,label=true,br=true,hr=true,script=true}
local function entities(s)
  local named={amp='&',lt='<',gt='>',quot='"',apos="'"}
  return (s:gsub('&([#%w]+);',function(name)
    if named[name] then return named[name] end
    local n=name:match('^#x(%x+)$'); n=n and tonumber(n,16) or tonumber(name:match('^#(%d+)$'))
    if n and n>=32 and n<=255 then return string.char(n) end
    return '&'..name..';'
  end))
end
function C.parse(source)
  assert(type(source)=='string' and #source<=32768,'Cashew page exceeds 32 KiB')
  local doc={tag='document',children={},title='Cashew page',scripts={}}
  local stack={doc}; local pos,count=1,0
  while pos<=#source do
    if source:sub(pos,pos+3)=='<!--' then
      local ending=assert(source:find('-->',pos+4,true),'Unclosed comment'); pos=ending+3
    elseif source:sub(pos,pos)=='<' then
      -- Find the end of a tag while respecting quoted attribute values.
      local ending,quote
      for i=pos+1,#source do local c=source:sub(i,i)
        if quote then if c==quote then quote=nil end
        elseif c=='"' or c=="'" then quote=c elseif c=='>' then ending=i; break end
      end
      assert(ending,'Unclosed tag')
      local raw=source:sub(pos+1,ending-1); pos=ending+1
      local close=raw:match('^/%s*([%w]+)%s*$')
      if close then
        assert(#stack>1 and stack[#stack].tag==close:lower(),'Mismatched closing tag: '..close)
        table.remove(stack)
      else
        local name,rest=raw:match('^%s*([%w]+)%s*(.-)%s*$'); assert(name,'Invalid tag')
        name=name:lower(); assert(allowed[name],'Unsupported Cashew tag: '..name)
        local selfClosing=rest:sub(-1)=='/'; if selfClosing then rest=rest:sub(1,-2) end
        local node={tag=name,attributes={},children={}}
        while rest:match('%S') do
          local key,q,value,tail=rest:match('^%s*([%w_-]+)%s*=%s*(["\'])(.-)%2%s*(.*)$')
          assert(key,'Attributes must have quoted values'); assert(node.attributes[key]==nil,'Duplicate attribute: '..key)
          node.attributes[key]=entities(value); rest=tail
        end
        count=count+1; assert(count<=256,'Cashew has more than 256 elements')
        local parent=stack[#stack]; parent.children[#parent.children+1]=node
        if name=='cashew' or name=='html' then doc.title=node.attributes.title or doc.title end
        if name=='script' then
          assert(not node.attributes.src,'External scripts are not supported; use an inline Pistachio script')
          assert(not node.attributes.type or node.attributes.type=='pistachio','Only Pistachio scripts are allowed')
          local a,b=source:find('</script%s*>',pos); assert(a,'Unclosed script')
          doc.scripts[#doc.scripts+1]=source:sub(pos,a-1); pos=b+1
        elseif name~='br' and name~='hr' and name~='input' and not selfClosing then
          assert(#stack<32,'Cashew nesting limit exceeded'); stack[#stack+1]=node
        end
      end
    else
      local ending=source:find('<',pos,true) or #source+1
      local text=entities(source:sub(pos,ending-1)); pos=ending
      stack[#stack].children[#stack[#stack].children+1]={tag='text',text=text}
    end
  end
  assert(#stack==1,'Unclosed Cashew tag: '..stack[#stack].tag)
  return doc
end
function C.text(node,variables)
  local parts={}; local size=0
  local function walk(n)
    if n.tag=='text' then parts[#parts+1]=n.text else for _,child in ipairs(n.children or {}) do walk(child) end end
  end
  walk(node)
  return (table.concat(parts):gsub('{([%a_][%w_]*)}',function(key)
    local value=variables and variables[key]; local part=value==nil and '{'..key..'}' or tostring(value)
    size=size+#part; assert(size<=131072,'Rendered text exceeds 128 KiB'); return part
  end))
end
function C.safeScript(ast)
  local functions={str=true,num=true,len=true,min=true,max=true,abs=true,floor=true,round=true,
    peanut=true,encode=true,upper=true,lower=true,array=true,random=true,slice=true}
  local function expression(node)
    if type(node)~='table' then return end
    if node.tag=='call' then assert(functions[node.name],'Web pages cannot call '..node.name) end
    for _,value in pairs(node) do if type(value)=='table' then expression(value) end end
  end
  local safe={let=true,set=true,on=true,['function']=true,['if']=true,['repeat']=true,every=true,notify=true,call=true,quit=true,app=true,
    label=true,button=true,input=true,checkbox=true,progress=true,banner=true,panel=true}
  for _,node in ipairs(ast) do
    assert(safe[node.op],'Web pages cannot use '..node.op)
    for _,name in ipairs({'target','value','x','y','width','height','fg','bg'}) do expression(node[name]) end
    if node.body then C.safeScript(node.body) end
    if node.other then C.safeScript(node.other) end
  end
  return true
end
return C

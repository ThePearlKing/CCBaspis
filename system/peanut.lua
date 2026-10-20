-- Peanut 1: JSON data plus comments, identifier keys, '=' and trailing commas.
-- No code evaluation. Lua: local peanut = require('peanut')
local P={version=1}
local arrayMT={__peanut='array'}
P.null=setmetatable({},{__tostring=function() return 'null' end})
function P.array(value) return setmetatable(value or {},arrayMT) end
local function utf8(n)
  if n<128 then return string.char(n)
  elseif n<2048 then return string.char(192+math.floor(n/64),128+n%64)
  elseif n<65536 then return string.char(224+math.floor(n/4096),128+math.floor(n/64)%64,128+n%64)
  else return string.char(240+math.floor(n/262144),128+math.floor(n/4096)%64,128+math.floor(n/64)%64,128+n%64) end
end
function P.decode(text)
  assert(type(text)=='string','Peanut expects a string')
  assert(#text<=1048576,'Peanut input exceeds 1 MiB')
  local pos=1
  local function fail(message)
    local _,line=text:sub(1,pos-1):gsub('\n','')
    error('Peanut line '..(line+1)..': '..message,0)
  end
  local function skip()
    while true do
      local _,last=text:find('^%s*',pos); pos=(last or pos-1)+1
      if text:sub(pos,pos)=='#' or text:sub(pos,pos+1)=='//' then
        pos=(text:find('\n',pos,true) or #text)+1
      else return end
    end
  end
  local function quoted()
    pos=pos+1; local out={}
    while pos<=#text do
      local c=text:sub(pos,pos); pos=pos+1
      if c=='"' then return table.concat(out)
      elseif c=='\\' then
        local e=text:sub(pos,pos); pos=pos+1
        local escapes={['"']='"',['\\']='\\',['/']='/',b='\b',f='\f',n='\n',r='\r',t='\t'}
        if escapes[e] then out[#out+1]=escapes[e]
        elseif e=='u' then
          local digits=text:sub(pos,pos+3)
          if #digits~=4 or digits:find('[^%da-fA-F]') then fail('Invalid Unicode escape') end
          local code=tonumber(digits,16); pos=pos+4
          if code>=0xd800 and code<=0xdbff then
            if text:sub(pos,pos+1)~='\\u' then fail('Missing low surrogate') end
            local low=tonumber(text:sub(pos+2,pos+5),16)
            if not low or low<0xdc00 or low>0xdfff then fail('Invalid low surrogate') end
            code=0x10000+(code-0xd800)*1024+low-0xdc00; pos=pos+6
          elseif code>=0xdc00 and code<=0xdfff then fail('Unexpected low surrogate') end
          out[#out+1]=utf8(code)
        else fail('Unknown escape') end
      elseif c:byte()<32 then fail('Control character in string')
      else out[#out+1]=c end
    end
    fail('Unclosed string')
  end
  local value
  value=function(depth)
    if depth>64 then fail('Maximum nesting exceeded') end
    skip(); local c=text:sub(pos,pos)
    if c=='"' then return quoted()
    elseif c=='{' or c=='[' then
      local array=c=='['; local close=array and ']' or '}'; pos=pos+1
      local result=array and P.array() or {}; local seen={}; skip()
      if text:sub(pos,pos)==close then pos=pos+1; return result end
      while true do
        skip(); local key
        if array then key=#result+1
        else
          if text:sub(pos,pos)=='"' then key=quoted()
          else key=text:match('^([%a_][%w_]*)',pos); if not key then fail('Expected object key') end; pos=pos+#key end
          if seen[key] then fail('Duplicate key: '..key) end; seen[key]=true
          skip(); local sep=text:sub(pos,pos)
          if sep~=':' and sep~='=' then fail("Expected ':' or '='") end
          pos=pos+1
        end
        result[key]=value(depth+1); skip(); local sep=text:sub(pos,pos); pos=pos+1
        if sep==close then return result end
        if sep~=',' then fail("Expected ',' or '"..close.."'") end
        skip(); if text:sub(pos,pos)==close then pos=pos+1; return result end
      end
    elseif text:sub(pos,pos+3)=='true' then pos=pos+4; return true
    elseif text:sub(pos,pos+4)=='false' then pos=pos+5; return false
    elseif text:sub(pos,pos+3)=='null' then pos=pos+4; return P.null
    else
      local number=text:match('^(-?%d+%.?%d*[eE][+-]?%d+)',pos) or text:match('^(-?%d+%.?%d*)',pos)
      if not number then fail('Expected a value') end
      if number:match('^-?0%d') or number:sub(-1)=='.' then fail('Invalid number') end
      pos=pos+#number; local n=tonumber(number)
      if not n or n==math.huge or n==-math.huge then fail('Number is not finite') end
      return n
    end
  end
  local result=value(0); skip(); if pos<=#text then fail('Unexpected trailing data') end
  return result
end
local function quote(s)
  local escapes={['"']='\\"',['\\']='\\\\',['\b']='\\b',['\f']='\\f',['\n']='\\n',['\r']='\\r',['\t']='\\t'}
  return '"'..s:gsub('[%z\1-\31\\"]',function(c) return escapes[c] or string.format('\\u%04x',c:byte()) end)..'"'
end
function P.encode(value,pretty)
  local seen={}
  local function encode(v,depth)
    if depth>64 then error('Peanut maximum nesting exceeded',0) end
    if v==P.null or v==nil then return 'null' end
    local kind=type(v)
    if kind=='string' then return quote(v)
    elseif kind=='boolean' then return tostring(v)
    elseif kind=='number' then
      assert(v==v and v~=math.huge and v~=-math.huge,'Peanut numbers must be finite'); return string.format('%.17g',v)
    elseif kind~='table' then error('Peanut cannot encode '..kind,0) end
    assert(not seen[v],'Peanut cannot encode cycles'); seen[v]=true
    local numeric,count,max=false,0,0
    for k in pairs(v) do
      count=count+1
      if type(k)=='number' and k>=1 and k%1==0 then numeric=true; max=math.max(max,k)
      elseif type(k)~='string' then error('Invalid Peanut object key',0) end
    end
    local array=getmetatable(v)==arrayMT or numeric
    local entries={}
    if array then
      assert(max==count,'Peanut arrays must be dense and cannot have object keys')
      for i=1,max do entries[#entries+1]=encode(v[i],depth+1) end
    else
      local names={}; for k in pairs(v) do names[#names+1]=k end; table.sort(names)
      for _,k in ipairs(names) do entries[#entries+1]=quote(k)..(pretty and ': ' or ':')..encode(v[k],depth+1) end
    end
    seen[v]=nil
    local first,last=array and '[' or '{',array and ']' or '}'
    if #entries==0 then return first..last end
    if pretty then
      local indent=string.rep('  ',depth+1)
      return first..'\n'..indent..table.concat(entries,',\n'..indent)..'\n'..string.rep('  ',depth)..last
    end
    return first..table.concat(entries,',')..last
  end
  return encode(value,0)
end
function P.read(path)
  local h,err=fs.open(path,'r'); if not h then return nil,err end
  local raw=h.readAll(); h.close()
  local ok,data=pcall(P.decode,raw); if not ok then return nil,data end; return data
end
function P.write(path,value)
  local ok,data=pcall(P.encode,value,true); if not ok then return nil,data end
  local h,err=fs.open(path,'w'); if not h then return nil,err end
  local worked,why=pcall(function() h.write(data); h.close() end)
  return worked or nil,why
end
P.parse=P.decode; P.stringify=P.encode
return P

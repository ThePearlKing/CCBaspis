local M={}
function M.new(random)
  random=random or math.random
  local s={cells={},score=0}
  local function spawn()
    local empty={}; for i=1,16 do if not s.cells[i] then empty[#empty+1]=i end end
    if #empty>0 then s.cells[empty[random(1,#empty)]]=random(1,10)==10 and 4 or 2 end
  end
  local function possible()
    for y=1,4 do for x=1,4 do local i=(y-1)*4+x; local v=s.cells[i]
      if not v or (x<4 and v==s.cells[i+1]) or (y<4 and v==s.cells[i+4]) then return true end
    end end
    return false
  end
  function s.key(key)
    if s.result or not ({left=true,right=true,up=true,down=true})[key] then return end
    local changed=false
    for line=1,4 do
      local ids,values={},{}
      for n=1,4 do
        local x,y
        if key=='left' or key=='right' then x=key=='left' and n or 5-n; y=line else x=line; y=key=='up' and n or 5-n end
        ids[n]=(y-1)*4+x; if s.cells[ids[n]] then values[#values+1]=s.cells[ids[n]] end
      end
      local merged={}; local n=1
      while n<=#values do
        local v=values[n]
        if values[n+1]==v then v=v*2; s.score=s.score+v; n=n+1 end
        merged[#merged+1]=v; n=n+1
      end
      for i,id in ipairs(ids) do if s.cells[id]~=merged[i] then changed=true end; s.cells[id]=merged[i] end
    end
    if changed then spawn() end
    for _,v in pairs(s.cells) do if v>=2048 then s.result='win'; s.message='2048. Nicely crunched.' end end
    if not s.result and not possible() then s.result='lose'; s.message='No moves left.' end
  end
  function s.draw(c)
    local ox=math.floor((c.w-20)/2)+1
    for y=1,4 do for x=1,4 do
      local v=s.cells[(y-1)*4+x]; local bg=colors.black
      if c.color and v then bg=({[2]=colors.gray,[4]=colors.blue,[8]=colors.cyan,[16]=colors.purple,[32]=colors.brown,[64]=colors.red})[v] or colors.green end
      c.text(ox+(x-1)*5,1+(y-1)*2,v and string.format('%4d',v) or '   .',colors.white,bg,4)
    end end
  end
  spawn(); spawn(); return s
end
return M

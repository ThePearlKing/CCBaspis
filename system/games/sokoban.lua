local M={}
M.levels={
  {'########','#      #','# .$@  #','#      #','########'},
  {'########','# . .  #','# $ $  #','#   @  #','#      #','########'},
  {'########','#  .   #','#  $   #','# . $  #','#  @   #','#      #','########'},
  {'########','# . .  #','# $ $  #','#      #','#  $ . #','# @    #','########'},
}
function M.new()
  local s={level=1,score=0,moves=0,history={}}
  local function id(x,y) return y*16+x end
  local function copy(t) local out={}; for k,v in pairs(t) do out[k]=v end; return out end
  function s.load(level)
    s.level=level; s.map=M.levels[level]; s.crates={}; s.goals={}; s.walls={}; s.history={}; s.cleared=false
    for y,row in ipairs(s.map) do for x=1,#row do
      local ch=row:sub(x,x); local i=id(x,y)
      if ch=='#' then s.walls[i]=true elseif ch=='$' then s.crates[i]=true elseif ch=='.' then s.goals[i]=true elseif ch=='@' then s.x,s.y=x,y end
    end end
  end
  function s.key(key)
    if s.result then return end
    if s.cleared then if key=='enter' then s.load(s.level+1) end; return end
    if key=='z' and #s.history>0 then local prev=table.remove(s.history); s.x,s.y,s.crates,s.moves=prev.x,prev.y,prev.crates,prev.moves; return end
    local d=({up={0,-1},w={0,-1},down={0,1},s={0,1},left={-1,0},a={-1,0},right={1,0},d={1,0}})[key]
    if not d then return end
    local x,y=s.x+d[1],s.y+d[2]; local target=id(x,y); local beyond=id(x+d[1],y+d[2])
    if s.walls[target] or (s.crates[target] and (s.walls[beyond] or s.crates[beyond])) then return end
    s.history[#s.history+1]={x=s.x,y=s.y,crates=copy(s.crates),moves=s.moves}; if #s.history>200 then table.remove(s.history,1) end
    if s.crates[target] then s.crates[target]=nil; s.crates[beyond]=true end
    s.x,s.y=x,y; s.moves=s.moves+1
    local complete=true; for i in pairs(s.goals) do if not s.crates[i] then complete=false end end
    if complete then
      s.score=s.level*100; s.cleared=true
      if s.level==#M.levels then s.result='win'; s.message='All four warehouses cleared.' end
    end
  end
  function s.draw(c)
    local ox=math.floor((c.w-16)/2)+1
    for y,row in ipairs(s.map) do for x=1,#row do
      local i=id(x,y); local glyph=s.walls[i] and '##' or s.crates[i] and (s.goals[i] and '**' or '[]') or s.goals[i] and '..' or '  '
      if s.x==x and s.y==y then glyph='@ ' end
      c.text(ox+(x-1)*2,y,glyph,c.color and (s.goals[i] and colors.lime or s.crates[i] and colors.yellow or colors.white) or colors.white)
    end end
    c.text(ox,8,'Level '..s.level..'/4')
    c.text(ox,9,s.cleared and 'Enter: next level' or 'Z undo / '..s.moves..' moves')
  end
  s.load(1); return s
end
return M

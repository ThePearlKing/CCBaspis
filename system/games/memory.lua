local M={}
function M.new(random)
  random=random or math.random
  local s={cards={},matched={},flipped={},cursor=1,turns=0,score=0}
  for i=1,16 do s.cards[i]=string.char(65+math.floor((i-1)/2)) end
  for i=16,2,-1 do local j=random(1,i); s.cards[i],s.cards[j]=s.cards[j],s.cards[i] end
  function s.key(key)
    if s.result then return end
    if key=='left' then s.cursor=math.max(1,s.cursor-1) elseif key=='right' then s.cursor=math.min(16,s.cursor+1)
    elseif key=='up' then s.cursor=math.max(1,s.cursor-4) elseif key=='down' then s.cursor=math.min(16,s.cursor+4)
    elseif key=='enter' or key=='space' then
      if #s.flipped==2 then s.flipped={}; return end
      if s.matched[s.cursor] or s.flipped[1]==s.cursor then return end
      s.flipped[#s.flipped+1]=s.cursor
      if #s.flipped==2 then
        s.turns=s.turns+1; local a,b=s.flipped[1],s.flipped[2]
        if s.cards[a]==s.cards[b] then
          s.matched[a],s.matched[b]=true,true; s.flipped={}; s.score=s.score+1
          if s.score==8 then s.result='win'; s.message='Eight pairs in '..s.turns..' tries.' end
        end
      end
    end
  end
  function s.mouse(button,x,y,c)
    local ox=math.floor((c.w-16)/2)+1; local xx=math.floor((x-ox)/4)+1
    if button==1 and xx>=1 and xx<=4 and y>=1 and y<=4 then s.cursor=(y-1)*4+xx; s.key('enter') end
  end
  function s.draw(c)
    local ox=math.floor((c.w-16)/2)+1
    for i=1,16 do
      local visible=s.matched[i] or s.flipped[1]==i or s.flipped[2]==i
      c.cell(ox+((i-1)%4)*4,1+math.floor((i-1)/4),'['..(visible and s.cards[i] or '?')..'] ',i==s.cursor)
    end
    c.text(ox,6,'Pairs '..s.score..'/8')
    c.text(ox,7,#s.flipped==2 and 'Enter: hide pair' or 'Tries '..s.turns)
  end
  return s
end
return M

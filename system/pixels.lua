-- Portable 2x3 subpixels per terminal cell. No CraftOS-PC graphics extensions.
local M = {}
local hex = "0123456789abcdef"
function M.new(w, h, fill)
  local b = { w = w, h = h, data = {} }
  for y = 1, h do b.data[y] = {}; for x = 1, w do b.data[y][x] = fill or colors.black end end
  function b.set(x, y, c)
    x, y = math.floor(x), math.floor(y)
    if x >= 1 and x <= w and y >= 1 and y <= h then b.data[y][x] = c end
  end
  function b.line(x1, y1, x2, y2, c)
    local dx, dy = math.abs(x2-x1), -math.abs(y2-y1)
    local sx, sy = x1 < x2 and 1 or -1, y1 < y2 and 1 or -1
    local err = dx + dy
    while true do
      b.set(x1, y1, c)
      if x1 == x2 and y1 == y2 then break end
      local e = 2 * err
      if e >= dy then err = err + dy; x1 = x1 + sx end
      if e <= dx then err = err + dx; y1 = y1 + sy end
    end
  end
  function b.rect(x, y, rw, rh, c)
    for yy = y, y + rh - 1 do for xx = x, x + rw - 1 do b.set(xx, yy, c) end end
  end
  return b
end
local function digit(c)
  local n = 0
  while c > 1 do c = c / 2; n = n + 1 end
  return hex:sub(n+1, n+1)
end
function M.cell(p)
  local count, order = {}, {}
  for _, c in ipairs(p) do
    if not count[c] then count[c] = 0; order[#order+1] = c end
    count[c] = count[c] + 1
  end
  table.sort(order, function(a, b) return count[a] > count[b] or (count[a] == count[b] and a < b) end)
  local bg, fg = order[1], order[2] or order[1]
  -- The sixth pixel is always background; invert the mask when necessary.
  if p[6] == fg then bg, fg = fg, bg end
  local bits = 0
  for i = 1, 5 do if p[i] == fg and fg ~= bg then bits = bits + 2^(i-1) end end
  return string.char(128 + bits), digit(fg), digit(bg)
end
function M.draw(b, target, ox, oy, maxW, maxH)
  target, ox, oy = target or term, ox or 1, oy or 1
  local tw, th = target.getSize()
  local cw = math.min(math.ceil(b.w/2), maxW or tw, tw-ox+1)
  local ch = math.min(math.ceil(b.h/3), maxH or th, th-oy+1)
  local function get(x,y) return b.data[y] and b.data[y][x] or colors.black end
  for cy = 1, ch do
    local text, fg, bg = {}, {}, {}
    for cx = 1, cw do
      local x,y = (cx-1)*2+1, (cy-1)*3+1
      text[cx],fg[cx],bg[cx] = M.cell({get(x,y),get(x+1,y),get(x,y+1),get(x+1,y+1),get(x,y+2),get(x+1,y+2)})
    end
    target.setCursorPos(ox, oy+cy-1)
    target.blit(table.concat(text),table.concat(fg),table.concat(bg))
  end
end
return M

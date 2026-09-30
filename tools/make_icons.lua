-- Draws the Hub's sidebar icons (white on transparent, 64x64 TGA) with a tiny anti-aliased rasterizer:
-- overview (four tiles), appearance (a palette), guild (two people), errors (a warning triangle).
-- Run:  lua tools/make_icons.lua
local here = arg and arg[0] and arg[0]:gsub("\\", "/"):match("^(.*)/tools/[^/]*$") or "D:/Projects/allemano-addons/AllemanoHub"
local N, SS = 64, 4 -- size and supersampling

local function tga(path, alpha)
  local out = { string.char(0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, N % 256, N // 256, N % 256, N // 256, 32, 8 + 32) }
  for y = 1, N do
    for x = 1, N do out[#out + 1] = string.char(255, 255, 255, alpha[(y - 1) * N + x]) end
  end
  local f = assert(io.open(path, "wb")); f:write(table.concat(out)); f:close()
end

-- shapes are functions (x, y) -> true in 0..64 coordinates
local function roundRect(x0, y0, x1, y1, r)
  return function(x, y)
    if x < x0 or x > x1 or y < y0 or y > y1 then return false end
    local cx = math.min(math.max(x, x0 + r), x1 - r)
    local cy = math.min(math.max(y, y0 + r), y1 - r)
    return (x - cx) ^ 2 + (y - cy) ^ 2 <= r * r
  end
end
local function circle(cx, cy, r) return function(x, y) return (x - cx) ^ 2 + (y - cy) ^ 2 <= r * r end end
local function ring(cx, cy, r, w) return function(x, y) local d = math.sqrt((x - cx) ^ 2 + (y - cy) ^ 2) return d <= r and d >= r - w end end
local function tri(ax, ay, bx, by, cx, cy)
  return function(x, y)
    local function s(px, py, qx, qy, rx, ry) return (px - rx) * (qy - ry) - (qx - rx) * (py - ry) end
    local d1, d2, d3 = s(x, y, ax, ay, bx, by), s(x, y, bx, by, cx, cy), s(x, y, cx, cy, ax, ay)
    local neg, pos = d1 < 0 or d2 < 0 or d3 < 0, d1 > 0 or d2 > 0 or d3 > 0
    return not (neg and pos)
  end
end

-- a drawing: list of { shape, add = true|false } applied in order (false erases)
local function render(path, parts)
  local alpha = {}
  for py = 0, N - 1 do
    for px = 0, N - 1 do
      local hit = 0
      for sy = 0, SS - 1 do
        for sx = 0, SS - 1 do
          local x, y = px + (sx + 0.5) / SS, py + (sy + 0.5) / SS
          local on = false
          for _, part in ipairs(parts) do
            if part[1](x, y) then on = part[2] end
          end
          if on then hit = hit + 1 end
        end
      end
      alpha[py * N + px + 1] = math.floor(255 * hit / (SS * SS) + 0.5)
    end
  end
  tga(path, alpha)
  print("wrote " .. path)
end

local dir = here .. "/Media/Icons/"
os.execute('mkdir "' .. dir:gsub("/", "\\") .. '" 2>nul')

-- overview: four tiles
render(dir .. "overview.tga", {
  { roundRect(8, 8, 29, 29, 5), true }, { roundRect(35, 8, 56, 29, 5), true },
  { roundRect(8, 35, 29, 56, 5), true }, { roundRect(35, 35, 56, 56, 5), true },
})

-- appearance: a palette (disc with a thumb notch and three holes)
render(dir .. "appearance.tga", {
  { circle(32, 33, 25), true },
  { circle(46, 44, 6), false },
  { circle(20, 30, 4.2), false }, { circle(30, 19, 4.2), false }, { circle(43, 22, 4.2), false },
})

-- guild: two people
render(dir .. "guild.tga", {
  { circle(23, 21, 9), true }, { roundRect(8, 36, 38, 56, 10), true },
  { circle(45, 24, 7.5), true }, { roundRect(34, 39, 58, 56, 8), true },
  { ring(23, 21, 12.5, 2.2), false }, -- a gap around the front head so the two read as two
})

-- errors: a warning triangle with an exclamation mark
render(dir .. "errors.tga", {
  { tri(32, 6, 60, 55, 4, 55), true },
  { tri(32, 17, 51, 49, 13, 49), false },
  { roundRect(29, 26, 35, 40, 2.5), true }, { circle(32, 45.5, 3.4), true },
})

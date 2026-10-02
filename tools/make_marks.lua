-- Makes the Hub's textures from AltBoard's mark/icon (same geometry, blue base recolored):
--   Media/wow/mark.tga and icon.tga in the Hub's own color (white), and
--   Media/marks/<id>.tga, the mark in each addon's color, for the sidebar and the cards.
-- Run from anywhere:  lua make_marks.lua   (needs the sibling AltBoard repo)
local here = arg and arg[0] and arg[0]:gsub("\\", "/"):match("^(.*)/tools/[^/]*$") or "D:/Projects/allemano-addons/AllemanoHub"
local repos = here:gsub("/[^/]*$", "")

local function readf(p) local f = assert(io.open(p, "rb")); local s = f:read("*a"); f:close(); return s end
local function writef(p, s) local f = assert(io.open(p, "wb")); f:write(s); f:close() end

-- kind "mark": transparent background, the base is pure blue with partial alpha at its edges.
-- kind "tile": dark tile; the base blends with the tile color at its edges.
local function recolor(src, kind, r2, g2, b2)
  local d = readf(src)
  local idlen = d:byte(1)
  local w, h = d:byte(13) + d:byte(14) * 256, d:byte(15) + d:byte(16) * 256
  local off = 18 + idlen
  local out = {}
  for i = 1, off do out[#out + 1] = d:sub(i, i) end
  local dark = { r = 18, g = 20, b = 24 }
  for p = 0, w * h - 1 do
    local i = off + p * 4 + 1
    local b, g, r, a = d:byte(i, i + 3)
    if b - r > 25 then
      if kind == "mark" then
        r, g, b = r2, g2, b2
      else
        local t = math.min(1, math.max(0, (b - dark.b) / (255 - dark.b)))
        r = math.floor(dark.r + t * (r2 - dark.r) + 0.5)
        g = math.floor(dark.g + t * (g2 - dark.g) + 0.5)
        b = math.floor(dark.b + t * (b2 - dark.b) + 0.5)
      end
    end
    out[#out + 1] = string.char(b, g, r, a)
  end
  out[#out + 1] = d:sub(off + w * h * 4 + 1)
  return table.concat(out)
end

local function hex(s) return tonumber(s:sub(1, 2), 16), tonumber(s:sub(3, 4), 16), tonumber(s:sub(5, 6), 16) end

local function mkdir(path) os.execute('mkdir "' .. path:gsub("/", "\\") .. '" 2>nul') end

local source = repos .. "/AltBoard/Media/wow/"
mkdir(here .. "/Media/wow")
mkdir(here .. "/Media/marks")

-- The Hub itself: the plain white mark (the brand mark).
local wr, wg, wb = hex("ECEDEF")
writef(here .. "/Media/wow/mark.tga", recolor(source .. "mark.tga", "mark", wr, wg, wb))
writef(here .. "/Media/wow/icon.tga", recolor(source .. "icon.tga", "tile", wr, wg, wb))

local colors = {
  hush = "3FD0E0", altboard = "5B8CFF", craftboard = "F0763A", art = "E5484D",
  alc = "45C97E", session = "E8A93B", skins = "E55D9E", asr = "9B7BFF",
}
for id, color in pairs(colors) do
  local r, g, b = hex(color)
  writef(here .. "/Media/marks/" .. id .. ".tga", recolor(source .. "mark.tga", "mark", r, g, b))
  print("mark", id, color)
end
print("done")

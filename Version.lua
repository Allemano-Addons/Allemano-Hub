-- Version: compare addon versions such as "0.6.3", "0.16.1" and "0.2.0-alpha2" (alpha < beta < release).
local _, HUB = ...

local Version = {}
HUB.Version = Version

local RANK = { alpha = 1, beta = 2 }

local function parse(v)
    v = tostring(v or "")
    local nums, rest = v:match("^v?([%d%.]+)(.*)$")
    if not nums then return nil end
    local parts = {}
    for n in nums:gmatch("%d+") do parts[#parts + 1] = tonumber(n) end
    local tag, tagNumber = rest:match("^%-(%a+)(%d*)")
    local rank = tag and (RANK[tag:lower()] or 0) or 3
    return parts, rank, tonumber(tagNumber) or 0
end

-- -1 if a is older than b, 1 if newer, 0 if equal (or not comparable).
function Version.Compare(a, b)
    local pa, ra, na = parse(a)
    local pb, rb, nb = parse(b)
    if not pa or not pb then return 0 end
    for i = 1, math.max(#pa, #pb) do
        local x, y = pa[i] or 0, pb[i] or 0
        if x ~= y then return x < y and -1 or 1 end
    end
    if ra ~= rb then return ra < rb and -1 or 1 end
    if na ~= nb then return na < nb and -1 or 1 end
    return 0
end

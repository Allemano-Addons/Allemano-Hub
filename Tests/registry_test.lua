-- Offline test of the Registry's list of Allemano addons. Run from the AllemanoHub folder:  lua Tests/registry_test.lua
local failed = 0
local function check(name, ok)
	if not ok then
		failed = failed + 1
		print("FAIL: " .. name)
	end
end

local HUB = {}
function HUB:Print() end
function HUB:Call(_, fn, ...) return fn(...) end
assert(loadfile("Registry.lua"))("AllemanoHub", HUB)
local known = HUB.Registry.known

local ids, folders, byId = {}, {}, {}
for _, e in ipairs(known) do
	check("an entry has an id, a folder and a name: " .. tostring(e.id), type(e.id) == "string" and type(e.folder) == "string" and type(e.name) == "string")
	check("ids are unique: " .. e.id, not ids[e.id])
	check("folders are unique: " .. e.folder, not folders[e.folder])
	ids[e.id], folders[e.folder] = true, true
	byId[e.id] = e
	check("the colour is six hex digits: " .. e.id, type(e.color) == "string" and e.color:match("^%x%x%x%x%x%x$") ~= nil)
	check("a slash command is given: " .. e.id, type(e.slash) == "string" and e.slash:sub(1, 1) == "/")
	if e.main and e.mark then
		local f = io.open("Media/marks/" .. e.mark .. ".tga", "rb")
		check("the mark file exists: " .. e.mark, f ~= nil)
		if f then f:close() end
	end
end

-- Arbiter Soft Reserve is there, in its purple, with its own mark
local asr = byId.asr
check("ASR is listed", asr ~= nil)
check("with the folder and the name of the addon", asr and asr.folder == "ArbiterSoftReserve" and asr.fullName == "Arbiter Soft Reserve")
check("in purple, with its CurseForge project and its saved data", asr and asr.color == "9B7BFF" and asr.cf == 1721476 and asr.sv == "ASR_DB")
check("it is a main addon with its own mark", asr and asr.main == true and asr.mark == "asr")
check("and opens its import box", asr and asr.openArg == "import")

-- It comes after the Loot Council it needs
local order = {}
for i, e in ipairs(known) do order[e.id] = i end
check("it follows ALC in the list", order.asr == order.alc + 1)

-- Open runs the addon's command with its argument
local ran
SlashCmdList = { ARBITERSOFTRESERVE = function(arg) ran = arg end }
SLASH_ARBITERSOFTRESERVE1 = "/asr"
check("Open finds the slash command and passes the argument", HUB.Registry:Open(asr) == true and ran == "import")
SlashCmdList.ALC = function(arg) ran = "alc:" .. arg end
local alc = byId.alc
HUB.Registry:Open(alc)
check("an addon without an open argument gets none", ran == "alc:")

if failed > 0 then
	print(failed .. " failed")
	os.exit(1)
end
print("ALL OK")

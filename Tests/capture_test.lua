-- Offline test of Capture.lua (the Errors page's catcher). Run from the AllemanoHub folder:  lua Tests/capture_test.lua
wipe = function(t) for k in pairs(t) do t[k] = nil end end
time, strlower, tremove = os.time, string.lower, table.remove -- the game's global aliases

local failed = 0
local function check(name, ok)
	if not ok then
		failed = failed + 1
		print("FAIL: " .. name)
	end
end

-- A fake Hub with the parts Capture.lua touches.
local handlers, printed = {}, {}
local HUB = {
	name = "AllemanoHub",
	Registry = {
		known = {
			{ folder = "ArbiterLootCouncil", name = "ALC" },
			{ folder = "Hush", name = "Hush", sv = "HushDB" },
			{ folder = "Hush_Feed", name = "Hush Feed" },
		},
	},
}
function HUB:RegisterEvent(event, fn) handlers[event] = fn return true end
function HUB:Print(...) printed[#printed + 1] = table.concat({ ... }, " ") end

assert(loadfile("Capture.lua"))("AllemanoHub", HUB)
local Capture = HUB.Capture
check("Capture is installed", type(Capture) == "table" and type(Capture.Catch) == "function")
check("it listens for the saved data", type(handlers.ADDON_LOADED) == "function")

-- Errors that come before the saved data is loaded are kept and stored when it is.
Capture.Catch("Interface\\AddOns\\ArbiterLootCouncil\\UI\\Widgets.lua:95: script ran too long")
HUB.db = { captured = {} }
handlers.ADDON_LOADED(nil, "AllemanoHub")
local list = HUB.db.captured.ArbiterLootCouncil
check("an early error is stored once the data is there", list and #list == 1)
check("with the file and line as where", list and list[1].where == "Widgets.lua:95")
check("and the whole message", list and list[1].msg:find("script ran too long", 1, true) ~= nil)

-- The folder in the path decides which addon it is. Forward slashes work too.
Capture.Catch("Interface/AddOns/Hush_Feed/Core.lua:12: attempt to index a nil value")
check("a forward-slash path is found", HUB.db.captured.Hush_Feed and #HUB.db.captured.Hush_Feed == 1)
check("the first error of an addon is announced once", #printed == 2)
Capture.Catch("Interface\\AddOns\\Hush_Feed\\Other.lua:3: something else")
check("a second one is stored but not announced again", #HUB.db.captured.Hush_Feed == 2 and #printed == 2)

-- The same error again right away is not repeated.
Capture.Catch("Interface\\AddOns\\ArbiterLootCouncil\\UI\\Widgets.lua:95: script ran too long")
check("a repeated error within a few seconds is stored once", #HUB.db.captured.ArbiterLootCouncil == 1)

-- Errors of other addons are none of our business.
Capture.Catch("Interface\\AddOns\\SomeoneElse\\Core.lua:1: boom")
Capture.Catch("Interface\\FrameXML\\Blizzard.lua:1: boom")
check("errors from other addons are ignored", HUB.db.captured.SomeoneElse == nil)

-- When the path is only in the stack, the stack names the addon.
Capture.Catch("attempt to call a nil value", "[C]: ?\nInterface\\AddOns\\Hush\\Core.lua:40: in function 'x'")
check("the stack can name the addon when the message does not", HUB.db.captured.Hush and #HUB.db.captured.Hush == 1)

-- An error the addon recorded itself a moment ago is not repeated.
local msg = "Interface\\AddOns\\Hush\\Chat.lua:7: attempt to compare nil with number"
HushDB = { errors = { { t = os.time(), where = "event", msg = msg } } }
HUB.Registry.known[2].sv = "HushDB"
local before = #HUB.db.captured.Hush
Capture.Catch(msg)
check("an error the addon already recorded is not stored twice", #HUB.db.captured.Hush == before)

-- Not more than twenty are kept per addon.
for i = 1, 30 do
	Capture.Catch("Interface\\AddOns\\Hush_Feed\\Core.lua:" .. i .. ": error number " .. i)
end
check("only the newest twenty are kept", #HUB.db.captured.Hush_Feed == 20
	and HUB.db.captured.Hush_Feed[20].msg:find("error number 30", 1, true) ~= nil)

-- Something that is not text must not break the catcher.
check("nothing is thrown for odd input", pcall(Capture.Catch, nil) and pcall(Capture.Catch, 42) and pcall(Capture.Catch, {}))

if failed > 0 then
	print(failed .. " failed")
	os.exit(1)
end
print("ALL OK")

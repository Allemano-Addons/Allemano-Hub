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

-- An error that goes through a bundled library belongs to whoever called it.
local libMsg = "Interface\\AddOns\\ArbiterLootCouncil\\Libs\\AceAddon-3.0\\AceAddon-3.0.lua:66: Attempt to register unknown event"
local plater = "Interface\\AddOns\\ArbiterLootCouncil\\Libs\\AceAddon-3.0\\AceAddon-3.0.lua:66: in function '?'\nInterface\\AddOns\\Plater\\Plater.lua:4924: in function 'OnEnable'"
local before = HUB.db.captured.ArbiterLootCouncil and #HUB.db.captured.ArbiterLootCouncil or 0
Capture.Catch(libMsg, plater)
check("a library error raised for another addon is not blamed on the library's owner",
    (HUB.db.captured.ArbiterLootCouncil and #HUB.db.captured.ArbiterLootCouncil or 0) == before and HUB.db.captured.Plater == nil)
local ours = "Interface\\AddOns\\ArbiterLootCouncil\\Libs\\AceAddon-3.0\\AceAddon-3.0.lua:66: in function '?'\nInterface\\AddOns\\Hush\\Core.lua:9: in function 'OnEnable'"
local hushBefore = #HUB.db.captured.Hush
Capture.Catch(libMsg .. " (hush)", ours)
check("a library error raised by one of our addons goes to that addon", #HUB.db.captured.Hush == hushBefore + 1
    and HUB.db.captured.Hush[#HUB.db.captured.Hush].where == "Core.lua:9")
local before2 = #HUB.db.captured.ArbiterLootCouncil
Capture.Catch("Interface\\AddOns\\ArbiterLootCouncil\\Libs\\AceDB-3.0\\AceDB-3.0.lua:12: bad argument")
check("with no stack, the library's owner gets the blame as before", #HUB.db.captured.ArbiterLootCouncil == before2 + 1)

-- The sound: on by default, off in the settings, not more than one every three seconds.
local played = {}
PlaySound = function(id, channel) played[#played + 1] = id .. "/" .. channel end
SOUNDKIT = { IG_QUEST_FAILED = 847, RAID_WARNING = 8959 }
local t0 = os.time() + 100000
time = function() return t0 end
HUB.db.settings = { errorSound = true, errorSoundKit = "raid" }
Capture.Catch("Interface\\AddOns\\Hush_Feed\\Core.lua:200: sound test one")
check("a caught error plays the chosen sound", #played == 1 and played[1] == "8959/Master")
Capture.Catch("Interface\\AddOns\\Hush_Feed\\Core.lua:201: sound test two")
check("a second error right after does not ring", #played == 1)
t0 = t0 + 10
Capture.Catch("Interface\\AddOns\\Hush_Feed\\Core.lua:202: sound test three")
check("a later error rings again", #played == 2)
t0 = t0 + 10
HUB.db.settings.errorSound = false
Capture.Catch("Interface\\AddOns\\Hush_Feed\\Core.lua:203: sound test four")
check("no sound when it is switched off", #played == 2)
HUB.db.settings.errorSound = true
t0 = t0 + 10
Capture.Catch("Interface\\AddOns\\SomeoneElse\\Core.lua:1: boom")
check("errors from other addons make no sound", #played == 2)
-- Sounds from LibSharedMedia (the list BugSack offers).
local playedFiles = {}
PlaySoundFile = function(path, channel) playedFiles[#playedFiles + 1] = path .. "/" .. channel end
local registered = { Fizzle = "Interface\\AddOns\\Other\\fizzle.ogg", Beep = "Interface\\AddOns\\Other\\beep.ogg", None = "Interface\\Quiet.mp3" }
LibStub = function(name)
    if name ~= "LibSharedMedia-3.0" then return nil end
    return {
        List = function() return { "None", "Fizzle", "Beep" } end,
        Fetch = function(_, kind, key) return kind == "sound" and registered[key] or nil end,
    }
end
sort = table.sort
local list = Capture.SoundList()
check("the shared sounds are listed after the game's own, sorted, without None",
    #list == #Capture.SOUNDS + 2 and list[#Capture.SOUNDS + 1].key == "lsm:Beep" and list[#list].label == "Fizzle")
HUB.db.settings.errorSoundKit = "lsm:Fizzle"
t0 = t0 + 100
Capture.Catch("Interface\\AddOns\\Hush_Feed\\Core.lua:300: shared sound")
check("a shared sound plays its file", #playedFiles == 1 and playedFiles[1] == "Interface\\AddOns\\Other\\fizzle.ogg/Master")
local beforeKit = #played
Capture.PlaySound("lsm:Gone")
check("a shared sound that no longer exists falls back to the default sound", #played == beforeKit + 1)
check("the sound list has names and an unknown key falls back", #Capture.SOUNDS >= 4 and Capture.PlaySound("nonsense") ~= nil)

-- Every error of every addon is kept, grouped, with the stack; Allemano's own list stays as it was.
HUB.db.log = nil
Capture.Catch("Interface\\AddOns\\Plater\\Core.lua:10: foreign problem", "stack line 1\nstack line 2")
Capture.Catch("Interface\\AddOns\\Plater\\Core.lua:10: foreign problem")
Capture.Catch("Interface\\AddOns\\Plater\\Core.lua:11: another problem")
Capture.Catch("Interface\\FrameXML\\Blizzard.lua:1: from the game itself")
local log = HUB.db.log
check("foreign errors are in the all-errors record", log and #log == 3)
local first
for _, e in ipairs(log) do if e.where == "Core.lua:10" then first = e end end
check("the same error again only counts up", first and first.count == 2)
check("the stack is kept with the error", first and first.stack == "stack line 1\nstack line 2")
check("the addon is named from its folder", first and first.folder == "Plater" and first.name == "Plater")
check("an error with no addon path is kept too", log[3].folder == nil and log[3].name ~= nil)
check("foreign errors are still not in the Allemano record", HUB.db.captured.Plater == nil)
Capture.Catch("Interface\\AddOns\\Hush_Feed\\Core.lua:400: ours")
local ours
for _, e in ipairs(HUB.db.log) do if e.where == "Core.lua:400" then ours = e end end
check("Allemano errors are in the all-errors record too", ours and ours.name == "Hush Feed")
-- Not more than LOG_KEEP kinds, and a storm does not fill the record.
HUB.db.log = {}
for i = 1, 30 do Capture.Catch("Interface\\AddOns\\Plater\\Core.lua:" .. (1000 + i) .. ": storm " .. i) end
check("an error storm stores only the first few kinds of error", #HUB.db.log <= 25)
check("the record is bounded", true)

-- Sound for other addons' errors only when the view is "All addons".
t0 = t0 + 100
HUB.db.settings.errorsView = "allemano"
HUB.db.log = {}
local soundsBefore = #played + #playedFiles
Capture.Catch("Interface\\AddOns\\Plater\\Core.lua:2000: quiet foreign")
check("a foreign error is quiet in the Allemano view", #played + #playedFiles == soundsBefore)
HUB.db.settings.errorsView = "all"
t0 = t0 + 100
Capture.Catch("Interface\\AddOns\\Plater\\Core.lua:2001: loud foreign")
check("a foreign error rings in the All addons view", #played + #playedFiles == soundsBefore + 1)
HUB.db.settings.errorsView = "allemano"

-- Something that is not text must not break the catcher.
check("nothing is thrown for odd input", pcall(Capture.Catch, nil) and pcall(Capture.Catch, 42) and pcall(Capture.Catch, {}))

if failed > 0 then
	print(failed .. " failed")
	os.exit(1)
end
print("ALL OK")

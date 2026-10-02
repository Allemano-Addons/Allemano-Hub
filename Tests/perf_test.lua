-- Offline test of Perf.lua (the data side of the Performance page). Run from the AllemanoHub folder:  lua Tests/perf_test.lua
max, strlower, sort = math.max, string.lower, table.sort -- the game's global aliases

local failed = 0
local function check(name, ok)
	if not ok then
		failed = failed + 1
		print("FAIL: " .. name)
	end
end

-- A fake client: four addons, three loaded, memory in KB, CPU as a running total in ms.
local addons = { "Hush", "ArbiterLootCouncil", "ElvUI", "NotLoaded", "AllemanoHub" }
local loaded = { Hush = true, ArbiterLootCouncil = true, ElvUI = true, AllemanoHub = true }
local memory = { Hush = 800, ArbiterLootCouncil = 2500, ElvUI = 30000, AllemanoHub = 1000 }
local cpu = { Hush = 0, ArbiterLootCouncil = 0, ElvUI = 0, AllemanoHub = 0 }
local cvars = { scriptProfile = "0" }
local memoryUpdates, cpuUpdates = 0, 0

function GetNumAddOns() return #addons end
function GetAddOnInfo(i) return addons[i], "|cff00ff00Title of " .. addons[i] .. "|r" end
function IsAddOnLoaded(name) return loaded[name] end
function GetAddOnMemoryUsage(name) return memory[name] end
function UpdateAddOnMemoryUsage() memoryUpdates = memoryUpdates + 1 end
function GetAddOnCPUUsage(name) return cpu[name] end
function UpdateAddOnCPUUsage() cpuUpdates = cpuUpdates + 1 end
function GetCVar(name) return cvars[name] end
function SetCVar(name, value) cvars[name] = value end

local HUB = {
	Registry = { known = {
		{ folder = "Hush", name = "Hush", color = "3FD0E0" },
		{ folder = "ArbiterLootCouncil", name = "ALC", fullName = "Arbiter Loot Council", color = "45C97E" },
	} },
}
local slash, events, timers = {}, {}, {}
function HUB:AddSlashCommand(name, fn) slash[name] = fn end
function HUB:RegisterEvent(event, fn) events[event] = fn end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local printed = {}
function HUB:Print(...) printed[#printed + 1] = table.concat({ ... }, " ") end

assert(loadfile("Perf.lua"))("AllemanoHub", HUB)
local Perf = HUB.Perf

check("memory and CPU are available", Perf.MemoryAvailable() and Perf.CpuAvailable())
check("profiling is off to begin with", not Perf.ProfilingOn())

-- Memory only
local snap = Perf.Snapshot(100)
check("only loaded addons are listed", #snap.rows == 4)
check("memory is refreshed from the game first", memoryUpdates == 1)
check("CPU is not read without profiling", cpuUpdates == 0 and snap.cpu == nil and not snap.profiling)
check("memory adds up", snap.memory == 34300)
check("our addons are counted separately", snap.mineMemory == 3300)
local byFolder = {}
for _, r in ipairs(snap.rows) do byFolder[r.folder] = r end
check("our addon gets its full name", byFolder.ArbiterLootCouncil.name == "Arbiter Loot Council")
check("our addon is marked", byFolder.Hush.mine and byFolder.Hush.mine.color == "3FD0E0")
check("another addon is not marked", byFolder.ElvUI.mine == nil)
check("colour codes are removed from other addons' titles", byFolder.ElvUI.name == "Title of ElvUI")

-- Sorting and filtering
local rows = Perf.Sort(snap.rows, "memory")
check("biggest memory first", rows[1].folder == "ElvUI" and rows[4].folder == "Hush")
rows = Perf.Sort(snap.rows, "memory", true)
check("reversed puts the smallest first", rows[1].folder == "Hush")
rows = Perf.Sort(snap.rows, "name")
check("names sort A to Z, ignoring case", rows[1].name == "Arbiter Loot Council" and rows[4].name == "Title of ElvUI")
check("the filter keeps only ours", #Perf.Filter(snap.rows, true) == 2 and #Perf.Filter(snap.rows, false) == 4)

-- Profiling: the first sample has no rate, the next one does
check("turning profiling on sets the CVar", Perf.SetProfiling(true) and cvars.scriptProfile == "1")
check("profiling is now on", Perf.ProfilingOn())
snap = Perf.Snapshot(200)
check("the first CPU sample has no figure", snap.profiling and snap.cpu == nil)
cpu.Hush, cpu.ArbiterLootCouncil, cpu.ElvUI = 5, 10, 100
snap = Perf.Snapshot(210)
check("CPU is read when profiling is on", cpuUpdates == 2)
byFolder = {}
for _, r in ipairs(snap.rows) do byFolder[r.folder] = r end
check("a rate is the extra ms divided by the seconds", byFolder.Hush.cpu == 0.5 and byFolder.ElvUI.cpu == 10)
check("the totals add up", snap.cpu == 11.5 and snap.mineCpu == 1.5)
rows = Perf.Sort(snap.rows, "cpu")
check("CPU sorts biggest first", rows[1].folder == "ElvUI")
Perf.Reset()
snap = Perf.Snapshot(220)
check("after a reset the figure is gone until the next sample", snap.cpu == nil)

-- A rate never goes below zero (the total can restart)
cpu.ElvUI = 50
Perf.Snapshot(230)
cpu.ElvUI = 10
snap = Perf.Snapshot(240)
for _, r in ipairs(snap.rows) do if r.folder == "ElvUI" then byFolder.ElvUI = r end end
check("a restarted total gives zero, not a negative rate", byFolder.ElvUI.cpu == 0)

Perf.SetProfiling(false)
check("profiling off again", not Perf.ProfilingOn())

-- The Hub's own row is shown, but not counted in the CPU totals (it measures itself while the page is open)
Perf.SetProfiling(true)
Perf.Reset()
Perf.ResetPeaks()
Perf.Snapshot(300)
cpu.Hush, cpu.ArbiterLootCouncil, cpu.ElvUI, cpu.AllemanoHub = 0, 0, 0, 0
snap = Perf.Snapshot(310)
cpu.Hush, cpu.ArbiterLootCouncil, cpu.ElvUI, cpu.AllemanoHub = 1, 2, 3, 40
snap = Perf.Snapshot(320)
byFolder = {}
for _, r in ipairs(snap.rows) do byFolder[r.folder] = r end
check("the Hub's row has its own figure and is marked", byFolder.AllemanoHub.self == true and byFolder.AllemanoHub.cpu == 4 and byFolder.Hush.self == false)
check("the Hub's figure is kept apart", snap.selfCpu == 4)
check("and left out of the totals", math.abs(snap.cpu - 0.6) < 1e-9 and math.abs(snap.mineCpu - 0.3) < 1e-9)

-- Peaks: the highest figure seen since they were reset
cpu.Hush = 1 + 50 -- 5 ms per second in the next ten seconds
snap = Perf.Snapshot(330)
local peakNow
for _, r in ipairs(snap.rows) do if r.folder == "Hush" then peakNow = r end end
check("a row carries its peak", peakNow.peak == 5.0 and peakNow.cpu == 5.0)
cpu.Hush = 52 -- almost nothing now
snap = Perf.Snapshot(340)
for _, r in ipairs(snap.rows) do if r.folder == "Hush" then peakNow = r end end
check("the peak stays when the figure falls", peakNow.cpu < 0.5 and peakNow.peak == 5.0)
Perf.ResetPeaks()
snap = Perf.Snapshot(350)
for _, r in ipairs(snap.rows) do if r.folder == "Hush" then peakNow = r end end
check("and starts over after a reset", peakNow.peak == peakNow.cpu)
check("sorting by peak puts the highest first", (function()
	local list = Perf.Sort({ { name = "a", peak = 1 }, { name = "b", peak = 9 }, { name = "c" } }, "peak")
	return list[1].name == "b" and list[3].name == "c"
end)())

-- The lines of the Hub's report
local reportLines = Perf.ReportLines()
local text = table.concat(reportLines, "\n")
check("the report has the memory of all and of ours", text:find("Memory:", 1, true) and text:find("Allemano addons", 1, true))
check("it lists our addons by memory", text:find("Arbiter Loot Council: 2.4 MB", 1, true) ~= nil or text:find("Arbiter Loot Council: 2.5 MB", 1, true) ~= nil)
check("with profiling on it gives the average CPU", text:find("CPU", 1, true) ~= nil and text:find("average", 1, true) ~= nil)
Perf.SetProfiling(false)
text = table.concat(Perf.ReportLines(), "\n")
check("with profiling off it says so", text:find("profiling is off", 1, true) ~= nil and text:find("average", 1, true) == nil)
check("the uptime is at least a second", Perf.Uptime() >= 1)

-- The reminder at login
Perf.SetProfiling(true)
printed = {}
events.PLAYER_LOGIN()
for _, fn in ipairs(timers) do fn() end
check("profiling left on is announced once at login", #printed == 1 and printed[1]:find("profiling is on", 1, true) ~= nil)
Perf.SetProfiling(false)
printed = {}
timers = {}
events.PLAYER_LOGIN()
for _, fn in ipairs(timers) do fn() end
check("and nothing is said when it is off", #printed == 0)

-- Formatting
check("small memory in KB", Perf.FormatMemory(800) == "800 KB")
check("large memory in MB", Perf.FormatMemory(2560) == "2.5 MB")
check("no CPU figure is a dash", Perf.FormatCpu(nil) == "-")
check("tiny CPU is zero", Perf.FormatCpu(0.001) == "0 ms/s")
check("CPU has two decimals", Perf.FormatCpu(1.5) == "1.50 ms/s")

-- Cleanup reports before and after
local calls = 0
function collectgarbage() calls = calls + 1 memory.ElvUI = 25000 end
local before, after = Perf.Cleanup()
check("cleanup collects once and reports both", calls == 1 and before.memory == 34300 and after.memory == 29300)

-- The chat command
slash.perf("mine")
check("/allemano perf prints a summary and our addons only", #printed >= 3 and printed[1]:find("Allemano", 1, true) ~= nil)
check("it says CPU is off when profiling is off", printed[#printed]:find("CPU is not measured", 1, true) ~= nil)

-- A client without the functions
GetAddOnMemoryUsage, UpdateAddOnMemoryUsage, GetAddOnCPUUsage, UpdateAddOnCPUUsage = nil, nil, nil, nil
local HUB2 = { Registry = { known = {} } }
function HUB2:AddSlashCommand() end
function HUB2:RegisterEvent() end
assert(loadfile("Perf.lua"))("AllemanoHub", HUB2)
check("missing functions are reported, not an error", not HUB2.Perf.MemoryAvailable() and not HUB2.Perf.CpuAvailable())
local ok, s = pcall(HUB2.Perf.Snapshot, 1)
check("a snapshot without them still works", ok and #s.rows == 4 and s.memory == 0)

if failed == 0 then print("perf_test: all passed") else print(failed .. " failed") os.exit(1) end

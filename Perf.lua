-- Perf: memory and CPU use of the loaded addons. The data side of the Performance page (no frames here, so it can
-- be tested offline). Memory comes from the game at any time. CPU only counts when the game's script profiling is
-- on (CVar scriptProfile, changed with a reload), and then it costs a little itself, so the page asks first.
local _, HUB = ...

local Perf = {}
HUB.Perf = Perf

local api = C_AddOns or {}
local getInfo = api.GetAddOnInfo or GetAddOnInfo
local numAddOns = api.GetNumAddOns or GetNumAddOns
local isLoaded = api.IsAddOnLoaded or IsAddOnLoaded
local getMemory = api.GetAddOnMemoryUsage or GetAddOnMemoryUsage
local getCpu = api.GetAddOnCPUUsage or GetAddOnCPUUsage
local updateMemory = api.UpdateAddOnMemoryUsage or UpdateAddOnMemoryUsage
local updateCpu = api.UpdateAddOnCPUUsage or UpdateAddOnCPUUsage

local prev -- { t = time of the last sample, cpu = { [folder] = total ms then } }
local peaks = {} -- [folder] = the highest ms per second seen since ResetPeaks
local startedAt = (GetTime and GetTime()) or 0 -- about when the game's CPU counters started (this load)
local SELF = "AllemanoHub" -- the Hub measures itself while the Performance page is open: its row is left out of the totals

local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
end

-- Which of the two the client can tell us.
function Perf.MemoryAvailable() return type(getMemory) == "function" and type(updateMemory) == "function" end
function Perf.CpuAvailable() return type(getCpu) == "function" and type(updateCpu) == "function" end

function Perf.ProfilingOn()
    return Perf.CpuAvailable() and tostring(safe(GetCVar, "scriptProfile")) == "1"
end

-- Turns script profiling on or off. It takes effect after a reload.
function Perf.SetProfiling(on)
    if type(SetCVar) ~= "function" then return false end
    return pcall(SetCVar, "scriptProfile", on and "1" or "0")
end

-- One folder -> registry entry lookup, so our own addons can be marked and coloured.
local function mineByFolder()
    local out = {}
    for _, e in ipairs(HUB.Registry and HUB.Registry.known or {}) do out[e.folder] = e end
    return out
end

-- Reads every loaded addon. Returns { rows = {...}, memory = KB of all, mineMemory = KB of ours,
-- cpu = ms per second of all (nil without profiling), mineCpu, selfCpu (the Hub's own), profiling = bool }.
-- A row: { folder, name, memory (KB), cpu (ms per second, nil without profiling), peak (the highest cpu seen),
-- cpuTotal (ms since the counters started), mine = registry entry or nil, self = true for the Hub }.
-- The CPU figure is the difference since the previous call, so the first call has none. The Hub's own row is
-- shown but not counted in `cpu` and `mineCpu`: while the page is open the Hub measures itself.
function Perf.Snapshot(now)
    now = now or (GetTime and GetTime()) or 0
    local profiling = Perf.ProfilingOn()
    if Perf.MemoryAvailable() then safe(updateMemory) end
    if profiling then safe(updateCpu) end

    local mine = mineByFolder()
    local dt = prev and (now - prev.t) or 0
    local cpuNow = {}
    local snap = { rows = {}, memory = 0, mineMemory = 0, profiling = profiling }
    if profiling then snap.cpu, snap.mineCpu = 0, 0 end

    for i = 1, (safe(numAddOns) or 0) do
        local folder, title = safe(getInfo, i)
        if folder and safe(isLoaded, folder) then
            local entry = mine[folder]
            local row = {
                folder = folder,
                name = entry and (entry.fullName or entry.name) or tostring(title or folder):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""),
                memory = tonumber(safe(getMemory, folder)) or 0,
                mine = entry,
            }
            snap.memory = snap.memory + row.memory
            if entry then snap.mineMemory = snap.mineMemory + row.memory end
            row.self = folder == SELF
            if profiling then
                local total = tonumber(safe(getCpu, folder)) or 0
                cpuNow[folder] = total
                row.cpuTotal = total
                if prev and prev.cpu[folder] and dt > 0 then
                    row.cpu = max(0, total - prev.cpu[folder]) / dt
                    peaks[folder] = max(peaks[folder] or 0, row.cpu)
                    if row.self then
                        snap.selfCpu = row.cpu
                    else
                        snap.cpu = snap.cpu + row.cpu
                        if entry then snap.mineCpu = snap.mineCpu + row.cpu end
                    end
                end
                row.peak = peaks[folder]
            end
            snap.rows[#snap.rows + 1] = row
        end
    end
    if profiling then
        prev = { t = now, cpu = cpuNow }
        if not dt or dt <= 0 then snap.cpu, snap.mineCpu = nil, nil end
    else
        prev = nil
    end
    return snap
end

-- Forgets the last sample (when the page is closed, so the next CPU figure is not an average over minutes).
function Perf.Reset() prev = nil end

-- Forgets the highest figures (when the page is opened: the peak is "since you opened the page").
function Perf.ResetPeaks() peaks = {} end

-- Seconds since the game's CPU counters started (about since this load of the Hub).
function Perf.Uptime(now)
    return max(1, (now or (GetTime and GetTime()) or 0) - startedAt)
end

-- Sorts rows in place. key: "name", "memory" or "cpu". Biggest first for numbers, A-Z for names; `reverse` flips it.
-- Ties and missing numbers fall back to the name, so the order does not jump around between refreshes.
function Perf.Sort(rows, key, reverse)
    local function less(a, b)
        local x, y
        if key == "name" then
            x, y = strlower(a.name), strlower(b.name)
            if x ~= y then return x < y end
        else
            x, y = a[key] or -1, b[key] or -1
            if x ~= y then return x > y end
        end
        return strlower(a.name) < strlower(b.name)
    end
    sort(rows, reverse and function(a, b) return less(b, a) end or less)
    return rows
end

function Perf.Filter(rows, mineOnly)
    if not mineOnly then return rows end
    local out = {}
    for _, r in ipairs(rows) do if r.mine then out[#out + 1] = r end end
    return out
end

function Perf.FormatMemory(kb)
    kb = tonumber(kb) or 0
    if kb >= 1024 then return ("%.1f MB"):format(kb / 1024) end
    return ("%.0f KB"):format(kb)
end

function Perf.FormatCpu(msPerSecond)
    if msPerSecond == nil then return "-" end
    if msPerSecond < 0.005 then return "0 ms/s" end
    return ("%.2f ms/s"):format(msPerSecond)
end

-- Memory after the game has cleaned up what nothing uses any more. The number the game shows includes garbage
-- that is waiting to be collected, so this is the fairer one. Returns the snapshot before and after.
function Perf.Cleanup()
    local before = Perf.Snapshot()
    collectgarbage("collect")
    local after = Perf.Snapshot()
    return before, after
end

-- /allemano perf: the biggest ones in the chat, so the numbers can be had without opening the window.
HUB:AddSlashCommand("perf", function(arg)
    local snap = Perf.Snapshot()
    local mineOnly = strlower(arg or "") == "mine"
    local rows = Perf.Sort(Perf.Filter(snap.rows, mineOnly), "memory")
    HUB:Print(("Memory %s in %d addons, %s of it Allemano."):format(Perf.FormatMemory(snap.memory), #snap.rows, Perf.FormatMemory(snap.mineMemory)))
    for i = 1, math.min(#rows, 12) do
        local r = rows[i]
        HUB:Print(("%s: %s%s"):format(r.name, Perf.FormatMemory(r.memory), snap.profiling and (", " .. Perf.FormatCpu(r.cpu)) or ""))
    end
    if not snap.profiling then
        HUB:Print("CPU is not measured: open the Performance page and turn on profiling.")
    end
end, "memory use of the addons (add 'mine' for the Allemano ones only)")

-- The lines of the Hub's report: memory of all and of the Allemano addons, and, with profiling on, the average CPU
-- since the counters started. Text only.
function Perf.ReportLines()
    local snap = Perf.Snapshot()
    local lines = { "Performance:" }
    if not Perf.MemoryAvailable() then
        lines[#lines + 1] = "  This client does not report addon memory."
        return lines
    end
    lines[#lines + 1] = ("  Memory: %s in all %d loaded addons, %s of it Allemano addons"):format(
        Perf.FormatMemory(snap.memory), #snap.rows, Perf.FormatMemory(snap.mineMemory))
    local mine = Perf.Sort(Perf.Filter(snap.rows, true), "memory")
    local seconds = Perf.Uptime()
    for _, r in ipairs(mine) do
        local cpu = ""
        if snap.profiling and r.cpuTotal then cpu = (", CPU %s average"):format(Perf.FormatCpu(r.cpuTotal / seconds)) end
        lines[#lines + 1] = ("  %s: %s%s"):format(r.name, Perf.FormatMemory(r.memory), cpu)
    end
    lines[#lines + 1] = snap.profiling
        and ("  Script profiling is on; the CPU figures are the average over the %d minutes since the reload."):format(math.floor(seconds / 60 + 0.5))
        or "  Script profiling is off, so there are no CPU figures."
    return lines
end

-- A reminder at login when script profiling was left on: it costs a little performance, and it only changes with
-- a reload, so the player is told once and can turn it off in Hub > Performance.
HUB:RegisterEvent("PLAYER_LOGIN", function()
    C_Timer.After(8, function()
        if Perf.ProfilingOn() then
            Perf.reminded = true
            HUB:Print("Script profiling is on (Hub > Performance). It costs a little performance: turn it off when you are done measuring.")
        end
    end)
end)

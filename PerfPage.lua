-- Performance page: how much memory (and, with profiling on, CPU) every loaded addon uses, ours marked. The
-- numbers come from Perf.lua and refresh every couple of seconds while the page is open. The choices (our addons
-- or all, the sort) are remembered.
local _, HUB = ...

local Theme, W, Window, Perf = HUB.Theme, HUB.W, HUB.Window, HUB.Perf

local ROW_H, PAD = 30, 28
local MEM_W, CPU_W, PEAK_W = 110, 100, 100 -- the right-aligned number columns
local REFRESH = 2                          -- seconds between samples
local BAR_ALPHA_MINE, BAR_ALPHA_OTHER = 0.40, 0.26 -- how strong the memory bars are
local SORT_KEYS = { name = true, memory = true, cpu = true, peak = true }

local function hexColor(hex) return Theme.Hex(hex) end

-- The page's remembered choices, in the Hub's saved settings.
local function saved() return HUB.db and HUB.db.settings or {} end

local function createRow(list)
    local row = CreateFrame("Frame", nil, list)
    row.bar = W.Fill(row, "selected", 1)
    row.bar:SetPoint("TOPLEFT", 0, -2)
    row.bar:SetPoint("BOTTOMLEFT", 0, 2)
    W.Round(row.bar, Theme.radius.control)
    row.name = W.Text(row, 0, "text")
    row.name:SetPoint("LEFT", 12, 0)
    row.name:SetPoint("RIGHT", row, "RIGHT", -(MEM_W + CPU_W + PEAK_W + 24), 0)
    row.mem = W.Text(row, 0, "text")
    row.mem:SetPoint("RIGHT", -(CPU_W + PEAK_W + 16), 0)
    row.mem:SetJustifyH("RIGHT")
    row.cpu = W.Text(row, 0, "textDim")
    row.cpu:SetPoint("RIGHT", -(PEAK_W + 16), 0)
    row.cpu:SetJustifyH("RIGHT")
    row.peak = W.Text(row, 0, "textDim")
    row.peak:SetPoint("RIGHT", -16, 0)
    row.peak:SetJustifyH("RIGHT")
    return row
end

-- The Hub measures itself while this page is open: its figures are shown with a star and are not in the totals.
local function cpuText(value, item)
    local text = Perf.FormatCpu(value)
    if item.self and value ~= nil then text = text .. " *" end
    return text
end

local function updateRow(row, item, page)
    row.name:SetText(item.name)
    if item.mine then
        row.name:SetTextColor(hexColor(item.mine.color))
    else
        row.name:SetTextColor(Theme:Color("textDim"))
    end
    row.mem:SetText(Perf.FormatMemory(item.memory))
    row.cpu:SetText(cpuText(item.cpu, item))
    row.peak:SetText(cpuText(item.peak, item))
    local width = row:GetWidth()
    local fraction = page.maxMemory > 0 and item.memory / page.maxMemory or 0
    row.bar:SetWidth(max(1, (width > 0 and width or 400) * fraction))
    -- Our addons get their own colour, the others a light grey: both stand out against the dark window.
    if item.mine then
        row.bar:SetColorTexture(hexColor(item.mine.color))
        row.bar:SetAlpha(BAR_ALPHA_MINE)
    else
        row.bar:SetColorTexture(Theme:Color("textDim"))
        row.bar:SetAlpha(BAR_ALPHA_OTHER)
    end
end

local COLUMNS = {
    { key = "name", label = "Addon" },
    { key = "memory", label = "Memory" },
    { key = "cpu", label = "CPU" },
    { key = "peak", label = "Peak" },
}

Window.pages.perf = {
    Build = function(parent)
        local s = saved()
        local page = {
            frame = CreateFrame("Frame", nil, parent),
            sortKey = SORT_KEYS[s.perfSort] and s.perfSort or "memory",
            reverse = s.perfReverse == true,
            mineOnly = s.perfScope ~= "all",
            maxMemory = 0,
        }
        local f = page.frame
        f:SetAllPoints()

        -- Remembers the choices for the next time.
        local function remember()
            local d = saved()
            d.perfSort, d.perfReverse, d.perfScope = page.sortKey, page.reverse, page.mineOnly and "mine" or "all"
        end

        local title = W.Text(f, 8, "text")
        title:SetPoint("TOPLEFT", PAD, -28)
        title:SetText("Performance")
        page.summary = W.Text(f, 0, "textDim")
        page.summary:SetPoint("TOPLEFT", PAD, -68)

        page.cleanup = W.Button(f, "Clean up memory", "accent", nil)
        page.cleanup:SetPoint("TOPRIGHT", -PAD, -28)
        page.cleanup:SetScript("OnClick", function()
            local before, after = Perf.Cleanup()
            page.cleaned = ("Cleanup: %s to %s"):format(Perf.FormatMemory(before.memory), Perf.FormatMemory(after.memory))
            page:Refresh()
        end)
        page.cleanup:HookScript("OnEnter", function(self)
            W.ShowTooltip(self, {
                "Clean up memory",
                "Asks the game to free the memory that addons no longer use but have not given back yet (one garbage collection, once, for all addons together).",
                "The memory is read before and after, and the page shows both numbers.",
                "It does not unload any addon and does not change settings or saved data. The game may stutter for a moment while it runs.",
                "Addons use memory again as they work, so the number is not permanent.",
            })
        end)
        page.cleanup:HookScript("OnLeave", function() W.HideTooltip() end)
        page.scope = W.Segment(f, {
            { value = "mine", label = "Allemano" },
            { value = "all", label = "All addons" },
        }, function(value)
            page.mineOnly = value == "mine"
            remember()
            page:Refresh()
        end)
        page.scope:Set(page.mineOnly and "mine" or "all")
        page.scope:SetPoint("RIGHT", page.cleanup, "LEFT", -12, 0)

        -- column headers (click to sort)
        page.headers = {}
        for _, col in ipairs(COLUMNS) do
            local b = CreateFrame("Button", nil, f)
            b:SetHeight(22)
            b.col = col
            b.text = W.Text(b, -1, "textFaint")
            b:SetScript("OnClick", function()
                if page.sortKey == col.key then
                    page.reverse = not page.reverse
                else
                    page.sortKey, page.reverse = col.key, false
                end
                remember()
                page:Refresh()
            end)
            page.headers[col.key] = b
        end
        local h = page.headers
        h.name:SetPoint("TOPLEFT", PAD + 12, -104)
        h.name.text:SetPoint("LEFT")
        h.name:SetWidth(120)
        local function rightAligned(header, offset, width)
            header:SetPoint("TOPRIGHT", -(PAD + offset), -104)
            header.text:SetPoint("RIGHT")
            header.text:SetJustifyH("RIGHT")
            header:SetWidth(width)
        end
        rightAligned(h.memory, CPU_W + PEAK_W + 16, MEM_W)
        rightAligned(h.cpu, PEAK_W + 16, CPU_W)
        rightAligned(h.peak, 16, PEAK_W)
        h.peak:SetScript("OnEnter", function(self)
            W.ShowTooltip(self, "The highest CPU figure seen since you opened this page. It shows short peaks that an average hides.")
        end)
        h.peak:HookScript("OnLeave", function() W.HideTooltip() end)

        page.list = W.VirtualList(f, ROW_H, createRow, function(row, item) updateRow(row, item, page) end)
        page.list:SetPoint("TOPLEFT", PAD, -130)
        page.list:SetPoint("BOTTOMRIGHT", -PAD, 108)

        -- the CPU note and the profiling switch
        page.note = CreateFrame("Frame", nil, f)
        page.note:SetPoint("BOTTOMLEFT", PAD, PAD)
        page.note:SetPoint("BOTTOMRIGHT", -PAD, PAD)
        page.note:SetHeight(76)
        W.Surface(page.note, "field", 1, Theme.radius.panel)
        page.noteText = W.Text(page.note, -1, "textDim")
        page.noteText:SetWordWrap(true)
        page.noteText:SetJustifyV("MIDDLE")
        page.noteText:SetPoint("TOPLEFT", 16, -8)
        page.noteText:SetPoint("BOTTOMLEFT", 16, 8)
        page.noteText:SetPoint("RIGHT", page.note, "RIGHT", -230, 0)
        page.profile = W.Button(page.note, "Turn on profiling", "plain", nil)
        page.profile:SetPoint("RIGHT", -16, 0)
        page.profile:SetScript("OnClick", function()
            if not page.armed then
                page.armed = true
                page.profile:Configure("Click again to reload", "accent")
                C_Timer.After(4, function()
                    page.armed = false
                    page:Refresh()
                end)
                return
            end
            page.armed = false
            Perf.SetProfiling(not Perf.ProfilingOn())
            ReloadUI()
        end)

        -- sample every REFRESH seconds while the page is on screen
        local elapsed = 0
        f:SetScript("OnUpdate", function(_, dt)
            elapsed = elapsed + dt
            if elapsed >= REFRESH then
                elapsed = 0
                page:Refresh()
            end
        end)
        f:SetScript("OnShow", function() Perf.ResetPeaks() end)
        f:SetScript("OnHide", function() Perf.Reset() end)

        function page:Refresh()
            local snap = Perf.Snapshot()
            local rows = Perf.Sort(Perf.Filter(snap.rows, self.mineOnly), self.sortKey, self.reverse)
            self.maxMemory = 0
            for _, r in ipairs(rows) do if r.memory > self.maxMemory then self.maxMemory = r.memory end end

            local line = ("Allemano addons use %s of %s in all (%d addons loaded)."):format(
                Perf.FormatMemory(snap.mineMemory), Perf.FormatMemory(snap.memory), #snap.rows)
            if snap.profiling and snap.mineCpu then
                line = line .. ("  CPU: %s of %s (the Hub's own measuring left out)."):format(Perf.FormatCpu(snap.mineCpu), Perf.FormatCpu(snap.cpu))
            end
            if self.cleaned then line = line .. "  " .. self.cleaned .. "." end
            self.summary:SetText(line)

            for key, b in pairs(self.headers) do
                local mark = self.sortKey == key and (self.reverse and " ^" or " v") or ""
                local label
                for _, col in ipairs(COLUMNS) do if col.key == key then label = col.label end end
                b.text:SetText(strupper(label) .. mark)
                b.text:SetTextColor(Theme:Color(self.sortKey == key and "text" or "textFaint"))
            end

            if not Perf.MemoryAvailable() then
                self.noteText:SetText("This client does not report addon memory, so there is nothing to show here.")
                self.profile:Hide()
            elseif not Perf.CpuAvailable() then
                self.noteText:SetText("This client does not report addon CPU use. Memory is shown.")
                self.profile:Hide()
            elseif snap.profiling then
                self.noteText:SetText("CPU is milliseconds per second of play (the average since the last sample). * The Hub measures itself while this page is open, so its row is not in the totals. Profiling costs a little performance: turn it off when you are done.")
                self.profile:Show()
                if not self.armed then self.profile:Configure("Turn off profiling", "plain") end
            else
                self.noteText:SetText("CPU is not measured. Profiling needs a reload and costs a little performance while it is on, so it is off until you ask for it.")
                self.profile:Show()
                if not self.armed then self.profile:Configure("Turn on profiling", "plain") end
            end

            self.list:SetData(rows, true)
        end
        return page
    end,
}

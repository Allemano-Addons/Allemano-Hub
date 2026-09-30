-- Errors page: every error the Allemano addons recorded (WoW Forever hides Lua errors, so each addon
-- catches its own), with the newest first, the selected one in full, and a report to send.
local _, HUB = ...

local Theme, W, Registry, Window = HUB.Theme, HUB.W, HUB.Registry, HUB.Window

local ROW_H, PAD = 58, 28
local LIST_W = 470

local function hexColor(hex) return Theme.Hex(hex) end

-- Errors are rebuilt on every refresh, so the selection is remembered by a key that identifies one error.
local function keyOf(item) return item.addon.id .. "|" .. item.t .. "|" .. item.where .. "|" .. #item.msg end

-- ---------------------------------------------------------------------------
-- List rows
-- ---------------------------------------------------------------------------

local function createRow(list)
    local row = CreateFrame("Button", nil, list)
    row.bg = W.Fill(row, "selected", 1)
    row.bg:SetPoint("TOPLEFT", 0, -3)
    row.bg:SetPoint("BOTTOMRIGHT", -8, 3)
    W.Round(row.bg, Theme.radius.control)
    row.bg:Hide()
    row.addon = W.Text(row, -3, "text")
    row.addon:SetPoint("TOPLEFT", 14, -12)
    row.time = W.Text(row, -2, "textFaint")
    row.time:SetPoint("TOPRIGHT", -22, -12)
    row.time:SetJustifyH("RIGHT")
    row.where = W.Text(row, 0, "text")
    row.where:SetPoint("TOPLEFT", 14, -26)
    row.where:SetPoint("RIGHT", row, "RIGHT", -22, 0)
    row.msg = W.Text(row, -1, "textDim")
    row.msg:SetPoint("TOPLEFT", 14, -41)
    row.msg:SetPoint("RIGHT", row, "RIGHT", -22, 0)
    row:SetScript("OnClick", function(self)
        local page = self.page
        page.selectedKey = keyOf(self.item)
        page:Refresh()
    end)
    row:SetScript("OnEnter", function(self)
        if keyOf(self.item) ~= self.page.selectedKey then self.bg:SetAlpha(0.5) self.bg:Show() end
    end)
    row:SetScript("OnLeave", function(self)
        if keyOf(self.item) ~= self.page.selectedKey then self.bg:Hide() end
    end)
    return row
end

local function updateRow(row, item, page)
    row.item, row.page = item, page
    local r, g, b = hexColor(item.addon.color)
    row.addon:SetText(strupper(item.addon.name .. (item.v and (" v" .. tostring(item.v)) or "")))
    row.addon:SetTextColor(r, g, b)
    row.time:SetText(date("%d/%m %H:%M", item.t))
    row.where:SetText(item.where)
    row.msg:SetText((item.msg:gsub("%s+", " ")))
    row.bg:SetAlpha(1)
    row.bg:SetShown(keyOf(item) == page.selectedKey)
end

-- ---------------------------------------------------------------------------
-- The page
-- ---------------------------------------------------------------------------

Window.pages.errors = {
    Build = function(parent)
        local page = { frame = CreateFrame("Frame", nil, parent) }
        local f = page.frame
        f:SetAllPoints()

        local title = W.Text(f, 8, "text")
        title:SetPoint("TOPLEFT", PAD, -28)
        title:SetText("Errors")
        page.summary = W.Text(f, 0, "textDim")
        page.summary:SetPoint("TOPLEFT", PAD, -68)

        page.copy = W.Button(f, "Copy report", "accent", function() HUB.Report.Show() end, "share")
        page.copy:SetPoint("TOPRIGHT", -PAD, -28)
        page.clear = W.Button(f, "Clear all", "plain", nil)
        page.clear:SetPoint("RIGHT", page.copy, "LEFT", -8, 0)
        local armed
        page.clear:SetScript("OnClick", function()
            if not armed then
                armed = true
                page.clear:Configure("Click again to confirm", "plain")
                C_Timer.After(4, function()
                    armed = false
                    page.clear:Configure("Clear all", "plain")
                end)
                return
            end
            armed = false
            page.clear:Configure("Clear all", "plain")
            Registry:ClearErrors()
            page.selectedKey = nil
            Window:Refresh()
        end)

        page.list = W.VirtualList(f, ROW_H, createRow, function(row, item) updateRow(row, item, page) end)
        page.list:SetPoint("TOPLEFT", PAD, -104)
        page.list:SetPoint("BOTTOMLEFT", PAD, PAD)
        page.list:SetWidth(LIST_W)

        page.detail = CreateFrame("Frame", nil, f)
        page.detail:SetPoint("TOPLEFT", PAD + LIST_W + 18, -104)
        page.detail:SetPoint("BOTTOMRIGHT", -PAD, PAD)
        W.Surface(page.detail, "field", 1, Theme.radius.panel)
        local d = page.detail
        d.addon = W.Text(d, -2, "text")
        d.addon:SetPoint("TOPLEFT", 18, -18)
        d.where = W.Text(d, 3, "text")
        d.where:SetPoint("TOPLEFT", 18, -38)
        d.where:SetPoint("RIGHT", d, "RIGHT", -18, 0)
        d.time = W.Text(d, -1, "textFaint")
        d.time:SetPoint("TOPLEFT", d.where, "BOTTOMLEFT", 0, -6)
        d.label = W.Text(d, -2, "textFaint")
        d.label:SetPoint("TOPLEFT", 18, -100)
        d.label:SetText("MESSAGE")
        d.msg = W.Text(d, 0, "text")
        d.msg:SetWordWrap(true)
        d.msg:SetJustifyV("TOP")
        d.msg:SetPoint("TOPLEFT", 18, -120)
        d.msg:SetPoint("RIGHT", d, "RIGHT", -18, 0)
        d.hint = W.Text(d, -1, "textFaint")
        d.hint:SetWordWrap(true)
        d.hint:SetPoint("BOTTOMLEFT", 18, 16)
        d.hint:SetPoint("RIGHT", d, "RIGHT", -18, 0)
        d.hint:SetText("Send the report in the Allemano Discord with a line about what you were doing.")

        page.empty = W.Text(f, 1, "textFaint")
        page.empty:SetPoint("TOPLEFT", PAD, -110)
        page.empty:SetText("No errors recorded. WoW Forever hides Lua errors, so the Allemano addons catch their own and list them here.")
        page.empty:SetWidth(LIST_W)
        page.empty:SetWordWrap(true)

        function page:Refresh()
            local errors = Registry:Errors()
            local addons, seen = 0, {}
            for _, e in ipairs(errors) do
                if not seen[e.addon.id] then seen[e.addon.id] = true addons = addons + 1 end
            end
            self.summary:SetText(#errors == 0 and "Nothing to report." or
                ("%d error%s from %d addon%s"):format(#errors, #errors > 1 and "s" or "", addons, addons > 1 and "s" or ""))

            -- keep the selection if it is still there, else the newest
            local selected
            for _, err in ipairs(errors) do if keyOf(err) == self.selectedKey then selected = err end end
            if not selected then
                selected = errors[1]
                self.selectedKey = selected and keyOf(selected) or nil
            end

            self.list:SetData(errors, true)
            self.empty:SetShown(#errors == 0)
            self.detail:SetShown(#errors > 0)
            self.clear:SetShown(#errors > 0)
            local e = selected
            if e then
                local r, g, b = hexColor(e.addon.color)
                d.addon:SetText(strupper(e.addon.name .. (e.v and (" v" .. tostring(e.v)) or "")))
                d.addon:SetTextColor(r, g, b)
                d.where:SetText(e.where)
                d.time:SetText(date("%Y-%m-%d %H:%M", e.t))
                d.msg:SetText(e.msg)
            end
        end
        return page
    end,
}

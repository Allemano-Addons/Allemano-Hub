-- Guild page: a table of the guild members who run the Hub, with the version of each Allemano addon
-- they have. Green = the newest version known, orange = older (an update exists), a dash = not installed.
local _, HUB = ...

local Theme, W, Registry, Window, Version = HUB.Theme, HUB.W, HUB.Registry, HUB.Window, HUB.Version

local ROW_H, PAD = 40, 28
local NAME_W, COL_W = 210, 90
local SHORT = { hub = "Hub", hush = "Hush", altboard = "AltBoard", art = "ART", ["session-tracker"] = "Ledger", craftboard = "Craft", alc = "ALC", asr = "ASR", skins = "Skins" }
local HUB_COLUMN = { id = "hub", name = "Allemano Hub", color = "ECEDEF", isHub = true }

local function hexColor(hex) return Theme.Hex(hex) end

local function ago(t)
    local s = time() - (t or 0)
    if s < 90 then return "now" end
    if s < 3600 then return ("%d min ago"):format(s / 60) end
    if s < 86400 then return ("%d h ago"):format(s / 3600) end
    return ("%d d ago"):format(s / 86400)
end

-- The columns: the Hub itself, then the main addons in the Registry's order.
local function columns()
    local cols = { HUB_COLUMN }
    for _, e in ipairs(Registry.known) do
        if e.main then cols[#cols + 1] = e end
    end
    return cols
end

-- ---------------------------------------------------------------------------
-- Rows
-- ---------------------------------------------------------------------------

local function createRow(list)
    local row = CreateFrame("Frame", nil, list)
    row.bg = W.Fill(row, "selected", 1)
    row.bg:SetPoint("TOPLEFT", 0, -2)
    row.bg:SetPoint("BOTTOMRIGHT", -8, 2)
    W.Round(row.bg, Theme.radius.control)
    row.dot = row:CreateTexture(nil, "ARTWORK")
    row.dot:SetSize(8, 8)
    row.dot:SetPoint("LEFT", 14, 0)
    W.Round(row.dot, 4)
    row.name = W.Text(row, 1, "text")
    row.name:SetPoint("TOPLEFT", 32, -7)
    row.sub = W.Text(row, -2, "textFaint")
    row.sub:SetPoint("BOTTOMLEFT", 32, 6)
    row.cells = {}
    for i = 1, 16 do
        local c = W.Text(row, -1, "text")
        c:SetJustifyH("LEFT")
        row.cells[i] = c
    end
    return row
end

local function updateRow(row, m, page)
    row.bg:SetShown(m.me and true or false)
    if m.online then row.dot:SetColorTexture(Theme:Color("good")) else row.dot:SetColorTexture(Theme:Color("textFaint")) end
    row.name:SetText(m.me and (m.name .. "  (you)") or m.name)
    local r, g, b = Theme.ClassColor(m.class)
    row.name:SetTextColor(r, g, b, m.online and 1 or 0.55)
    local sub = "Hub " .. tostring(m.hub or "?")
    if not m.me and not m.online then sub = sub .. "  ·  seen " .. ago(m.t) end
    if m.left then sub = sub .. "  ·  left the guild" end
    row.sub:SetText(sub)
    for i, col in ipairs(page.columns) do
        local cell = row.cells[i]
        local slot = i - page.scroll -- columns scrolled out to the left or not fitting on the right are hidden
        if slot < 1 or slot > page.visibleCols then
            cell:Hide()
        else
        cell:ClearAllPoints()
        cell:SetPoint("LEFT", row, "LEFT", NAME_W + (slot - 1) * COL_W, 0)
        local v
        if col.isHub then v = m.hub and tostring(m.hub) or nil else v = m.addons[col.id] end
        if not v then
            cell:SetText("–")
            cell:SetTextColor(Theme:Color("textFaint"))
        else
            cell:SetText(v)
            local latest = page.latest[col.id]
            if latest and Version.Compare(v, latest) < 0 then
                cell:SetTextColor(Theme:Color("warn"))
            elseif latest and Version.Compare(v, latest) > 0 then
                cell:SetTextColor(hexColor(col.color))
            else
                cell:SetTextColor(Theme:Color("good"))
            end
        end
        cell:Show()
        end
    end
    for i = #page.columns + 1, #row.cells do row.cells[i]:Hide() end
end

-- ---------------------------------------------------------------------------
-- The page
-- ---------------------------------------------------------------------------

Window.pages.guild = {
    Build = function(parent)
        local page = { frame = CreateFrame("Frame", nil, parent), columns = columns(), latest = {}, scroll = 0, visibleCols = 6 }
        local f = page.frame
        f:SetAllPoints()

        local title = W.Text(f, 8, "text")
        title:SetPoint("TOPLEFT", PAD, -28)
        title:SetText("Guild")
        page.summary = W.Text(f, 0, "textDim")
        page.summary:SetPoint("TOPLEFT", PAD, -68)

        page.ask = W.Button(f, "Ask the guild", "accent", function()
            if HUB.Guild.Ask(false) then HUB:Print("Asked the guild.") else HUB:Print("Asked a moment ago; wait a minute.") end
        end, "sync")
        page.ask:SetPoint("TOPRIGHT", -PAD, -28)

        local shareLabel = W.Text(f, 0, "textDim")
        shareLabel:SetPoint("RIGHT", page.ask, "LEFT", -64, 0)
        shareLabel:SetText("Share my addon list")
        page.share = W.Toggle(f, function(on) HUB:SetSetting("shareAddons", on) end)
        page.share:SetPoint("LEFT", shareLabel, "RIGHT", 10, 0)
        page.share.refresh = function() page.share:Set(HUB.db.settings.shareAddons ~= false) end

        -- column headings
        local header = CreateFrame("Frame", nil, f)
        header:SetPoint("TOPLEFT", PAD, -104)
        header:SetPoint("TOPRIGHT", -PAD, -104)
        header:SetHeight(28)
        W.Line(header, "bottom", "line")
        local member = W.Text(header, -2, "textFaint")
        member:SetPoint("LEFT", 32, 0)
        member:SetText("MEMBER")
        page.headings, page.marks = {}, {}
        for i, col in ipairs(page.columns) do
            local mark = header:CreateTexture(nil, "ARTWORK")
            mark:SetSize(13, 11)
            mark:SetTexture(col.isHub and W.MARK or Window.MarkPath(col))
            local fs = W.Text(header, -2, "textFaint")
            fs:SetPoint("LEFT", mark, "RIGHT", 5, 0)
            fs:SetText(strupper(SHORT[col.id] or col.name))
            page.marks[i], page.headings[i] = mark, fs
        end

        -- Place the column headings for the current scroll position (the cells follow in updateRow).
        function page:LayoutHeadings()
            for i = 1, #self.columns do
                local slot = i - self.scroll
                local show = slot >= 1 and slot <= self.visibleCols
                self.marks[i]:SetShown(show)
                self.headings[i]:SetShown(show)
                if show then
                    self.marks[i]:ClearAllPoints()
                    self.marks[i]:SetPoint("LEFT", NAME_W + (slot - 1) * COL_W, 0)
                end
            end
        end

        page.list = W.VirtualList(f, ROW_H, createRow, function(row, m) updateRow(row, m, page) end)
        page.list:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
        page.list:SetPoint("BOTTOMRIGHT", -PAD, PAD + 58)

        -- More addons than fit: a slider under the table moves the columns sideways.
        page.slider = W.Slider(f, 0, 1, 1, 400, nil, function(value)
            page.scroll = value
            page:LayoutHeadings()
            page.list:Refresh()
        end)
        page.slider.label:Hide()
        page.slider:SetPoint("BOTTOMLEFT", PAD + NAME_W, PAD + 38)
        page.sliderHint = W.Text(f, -2, "textFaint")
        page.sliderHint:SetPoint("RIGHT", page.slider, "LEFT", -10, 0)
        page.sliderHint:SetText("MORE ADDONS")

        page.note = W.Text(f, -1, "textFaint")
        page.note:SetWordWrap(true)
        page.note:SetPoint("BOTTOMLEFT", PAD, PAD)
        page.note:SetPoint("BOTTOMRIGHT", -PAD, PAD)
        page.note:SetText("Green: the newest version known. Orange: an update exists. A dash: not installed. Members appear when " ..
            "they run Allemano Hub (it is optional) and it has heard from them; offline members keep their last list.")

        function page:Refresh()
            self.share.refresh()
            for _, e in ipairs(Registry:List()) do self.latest[e.id] = e.latest end
            local members = HUB.Guild:Members()
            -- The newest Hub version seen (mine included) is the green one.
            self.latest.hub = nil
            for _, m in ipairs(members) do
                local v = m.hub and tostring(m.hub) or nil
                if v and v ~= "" and (not self.latest.hub or Version.Compare(self.latest.hub, v) < 0) then self.latest.hub = v end
            end
            -- How many columns fit; the slider covers the rest.
            local viewW = (self.list:GetWidth() or 0) > 100 and self.list:GetWidth() or 840
            self.visibleCols = max(1, floor((viewW - NAME_W - 16) / COL_W))
            local maxScroll = max(0, #self.columns - self.visibleCols)
            self.scroll = min(self.scroll, maxScroll)
            self.slider:SetMinMaxValues(0, max(1, maxScroll))
            self.slider:SetWidth(max(120, viewW - NAME_W - 120))
            self.slider:Set(self.scroll)
            self.slider:SetShown(maxScroll > 0)
            self.sliderHint:SetShown(maxScroll > 0)
            self:LayoutHeadings()
            local others, online = HUB.Guild:Count()
            if not IsInGuild() then
                self.summary:SetText("You are not in a guild.")
            elseif others == 0 then
                self.summary:SetText("No one else has shared their addon list yet. Press \"Ask the guild\".")
            else
                self.summary:SetText(("%d guild member%s with Allemano Hub, %d online"):format(others, others > 1 and "s" or "", online))
            end
            self.list:SetData(members, true)
        end
        return page
    end,
}

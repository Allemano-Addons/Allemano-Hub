-- Overview page: an update banner, a card per Allemano addon, and the latest release notes.
-- "Update available" and the news come from Releases.lua, which tools/gen_releases.lua writes
-- from the addons' TOC versions and changelogs (an addon cannot ask the internet).
local _, HUB = ...

local Theme, W, Registry, Window = HUB.Theme, HUB.W, HUB.Registry, HUB.Window

local ROW_H = 54
local NEWS_W, PAD = 260, 28
local NEWS_AREA_H = 400 -- window height (680) minus the title bar, the news heading and the bottom margin
local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

local function shortDate(iso)
    local _, m, d = tostring(iso or ""):match("^(%d+)-(%d+)-(%d+)$")
    if not m then return "" end
    return MONTHS[tonumber(m)] .. " " .. tonumber(d)
end

local function hexColor(hex) return Theme.Hex(hex) end

-- ---------------------------------------------------------------------------
-- Banner
-- ---------------------------------------------------------------------------

local function buildBanner(parent)
    local b = CreateFrame("Frame", nil, parent)
    b:SetPoint("TOPLEFT", PAD, -74)
    b:SetPoint("TOPRIGHT", -PAD, -74)
    b:SetHeight(76)
    W.Surface(b, "field", 1, Theme.radius.panel)
    b.icon = W.Icon(b, "share", 18, "textDim")
    b.icon:SetTexCoord(0, 1, 1, 0) -- the upload arrow, flipped: a download arrow
    b.icon:SetPoint("LEFT", 22, 0)
    b.title = W.Text(b, 3, "text")
    b.title:SetPoint("TOPLEFT", 58, -18)
    b.detail = W.Text(b, 0, "textDim")
    b.detail:SetPoint("BOTTOMLEFT", 58, 16)
    b.detail:SetPoint("RIGHT", -20, 0)
    return b
end

local function refreshBanner(b)
    local updates = Registry:Updates()
    if #updates == 0 then
        b.title:SetText("Everything is up to date")
        b.detail:SetText("Checked against the release list built into this Hub (" .. tostring(HUB.releasesGenerated or "?") ..
            "). Updates arrive through the CurseForge app.")
        b.icon:SetVertexColor(Theme:Color("good"))
        return
    end
    b.icon:SetVertexColor(Theme:Color("warn"))
    b.title:SetText(("%d update%s available"):format(#updates, #updates > 1 and "s" or ""))
    local parts = {}
    for i, e in ipairs(updates) do
        if i <= 3 then parts[#parts + 1] = ("%s %s -> %s%s"):format(e.name, e.version, e.latest, e.latestFromGuild and " (seen in the guild)" or "") end
    end
    if #updates > 3 then parts[#parts + 1] = ("+%d more"):format(#updates - 3) end
    b.detail:SetText(table.concat(parts, ",  ") .. "  \194\183  update in the CurseForge app")
end

-- ---------------------------------------------------------------------------
-- The addons: one row each with the version (orange when an update exists), memory, errors, and
-- buttons for Open, Settings and a menu (what's new, the CurseForge link, the errors).
-- ---------------------------------------------------------------------------

local COL_VERSION, COL_MEMORY, COL_ERRORS = 188, 294, 354

local function openMenu(e, anchor)
    local items = { { text = e.fullName or e.name, title = true } }
    local rel = HUB.releases and HUB.releases[e.id]
    if rel and rel.note and rel.note ~= "" then
        items[#items + 1] = { text = "What's new in " .. tostring(rel.version or "the latest version"), onClick = function()
            Window.ShowCopyBox((e.fullName or e.name) .. " " .. tostring(rel.version or ""), rel.note)
        end }
    end
    if e.cf then
        items[#items + 1] = { text = "Copy the CurseForge link", onClick = function()
            Window.ShowCopyBox(e.fullName or e.name, Registry:CurseForgeURL(e))
        end }
    end
    if (e.errorCount or 0) > 0 then
        items[#items + 1] = { text = ("Show %d error%s"):format(e.errorCount, e.errorCount > 1 and "s" or ""), onClick = function()
            Window:Select("errors")
        end }
    end
    if #items == 1 then items[#items + 1] = { text = "Nothing to show yet" } end
    W.OpenMenu(items, anchor)
end

local function createCard(list)
    local row = CreateFrame("Button", nil, list)
    row.bg = W.Surface(row, "field", 1, Theme.radius.control)
    row.mark = row:CreateTexture(nil, "ARTWORK")
    row.mark:SetSize(28, 23)
    row.mark:SetPoint("LEFT", 16, 0)
    row.name = W.Text(row, 1, "text")
    row.name:SetPoint("TOPLEFT", 58, -9)
    row.name:SetWidth(COL_VERSION - 66)
    row.label = W.Text(row, -3, "textDim")
    row.label:SetPoint("BOTTOMLEFT", 58, 9)
    row.version = W.Text(row, 0, "text")
    row.version:SetPoint("LEFT", COL_VERSION, 0)
    row.version:SetWidth(COL_MEMORY - COL_VERSION - 6) -- a longer text is cut off, never printed over its neighbour
    row.memory = W.Text(row, -1, "textDim")
    row.memory:SetPoint("LEFT", COL_MEMORY, 0)
    row.memory:SetWidth(COL_ERRORS - COL_MEMORY - 6)
    row.errors = W.Text(row, -1, "warn")
    row.errors:SetPoint("LEFT", COL_ERRORS, 0)
    row.errors:SetWidth(64)

    row.more = W.Button(row, "...", "plain", function(self) if row.entry then openMenu(row.entry, self) end end)
    row.more:SetWidth(30)
    row.more:SetPoint("RIGHT", -20, 0)
    row.open = W.Button(row, "Open", "plain", function() if row.entry then Registry:Open(row.entry) end end)
    row.open:SetWidth(64)
    row.open:SetPoint("RIGHT", row.more, "LEFT", -6, 0)
    row.settings = W.IconButton(row, "settings", "Settings", function() if row.entry then Registry:OpenSettings(row.entry) end end)
    row.settings:SetPoint("RIGHT", row.open, "LEFT", -6, 0)

    row:SetScript("OnEnter", function(self)
        local e = self.entry
        if not e then return end
        local lines = { e.fullName or e.name, e.blurb or "" }
        if e.update then lines[#lines + 1] = ("Update: %s -> %s (in the CurseForge app)"):format(tostring(e.version), tostring(e.latest)) end
        if (e.errorCount or 0) > 0 then lines[#lines + 1] = ("%d recorded error%s"):format(e.errorCount, e.errorCount > 1 and "s" or "") end
        if not e.installed and e.cf then lines[#lines + 1] = "Click for the CurseForge link" end
        W.ShowTooltip(self, lines)
    end)
    row:SetScript("OnLeave", function() W.HideTooltip() end)
    row:SetScript("OnClick", function(self)
        local e = self.entry
        if e and not e.installed and e.cf then Window.ShowCopyBox(e.fullName or e.name, Registry:CurseForgeURL(e)) end
    end)
    return row
end

local function updateCard(row, e)
    row.entry = e
    local path = Window.MarkPath(e)
    if path then row.mark:SetTexture(path) end
    row.mark:SetAlpha(e.installed and 1 or 0.35)
    row.name:SetText(e.name)
    row.name:SetTextColor(Theme:Color(e.installed and "text" or "textDim"))
    row.label:SetText(e.label or "")
    local r, g, b = hexColor(e.color)
    row.label:SetTextColor(r, g, b, e.installed and 1 or 0.5)

    if not e.installed then
        row.version:SetText(e.soon and "Soon" or "Not installed")
        row.version:SetTextColor(Theme:Color("textFaint"))
    elseif not e.loaded then
        row.version:SetText("Not loaded")
        row.version:SetTextColor(Theme:Color("textFaint"))
    else
        row.version:SetText(tostring(e.version or "?"))
        row.version:SetTextColor(Theme:Color(e.update and "warn" or "good"))
    end
    row.memory:SetShown(e.loaded and e.memory ~= nil)
    if e.memory then row.memory:SetText(HUB.Perf.FormatMemory(e.memory)) end
    local n = e.errorCount or 0
    row.errors:SetShown(e.installed and true or false)
    if n > 0 then
        row.errors:SetText(n == 1 and "1 error" or (n .. " errors"))
        row.errors:SetTextColor(Theme:Color("warn"))
    else
        row.errors:SetText("no errors")
        row.errors:SetTextColor(Theme:Color("textFaint"))
    end
    row.open:SetShown((e.loaded and e.slash) and true or false)
    row.settings:SetShown((e.loaded and e.settings) and true or false)
    row.more:SetShown(true)
end

-- ---------------------------------------------------------------------------
-- News
-- ---------------------------------------------------------------------------

local function createNewsCard(parent)
    local c = CreateFrame("Frame", nil, parent)
    W.Surface(c, "field", 1, Theme.radius.control)
    c.name = W.Text(c, -3, "text")
    c.name:SetPoint("TOPLEFT", 14, -12)
    c.date = W.Text(c, -2, "textFaint")
    c.date:SetPoint("TOPRIGHT", -14, -12)
    c.date:SetJustifyH("RIGHT")
    c.note = W.Text(c, 0, "text")
    c.note:SetWordWrap(true)
    c.note:SetPoint("TOPLEFT", 14, -32)
    c.note:SetWidth(NEWS_W - 28)
    return c
end

local function updateNewsCard(c, item)
    local r, g, b = hexColor(item.entry.color)
    c.name:SetText(strupper(item.entry.name))
    c.name:SetTextColor(r, g, b)
    c.date:SetText(shortDate(item.date))
    c.note:SetText(("%s"):format(item.note))
    c:SetHeight(32 + c.note:GetStringHeight() + 16)
end

-- ---------------------------------------------------------------------------
-- The page
-- ---------------------------------------------------------------------------

Window.pages.overview = {
    Build = function(parent)
        local page = { frame = CreateFrame("Frame", nil, parent), news = {} }
        local f = page.frame
        f:SetAllPoints()

        local title = W.Text(f, 8, "text")
        title:SetPoint("TOPLEFT", PAD, -28)
        title:SetText("Overview")

        page.banner = buildBanner(f)

        local function label(text, point, x, y)
            local fs = W.Text(f, -2, "textFaint")
            fs:SetPoint(point, x, y)
            fs:SetText(text)
        end
        label("YOUR ADDONS", "TOPLEFT", PAD, -176)
        label("NEWS", "TOPRIGHT", -(PAD + NEWS_W - 30), -176)

        page.list = W.VirtualList(f, ROW_H, createCard, function(row, e) updateCard(row, e) end)
        page.list:SetPoint("TOPLEFT", PAD, -200)
        page.list:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(PAD + NEWS_W + 22), PAD)
        page.newsArea = CreateFrame("Frame", nil, f)
        page.newsArea:SetPoint("TOPRIGHT", -PAD, -200)
        page.newsArea:SetPoint("BOTTOMRIGHT", -PAD, PAD)
        page.newsArea:SetWidth(NEWS_W)

        function page:Refresh()
            refreshBanner(self.banner)

            local entries = Registry:Main()
            -- memory per addon and the number of recorded errors, for the rows
            local memory = {}
            if HUB.Perf.MemoryAvailable() then
                for _, r in ipairs(HUB.Perf.Snapshot().rows) do memory[r.folder] = r.memory end
            end
            local errorCount = {}
            for _, err in ipairs(Registry:Errors()) do errorCount[err.addon.id] = (errorCount[err.addon.id] or 0) + 1 end
            for _, e in ipairs(entries) do
                e.memory = memory[e.folder]
                e.errorCount = errorCount[e.id] or 0
            end
            self.list:SetData(entries, true)

            -- news: the newest note of each addon, newest first
            local items = {}
            for _, e in ipairs(entries) do
                local rel = HUB.releases and HUB.releases[e.id]
                if rel and rel.note and rel.note ~= "" then
                    items[#items + 1] = { entry = e, date = rel.date or "", note = rel.note }
                end
            end
            table.sort(items, function(a, b)
                if a.date ~= b.date then return a.date > b.date end
                return a.entry.name < b.entry.name
            end)
            -- as many as fit in the column
            local y, shown = 0, 0
            for i = 1, #items do
                local c = self.news[i]
                if not c then
                    c = createNewsCard(self.newsArea)
                    self.news[i] = c
                end
                c:SetWidth(NEWS_W)
                updateNewsCard(c, items[i])
                if y + c:GetHeight() > NEWS_AREA_H then break end
                c:ClearAllPoints()
                c:SetPoint("TOPLEFT", 0, -y)
                c:Show()
                shown = shown + 1
                y = y + c:GetHeight() + 8
            end
            for i = shown + 1, #self.news do self.news[i]:Hide() end
        end
        return page
    end,
}

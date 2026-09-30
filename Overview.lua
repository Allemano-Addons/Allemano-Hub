-- Overview page: an update banner, a card per Allemano addon, and the latest release notes.
-- "Update available" and the news come from Releases.lua, which tools/gen_releases.lua writes
-- from the addons' TOC versions and changelogs (an addon cannot ask the internet).
local _, HUB = ...

local Theme, W, Registry, Window = HUB.Theme, HUB.W, HUB.Registry, HUB.Window

local CARD_H, CARD_GAP = 72, 10
local NEWS_W, PAD = 300, 28
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
        if i <= 3 then parts[#parts + 1] = ("%s %s -> %s"):format(e.name, e.version, e.latest) end
    end
    if #updates > 3 then parts[#parts + 1] = ("+%d more"):format(#updates - 3) end
    b.detail:SetText(table.concat(parts, ",  ") .. "  \194\183  update in the CurseForge app")
end

-- ---------------------------------------------------------------------------
-- Addon cards
-- ---------------------------------------------------------------------------

local function createCard(parent)
    local card = CreateFrame("Button", nil, parent)
    card:SetHeight(CARD_H)
    W.Surface(card, "field", 1, Theme.radius.control)
    card.mark = card:CreateTexture(nil, "ARTWORK")
    card.mark:SetSize(28, 23)
    card.mark:SetPoint("LEFT", 16, 0)
    card.name = W.Text(card, 1, "text")
    card.name:SetPoint("TOPLEFT", 58, -16)
    card.name:SetPoint("RIGHT", card, "RIGHT", -82, 0)
    card.label = W.Text(card, -3, "textDim")
    card.label:SetPoint("BOTTOMLEFT", 58, 15)
    card.open = W.Button(card, "Open", "plain", function() if card.entry then Registry:Open(card.entry) end end)
    card.open:SetPoint("RIGHT", -14, 0)
    card.open:SetWidth(64)
    card.status = W.Text(card, -1, "textFaint")
    card.status:SetPoint("RIGHT", -16, 0)
    card.status:SetJustifyH("RIGHT")
    card:SetScript("OnClick", function(self)
        local e = self.entry
        if e and not e.installed and e.cf then Window.ShowCopyBox(e.fullName or e.name, Registry:CurseForgeURL(e)) end
    end)
    card:SetScript("OnEnter", function(self)
        local e = self.entry
        if e then W.ShowTooltip(self, { e.fullName or e.name, e.blurb or "", e.installed and "" or (e.cf and "Click for the CurseForge link" or "") }) end
    end)
    card:SetScript("OnLeave", function() W.HideTooltip() end)
    return card
end

local function updateCard(card, e)
    card.entry = e
    local path = Window.MarkPath(e)
    if path then card.mark:SetTexture(path) end
    card.mark:SetAlpha(e.installed and 1 or 0.35)
    card.name:SetText(e.name)
    card.name:SetTextColor(Theme:Color(e.installed and "text" or "textDim"))
    card.label:SetText(e.label or "")
    local r, g, b = hexColor(e.color)
    card.label:SetTextColor(r, g, b, e.installed and 1 or 0.5)
    local canOpen = e.loaded and e.slash
    card.open:SetShown(canOpen and true or false)
    card.status:SetShown(not canOpen)
    if not e.installed then
        card.status:SetText(e.soon and "Soon" or "Not installed")
    else
        card.status:SetText("Not loaded")
    end
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
        local page = { frame = CreateFrame("Frame", nil, parent), cards = {}, news = {} }
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

        page.cardArea = CreateFrame("Frame", nil, f)
        page.cardArea:SetPoint("TOPLEFT", PAD, -200)
        page.cardArea:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(PAD + NEWS_W + 22), PAD)
        page.newsArea = CreateFrame("Frame", nil, f)
        page.newsArea:SetPoint("TOPRIGHT", -PAD, -200)
        page.newsArea:SetPoint("BOTTOMRIGHT", -PAD, PAD)
        page.newsArea:SetWidth(NEWS_W)

        function page:Refresh()
            refreshBanner(self.banner)

            local entries = Registry:Main()
            local w = self.cardArea:GetWidth()
            local cardW = (w - CARD_GAP) / 2
            for i, e in ipairs(entries) do
                local card = self.cards[i]
                if not card then
                    card = createCard(self.cardArea)
                    self.cards[i] = card
                end
                card:SetWidth(cardW)
                card:ClearAllPoints()
                local col, row = (i - 1) % 2, floor((i - 1) / 2)
                card:SetPoint("TOPLEFT", col * (cardW + CARD_GAP), -row * (CARD_H + CARD_GAP))
                updateCard(card, e)
                card:Show()
            end
            for i = #entries + 1, #self.cards do self.cards[i]:Hide() end

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

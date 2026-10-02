-- Window: the Hub. A title bar, a sidebar (the Hub's pages and every Allemano addon) and the
-- selected page. Pages live in their own files and register with Window.pages[key] = { Build = fn }.
local _, HUB = ...

local Theme, W, Registry = HUB.Theme, HUB.W, HUB.Registry
local Window = {}
HUB.Window = Window

local MEDIA = "Interface\\AddOns\\AllemanoHub\\Media\\"
local WIDTH, HEIGHT = 1120, 680
local TITLE_H, SIDE_W = 50, 214
local NAV_H = 34

Window.pages = {}   -- key -> { Build = function(parent) -> page }
Window.MEDIA = MEDIA

local frame, content
local built = {}    -- key -> page (frames are built the first time a page is shown)
local navRows = {}  -- the sidebar rows, in order
local current

local HUB_PAGES = {
    { key = "overview", label = "Overview", icon = "overview" },
    { key = "appearance", label = "Appearance", icon = "appearance" },
    { key = "guild", label = "Guild", icon = "guild" },
    { key = "errors", label = "Errors", icon = "errors", badge = true },
    { key = "perf", label = "Performance", icon = "sync" },
}

function Window.MarkPath(entry) return entry.mark and (MEDIA .. "marks\\" .. entry.mark) or nil end

-- ---------------------------------------------------------------------------
-- A small box with text to copy (links cannot be opened from the game).
-- ---------------------------------------------------------------------------

local copyBox
function Window.ShowCopyBox(title, text)
    if not copyBox then
        copyBox = CreateFrame("Frame", "AllemanoHubCopyBox", UIParent)
        tinsert(UISpecialFrames, "AllemanoHubCopyBox")
        copyBox:SetFrameStrata("DIALOG")
        copyBox:SetToplevel(true)
        copyBox:SetSize(460, 118)
        copyBox:SetPoint("CENTER", 0, 80)
        copyBox:EnableMouse(true)
        W.Surface(copyBox, "window", 0.98, Theme.radius.panel)
        copyBox.title = W.Text(copyBox, 2, "text")
        copyBox.title:SetPoint("TOPLEFT", 16, -14)
        copyBox.edit = W.EditBox(copyBox, "", 30)
        copyBox.edit:SetPoint("TOPLEFT", 16, -44)
        copyBox.edit:SetPoint("TOPRIGHT", -16, -44)
        copyBox.edit.icon:Hide()
        copyBox.edit:SetTextInsets(10, 10, 0, 0)
        copyBox.edit:SetScript("OnEscapePressed", function() copyBox:Hide() end)
        copyBox.hint = W.Text(copyBox, -1, "textFaint")
        copyBox.hint:SetPoint("TOPLEFT", 16, -84)
        copyBox.hint:SetText("Press Ctrl+C to copy, then Esc")
        local close = W.CloseButton(copyBox, function() copyBox:Hide() end)
        close:SetPoint("TOPRIGHT", -8, -8)
    end
    copyBox.title:SetText(title)
    copyBox.edit:SetText(text)
    copyBox.edit:SetScript("OnTextChanged", function(self) -- read only: put the text back if it is edited
        if self:GetText() ~= text then self:SetText(text) self:HighlightText() end
    end)
    copyBox:Show()
    copyBox.edit:SetFocus()
    copyBox.edit:HighlightText()
end

-- ---------------------------------------------------------------------------
-- Sidebar
-- ---------------------------------------------------------------------------

local function navRow(parent, def)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(NAV_H)
    row.def = def
    row.bg = W.Fill(row, "selected", 1)
    row.bg:SetPoint("TOPLEFT", 8, -1)
    row.bg:SetPoint("BOTTOMRIGHT", -8, 1)
    W.Round(row.bg, Theme.radius.control)
    row.bg:Hide()
    if def.mark then
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 15)
        row.icon:SetPoint("LEFT", 22, 0)
        row.icon:SetTexture(def.mark)
    else
        row.icon = W.Icon(row, def.icon, 16, "textDim")
        row.icon:SetPoint("LEFT", 22, 0)
    end
    row.text = W.Text(row, 1, "textDim")
    row.text:SetPoint("LEFT", 48, 0)
    row.badge = W.Text(row, -1, "warn")
    row.badge:SetPoint("RIGHT", -24, 0)
    row.badge:SetJustifyH("RIGHT")
    row.dot = row:CreateTexture(nil, "ARTWORK")
    row.dot:SetSize(7, 7)
    row.dot:SetPoint("RIGHT", -26, 0)
    W.Round(row.dot, 3.5)
    row.dot:SetColorTexture(Theme:Color("warn"))
    row.dot:Hide()
    row:SetScript("OnEnter", function(self) if self.def.key ~= current then self.bg:SetAlpha(0.5) self.bg:Show() end end)
    row:SetScript("OnLeave", function(self) if self.def.key ~= current then self.bg:Hide() end end)
    row:SetScript("OnClick", function(self) Window:Select(self.def.key) end)
    row.text:SetText(def.label)
    return row
end

local function sectionLabel(parent, text, y)
    local fs = W.Text(parent, -2, "textFaint")
    fs:SetPoint("TOPLEFT", 24, y)
    fs:SetText(text)
    return fs
end

local function buildSidebar(parent)
    local s = CreateFrame("Frame", nil, parent)
    s:SetWidth(SIDE_W)
    s:SetPoint("TOPLEFT", 1, -TITLE_H)
    s:SetPoint("BOTTOMLEFT", 1, 1)
    local sbg = W.Fill(s, "sidebar", 1)
    sbg:SetAllPoints()
    W.Round(sbg, Theme.radius.panel)
    local cap = W.Fill(s, "sidebar", 1)
    cap:SetPoint("TOPLEFT")
    cap:SetPoint("TOPRIGHT")
    cap:SetHeight(24)
    W.Line(s, "right", "line")

    sectionLabel(s, "HUB", -20)
    local y = -40
    for _, def in ipairs(HUB_PAGES) do
        local row = navRow(s, def)
        row:SetPoint("TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", 0, y)
        navRows[#navRows + 1] = row
        y = y - NAV_H - 2
    end

    local sep = W.Line(s, "top", "line")
    sep:ClearAllPoints()
    sep:SetPoint("TOPLEFT", 16, y - 8)
    sep:SetPoint("TOPRIGHT", -16, y - 8)
    sep:SetHeight(Theme:Pixel(s))
    sectionLabel(s, "ADDONS", y - 26)
    y = y - 46
    s.addonsTop = y
    frame.sidebar = s
end

-- The addon rows follow what the Registry lists (built the first time the window opens).
local function buildAddonRows()
    local s = frame.sidebar
    local y = s.addonsTop
    for _, e in ipairs(Registry:Main()) do
        local row = navRow(s, { key = "addon:" .. e.id, label = e.name, mark = Window.MarkPath(e), entry = e })
        row:SetPoint("TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", 0, y)
        navRows[#navRows + 1] = row
        y = y - NAV_H - 2
    end
end

function Window:RefreshNav()
    local errors = Registry:ErrorCount()
    local byId = {}
    for _, e in ipairs(Registry:List()) do byId[e.id] = e end
    for _, row in ipairs(navRows) do
        local def = row.def
        local selected = def.key == current
        row.bg:SetAlpha(1)
        row.bg:SetShown(selected)
        row.text:SetTextColor(Theme:Color(selected and "text" or "textDim"))
        if def.badge then
            row.badge:SetText(errors > 0 and tostring(errors) or "")
        end
        if def.key == "perf" then
            -- a reminder that script profiling is on: it costs a little performance
            row.badge:SetText(HUB.Perf and HUB.Perf.ProfilingOn() and "ON" or "")
        end
        if def.entry then
            local e = byId[def.entry.id] or def.entry
            row.dot:SetShown(e.update and true or false)
            row.icon:SetAlpha(e.installed and 1 or 0.4)
            row.text:SetTextColor(Theme:Color(not e.installed and "textFaint" or selected and "text" or "textDim"))
        elseif def.icon then
            row.icon:SetVertexColor(Theme:Color(selected and "text" or "textDim"))
        end
    end
end

-- ---------------------------------------------------------------------------
-- Pages
-- ---------------------------------------------------------------------------

-- A page for what is not built yet.
local function placeholder(label)
    return {
        Build = function(parent)
            local page = { frame = CreateFrame("Frame", nil, parent) }
            page.frame:SetAllPoints()
            local title = W.Text(page.frame, 8, "text")
            title:SetPoint("TOPLEFT", 28, -28)
            title:SetText(label)
            local text = W.Text(page.frame, 1, "textFaint")
            text:SetPoint("TOPLEFT", 28, -74)
            text:SetText("Coming in a later version.")
            function page:Refresh() end
            return page
        end,
    }
end

function Window:Select(key)
    if not frame then return end
    current = key
    for k, page in pairs(built) do page.frame:SetShown(k == key) end
    local page = built[key]
    if not page then
        local def = Window.pages[key]
        if not def then
            local label = key
            for _, row in ipairs(navRows) do if row.def.key == key then label = row.def.label end end
            def = placeholder(label)
        end
        page = def.Build(content)
        built[key] = page
    end
    page.frame:Show()
    if key == "errors" and frame:IsShown() then Registry:MarkErrorsSeen() end
    if page.Refresh then page:Refresh() end
    self:RefreshNav()
    if HUB.UpdateLauncher then HUB.UpdateLauncher() end
end

-- The built page for a key (used by tests).
function Window.Page(key) return built[key] end

function Window:Refresh()
    if not frame or not frame:IsShown() then return end
    local page = current and built[current]
    if current == "errors" then Registry:MarkErrorsSeen() end
    if page and page.Refresh then page:Refresh() end
    self:RefreshNav()
    if HUB.UpdateLauncher then HUB.UpdateLauncher() end
end

-- ---------------------------------------------------------------------------
-- Frame
-- ---------------------------------------------------------------------------

local function savePosition()
    local d = HUB.db.settings
    local scale = frame:GetScale()
    d.left, d.top = frame:GetLeft() * scale, frame:GetTop() * scale
end

local function restorePosition()
    local d = HUB.db.settings
    local scale = frame:GetScale()
    frame:ClearAllPoints()
    if d.left and d.top then
        frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", d.left / scale, d.top / scale)
    else
        frame:SetPoint("CENTER")
    end
end

local function build()
    frame = CreateFrame("Frame", "AllemanoHubFrame", UIParent)
    tinsert(UISpecialFrames, "AllemanoHubFrame") -- ESC closes it
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetSize(WIDTH, HEIGHT)
    frame:SetScale(HUB.db.settings.scale or 1)
    frame.bg = W.Surface(frame, "window", HUB.db.settings.bgAlpha or 0.97, Theme.radius.panel)

    local title = CreateFrame("Frame", nil, frame)
    title:SetPoint("TOPLEFT")
    title:SetPoint("TOPRIGHT")
    title:SetHeight(TITLE_H)
    W.Line(title, "bottom", "line")
    title:EnableMouse(true)
    title:RegisterForDrag("LeftButton")
    title:SetScript("OnDragStart", function() frame:StartMoving() end)
    title:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        savePosition()
    end)

    local logo = title:CreateTexture(nil, "ARTWORK")
    logo:SetSize(26, 22)
    logo:SetPoint("LEFT", 18, 0)
    if logo:SetTexture(W.MARK) == false then logo:SetColorTexture(Theme:Color("accent")) end
    local name = W.Text(title, 3, "text")
    name:SetPoint("LEFT", logo, "RIGHT", 12, 0)
    name:SetText("ALLEMANO")
    local sub = W.Text(title, -3, "textDim")
    sub:SetPoint("LEFT", name, "RIGHT", 10, -2)
    sub:SetText("HUB")

    local close = W.CloseButton(title, function() frame:Hide() end)
    close:SetPoint("RIGHT", -14, 0)
    local version = W.Text(title, 0, "textFaint")
    version:SetPoint("RIGHT", close, "LEFT", -18, 0)
    version:SetText("v" .. tostring(HUB.version))

    buildSidebar(frame)
    buildAddonRows()

    content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", frame.sidebar, "TOPRIGHT", 0, 0)
    content:SetPoint("BOTTOMRIGHT", -1, 1)
    frame.content = content

    frame:SetScript("OnShow", function()
        if not current then Window:Select("overview") else Window:Refresh() end
    end)
    restorePosition()
    frame:Hide()
end

function Window.Frame() return frame end

function Window.Toggle()
    if not frame then build() end
    frame:SetShown(not frame:IsShown())
end

function Window.Show()
    if not frame then build() end
    frame:Show()
end

function Window.ResetPosition()
    HUB.db.settings.left, HUB.db.settings.top = nil, nil
    if frame then restorePosition() end
end

HUB:OnSettingChanged(function(key, value)
    if not frame then return end
    if key == "scale" then
        local d = HUB.db.settings
        if not (d.left and d.top) then savePosition() end
        frame:SetScale(value)
        restorePosition()
    elseif key == "bgAlpha" then
        frame.bg:SetAlpha(value)
    elseif key == "accentMode" or key == "accent" or key == "font" or key == "textSize" then
        Window:Refresh()
    end
end)

HUB:AddSlashCommand("open", function() Window.Toggle() end, "open or close the window")

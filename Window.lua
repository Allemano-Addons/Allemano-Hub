-- Window: the Hub. A list of every Allemano addon with its version and state, and shortcuts.
local _, HUB = ...

local Theme, W, Registry = HUB.Theme, HUB.W, HUB.Registry
local Window = {}
HUB.Window = Window

local WIDTH, HEIGHT = 660, 580
local TITLE_H, FOOTER_H, ROW_H = 46, 56, 50
local frame, rows = nil, {}

-- ---------------------------------------------------------------------------
-- A small box with text to copy (links cannot be opened from the game).
-- ---------------------------------------------------------------------------

local copyBox
local function showCopyBox(title, text)
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
Window.ShowCopyBox = showCopyBox

-- ---------------------------------------------------------------------------
-- Rows
-- ---------------------------------------------------------------------------

local function createRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_H)
    row.bg = W.Fill(row, "selected", 1)
    row.bg:SetPoint("TOPLEFT", 0, -2)
    row.bg:SetPoint("BOTTOMRIGHT", 0, 2)
    W.Round(row.bg, Theme.radius.control)
    row.bar = W.Fill(row, "accent", 1, "ARTWORK")
    row.bar:SetSize(4, 28)
    row.bar:SetPoint("LEFT", 12, 0)
    W.Round(row.bar, 2)
    row.name = W.Text(row, 2, "text")
    row.name:SetPoint("TOPLEFT", 28, -11)
    row.blurb = W.Text(row, -1, "textDim")
    row.blurb:SetPoint("BOTTOMLEFT", 28, 10)
    row.blurb:SetPoint("RIGHT", row, "RIGHT", -250, 0)
    row.status = W.Text(row, -1, "textDim")
    row.status:SetPoint("TOPRIGHT", row, "TOPRIGHT", -186, -11)
    row.status:SetJustifyH("RIGHT")
    row.version = W.Text(row, 0, "textDim")
    row.version:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -186, 10)
    row.version:SetJustifyH("RIGHT")
    row.open = W.Button(row, "Open", "accent", function() Registry:Open(row.entry) end)
    row.open:SetPoint("RIGHT", -12, 0)
    row.open:SetWidth(78)
    row.settings = W.IconButton(row, "settings", "Settings", function() Registry:OpenSettings(row.entry) end)
    row.settings:SetPoint("RIGHT", row.open, "LEFT", -6, 0)
    row.get = W.Button(row, "Get it", "plain", function()
        local url = Registry:CurseForgeURL(row.entry)
        if url then showCopyBox(row.entry.name .. " on CurseForge", url) end
    end)
    row.get:SetPoint("RIGHT", -12, 0)
    row.get:SetWidth(78)
    return row
end

local function hexColor(hex)
    return Theme.Hex(hex)
end

local function updateRow(row, e)
    row.entry = e
    row.bar:SetColorTexture(hexColor(e.color))
    row.name:SetText(e.name)
    row.blurb:SetText(e.blurb or "")
    row.version:SetText(e.version and ("v" .. e.version) or "")
    if not e.installed then
        row.status:SetText("Not installed")
        row.status:SetTextColor(Theme:Color("textFaint"))
        row.name:SetTextColor(Theme:Color("textDim"))
    elseif e.loaded then
        row.status:SetText("Loaded")
        row.status:SetTextColor(Theme:Color("good"))
        row.name:SetTextColor(Theme:Color("text"))
    else
        row.status:SetText("Installed, not loaded")
        row.status:SetTextColor(Theme:Color("warn"))
        row.name:SetTextColor(Theme:Color("text"))
    end
    local canOpen = e.loaded and e.slash
    row.open:SetShown(canOpen and true or false)
    row.settings:SetShown(canOpen and e.settings and true or false)
    row.get:SetShown(not e.installed and e.cf and true or false)
    row.bg:SetAlpha(e.installed and 1 or 0.55)
end

function Window:Refresh()
    if not frame or not frame:IsShown() then return end
    local list = Registry:List()
    local installed = 0
    for i, e in ipairs(list) do
        local row = rows[i]
        if not row then
            row = createRow(frame.body)
            row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
            row:SetPoint("TOPRIGHT", 0, -(i - 1) * ROW_H)
            rows[i] = row
        end
        updateRow(row, e)
        row:Show()
        if e.installed then installed = installed + 1 end
    end
    for i = #list + 1, #rows do rows[i]:Hide() end
    frame.count:SetText(("%d of %d installed"):format(installed, #list))
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
    logo:SetSize(24, 24)
    logo:SetPoint("LEFT", 16, 0)
    if logo:SetTexture(W.MARK) == false then logo:SetColorTexture(Theme:Color("accent")) end
    local name = W.Text(title, 4, "text")
    name:SetPoint("LEFT", logo, "RIGHT", 10, 0)
    name:SetText("Allemano Hub")

    local close = W.CloseButton(title, function() frame:Hide() end)
    close:SetPoint("RIGHT", -12, 0)
    local refresh = W.IconButton(title, "sync", "Refresh", function() Window:Refresh() end)
    refresh:SetPoint("RIGHT", close, "LEFT", -4, 0)
    frame.count = W.Text(title, 0, "textDim")
    frame.count:SetPoint("RIGHT", refresh, "LEFT", -12, 0)

    frame.body = CreateFrame("Frame", nil, frame)
    frame.body:SetPoint("TOPLEFT", 14, -(TITLE_H + 12))
    frame.body:SetPoint("TOPRIGHT", -14, -(TITLE_H + 12))
    frame.body:SetHeight(#Registry.known * ROW_H + 40)

    local footer = CreateFrame("Frame", nil, frame)
    footer:SetPoint("BOTTOMLEFT")
    footer:SetPoint("BOTTOMRIGHT")
    footer:SetHeight(FOOTER_H)
    W.Line(footer, "top", "line")
    local note = W.Text(footer, -1, "textFaint")
    note:SetPoint("LEFT", 16, 0)
    note:SetText("Allemano Hub is optional. Every addon works without it.")
    local discord = W.Button(footer, "Discord", "plain", function() showCopyBox("Allemano Discord", Registry.URL.discord) end)
    discord:SetPoint("RIGHT", -14, 0)
    local site = W.Button(footer, "Website", "plain", function() showCopyBox("Allemano Addons", Registry.URL.site) end)
    site:SetPoint("RIGHT", discord, "LEFT", -8, 0)
    frame.footer = footer

    frame:SetScript("OnShow", function() Window:Refresh() end)
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

-- Launcher: the same small movable button as the other Allemano addons (a dark rounded square
-- with the mark filling it). Click opens the Hub, drag moves it.
local _, HUB = ...

local Theme, W = HUB.Theme, HUB.W
local SIZE = 30
local button, badge

local function savePosition()
    local d = HUB.db.settings
    d.launcherLeft, d.launcherTop = button:GetLeft(), button:GetTop()
end

local function restorePosition()
    local d = HUB.db.settings
    button:ClearAllPoints()
    if d.launcherLeft and d.launcherTop then
        button:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", d.launcherLeft, d.launcherTop)
    else
        button:SetPoint("TOP", UIParent, "TOP", 120, -8) -- right of the other Allemano buttons
    end
end

local function build()
    button = CreateFrame("Button", nil, UIParent)
    button:SetSize(SIZE, SIZE)
    button:SetFrameStrata("HIGH")
    button:SetClampedToScreen(true)
    button:SetMovable(true)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    local _, border = W.Surface(button, "sidebar", 0.95, Theme.radius.control)

    local logo = button:CreateTexture(nil, "ARTWORK")
    logo:SetPoint("TOPLEFT", 2, -2)
    logo:SetPoint("BOTTOMRIGHT", -2, 2)
    if logo:SetTexture(W.MARK) == false then logo:SetColorTexture(Theme:Color("accent")) end

    -- A small number for errors that came in since the Errors page was last opened.
    local badgeFrame = CreateFrame("Frame", nil, button)
    badgeFrame:SetSize(16, 14)
    badgeFrame:SetPoint("CENTER", button, "TOPRIGHT", -1, -1)
    badgeFrame:SetFrameLevel(button:GetFrameLevel() + 3)
    local badgeFill = W.Fill(badgeFrame, "warn", 1)
    badgeFill:SetAllPoints()
    W.Round(badgeFill, 6)
    badge = W.Text(badgeFrame, -3, "text", "OVERLAY")
    badge:SetPoint("CENTER", 0, 0)
    badge:SetJustifyH("CENTER")
    badge:SetTextColor(0.05, 0.05, 0.07)
    badgeFrame:Hide()
    button.badgeFrame = badgeFrame

    button:SetScript("OnEnter", function(self)
        border:SetColor(Theme:Color("accent"))
        local unseen = HUB.Registry:UnseenErrors()
        local extra = unseen > 0 and ("\n|cffe8a33d" .. unseen .. " new error" .. (unseen > 1 and "s" or "") .. "|r") or ""
        W.ShowTooltip(self, "Allemano Hub - your Allemano addons" .. extra)
    end)
    button:SetScript("OnLeave", function()
        border:SetColor(Theme:Color("line"))
        W.HideTooltip()
    end)
    button:SetScript("OnClick", function() HUB.Window.Toggle() end)
    button:SetScript("OnDragStart", function(self)
        if not HUB.db.settings.launcherLocked then self:StartMoving() end
    end)
    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePosition()
    end)
    restorePosition()
    button:SetShown(HUB.db.settings.launcher ~= false)
    HUB.UpdateLauncher()
end

function HUB.UpdateLauncher()
    if not button then return end
    local n = HUB.Registry:UnseenErrors()
    badge:SetText(n > 99 and "99" or tostring(n))
    button.badgeFrame:SetShown(n > 0)
end

function HUB.ResetLauncherPosition()
    HUB.db.settings.launcherLeft, HUB.db.settings.launcherTop = nil, nil
    if button then restorePosition() end
end

HUB:OnSettingChanged(function(key, value)
    if key == "launcher" and button then button:SetShown(value ~= false) end
end)

HUB:RegisterEvent("PLAYER_LOGIN", function() HUB:Call("launcher", build) end)

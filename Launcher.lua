-- Launcher: the same small movable button as the other Allemano addons (a dark rounded square
-- with the mark filling it). Click opens the Hub, drag moves it.
local _, HUB = ...

local Theme, W = HUB.Theme, HUB.W
local SIZE = 30
local button

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

    button:SetScript("OnEnter", function(self)
        border:SetColor(Theme:Color("accent"))
        W.ShowTooltip(self, "Allemano Hub - your Allemano addons")
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
end

function HUB.ResetLauncherPosition()
    HUB.db.settings.launcherLeft, HUB.db.settings.launcherTop = nil, nil
    if button then restorePosition() end
end

HUB:OnSettingChanged(function(key, value)
    if key == "launcher" and button then button:SetShown(value ~= false) end
end)

HUB:RegisterEvent("PLAYER_LOGIN", function() HUB:Call("launcher", build) end)

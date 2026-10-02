-- Report: a text to paste in the Allemano Discord when something is wrong - the game and addon
-- versions and every error the addons recorded - and a box to copy it from.
local _, HUB = ...

local Theme, W, Registry = HUB.Theme, HUB.W, HUB.Registry
local Report = {}
HUB.Report = Report

local MAX_OTHER_ADDONS = 60

local api = C_AddOns or {}
local getInfo = api.GetAddOnInfo or GetAddOnInfo
local isLoaded = api.IsAddOnLoaded or IsAddOnLoaded
local numAddOns = api.GetNumAddOns or GetNumAddOns

local function safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end

function Report.Build()
    local lines = {}
    local function add(s) lines[#lines + 1] = s end

    local gameVersion, build = safe(GetBuildInfo)
    add("Allemano Hub report")
    add("Created: " .. date("%Y-%m-%d %H:%M"))
    add(("Game: %s (build %s), locale %s"):format(tostring(gameVersion), tostring(build), tostring(safe(GetLocale))))
    local class = select(2, UnitClass("player"))
    add(("Character: %s, level %s"):format(tostring(class), tostring(UnitLevel("player"))))
    add("")

    add("Allemano addons:")
    local known = {}
    for _, e in ipairs(Registry:List()) do
        known[e.folder] = true
        if e.installed then
            local state = e.loaded and "loaded" or "installed, not loaded"
            local update = e.update and (", newer known: " .. tostring(e.latest)) or ""
            add(("  %s %s (%s%s)"):format(e.fullName or e.name, tostring(e.version or "?"), state, update))
        end
    end
    add(("  Allemano Hub %s (%s)"):format(tostring(HUB.version), "loaded"))
    known["AllemanoHub"] = true

    -- Memory (and CPU, with profiling on) of the Allemano addons.
    local ok, perfLines = pcall(HUB.Perf.ReportLines)
    if ok and perfLines then
        add("")
        for _, line in ipairs(perfLines) do add(line) end
    end

    -- Other loaded addons: names only, they help to find conflicts.
    local others = {}
    for i = 1, (safe(numAddOns) or 0) do
        local name = safe(getInfo, i)
        if name and not known[name] and safe(isLoaded, name) then others[#others + 1] = name end
    end
    if #others > 0 then
        local shown = {}
        for i = 1, math.min(#others, MAX_OTHER_ADDONS) do shown[i] = others[i] end
        add("")
        add(("Other loaded addons (%d): %s%s"):format(#others, table.concat(shown, ", "),
            #others > MAX_OTHER_ADDONS and ", ..." or ""))
    end

    add("")
    local errors = Registry:Errors()
    if #errors == 0 then
        add("Errors: none recorded")
    else
        add(("Errors (%d, newest first):"):format(#errors))
        for _, e in ipairs(errors) do
            add(("  [%s%s] %s  %s: %s"):format(e.addon.name, e.v and (" v" .. tostring(e.v)) or "",
                date("%d/%m %H:%M", e.t), e.where, e.msg))
        end
    end
    add("")
    add("(ALC keeps its own log: /alc debug log)")
    return table.concat(lines, "\n")
end

-- ---------------------------------------------------------------------------
-- A box with a long text to copy (Ctrl+A is not needed: it opens with everything selected).
-- ---------------------------------------------------------------------------

local box
function Report.ShowBox(title, text, hint)
    if not box then
        box = CreateFrame("Frame", "AllemanoHubReportBox", UIParent)
        tinsert(UISpecialFrames, "AllemanoHubReportBox")
        box:SetFrameStrata("DIALOG")
        box:SetToplevel(true)
        box:SetSize(640, 440)
        box:SetPoint("CENTER", 0, 20)
        box:EnableMouse(true)
        W.Surface(box, "window", 0.98, Theme.radius.panel)
        box.title = W.Text(box, 2, "text")
        box.title:SetPoint("TOPLEFT", 18, -16)
        box.hint = W.Text(box, -1, "textFaint")
        box.hint:SetPoint("BOTTOMLEFT", 18, 16)
        local close = W.CloseButton(box, function() box:Hide() end)
        close:SetPoint("TOPRIGHT", -10, -10)

        local field = CreateFrame("Frame", nil, box)
        field:SetPoint("TOPLEFT", 18, -48)
        field:SetPoint("BOTTOMRIGHT", -18, 44)
        W.Surface(field, "field", 1, Theme.radius.control)
        box.scroll = CreateFrame("ScrollFrame", nil, field)
        box.scroll:SetPoint("TOPLEFT", 10, -10)
        box.scroll:SetPoint("BOTTOMRIGHT", -10, 10)
        box.scroll:EnableMouseWheel(true)
        box.edit = CreateFrame("EditBox", nil, box.scroll)
        box.edit:SetMultiLine(true)
        box.edit:SetAutoFocus(false)
        box.edit:SetMaxLetters(0)
        box.edit:SetFont(Theme:FontPath(), Theme:TextSize(-1), "")
        box.edit:SetTextColor(Theme:Color("text"))
        box.edit:SetWidth(580)
        box.scroll:SetScrollChild(box.edit)
        box.edit:SetScript("OnEscapePressed", function() box:Hide() end)
        box.scroll:SetScript("OnMouseWheel", function(self, delta)
            local max = math.max(0, box.edit:GetHeight() - self:GetHeight())
            self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - delta * 40)))
        end)
        box.edit:SetScript("OnCursorChanged", function(_, _, y, _, h)
            -- keep the cursor line in view when the text is clicked or navigated
            local scroll = box.scroll
            local top = -y
            if top < scroll:GetVerticalScroll() then scroll:SetVerticalScroll(top)
            elseif top + h > scroll:GetVerticalScroll() + scroll:GetHeight() then scroll:SetVerticalScroll(top + h - scroll:GetHeight()) end
        end)
    end
    box.title:SetText(title)
    box.hint:SetText(hint or "Press Ctrl+C to copy, then Esc")
    box.edit:SetScript("OnTextChanged", function(self) -- read only: put the text back if it is edited
        if self:GetText() ~= text then self:SetText(text) end
    end)
    box.edit:SetText(text)
    box.scroll:SetVerticalScroll(0)
    box:Show()
    box.edit:SetFocus()
    box.edit:HighlightText()
end

function Report.Show()
    Report.ShowBox("Allemano report", Report.Build(),
        "Ctrl+C to copy, then paste it in the Allemano Discord. Esc closes.")
end

HUB:AddSlashCommand("report", function() Report.Show() end, "a report to paste in the Discord when something is wrong")

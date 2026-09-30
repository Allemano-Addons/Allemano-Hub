-- Appearance page: font, text size, accent color, background, scale and the launcher button of the Hub.
-- Every change applies at once (HUB:SetSetting).
local _, HUB = ...

local Theme, W, Window = HUB.Theme, HUB.W, HUB.Window

local LABEL_X, CONTROL_X, ROW = 28, 220, 40
local FRIZ = "Fonts\\FRIZQT__.TTF"

local function set(key, value) HUB:SetSetting(key, value) end

Window.pages.appearance = {
    Build = function(parent)
        local page = { frame = CreateFrame("Frame", nil, parent), controls = {} }
        local f = page.frame
        f:SetAllPoints()
        local s = HUB.db.settings

        local title = W.Text(f, 8, "text")
        title:SetPoint("TOPLEFT", LABEL_X, -28)
        title:SetText("Appearance")

        -- Layout helpers: y grows downward while building.
        local y = 84
        local function heading(text)
            y = y + 6
            local fs = W.Text(f, -2, "textFaint")
            fs:SetPoint("TOPLEFT", LABEL_X, -y)
            fs:SetText(strupper(text))
            y = y + 26
        end
        local function row(label, control, offset)
            local fs = W.Text(f, 0, "textDim")
            fs:SetPoint("TOPLEFT", LABEL_X, -(y + 7))
            fs:SetText(label)
            control:SetPoint("TOPLEFT", CONTROL_X, -(y + (offset or 3)))
            y = y + ROW
        end
        local function toggleRow(label, get, onChange)
            local t = W.Toggle(f, onChange)
            row(label, t, 9)
            t.refresh = function() t:Set(get()) end
            page.controls[#page.controls + 1] = t
        end

        -- Font ---------------------------------------------------------------
        heading("Text")
        local font = W.Dropdown(f, 290, function()
            local opts = { { value = "Auto", label = "Automatic (Expressway if available)" } }
            for _, ft in ipairs(Theme:AvailableFonts()) do opts[#opts + 1] = { value = ft.name, label = ft.name, font = ft.path } end
            return opts
        end, function(v) set("font", v) end)
        row("Font", font)
        font.refresh = function() font:Set(s.font) end
        page.controls[#page.controls + 1] = font

        page.using = W.Text(f, -1, "textFaint")
        page.using:SetWordWrap(true)
        page.using:SetPoint("TOPLEFT", CONTROL_X, -(y - 6))
        page.using:SetWidth(430)
        y = y + 34

        local size = W.Segment(f, {
            { value = "S", label = "Small" }, { value = "M", label = "Medium" }, { value = "L", label = "Large" },
        }, function(v) set("textSize", v) end)
        row("Text size", size, 5)
        size.refresh = function() size:Set(s.textSize) end
        page.controls[#page.controls + 1] = size

        -- Color ----------------------------------------------------------------
        heading("Color")
        local swatches = CreateFrame("Frame", nil, f)
        local accent = W.Segment(f, {
            { value = "own", label = "Allemano white" }, { value = "class", label = "Class" }, { value = "custom", label = "Custom" },
        }, function(v)
            set("accentMode", v)
            swatches.refresh()
        end)
        row("Accent", accent, 5)
        accent.refresh = function() accent:Set(s.accentMode) end
        page.controls[#page.controls + 1] = accent

        swatches:SetSize(#Theme.ACCENTS * 26, 22)
        swatches:SetPoint("TOPLEFT", CONTROL_X, -(y - 2))
        swatches.list = {}
        for i, hexColor in ipairs(Theme.ACCENTS) do
            local sw = W.Swatch(swatches, hexColor, function()
                s.accentMode = "custom"
                accent:Set("custom")
                set("accent", hexColor)
                swatches.refresh()
            end)
            sw:SetPoint("LEFT", (i - 1) * 26, 0)
            sw.hex = hexColor
            swatches.list[i] = sw
        end
        swatches.refresh = function()
            for _, sw in ipairs(swatches.list) do
                sw:SetSelected(s.accentMode == "custom" and s.accent == sw.hex)
                sw:SetAlpha(s.accentMode == "custom" and 1 or 0.4)
            end
        end
        page.controls[#page.controls + 1] = swatches
        y = y + ROW - 6

        -- Window ---------------------------------------------------------------
        heading("Window")
        local alpha = W.Slider(f, 50, 100, 5, 190, function(v) return v .. "%" end, function(v) set("bgAlpha", v / 100) end)
        row("Background", alpha, 9)
        alpha.refresh = function() alpha:Set(floor((s.bgAlpha or 0.97) * 100 + 0.5)) end
        page.controls[#page.controls + 1] = alpha

        -- The slider sits inside the window it scales, so resizing while the thumb is held would move it
        -- out from under the mouse. The number follows the thumb; the window changes when it is let go.
        local pendingScale
        local scale = W.Slider(f, 70, 130, 5, 190, function(v) return v .. "%" end, function(v) pendingScale = v / 100 end)
        scale:HookScript("OnMouseUp", function()
            if pendingScale and pendingScale ~= s.scale then set("scale", pendingScale) end
            pendingScale = nil
        end)
        row("Window scale", scale, 9)
        scale.refresh = function() scale:Set(floor((s.scale or 1) * 100 + 0.5)) end
        page.controls[#page.controls + 1] = scale

        -- Launcher ---------------------------------------------------------------
        heading("Launcher button")
        toggleRow("Show button", function() return s.launcher ~= false end, function(on) set("launcher", on) end)
        toggleRow("Lock position", function() return s.launcherLocked == true end, function(on) set("launcherLocked", on) end)
        local reset = W.Button(f, "Reset window positions", "plain", function()
            Window.ResetPosition()
            HUB.ResetLauncherPosition()
            HUB:Print("Window and launcher positions reset.")
        end)
        row("", reset, 0)

        -- Preview ----------------------------------------------------------------
        local card = CreateFrame("Frame", nil, f)
        card:SetPoint("TOPRIGHT", -28, -84)
        card:SetSize(300, 190)
        W.Surface(card, "field", 1, Theme.radius.panel)
        local label = W.Text(card, -2, "textFaint")
        label:SetPoint("TOPLEFT", 18, -16)
        label:SetText("PREVIEW")
        local big = W.Text(card, 6, "text")
        big:SetPoint("TOPLEFT", 18, -40)
        big:SetText("Allemano Hub")
        local sample = W.Text(card, 1, "text")
        sample:SetWordWrap(true)
        sample:SetPoint("TOPLEFT", 18, -76)
        sample:SetWidth(264)
        sample:SetText("The quick brown fox jumps over the lazy dog.")
        local small = W.Text(card, -1, "textDim")
        small:SetPoint("TOPLEFT", 18, -128)
        small:SetText("Overview  ·  Guild  ·  0123456789")
        local button = W.Button(card, "Open", "plain")
        button:SetPoint("BOTTOMLEFT", 18, 16)

        function page:Refresh()
            for _, c in ipairs(self.controls) do c.refresh() end
            local name = s.font
            local resolved = Theme:FontPath() == FRIZ and "Friz Quadrata" or (name == "Auto" and Theme.AUTO_FONT or name)
            local text = "Using: " .. tostring(resolved)
            if name == "Auto" and Theme:FontPath() == FRIZ then
                text = text .. " (install EllesmereUI for more fonts; WoW Forever only accepts the game's fonts and those other addons register)"
            end
            self.using:SetText(text)
        end
        return page
    end,
}

-- The preview and every text follow a font change at once (the widgets repaint themselves).
HUB:OnSettingChanged(function(key)
    if key == "font" and Window.Page and Window.Page("appearance") then Window.Page("appearance"):Refresh() end
end)

--[[	Modern TargetFrame ThreatIndicators Module
	by SDPhantom
	https://www.wowinterface.com/forums/member.php?u=34145
	https://www.curseforge.com/members/sdphantomgamer/projects	]]
--------------------------------------------------------------------------

--------------------------
--[[	Namespace	]]
--------------------------
local AddOn = select(2, ...);
AddOn.Options = AddOn.Options or {};

if Carpenter and Carpenter.Client and Carpenter.Client.isRetail then
    return;
end

-- Offsets from the top of the target frame health bar, used when the health
-- bar can be found. X pushes right because the portrait sits on the right, so
-- the bar's center is left of the frame's. Y lifts the indicator clear of the
-- frame border, which draws over it at this strata.
local THREAT_OFFSET_X = 4;
local THREAT_OFFSET_Y = 19;

-- Robust version check
if not AddOn.ClientVersionMajor then
    local version = GetBuildInfo();
    AddOn.ClientVersionMajor = tonumber(version:match("^(%d+)")) or 1;
end

-- Glow offsets from the unit frame's TOPLEFT. The glow wraps the whole frame,
-- so it stays anchored to the frame rather than the health bar. Classic Era
-- used to need its own offsets, but Edit Mode lined its frame up with TBC's.
local THREAT_GLOW_OFFSET_X = -6;
local THREAT_GLOW_OFFSET_Y = -3;

----------------------------------
--[[	Options Defaults	]]
----------------------------------
AddOn.Options.ThreatIndicatorNumber = true;
AddOn.Options.ThreatIndicatorGlow = true;

--------------------------
--[[	Local Variables	]]
--------------------------
local ThreatStatusColors = {
    [0] = { 0.69, 0.69, 0.69 },
    { 1, 1,   0.47 },
    { 1, 0.6, 0 },
    { 1, 0,   0 },
}

--------------------------
--[[	Threat Frames	]]
--------------------------
local CreateThreatIndicator; do --	function CreateThreatIndicator(unitframe)
    local function Indicator_Update(self)
        local unit = self.Unit;
        -- Gate the module's own sub-options behind Carpenter's setting, which
        -- otherwise never reaches this adapted module.
        local settingOn = not Carpenter or not Carpenter.IsEnabled or Carpenter:IsEnabled("threatIndicatorEnabled");
        local EnableNumeric = settingOn and AddOn.Options.ThreatIndicatorNumber;
        local EnableGlow = settingOn and AddOn.Options.ThreatIndicatorGlow;

        -- /cpthreat preview: the real readout needs a group and live threat, so
        -- show sample values instead while checking placement.
        if AddOn.ThreatIndicatorTestMode then
            if UnitExists(unit) then
                local r, g, b = unpack(ThreatStatusColors[3]);
                self.Text:SetFormattedText("%.0f%%", 100);
                self.Background:SetVertexColor(r, g, b);
                self:Show();
                self.Glow:SetVertexColor(r, g, b);
                self.Glow:Show();
            else
                self:Hide();
                self.Glow:Hide();
            end
            return;
        end

        if (EnableNumeric or EnableGlow) and UnitExists(unit) then
            local tanking, status, _, percent = UnitDetailedThreatSituation("player", unit);

            if status then
                local r, g, b = unpack(ThreatStatusColors[status or 0]);

                -- Numeric Indicator: Restricted to Groups/Raids
                if EnableNumeric and (IsInGroup() or IsInRaid()) then
                    if tanking and not (status == 3 and percent == 100) then
                        percent = UnitThreatPercentageOfLead("player", unit);
                    end

                    if percent and percent > 0 then
                        percent = min(percent, 999);
                        self.Text:SetFormattedText("%.0f%%", percent);
                        self.Background:SetVertexColor(r, g, b);
                        self:Show();
                    else
                        self:Hide();
                    end
                else
                    self:Hide();
                end

                -- Glow Indicator: Always shows regardless of group status
                if EnableGlow and status > 0 then
                    self.Glow:SetVertexColor(r, g, b);
                    self.Glow:Show();
                else
                    self.Glow:Hide();
                end
            else
                self:Hide();
                self.Glow:Hide();
            end
        else
            self:Hide();
            self.Glow:Hide();
        end

        -- Refresh aura positions
        if self.Parent.UpdateAuras then
            self.Parent:UpdateAuras();
        elseif TargetFrame_UpdateAuras then
            TargetFrame_UpdateAuras(self.Parent);
        end
    end

    function CreateThreatIndicator(unitframe)
        local unit = unitframe.unit;

        -- Parent to UIParent so we don't taint the secure unit frame (fixes Set Focus / protected actions).
        local indicator = CreateFrame("Frame", nil, UIParent);

        -- Anchor above the health bar where it is available. Edit Mode changed
        -- the outer frame's bounds, so offsets measured from it drift.
        local Unit = AddOn.Private and AddOn.Private.Unit;
        local healthBar = Unit and Unit.FrameHealthBar and Unit.FrameHealthBar(unit);
        if healthBar then
            indicator:SetPoint("BOTTOM", healthBar, "TOP", THREAT_OFFSET_X, THREAT_OFFSET_Y);
        elseif AddOn.ClientVersionMajor < 2 then
            indicator:SetPoint("BOTTOM", unitframe, "TOP", -50, -23);
        else
            indicator:SetPoint("BOTTOM", unitframe, "TOP", -31, -25);
        end
        indicator:SetSize(49, 18);
        indicator:Hide();
        -- Under the unit frame and aura row: low strata + low level (strata wins over level)
        indicator:SetFrameStrata("BACKGROUND");
        indicator:SetFrameLevel(0);

        indicator.Parent = unitframe;
        indicator.Unit = unit;
        indicator.Update = Indicator_Update;

        indicator.Background = indicator:CreateTexture(nil, "BACKGROUND");
        indicator.Background:SetTexture("Interface\\TargetingFrame\\UI-StatusBar");
        indicator.Background:SetPoint("TOP", 0, -3);
        indicator.Background:SetSize(37, 14);

        indicator.Text = indicator:CreateFontString(nil, "BACKGROUND", "GameFontHighlight");
        indicator.Text:SetDrawLayer("BACKGROUND", 1);
        indicator.Text:SetPoint("TOP", 0, -4);

        local border = indicator:CreateTexture(nil, "ARTWORK");
        border:SetTexture("Interface\\TargetingFrame\\NumericThreatBorder");
        border:SetTexCoord(0, 0.765625, 0, 0.5625);
        border:SetAllPoints(indicator);

        -- Frame Glow: create on indicator and anchor to unitframe so we don't taint the secure frame
        indicator.Glow = indicator:CreateTexture(nil, "BACKGROUND");
        indicator.Glow:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Flash");
        indicator.Glow:SetTexCoord(0, 0.9453125, 0, AddOn.ClientVersionMajor < 2 and 0.181640625 or 0.7265625);
        indicator.Glow:SetPoint("TOPLEFT", unitframe, "TOPLEFT", THREAT_GLOW_OFFSET_X, THREAT_GLOW_OFFSET_Y);
        indicator.Glow:SetSize(242, 93);
        indicator.Glow:Hide();

        if unitframe == TargetFrame then
            indicator:RegisterEvent("PLAYER_TARGET_CHANGED");
        end
        if _G.FocusFrame and unitframe == FocusFrame then
            indicator:RegisterEvent("PLAYER_FOCUS_CHANGED");
        end

        indicator:RegisterEvent("GROUP_ROSTER_UPDATE");
        indicator:RegisterUnitEvent("UNIT_THREAT_LIST_UPDATE", unit);
        indicator:SetScript("OnEvent", Indicator_Update);

        return indicator;
    end
end

local ThreatIndicators = {};
for _, unitframe in ipairs({ TargetFrame, _G.FocusFrame }) do
    if unitframe then
        ThreatIndicators[unitframe] = CreateThreatIndicator(unitframe);
    end
end

----------------------------------
--[[	Buffs On Top Correction	]]
----------------------------------
local AURA_START_X = 5;
local function TargetFrame_OnUpdateAuraPositions(self, basename, numauras, numother, _, _, _, _, flip)
    local indicator = ThreatIndicators[self];
    local prefix = self:GetName();

    if indicator and flip and numauras > 0 and indicator:IsShown() then
        local friendly = UnitIsFriend("player", self.unit);
        if (basename == prefix .. "Buff" and (friendly or numother <= 0))
            or (basename == prefix .. "Debuff" and not (friendly and numother > 0)) then
            local aura = _G[basename .. 1];
            if aura then
                aura:SetPoint("BOTTOMLEFT", self, "TOPLEFT", AURA_START_X, 3);
            end
        end
    end
end

-- Only hook TargetFrame; hooking FocusFrame taints it and blocks Set Focus.
if TargetFrame_UpdateAuraPositions then
    hooksecurefunc("TargetFrame_UpdateAuraPositions", TargetFrame_OnUpdateAuraPositions);
elseif TargetFrameMixin and TargetFrameMixin.UpdateAuraPositions then
    hooksecurefunc(TargetFrame, "UpdateAuraPositions", TargetFrame_OnUpdateAuraPositions);
end

----------------------------------
--[[	Feature Registration	]]
----------------------------------
local function Options_OnChanged()
    for _, indicator in pairs(ThreatIndicators) do
        indicator:Update();
    end
end

if AddOn.RegisterFeature then
    AddOn.RegisterFeature("ThreatIndicatorNumber", Options_OnChanged);
    AddOn.RegisterFeature("ThreatIndicatorGlow", Options_OnChanged);
end

-- Refresh straight away when the Carpenter option is toggled, so the
-- indicators hide without waiting for the next threat event.
if Carpenter and Carpenter.RegisterFeature then
    Carpenter:RegisterFeature("threatIndicatorEnabled", {
        Enable = Options_OnChanged,
        Disable = Options_OnChanged,
    });
end

SLASH_CARPENTERTHREATTEST1 = "/cpthreat";
SlashCmdList["CARPENTERTHREATTEST"] = function()
    AddOn.ThreatIndicatorTestMode = not AddOn.ThreatIndicatorTestMode;
    Options_OnChanged();

    local state = AddOn.ThreatIndicatorTestMode and "on" or "off";
    local hint = AddOn.ThreatIndicatorTestMode and " Target something to see the placement." or "";
    print("|cffffd200Carpenter:|r threat indicator preview " .. state .. "." .. hint);
end

--[[ Carpenter - Retail Unit Frame Cleaner visuals ]]
local _, ns = ...
ns.Private = ns.Private or {}

local Visuals = ns.Private.RetailUnitFrameCleanerVisuals or {}
ns.Private.RetailUnitFrameCleanerVisuals = Visuals

local hiddenParent

local function GetHiddenParent()
    if not hiddenParent then
        hiddenParent = CreateFrame("Frame", "CarpenterRetailHiddenParent", UIParent)
        hiddenParent:Hide()
    end
    return hiddenParent
end

local function IsCompactPartyMemberVisual(frame)
    local current = frame
    while current do
        local name = current.GetName and current:GetName()
        if type(name) == "string" and name:match("^CompactPartyFrameMember%d") then
            return true
        end
        current = current.GetParent and current:GetParent() or nil
    end
    return false
end

local function HideFrameVisuals(frame)
    if not frame then return end
    if frame._CarpenterOriginalVisualAlpha == nil and frame.GetAlpha then
        frame._CarpenterOriginalVisualAlpha = frame:GetAlpha()
    end
    if frame.SetAlpha then
        frame:SetAlpha(0)
    end
end

local function RestoreFrameVisuals(frame)
    if not frame then return end
    if frame.SetAlpha then
        frame:SetAlpha(frame._CarpenterOriginalVisualAlpha or 1)
    end
    frame._CarpenterOriginalVisualAlpha = nil
end

function Visuals.HideFrame(frame)
    if not frame or frame._CarpenterHiding then return end
    if IsCompactPartyMemberVisual(frame) then return end
    if frame._CarpenterHiddenByCleaner then return end
    local isProtected = frame.IsProtected and frame:IsProtected()
    if isProtected and InCombatLockdown and InCombatLockdown() then return end

    frame._CarpenterHiding = true
    if frame._CarpenterWasShown == nil then
        frame._CarpenterWasShown = frame.IsShown and frame:IsShown()
    end
    frame._CarpenterHiddenByCleaner = true
    HideFrameVisuals(frame)
    if frame.Hide then
        frame:Hide()
    end
    if frame.SetParent and frame.GetParent and not frame._CarpenterOriginalParent then
        frame._CarpenterOriginalParent = frame:GetParent()
        frame:SetParent(GetHiddenParent())
    end
    frame._CarpenterHiding = nil
end

function Visuals.RestoreFrame(frame)
    if not frame then return end
    if not frame._CarpenterHiddenByCleaner and not frame._CarpenterOriginalParent then return end
    local isProtected = frame.IsProtected and frame:IsProtected()
    if isProtected and InCombatLockdown and InCombatLockdown() then return end

    if frame._CarpenterOriginalParent then
        frame:SetParent(frame._CarpenterOriginalParent)
        frame._CarpenterOriginalParent = nil
    end
    RestoreFrameVisuals(frame)
    if frame._CarpenterHiddenByCleaner and frame._CarpenterWasShown and frame.Show then
        frame:Show()
    end
    frame._CarpenterHiddenByCleaner = nil
    frame._CarpenterWasShown = nil
end

function Visuals.HookHide(frame, predicate)
    if not frame or frame._CarpenterRetailCleanerHooked then return end
    frame._CarpenterRetailCleanerHooked = true

    if frame.HookScript then
        frame:HookScript("OnShow", function(self)
            if predicate() then
                Visuals.HideFrame(self)
            end
        end)
    end
    if frame.Show then
        pcall(hooksecurefunc, frame, "Show", function(self)
            if predicate() then
                Visuals.HideFrame(self)
            end
        end)
    end
    if frame.SetAlpha then
        pcall(hooksecurefunc, frame, "SetAlpha", function(self)
            if predicate() then
                Visuals.HideFrame(self)
            end
        end)
    end
    if frame.SetVertexColor then
        pcall(hooksecurefunc, frame, "SetVertexColor", function(self)
            if predicate() then
                Visuals.HideFrame(self)
            end
        end)
    end
end

function Visuals.HideFrameAlpha(frame)
    if not frame or frame._CarpenterAlphaHiding then return end
    if IsCompactPartyMemberVisual(frame) then return end
    if frame._CarpenterAlphaHiddenByCleaner then return end
    local isProtected = frame.IsProtected and frame:IsProtected()
    if isProtected and InCombatLockdown and InCombatLockdown() then return end

    frame._CarpenterAlphaHiding = true
    if frame._CarpenterOriginalAlpha == nil and frame.GetAlpha then
        frame._CarpenterOriginalAlpha = frame:GetAlpha()
    end
    if frame.SetAlpha then
        frame:SetAlpha(0)
    end
    if frame.EnableMouse then
        frame:EnableMouse(false)
    end
    if frame.SetMouseClickEnabled then
        frame:SetMouseClickEnabled(false)
    end
    frame._CarpenterAlphaHiddenByCleaner = true
    frame._CarpenterAlphaHiding = nil
end

function Visuals.RestoreFrameAlpha(frame)
    if not frame then return end
    if not frame._CarpenterAlphaHiddenByCleaner then return end

    if frame.SetAlpha then
        frame:SetAlpha(frame._CarpenterOriginalAlpha or 1)
    end
    if frame.EnableMouse then
        frame:EnableMouse(true)
    end
    if frame.SetMouseClickEnabled then
        frame:SetMouseClickEnabled(true)
    end
    frame._CarpenterOriginalAlpha = nil
    frame._CarpenterAlphaHiddenByCleaner = nil
end

function Visuals.HookAlphaHide(frame, predicate)
    if not frame or frame._CarpenterRetailAlphaHooked then return end
    frame._CarpenterRetailAlphaHooked = true

    if frame.HookScript then
        frame:HookScript("OnShow", function(self)
            if predicate() then
                Visuals.HideFrameAlpha(self)
            end
        end)
    end
    if frame.SetAlpha then
        pcall(hooksecurefunc, frame, "SetAlpha", function(self)
            if predicate() then
                Visuals.HideFrameAlpha(self)
            end
        end)
    end
end

--[[ Carpenter - Hover fade ]]
-- One fade loop for the features that hide part of the interface until the
-- mouse comes near it: the alpha runs between 0 and 1 over fixed times, and
-- a frame counts as hovered when the cursor is within a padding of its
-- edges. Fade Chat, Fade Minimap, Fade Micro Menu & Bags and Hide Chat
-- Buttons all run on it.

Carpenter = Carpenter or {}

local HoverFade = {}
Carpenter.HoverFade = HoverFade

HoverFade.FADE_IN_SECONDS = 0.2
HoverFade.FADE_OUT_SECONDS = 0.6
HoverFade.UPDATE_INTERVAL = 0.05

-- Whether the cursor is within `padding` of the frame's edges. The edges are
-- in the frame's own scale, which Edit Mode can change. `visibility` is
-- "shown", "visible" or nil: a hidden frame keeps its edges, so a caller
-- that wants a hidden frame to still count (the faded minimap) passes nil.
function HoverFade.IsMouseOverPaddedFrame(frame, padding, visibility)
    if not frame or not frame.GetLeft then return false end
    if visibility == "shown" and not (frame.IsShown and frame:IsShown()) then return false end
    if visibility == "visible" and not (frame.IsVisible and frame:IsVisible()) then return false end

    local left, right, top, bottom = frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    if not left or not right or not top or not bottom then return false end

    local scale = (frame.GetEffectiveScale and frame:GetEffectiveScale())
        or (UIParent and UIParent:GetEffectiveScale()) or 1
    local x, y = GetCursorPosition()
    x, y = x / scale, y / scale
    padding = padding or 0

    return x >= left - padding and x <= right + padding and y >= bottom - padding and y <= top + padding
end

-- Whether the cursor is over the frame by its own hit test, or by the legacy
-- global on clients whose frames lack the method.
function HoverFade.IsMouseOverFrame(frame)
    if not frame then return false end
    if type(frame.IsMouseOver) == "function" then
        return frame:IsMouseOver() == true
    end
    if type(MouseIsOver) == "function" then
        return MouseIsOver(frame) == true
    end
    return false
end

-- A fader steps its alpha toward 1 while options.shouldShow() holds and
-- toward 0 otherwise, calling options.apply(alpha) whenever it changes.
--   isEnabled()           optional; a false answer stops the loop
--   onTick(alpha, changed) optional; runs every pass, return true to apply anyway
--   fadeIn, fadeOut       seconds for a full fade; interval between passes
function HoverFade.Create(options)
    local fadeIn = options.fadeIn or HoverFade.FADE_IN_SECONDS
    local fadeOut = options.fadeOut or HoverFade.FADE_OUT_SECONDS
    local interval = options.interval or HoverFade.UPDATE_INTERVAL
    local shouldShow, apply, isEnabled, onTick = options.shouldShow, options.apply, options.isEnabled, options.onTick

    local fader = { alpha = 1 }
    local frame = CreateFrame("Frame")
    frame:Hide()
    frame:SetScript("OnUpdate", function(self, elapsed)
        if isEnabled and not isEnabled() then
            self:Hide()
            return
        end

        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < interval then return end
        local step = self.elapsed
        self.elapsed = 0

        local target = shouldShow() and 1 or 0
        local changed = false
        if fader.alpha < target then
            fader.alpha = math.min(target, fader.alpha + step / fadeIn)
            changed = true
        elseif fader.alpha > target then
            fader.alpha = math.max(target, fader.alpha - step / fadeOut)
            changed = true
        end

        if onTick and onTick(fader.alpha, changed) then
            changed = true
        end
        if changed then
            apply(fader.alpha)
        end
    end)

    -- Writes the current alpha to the frames.
    function fader:Apply()
        apply(self.alpha)
    end

    -- Runs the loop, from `alpha` when given.
    function fader:Start(alpha)
        if alpha then self.alpha = alpha end
        self:Apply()
        frame:Show()
    end

    -- Stops the loop, leaving the frames at `alpha` when given.
    function fader:Stop(alpha)
        frame:Hide()
        if alpha then
            self.alpha = alpha
            self:Apply()
        end
    end

    function fader:IsRunning()
        return frame:IsShown()
    end

    return fader
end

local addon, ns = ...
local raidframes = {}

raidframes = UberUI:CreateFrame("Frame");

-- All texture and color updates are now handled by the
-- centralized hook in core/compactunitframe.lua

UberUI.raidframes = raidframes;

local addon, ns = ...

-- Copy chat: a small button in the top-right corner of each chat window
-- except the combat log (faint until hovered; uuidb.general.chatcopybutton)
-- and /uucopychat [lines] open that window's history in the copyable popup.
-- It shows in chat's colors (channel color, class-colored names, link
-- colors); copying from the box gives only the text, no color codes (checked
-- in game). Links become their text and icons are dropped; messages the game
-- hides from addons (secret) show as a placeholder. Only our own buttons on
-- Blizzard's chat frames -- no hooks.

local chatcopy = {}

local ICON = "Interface\\Buttons\\UI-GuildButton-PublicNote-Up"
local IDLE_ALPHA = 0.35
local buttons = {}

local function Enabled()
    return uuidb and uuidb.general and uuidb.general.chatcopybutton ~= false
end

-- The combat log (always ChatFrame2: Blizzard_CombatLog sets COMBATLOG to
-- it, and IsCombatLog checks the same) keeps no readable message history.
local function IsCombatLog(frame)
    return frame ~= nil and frame == ChatFrame2
end

-- The message's own colors (class-colored names, item link colors) inside
-- its channel color; links become their text, icons go.
local function ColoredChatText(text, r, g, b)
    text = text:gsub("|H.-|h(.-)|h", "%1")
    text = text:gsub("|T.-|t", ""):gsub("|A.-|a", "")
    if type(r) == "number" and type(g) == "number" and type(b) == "number" then
        text = ("|cff%02x%02x%02x%s|r"):format(
            math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), text)
    end
    return text
end

-- count: the last N lines, or nil for the whole history.
function chatcopy.Copy(frame, count)
    frame = frame or SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME
    if not (frame and frame.GetNumMessages and frame.GetMessageInfo) then return end
    if IsCombatLog(frame) then
        UIErrorsFrame:AddMessage("The combat log can't be copied -- pick a chat tab.", 1, 0.3, 0.3)
        return
    end
    local total = frame:GetNumMessages() or 0
    local first = count and math.max(1, total - count + 1) or 1
    local lines = {}
    local function IsPlain(v) return not (issecretvalue and issecretvalue(v)) end
    for i = first, total do
        local ok, text, r, g, b = pcall(frame.GetMessageInfo, frame, i)
        if ok and type(text) == "string" and IsPlain(text) then
            if not (IsPlain(r) and IsPlain(g) and IsPlain(b)) then r, g, b = nil, nil, nil end
            local okC, c = pcall(ColoredChatText, text, r, g, b)
            lines[#lines + 1] = okC and c or text
        elseif ok and text ~= nil then
            lines[#lines + 1] = "|cff808080<message hidden from addons>|r"
        end
    end
    local name = frame.GetName and frame:GetName() or "chat"
    local tab = _G[name .. "Tab"]
    local label = (tab and tab.GetText and tab:GetText()) or name
    -- Opens at the bottom: the latest messages are what's usually wanted.
    UberUI.ShowReport(("Chat: %s -- %d line(s)\n\n%s"):format(tostring(label), #lines, table.concat(lines, "\n")), true)
end

local function CreateButton(chatFrame)
    local b = CreateFrame("Button", nil, chatFrame)
    b:SetSize(16, 16)
    b:SetPoint("TOPRIGHT", chatFrame, "TOPRIGHT", 0, 0)
    b:SetFrameLevel(chatFrame:GetFrameLevel() + 10)
    b:SetNormalTexture(ICON)
    b:SetHighlightTexture(ICON, "ADD")
    b:SetAlpha(IDLE_ALPHA)
    b:SetScript("OnEnter", function(self)
        self:SetAlpha(1)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Copy Chat")
        GameTooltip:AddLine("Open this window's chat history in a box you can copy from.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self)
        self:SetAlpha(IDLE_ALPHA)
        GameTooltip:Hide()
    end)
    b:SetScript("OnClick", function() chatcopy.Copy(chatFrame) end)
    return b
end

-- Called at login and from the option's checkbox.
function chatcopy:Refresh()
    local on = Enabled()
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        local chatFrame = _G["ChatFrame" .. i]
        if chatFrame and not IsCombatLog(chatFrame) then
            local b = buttons[chatFrame]
            if on and not b then
                b = CreateButton(chatFrame)
                buttons[chatFrame] = b
            end
            if b then b:SetShown(on) end
        end
    end
end

SLASH_UBERUICOPYCHAT1 = "/uucopychat"
SlashCmdList["UBERUICOPYCHAT"] = function(msg)
    chatcopy.Copy(nil, tonumber(msg and msg:match("%d+")))
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function() chatcopy:Refresh() end)

UberUI.chatcopy = chatcopy

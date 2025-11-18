-- This is an example of how to capture and use event parameters.

-- 1. Create a Frame to listen for events.
-- It's good practice to give it a unique name.
local eventHandlerFrame = UberUI:CreateFrame("Frame", "UberUIExampleEventFrame")

-- 2. Define the function that will handle the event.
-- The arguments are: self, event, ... (a variable number of arguments for event parameters)
local function eventHandler(self, event, ...)
    -- For NAME_PLATE_UNIT_ADDED, the first parameter is 'unitId'.
    -- We can capture the first argument from the '...' varargs.
    local unitId = ...

    -- You can now use the 'unitId' variable.
    -- For this example, we'll just print it to the default chat window.
    print(string.format("Event '%s' fired for unit: %s", event, tostring(unitId)))
end

-- 3. Set the frame's script handler for the "OnEvent" signal.
eventHandlerFrame:SetScript("OnEvent", eventHandler)

-- 4. Register the specific event you want to listen for on this frame.
eventHandlerFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")

print("UberUI: Example event handler for NAME_PLATE_UNIT_ADDED is loaded and ready.")

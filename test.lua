function Color()
    if not BuffIconCooldownViewer then
        print("ERROR: BuffIconCooldownViewer not found!")
        return
    end

    local dc = uuidb.general.darkencolor

    print("\n" .. string.rep("=", 80))
    print("TESTING DIFFERENT DARKENING METHODS ON OVERLAY TEXTURE")
    print(string.rep("=", 80))

    local children = { BuffIconCooldownViewer:GetChildren() }
    print("\nBuffIconCooldownViewer has " .. #children .. " children")

    for i, f in ipairs(children) do
        print("\n" .. string.rep("█", 80))
        print("TESTING FRAME #" .. i)
        print(string.rep("█", 80))

        if f.Icon then
            print("\nFrame has Icon - finding OVERLAY textures...")

            local overlayCount = 0
            for _, r in ipairs({ f:GetRegions() }) do
                if r:IsObjectType("Texture") and r:GetDrawLayer() == "OVERLAY" then
                    overlayCount = overlayCount + 1

                    local atlas = "unknown"
                    if r.GetAtlas then
                        atlas = r:GetAtlas() or "none"
                    end

                    print("\nFound OVERLAY texture #" .. overlayCount)
                    print("  Atlas: " .. atlas)

                    -- Test 1: Just SetVertexColor
                    print("\n  [TEST 1] SetVertexColor with darken color...")
                    r:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
                    print("  Applied. Check if border darkened.")
                    print("  Press ENTER to continue...")
                    io.read()

                    -- Reset
                    r:SetVertexColor(1, 1, 1, 1)

                    -- Test 2: SetDesaturated
                    print("\n  [TEST 2] SetDesaturated(true)...")
                    if r.SetDesaturated then
                        r:SetDesaturated(true)
                        print("  Applied. Check if border is grayscale.")
                        print("  Press ENTER to continue...")
                        io.read()
                        r:SetDesaturated(false)
                    else
                        print("  SetDesaturated not available")
                    end

                    -- Test 3: Combination
                    print("\n  [TEST 3] SetVertexColor + SetDesaturated...")
                    r:SetVertexColor(dc.r, dc.g, dc.b, dc.a)
                    if r.SetDesaturated then
                        r:SetDesaturated(true)
                    end
                    print("  Applied. Check if border is dark and desaturated.")
                    print("  Press ENTER to continue...")
                    io.read()

                    -- Reset to original
                    print("\n  Resetting to original state...")
                    r:SetVertexColor(1, 1, 1, 1)
                    if r.SetDesaturated then
                        r:SetDesaturated(false)
                    end
                    print("  Reset complete.")
                end
            end

            if overlayCount == 0 then
                print("\n  WARNING: No OVERLAY textures found on this frame!")
            else
                print("\n  Tested " .. overlayCount .. " OVERLAY texture(s)")
            end
        else
            print("\n  Frame has no Icon property, skipping")
        end

        -- Only test first frame
        if i >= 1 then
            print("\n(Only testing first frame)")
            break
        end
    end

    print("\n" .. string.rep("=", 80))
    print("TESTING COMPLETE")
    print("Which method(s) worked best?")
    print(string.rep("=", 80))
end

Color()

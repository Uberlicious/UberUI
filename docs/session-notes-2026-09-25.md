# Session notes — 2026-09-24/25

Checkpoint on branch `checkpoint/targetframe-aura-borders`. **Nothing below has been tested in game unless marked tested.** It all parses cleanly (`luac -p`).

## 1. Nameplate taint errors (mitigation, untested)

**Symptom:** "attempt to compare a secret number value (execution tainted by 'Uber UI')" at:
- `TextStatusBar.lua:110`
- `CompactUnitFrame.lua:1206` (`CompactUnitFrame_UpdateHealPrediction`)

Both come from Blizzard's nameplate `OnNamePlateAdded → SetUnit` chain.

**Likely cause:** `UpdateRaidTargetScale` in `core/nameplates.lua` re-anchored (`ClearAllPoints`/`SetPoint`) and rescaled the native `RaidTargetFrame` on every plate add and every target change, even at default settings (scale 1, top anchor off). It was the only nameplate layout write left at defaults. "Small friendly nameplates" was ruled out because the user has it off.

**Change:** at default settings, `UpdateRaidTargetScale` now doesn't touch the nameplate at all. If it modified a frame earlier (feature on), it restores the original points and scale 1 once, then forgets the frame.

**Diagnostics:** new `/uuidebugtaint` (`core/uuidebug.lua`). It uses `issecurevariable` to report which nameplate fields, shared option tables, mixins and Blizzard-looking globals are tainted, and by which addon. If the errors come back, run it while they're happening. It names the real source.

## 2. Compact party/raid aura containers (new feature, untested)

Full design, rules, sources and testing checklist: **`docs/compact-frame-auras.md`**. Short version:

- In 12.1, compact frames have **no Lua aura buttons**. The forbidden `Blizzard_PrivateAurasUI` draws everything, so native auras are switched off with the raid frame CVars (`raidFramesDisplayBuffs`, `raidFramesDisplayDebuffs`, `raidFramesCenterBigDefensive`). The originals are saved and restored on "None"/off.
- New `core/compactauras.lua` builds debuff, buff and Big Defensive containers on every `CompactPartyFrameMember` / `CompactRaidFrame` / `CompactRaidGroup…Member` frame.
- Aura selection runs Blizzard's own compact rules through `SetAuraProcessingPolicy(ProcessAura)` + `processedAuraType` candidate filters, sorted with Blizzard's `UnitFrameDebuff` / `BigDefensive` orders. That's different from target/focus's PLAYER/!PLAYER split.
- Private (boss) auras show automatically. Custom aura containers read the private source; the 12.1 API notes confirm this.
- Sizes and anchors mirror Blizzard's layout templates and Edit Mode icon size %. Only the Big Defensive scales with frame size.
- **aurakit additions:** `BuildGroupedAuraContainer`, `SetGroupedContainerSizes`, `RefreshGroupButtons`. Target/focus behaviour is unchanged.
- **Options:** the compact settings moved out of "Coming Soon" (retail only):
  - Compact Raid/Party Buffs and Debuffs style dropdowns (None = off, native restored)
  - "Style Compact Raid/Party Big Defensive" checkbox
  - No "show dispels" option (enemy stealable buffs can't appear on raid frames).
  - The "highlight debuffs" option was added and then removed again as redundant with the dropdowns.
- **Diagnostics:** new `/uuidebugcompact`.
- **How other addons handle boss abilities** (DandersFrames, EllesmereUI, Raid Frame Auras): all use `HARMFUL` + `isBossAura` / `isRoleAura` candidate filters. None show helpful boss auras. DandersFrames has an optional "important" scale.
- **Open:** we don't yet enlarge boss/role debuffs 1.5× like Blizzard does. Proposed: a boss group (`isBossOrRoleAura = true`, 1.5× when the player's `raidFramesDisplayLargerRoleSpecificDebuffs` is on). Not built.
- **Known 12.1 Blizzard bug** (not ours): aura containers sometimes don't show HoTs on raid frames in instances. It's reported for DandersFrames, EllesmereUI and default frames alike.

## 3. Player frame mana bar (tested by user)

- **Flat texture reverting in combat:** Blizzard's `UnitFrameManaBar_Update` → `UnitFrameManaBar_UpdateType` re-applies its atlas on every mana bar update. Our player-frame event handler skips everything in combat, so Blizzard's texture stuck until combat ended. Fixed with a post-hook on `UnitFrameManaBar_UpdateType` that re-applies our texture/color for the player and pet mana bars (uses the bar's own unit, so vehicles work). Mana bar styling now goes through one shared helper.
- **Mana cost prediction hard to see:** Blizzard tints it once at load with `MANAPREDICTIONBLUE`, nearly the same blue as a flat-textured mana bar. It's now tinted with the bar's power color lightened toward white by `MANA_COST_PREDICTION_LIGHTEN` (0.35 after tuning from 0.55). It follows druid forms and also applies when only the secondary texture is set.
- **Side effect:** the pet mana bar is now desaturated before coloring, like the player's.

## 4. Darkness slider, bags, action bars (tested by user)

- **Slider refresh:** `misc:AllFramesColor()` never called `BagSlots()`, `ObjectiveTrackerFrames()` or `partyframes:Color()`, so those didn't follow the slider. Added.
- **Backpack:** it only ever got half the darkening (`(r + 1) / 2`), added Nov 2025 with no recorded reason. It now darkens like the other bag slots.
- **Keyring:** moved into the shared bag list so it keeps its darkening when Blizzard redraws it (previously tinted once at load).
- **Dividers:** new `general:DarkenDividers` / `general:HookDividers` (`core/generalfunctions.lua`) darken the pooled three-slice divider pieces between buttons (`TopEdge` / `Center` / `BottomEdge`, or `LeftEdge` / `RightEdge` on vertical bars). They're re-applied on every `UpdateDividers` because Blizzard releases and re-acquires them. Hooked on:
  - `MainActionBar` (retail and Forever)
  - `BagsBar` (Forever only; retail's bags bar has no dividers, and the hook skips it)
- **Retail vs Forever bags:** Forever uses square bag buttons with action bar frame art (`ui-hud-actionbar-iconframe-bags`); retail uses round `bag-border` art. Both draw it through the same `UpdateTextures` → NormalTexture path with the same button names, so one code path covers both. Forever's gamepad bag layout uses different button names and isn't covered.
- **Tried and reverted at the user's request:**
  - Bag pushed-texture tint
  - Action bar `SlotArt` / `SlotBackground` tint (twice)
  - Bag icon (`…IconTexture`) tint, which also darkened the bag pictures themselves

## Reference: reading current Blizzard source

The Blizzard dumps in this repo (`AddOns/`, `blizzard_source/`) are older than 12.1. Use the `D:\github\wow-ui-source` clone instead. `git fetch` fails over SSH there, but these were current as of this session:
- `origin/live` = 12.1.0 (69875)
- `origin/forever` = 1.60.1 (69913)

```bash
git -C /d/github/wow-ui-source show origin/live:Interface/AddOns/<path>
```

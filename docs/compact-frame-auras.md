# Compact party/raid frame aura containers

Status as of this writing (2026-09-24): **built, parses cleanly, not yet tested in-game.** Read this before touching `core/compactauras.lua`, the compact parts of `core/aurakit.lua`, or the compact aura options. Most of what's below was expensive to establish, and several early assumptions turned out to be wrong.

## TL;DR

- In 12.1, Blizzard's compact party/raid frames **no longer have Lua aura buttons**. All their auras are drawn by the forbidden `Blizzard_PrivateAurasUI` addon. We can't hide, restyle or read those frames.
- So we **turn the native auras off through the player's own raid frame CVars** and draw our own with aurakit-styled `CustomAuraContainerTemplate` containers.
- Our containers **show private (boss) auras automatically**. No `AddPrivateAuraAnchor` slots are needed.
- Aura selection uses **Blizzard's exact compact-frame rules** via `SetAuraProcessingPolicy(ProcessAura)`, not the target/focus `PLAYER`/`!PLAYER` split.
- **Never write fields onto Blizzard frames or tables** from this code. See [Taint rules](#taint-rules).

## Where to read Blizzard's source (important)

The Blizzard source dumps inside this repo (`AddOns/` and `blizzard_source/`) are **older than 12.1**. They still show `frame.buffFrames` / `debuffFrames` and have no Big Defensive or aura size settings. Don't trust them for 12.x aura code.

Use the `origin/live` branch of the local `D:\github\wow-ui-source` clone instead (12.1.0 build 69875 as of this writing):

```bash
git -C /d/github/wow-ui-source show origin/live:Interface/AddOns/Blizzard_PrivateAurasUI/Blizzard_PrivateAurasUI.lua
```

`git fetch` on that clone fails with SSH access errors, but `origin/live` was already current. Key files:

| File (under `Interface/AddOns/`) | What's in it |
|---|---|
| `Blizzard_UnitFrame/Shared/CompactUnitFrame.lua` | `DefaultCompactUnitFrameSetup`, size constants, `ContainerPrivateAuraBehaviorMixin` (the attributes it hands to the renderer) |
| `Blizzard_PrivateAurasUI/Blizzard_PrivateAurasUI.lua` | The forbidden native renderer: `ProcessAura` usage, `PrivateAuraUnitFrameLayoutTemplates`, Big Defensive handling |
| `Blizzard_AuraContainer/Blizzard_CustomAuraContainer.lua` | `AddAuraGroup` options, candidate filters, `SetAuraProcessingPolicy`, `SetAuraGroupLayout` |
| `Blizzard_AuraContainer/Blizzard_AuraContainerShared.lua` | Enums: `AuraContainerSortMethod`, `CustomAuraContainerAuraProcessingPolicy`, batch size |
| `Blizzard_AuraContainer/Blizzard_AuraContainerSources.lua` | Public vs private aura sources |
| `Blizzard_FrameXMLUtil/AuraUtil.lua` | `AuraUtil.ProcessAura`, `AuraFilters` token list, `IsBigDefensive` |
| `Blizzard_CUFProfiles/Blizzard_CompactUnitFrameProfiles.lua` | CVar → compact frame option mapping |

## How native compact auras work in 12.1

- Each compact frame registers itself as **one** private-aura *container* anchor (`ContainerPrivateAuraBehaviorMixin`, `isContainer = true`).
- It passes its settings as frame attributes: `max-buffs`, `max-debuffs`, `buff-size`, `debuff-size`, `big-defensive-size`, `aura-organization-type`, `power-bar-used-height`, `group-type`, `ignore-buffs`, and so on.
- `Blizzard_PrivateAurasUI` reads those attributes and draws buffs, debuffs, dispel type icons, the dispel overlay and the Big Defensive.
- Its XML is wrapped in `<ScopedModifier forbidden="true" hideFromGlobalEnv="true">`. Those frames are forbidden and have no global names.
- The **Big Defensive** is not a container. It's a single pooled `PrivateAuraTemplate` frame (`BigDefensiveBuff`), centred on the compact frame, filled with the top entry of a sorted list of auras passing `AuraUtil.IsBigDefensive`.

## Turning native auras off

The only supported switch is the player's own raid frame options, which are CVars:

| Our feature | CVar | Blizzard option it drives |
|---|---|---|
| Buffs | `raidFramesDisplayBuffs` | `displayBuffs` |
| Debuffs | `raidFramesDisplayDebuffs` | `displayDebuffs` |
| Big Defensive | `raidFramesCenterBigDefensive` | `raidFramesCenterBigDefensive` |

- When a feature is on, `compactauras:ApplyNativeCVars()` saves the original value to `uuidb.cuf.nativecvars[cvar]`, then sets the CVar to `"0"`.
- When a feature is set to None or turned off, it restores the saved value and clears it.
- CVar changes are made **out of combat only**. In combat they're deferred to `PLAYER_REGEN_ENABLED`.
- A CVar change fires the `CVAR_UPDATE` event. Blizzard's `CompactUnitFrameProfiles` re-runs frame setup from its own event handler, **not** inside our `SetCVar` call, so this doesn't taint Blizzard's frame setup.
- Turning native debuffs off does **not** remove the dispel overlay or dispel type icons. `CheckAddDispel` runs independently of the debuff toggle and is driven by `raidFramesDispelIndicatorType` / `raidFramesDispelIndicatorOverlay`.
- If Uber UI is disabled or uninstalled while a feature is on, the CVars stay at `"0"` and the player has to re-enable Blizzard's options by hand. Setting the features to None first restores them.

## Private (boss) auras

**Addon-made custom aura containers include private auras.** Early in the investigation I assumed they didn't, and that was wrong.

- `CustomAuraContainerPrivateMixin` builds on `ManagedAuraContainerPrivateMixin`, whose `ShouldIncludePrivateAuraSource()` returns `true`. The custom container doesn't override it, so groups read from `AuraContainerAuraSourceLists.PublicAndPrivate`.
- The private source lists `C_UnitAurasPrivate.GetAllPrivateAuraInstanceIDs(unit)` and ignores the filter string at that step.
- Filtering happens afterwards in `AuraContainerUtil.ShouldIncludeAuraForFilterString`. For private auras it calls `C_UnitAurasPrivate.IsPrivateAuraFilteredOutByInstanceID(unit, id, filterString)`.
- The container registers `C_UnitAurasPrivate.AddPrivateAuraUpdateCallback` for its unit, so private auras update live.

A plain `HARMFUL` group therefore covers private boss debuffs.

**EllesmereUI reference** (`D:\github\EllesmereUI`): up to v8.7 it registered its own per-slot `C_UnitAuras.AddPrivateAuraAnchor` anchors (`RegisterPrivateAuraSlots`, `isContainer = false`, `auraIndex = i`) plus a dispel overlay container anchor. v8.8 (2026-08-11) removed all of it. The most likely reason is that its AuraContainer displays already cover private auras. A few stale comments about re-registering anchors are still in `EllesmereUIRaidFrames.lua`.

## Aura selection rules

Compact frames use different rules from target/focus. Blizzard classifies every aura with `AuraUtil.ProcessAura` into **Buff**, **Debuff**, **Dispel** or **None**:

- **Debuff**: boss auras and role auras (including *helpful* boss auras, which Blizzard shows in the debuff row), priority debuffs, and ordinary harmful auras that pass `ShouldDisplayDebuff`.
- **Dispel**: harmful auras flagged `isRaid` (dispellable by the group) with a dispellable type. Blizzard shows these in the debuff row too, and as dispel type icons.
- **Buff**: `ShouldDisplayBuff`, meaning auras cast by you (or your pet/vehicle) that you can apply and that aren't self-only, plus spells Blizzard flags for your spec.
- `displayOnlyDispellableDebuffs` (CVar `raidFramesDisplayOnlyDispellableDebuffs`) drops ordinary non-dispellable debuffs.

The 12.1 container can run that exact function itself:

- `container:SetAuraProcessingPolicy(CustomAuraContainerAuraProcessingPolicy.ProcessAura, { displayOnlyDispellableDebuffs, ignoreBuffs, ignoreDebuffs, ignoreDispelDebuffs })` stores `ProcessAura`'s result on each aura as `processedAuraType`.
- A group's `candidateFilters = { processedAuraType = AuraUtil.AuraUpdateChangedType.X }` keeps only auras of that type. The match is **exact**, so Debuff and Dispel need separate groups.
- The policy must be set **before** adding groups. Without it, any `processedAuraType` filter hides everything.
- Nothing in Blizzard's own UI uses this policy yet. If something misbehaves, suspect this first.

Our groups (`core/compactauras.lua`):

| Container | Group | Filter | processedAuraType | Max | Sort |
|---|---|---|---|---|---|
| Debuffs | `debuffs` | `HARMFUL` | Debuff | 5 | `UnitFrameDebuff` |
| Debuffs | `dispels` | `HARMFUL` | Dispel | 3 | `UnitFrameDebuff` |
| Buffs | `buffs` | `HELPFUL` | Buff | 6 | default |
| Big Defensive | `bigdefensive` | `HELPFUL\|BIG_DEFENSIVE` | (no policy) | 1 | `BigDefensive` |

- If the engine's container aura data doesn't populate `isRaid`, nothing classifies as Dispel. Those debuffs fall through to Debuff and still show in the first group.
- Blizzard's debuff cap is 5 total. Ours can show up to 8 (5 + 3) when both kinds are present.
- Each `AddAuraGroup` creates a batch of **10 buttons up front** (`CustomAuraContainerConstants.FrameCreationBatchSize`). Four groups × up to 45 frames adds up, so don't add groups casually.

Filter tokens available in 12.1 (`AuraUtil.AuraFilters`): `HELPFUL`, `HARMFUL`, `PLAYER`, `RAID`, `CANCELABLE`, `INCLUDE_NAME_PLATE_ONLY`, `MAW`, `EXTERNAL_DEFENSIVE`, `CROWD_CONTROL`, `RAID_IN_COMBAT`, `RAID_PLAYER_DISPELLABLE`, `BIG_DEFENSIVE`, `IMPORTANT`, `DISPELLABLE`. A leading `!` negates (except `INCLUDE_NAME_PLATE_ONLY` and `MAW`).

Boolean candidate filters: `isFromPlayerOrPlayerPet`, `isRoleAura`, `isPriorityAura`, `isStealable`, `nameplateShowAll`, `nameplateShowPersonal`, `canApplyAura`, `isBossAura`, `isBossOrRoleAura`. Also available: `includeSpellIDs`, `excludeSpellIDs`, `includeDispelTypes`, `excludeDispelTypes`, `maxDuration`.

## Sizes

Constants from `CompactUnitFrame.lua`: native frame 72×36, `NATIVE_UNIT_FRAME_AURA_SIZE = 11`, Big Defensive base = 22.

| Icon | Size | Scale clamp |
|---|---|---|
| Buffs | `11 × BuffIconSize%` | 0.5–2 |
| Debuffs | `11 × DebuffIconSize%` | 0.5–2 |
| Big Defensive | `22 × componentScale × BigDefensiveIconSize%` | 0.5–1 |

- The % comes from `EditModeManagerFrame:GetRaidFrameIconScale(frame.groupType, 1, Enum.EditModeUnitFrameSetting.X)`.
- `componentScale = min(height / 36, width / 72)`, using `EditModeManagerFrame:GetRaidFrameWidth/Height(groupType, default)`.
- Only the Big Defensive follows frame size. Buffs and debuffs don't.
- Sizes are recomputed from a post-hook on `DefaultCompactUnitFrameSetup`, which Blizzard re-runs on Edit Mode and profile changes. Existing buttons are resized in place with `aurakit.SetGroupedContainerSizes` (calls `SetAuraGroupLayout` and resizes each button).

## Layout

Copied from `PrivateAuraUnitFrameLayoutTemplates` in `Blizzard_PrivateAurasUI.lua`. "Bottom" = `2 + power bar height` (`frame.powerBarUsedHeight`); edges are inset 3px.

| Template (`Enum.RaidAuraOrganizationType`) | Buffs | Debuffs |
|---|---|---|
| Legacy | BOTTOMRIGHT, grow left/up, 3 per row | BOTTOMLEFT, grow right/up, 3 per row |
| BuffsTopDebuffsBottom | TOPRIGHT (−3, −3), grow left/down, 6 per row | BOTTOMRIGHT, grow left/up, 3 per row |
| BuffsRightDebuffsLeft | same as Legacy | same as Legacy |

- The Big Defensive is centred on the frame in every template.
- Blizzard also shifts icons inward by `dispelOverlayAuraOffset` when the dispel overlay is on. We don't, yet.
- Containers aren't repositioned while playing. They're placed once per setup pass.

## Frame discovery and units

- Only frames named `CompactPartyFrameMember%d`, `CompactRaidFrame%d` and `CompactRaidGroup%dMember%d` are handled. Arena frames (PvP rules) and nameplates (which share the `CompactUnitFrame_*` functions) are excluded by name.
- Frames are found at `PLAYER_LOGIN` by name and afterwards through a post-hook on `CompactUnitFrame_SetUnit`. Frames are reused as the roster changes.
- Containers point at `frame.displayedUnit or frame.unit`. A post-hook on `CompactUnitFrame_UpdateAll` catches vehicle swaps, which change `displayedUnit` without a `SetUnit` call.
- An unassigned container points at `"none"`, the engine's null binding. **Never use `"player"` as a placeholder**, or empty frames show your own auras.
- Containers are **created out of combat only** (EllesmereUI found creation fails in combat). Frames first seen in combat are queued and keep native auras until `PLAYER_REGEN_ENABLED`. `SetUnit`, `Show`/`Hide` and repositioning work in combat.
- Containers are created lazily per enabled feature, to avoid allocating buttons that are never used.

## Settings

Options panel, retail only (`WOW_PROJECT_MAINLINE`), right after the Focus options:

| Option | Saved variable | Default | Notes |
|---|---|---|---|
| Compact Raid/Party Buffs | `aurastyle_compactbuffs` | `both` | None = off, native restored |
| Compact Raid/Party Debuffs | `aurastyle_compactdebuffs` | `zoom` | None = off, native restored |
| Style Compact Raid/Party Big Defensive | `compactbigdefensive` | `true` | Styled with the buff style |

- There's deliberately **no "Show Dispels" option** for compact buffs. Enemy stealable buffs can't appear on friendly raid frames, so compact buttons always pass `showDispel = false`.
- There's also **no separate debuff highlight option**. Debuff borders follow the style dropdown exactly like target/focus: dispel-type colours for Zoom Only, dark border for Zoom & Dark Border / Dark Border Only.

## Taint rules

Learned the hard way on nameplates (secret health comparisons failing with "execution tainted by 'Uber UI'"):

- **Never write Lua fields onto Blizzard frames or Blizzard tables.** Blizzard later reads them in secure code, and the taint spreads into secret-value comparisons. Per-frame state lives in the weak-keyed `frameState` table in `compactauras.lua`.
- Writing fields onto **our own** containers and aura buttons (`container.uuGroups`, `button.isBuff`, …) is fine.
- **Don't call `CompactUnitFrame_SetMaxBuffs` / `SetMaxDebuffs`** or anything else that writes to `frame.max*`. Those are exactly the fields Blizzard reads before its secret-value comparisons.
- Reading Blizzard fields (`frame.groupType`, `frame.displayedUnit`, `frame.powerBarUsedHeight`) is fine.
- `hooksecurefunc` post-hooks are fine as long as they only touch our own objects.
- Calling `SetWidth`/`SetPoint`/`SetScale` on Blizzard frames from addon code is suspect, because it can run Blizzard scripts such as `OnSizeChanged` in tainted code.

## Known differences from Blizzard

- Helpful boss auras don't show. Blizzard puts them in the debuff row. A third debuff group (`HELPFUL`, processedAuraType = Debuff) would catch them, at a cost of 10 buttons per frame.
- `PrivateGroupBuffsManager`'s hidden group buffs aren't applied, and neither is `aura.hideOnPartyFrames`.
- Boss and role debuffs aren't enlarged (Blizzard uses `BOSS_DEBUFF_SCALE_INCREASE` with `displayLargerRoleSpecificDebuffs`).
- A one-slot container shows the first entry in `BigDefensive` sort order. That should match Blizzard's `BigDefensiveAuraCompare`, but hasn't been verified with two defensives overlapping.
- No dispel overlay inset (see Layout).

## Testing checklist

1. `/reload` in a party using raid-style party frames, then in a raid.
2. `/uuidebugcompact` shows the settings, native CVars (current and saved original), each frame's containers with unit, shown state, active icon count and size per group, any `AddAuraGroup` errors, and frames waiting for combat to end.
3. Check:
   - Boss private debuffs appear in the debuff row.
   - Dispellable debuffs appear. If they're always in the `debuffs` group and `dispels` stays at 0, `isRaid` isn't populated. That's harmless, but worth knowing.
   - Changing Edit Mode buff/debuff/Big Defensive size % resizes icons.
   - All three aura organization templates.
   - Power bar on and off (bottom offset).
   - Roster changes and joining mid-combat.
   - Setting each option to None or off restores Blizzard's native icons, and setting it back turns them off again.
   - Nothing throws "execution tainted by 'Uber UI'".

## Files

| File | Role |
|---|---|
| `core/compactauras.lua` | The module: CVars, sizes/layout, container construction, frame discovery, hooks |
| `core/aurakit.lua` | `BuildGroupedAuraContainer`, `SetGroupedContainerSizes`, `RefreshGroupButtons` |
| `options.lua` | The three compact settings (moved out of "Coming Soon") |
| `config.lua` | Default for `compactbigdefensive` |
| `core/uuidebug.lua` | `/uuidebugcompact` |
| `Uber UI.toc` | Loads `core\compactauras.lua` after `core\compactunitframe.lua` |

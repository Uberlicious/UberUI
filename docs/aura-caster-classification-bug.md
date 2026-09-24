# Target/focus frame "buff shown in both mine/other containers" bug

Status as of this writing: **root cause identified, mitigation implemented and confirmed working in-game by the user.** Read this whole file before touching `core/aurakit.lua`, `core/targetframe.lua`, or `core/focusframe.lua`'s aura code again — a lot of dead ends below were expensive to rule out.

## The original symptom

Target/focus frame custom aura containers split buffs/debuffs into `*_mine` (large icon) and `*_other` (small icon) sub-groups, using Blizzard's `AddAuraGroup` filter-string tokens `"HELPFUL|PLAYER"` / `"HELPFUL|!PLAYER"` (and the `HARMFUL` equivalents). Reported bug: when targeting a friendly party member, a buff **they** cast on themselves (not cast by the local player) would sometimes render in **both** the `mine` and `other` containers instead of only `other`.

## Root cause (confirmed)

The engine's caster-identity resolution for an aura degrades when the unit carrying that aura is **outside the local player's current zone**:

- While the observer and the unit share a zone, `auraData.sourceUnit` correctly resolves (e.g. `"party1"`), and `"HELPFUL|PLAYER"` / `"HELPFUL|!PLAYER"` partition correctly — an aura matches exactly one.
- The moment the observer crosses a zone boundary away from that unit, `auraData.sourceUnit` for that unit's own auras goes to **`nil`** (unresolvable) — even though the aura itself is still fully known (name, icon, duration, instance ID all still readable).
- When `sourceUnit` is unresolvable, the engine's `PLAYER`/`!PLAYER` classification (and the `isFromPlayerOrPlayerPet` field on aura data, and the `candidateFilters.isFromPlayerOrPlayerPet` `AddAuraGroup` option — all three read the *same* underlying flag) does not fail toward one deterministic answer. It satisfies **both** filters at once. That's the duplicate.

Precisely characterized via `/uuidebugoverlapwatch` (see Tooling below):

- Not distance/range-based — walking the same distance away **without** crossing a zone boundary does not trigger it.
- Triggered specifically by the zone-boundary crossing, but doesn't manifest instantly — takes roughly 2-4 seconds after the `ZONE_CHANGED_NEW_AREA`-family event to actually flip.
- Once triggered, persists indefinitely (does not self-correct while remaining in the different zone).
- Clears within a few seconds of returning to the same zone as the unit.
- **Confirmed identical on both WoW Forever (1.60.1) and retail** — this is a general Blizzard client bug, not version-specific.
- **Confirmed identical on the Target Frame alone**, no party/raid frames involved — this is not raid/party-frame-specific either, despite first being noticed there.
- Blizzard's own default UI (`CompactPartyFrame`) shows a *related but different* failure mode under the same condition: instead of duplicating, the ambiguous buff simply **disappears** (e.g. a priest's own Power Word: Fortitude vanishes from the party frame once the priest zones away from that ally, confirmed via screenshots). Checked `CompactPartyFrame.lua` / `CompactUnitFrame.lua` / `PartyFrame.lua` source — buff/debuff rendering there is 100% engine-native (secure attribute-driven, e.g. `SetAttribute("max-buffs", ...)`), zero Lua-visible implementation. Blizzard's exact internal "hide instead of duplicate" mechanism can't be inspected from source, only its outcome observed.

Definitive combined capture (`/uuidebugoverlapwatch`, watching all units, with the same ally simultaneously targeted *and* set as focus's... actually just targeted + party1 in this capture — both unit tokens resolving to the same character fire in lockstep on the identical `auraInstanceID`s, confirming one underlying engine bug hitting every consumer identically, not a per-frame quirk):

```
==== overlap watcher log (7 entries) ====
#1 [ZONE CHANGE] time=13:20:30 sinceLogin=93s -> zone=Undercity | target=[visible=true inRange=<secret> sameZoneMap=false] party1=[visible=true inRange=<secret> sameZoneMap=false]
#2 [OVERLAP STARTED] time=13:20:32 sinceLogin=96s unit=target auraInstanceID=4294966995 name=Devotion Aura sourceUnit=nil zone=Undercity visible=false inRange=<secret> sameZoneMap=false inCombat=false class=SHAMAN
#3 [OVERLAP STARTED] time=13:20:32 sinceLogin=96s unit=target auraInstanceID=4294966996 name=Blessing of Might sourceUnit=nil zone=Undercity visible=false inRange=<secret> sameZoneMap=false inCombat=false class=SHAMAN
#4 [OVERLAP STARTED] time=13:20:32 sinceLogin=96s unit=target auraInstanceID=4294966997 name=Find Minerals sourceUnit=nil zone=Undercity visible=false inRange=<secret> sameZoneMap=false inCombat=false class=SHAMAN
#5 [OVERLAP STARTED] time=13:20:32 sinceLogin=96s unit=party1 auraInstanceID=4294966995 name=Devotion Aura sourceUnit=nil zone=Undercity visible=false inRange=<secret> sameZoneMap=false inCombat=false class=SHAMAN
#6 [OVERLAP STARTED] time=13:20:32 sinceLogin=96s unit=party1 auraInstanceID=4294966996 name=Blessing of Might sourceUnit=nil zone=Undercity visible=false inRange=<secret> sameZoneMap=false inCombat=false class=SHAMAN
#7 [OVERLAP STARTED] time=13:20:32 sinceLogin=96s unit=party1 auraInstanceID=4294966997 name=Find Minerals sourceUnit=nil zone=Undercity visible=false inRange=<secret> sameZoneMap=false inCombat=false class=SHAMAN
```

Note: `target`/`focus` unit tokens only report while they actually exist (i.e. while something is targeted / focused) — `party1`-style tokens exist regardless of target selection. To capture all relevant frames at once, target (and optionally focus) the same character who is also a party member.

## The fix (implemented, working)

`core/aurakit.lua` adds two functions:

```lua
-- Queries C_UnitAuras.GetUnitAuraInstanceIDs(unit, ...) DIRECTLY, no
-- AddAuraGroup/container/button involved (important -- see "Dead ends"
-- below re: GetAuraGroupFrameCount). Returns true if any instance ID
-- currently matches both "<base>|PLAYER" and "<base>|!PLAYER" for unit.
aurakit.HasAmbiguousMineMatch(unit, isHarmful)

-- Returns 0 when HasAmbiguousMineMatch is true, else normalMaxCount.
aurakit.GetSafeMineMaxFrameCount(unit, isHarmful, normalMaxCount)
```

`core/targetframe.lua` and `core/focusframe.lua`'s `UpdateAuras()` route the `"mine"` group's `SetAuraGroupMaxFrameCount` call through `GetSafeMineMaxFrameCount`, forcing it to 0 during ambiguity while leaving `"other"` untouched. Net effect: during the ambiguous window, the affected aura stays visible via the correctly-populated `"other"`/small slot instead of duplicating — and unlike Blizzard's own UI, it never disappears either.

Both files also now register `ZONE_CHANGED_NEW_AREA` / `ZONE_CHANGED` / `ZONE_CHANGED_INDOORS` and re-run `UpdateAuras()` at +1s/+3s/+5s after any zone transition, since the ambiguity doesn't flip instantly at the event.

## Not yet done / follow-up work

- **Raid/party frame equivalent.** `core/compactunitframe.lua`'s `UpdateAllAuras()` is an empty stub with a comment saying raid frame auras are "locked in Blizzard's forbidden secure environment" — checked git history, this has *never* had real aura-styling code, it's not a regression. This bug visibly affects `CompactPartyFrame`/`CompactRaidFrame` too (confirmed via screenshots), but the mitigation technique used for target/focus (gate `SetAuraGroupMaxFrameCount` on our own `AddAuraGroup` container) **cannot** be applied there, because raid/party frame buff/debuff rendering is engine-native with no addon-controlled `AddAuraGroup` container to gate at all. Whatever raid/party frame border/styling work happens needs its own, different mitigation — not designed yet.
- **Bug report never submitted.** Drafted (see conversation) for `ClassicWoWCommunity/forever-bugs`, then reconsidered once retail was confirmed affected too — that tracker is Forever-specific and this isn't. Should go to Blizzard's actual bug-report channel (in-game Help → Submit Feedback → Bug Report, or the WoW forums Bug Report subforum) instead. Never actually posted anywhere yet.
- **EllesmereUI's raid frame code** (`EllesmereUIRaidFrames/EUI_RaidFrames_AuraContainers.lua`, ~3600 lines just for that file) independently documents the same `isFromPlayerOrPlayerPet` unreliability ("matches auras cast by ANY player (verified: same-spec allies' buffs pass it)") and works around it by using the `PLAYER` filter token only for narrow, single-purpose "own-only" indicator slots rather than paired mine/other group splits. Worth a closer read if/when doing raid frame work, now that the `sourceUnit`-goes-`nil` root cause is understood precisely — their approach may or may not have the same zone-crossing exposure.

## Dead ends (do not re-investigate these without new information)

All of the following were tried and ruled out this session, in roughly this order:

1. **Single-group topology matching Blizzard's real `TargetFrameAuraContainer`** (one `"HELPFUL"` group, no `PLAYER` token at all — this is literally how Blizzard's own target frame works, confirmed by reading `TargetFrameAuraContainer.lua`/`TargetFrameAuraShared.lua` in `wow-ui-source`). This does structurally eliminate the duplicate, but Blizzard's own large/small sizing (`ShouldShowAuraWithLargeSize`) reads `sourceUnit` inside their own secure code, a privilege addon Lua doesn't have — so this path loses the mine/other size distinction entirely. Was fully implemented, then reverted at the user's request because the size distinction is a hard requirement, not just a nice-to-have.
2. **Native Blizzard button injection** — tried restyling Blizzard's real `TargetFrame`/`FocusFrame` aura buttons directly (inspired by `core/buffsandauras.lua`'s working technique on the player's own legacy `BuffFrame`/`DebuffFrame`). Dead end, empirically confirmed via `/uuidebugnativeaura`: `TargetFrameAuraContainerSharedMixin` has no `GetAuraGroupFrameCount`/`GetAuraGroupFrame` (those only exist on `CustomAuraContainerSharedMixin`, i.e. only containers *we* create), `.buffAuraGroup`/`.debuffAuraGroup` are secure-private fields reading back as `nil` to insecure code, and `blizzAuras:GetChildren()` returns 0. There is no enumeration API for native buttons at all. `buffsandauras.lua`'s success is on Blizzard's *old legacy* `AuraFrameMixin` system (plain Lua fields, no secure partitioning) — an unrelated, older widget type that doesn't apply to Target/Focus frames.
3. **Masque** (github.com/SFX-WoW/Masque) reviewed for ideas. Doesn't help — it's pure opt-in registration (`Group:AddButton`) on buttons a host addon already owns and builds itself; it never reaches into a frame on its own initiative, so it hits the exact same wall as #2 for anything it doesn't control.
4. **`candidateFilters.isFromPlayerOrPlayerPet`** (an `AddAuraGroup` option, distinct from the `PLAYER` filter string token). Tested via `/uuidebugcandidatefilter` with a throwaway container: setting it `true` in one group and `false` in another admitted **100% of auras to both** (`all=10, mine=10, other=10`) — a complete no-op on this client, not just unreliable.
5. **Per-button `auraInstanceID` / `:GetAuraInstance()`** on our own `AddAuraGroup`-created buttons. Tested via `/uuidebugauras`: `auraInstanceID` is `nil` (the field doesn't exist on these buttons at all, not secret, genuinely absent), and `:GetAuraInstance()` errors "attempt to call a nil value" (the method doesn't exist either). Even `:IsShown()` reads as `<secret>` on these buttons.
6. **Per-button `:GetCasterName()` / `:GetSpellName()`** — found via a full `pairs()` key dump on a real button (`/uuidebugcorrelate`) that these exist as real methods. But they're never populated by the engine — they're an addon-writable cache pair (`SetCasterName`/`GetCasterName`), not something the engine fills in. Always `nil` in practice.
7. **Index correlation via `AuraContainerSortMethod.AuraInstanceIDOnly`** (sort a single group by strict ascending `auraInstanceID`, sort an independent `AuraUtil.ForEachAura` enumeration the same way, assume matching position = matching aura). Abandoned: `GetAuraGroupFrameCount` was found to reflect **pool capacity** (`CustomAuraContainerConstants.FrameCreationBatchSize = 10`, confirmed in `Blizzard_AuraContainerShared.lua`), not the real active-match count — a container reported `10` buttons when only `5` real auras existed. There's no way to tell which of the 10 are "real" vs pool padding from insecure code, since `:IsShown()` is secret on every button tested (see #5).
8. **`AuraUtil.ForEachAura(unit, filter, nil, callback, true)`** direct unit-level enumeration — **this one actually works.** `auraData.sourceUnit`, `.name`, `.auraInstanceID`, `.isHarmful`/`.isHelpful` are all real, readable, and accurate (verified against `UnitIsUnit("player", sourceUnit)` ground truth in multiple scenarios). This is what eventually found the root cause. Its limitation: it's a unit-level query with no connection back to a specific rendered button in our `AddAuraGroup` containers (which expose no identity per #5/#6), so it can't be used to fix per-button *sizing* — only to detect the ambiguous *condition* for a unit as a whole, which is exactly what the shipped fix does (gate the whole `"mine"` group's count, not a specific button).

The 5th parameter / predicate-function idea for `AddAuraGroup` suggested by an external (Gemini) research pass was **fabricated** — the real signature (confirmed by directly reading `Blizzard_CustomAuraContainer.lua`) is `AddAuraGroup(groupKey, filterString, options)` with a fixed `candidateFilters` whitelist, no arbitrary predicate callback support. Don't chase that again either.

## Debug tooling (all in `core/uuidebug.lua`, all still present in the codebase)

- `/uuidebug` — pre-existing general addon/native-container state dump.
- `/uuidebugauras [target|focus]` — per-button aura source dump via `GetAuraDataByAuraInstanceID` on our own custom containers.
- `/uuidebugnativeaura [target|focus]` — proof-of-concept that tries to inject a border directly onto Blizzard's native aura buttons (dead end #2 above; kept for reference/regression-proofing that assumption).
- `/uuidebugcandidatefilter [target|focus]` — tests whether `candidateFilters.isFromPlayerOrPlayerPet` is a true partition (dead end #4 above).
- `/uuidebugauraenum [target|focus]` — direct `AuraUtil.ForEachAura` enumeration; the tool that found `sourceUnit` is real/accurate while `isFromPlayerOrPlayerPet` is not (see #8 above). **Remember**: pass `usePackedAura = true` (5th arg) or you get an unpacked tuple instead of a table and every field silently reads back `nil`.
- `/uuidebugcorrelate [target|focus]` — button key-dump plus count-parity check between a sorted single-group container and direct enumeration; found the `FrameCreationBatchSize=10` pool-capacity issue (#7) and that `GetCasterName`/`GetSpellName` are never populated (#6).
- `/uuidebugvisualtest [target|focus|hide]` — puts up 6 big, labeled, unstyled icon rows (`HELPFUL|PLAYER`, `HELPFUL|!PLAYER`, `HELPFUL` baseline, and the `HARMFUL` equivalents) for a direct "which row does this specific buff render in" visual check. This is what first visually proved the duplicate on WoW Forever.
- `/uuidebugoverlapwatch [stop|clear|<unit token>]` + `/uuidebugoverlaylog` — the tool that actually found the root cause. Background 1s ticker comparing `C_UnitAuras.GetUnitAuraInstanceIDs(unit, "HELPFUL|PLAYER")` vs `"HELPFUL|!PLAYER"` for real instance-ID overlap across target/focus/party1-4/raid1-10 (default) or a single specified unit, logging `OVERLAP STARTED`/`OVERLAP CLEARED` state transitions plus `ZONE CHANGE` events with proximity context (`UnitIsVisible`, `UnitInRange`, and `sameZoneMap` via `C_Map.GetPlayerMapPosition` — the same mechanism that places party/raid dots on the world map, since there's no direct "get another player's zone" API).

Every field these tools print goes through a `SecretSafe`/`SecretSafeEnum` helper before hitting `string.format`/`table.concat` — a secret value is contagious through both (even `tostring()` of one stays secret) and will otherwise crash the report with "invalid value (secret) ... for 'concat'". This bit us twice before the helper was applied consistently; route any new field through it.

## Codebase state note

At one point this session the whole 4-group `mine`/`other` design was replaced with the single-group topology (dead end #1), fully implemented across `aurakit.lua`/`targetframe.lua`/`focusframe.lua`, then **fully reverted** via `git checkout` back to the original 4-group design at the user's explicit request, before the current ambiguity-detection mitigation (which builds on top of the original 4-group design, not the single-group one) was designed and implemented. If you're diffing against an older commit, that single-group detour won't show up anywhere — it was reverted before being committed.

# Nameplate aura styling — research notes (shelved 2026-09-25)

Status: **not implemented.** Attempted once, reverted. This document captures why, and the
design for whichever future session picks it back up. See [`compact-frame-auras.md`](compact-frame-auras.md)
for the sibling project this most resembles in spirit and scope.

## TL;DR

- Nameplate auras are a **third, separate aura architecture** from everything else in this
  addon (`NamePlateAurasMixin` / `NamePlateAuraItemMixin`, `Blizzard_NamePlateAuras.lua`) —
  not the forbidden private-aura renderer compact/arena frames use, not target/focus/party's
  own containers either. Confirmed identical between retail 12.1 and WoW Forever 1.60.1.
- First attempt hooked `NamePlateAuraItemMixin:SetAura` and retinted Blizzard's own pooled
  buttons directly (the technique that worked for party/arena). **This is the wrong
  architecture for nameplates** — their aura data can be genuinely secret-wrapped, and even
  read-only `tostring()` on a secret-derived field crashes. The right approach is a custom
  `aurakit`-built `AuraContainer` (same idea as target/focus), not touching Blizzard's own
  buttons at all.
- A production-scale implementation is a real undertaking — closer to `compactauras.lua` in
  size than to party/arena — because of a container-creation performance cost at nameplate
  scale (many simultaneous frames, unlike a handful of raid slots). EllesmereUI's nameplate
  module (which does this in production) uses a pool-of-pre-built-containers-with-attach/
  detach architecture specifically because of this.
- Current native icons are already fairly modern-looking and considered "okay for now" —
  this was descoped by user decision, not because it's unsolvable.

## What was tried and reverted

`core/nameplates.lua` briefly had:
- `SafeIsBuff`/`IsSecretValue` guards, an `EnsureNameplateAuraBorder` helper, and
  `StyleAuraItem`/`RefreshAuraStyle` functions styling `button.Icon`/a custom border directly.
- A `hooksecurefunc(NamePlateAuraItemMixin, "SetAura", ...)` hook, deferred via
  `C_Timer.After(0, ...)` per this file's established taint-avoidance convention (see the
  file's own top-of-file comment and the `NAME_PLATE_UNIT_ADDED` handler for why deferral is
  mandatory here — writing to nameplate frames synchronously inside Blizzard's own
  `OnNamePlateAdded -> SetUnit` chain has already caused real "execution tainted by 'Uber UI'"
  errors in this addon, documented at the top of this file and in
  `session-notes-2026-09-25.md`).
- A `/uuidebugnpauras` diagnostic command in `core/uuidebug.lua`.

All of this was removed. `aurastyle_nameplatebuffs`/`aurastyle_nameplatedebuffs` config
defaults and the options.lua dropdowns were also removed — nothing references those keys
anymore.

### Two real bugs found and fixed along the way (useful regardless of the architecture)

1. **Round-icon assumption was wrong.** The template masks the icon via
   `UI-HUD-CoolDownManager-Mask` and draws a decorative ring via
   `UI-HUD-CoolDownManager-IconOverlay` (no `parentKey`, unreachable from Lua). Both
   assumptions (round shape, ring visible) turned out to be wrong in practice. This file's
   OWN opening comment already documented that a same-family `UI-HUD-CoolDownManager-*` atlas
   was pixel-dumped and found "almost entirely alpha=0, not a usable shape" when tried for
   the health bar mask — the exact same unreliability bit the aura border. **Lesson: don't
   trust this atlas family's names/shapes without visual confirmation; use the same proven
   square-crop asset (`Interface\Buttons\UI-Debuff-Overlays`) everything else in this addon
   already uses successfully.**
2. **`general:ApplyAuraIconInset` was extracted as a shared helper** in
   `core/generalfunctions.lua` (previously duplicated locally in `core/arenaframes.lua`) —
   the standard "icon insets 1px when zoom or a border is active" convention used by every
   other aura style implementation (target/focus/party/arena). This is still in place and
   used by arena; keep it if nameplate work resumes.

## The secret-value finding (the actual blocker)

Debug tooling (`BuildNameplateAuraReport` in `core/uuidebug.lua`) crashed with:

```
invalid value (secret) at index N in table for 'concat'
```

from `tostring(button.isBuff)` — `button.isBuff` is Blizzard's own field, copied verbatim from
`aura.isHelpful` inside `NamePlateAuraItemMixin:SetAura`. Confirmed via Blizzard's own
generated documentation, `Blizzard_APIDocumentationGenerated/SecretPredicatesDocumentation.lua`,
predicate `SecretWhenAurasRestricted`:

> "Guarded APIs and events produce secret values when combat, encounter, challenge mode, or
> PvP match addon restrictions are in effect."

**This is not nameplate-specific.** It's a game-state predicate (combat/encounter/challenge/
PvP), not a unit-token predicate — target/focus/party/compact aura data is equally subject to
it. Those frame types never hit this because `aurakit.BuildAuraContainer` /
`BuildGroupedAuraContainer` never read `aura.isHelpful` in our own Lua and branch on it — they
hand a filter string to the engine's own `AddAuraGroup`/`SetAuraProcessingPolicy`, which
classifies buffs vs. debuffs entirely inside trusted engine code, and only reveal to us which
bucket a button landed in (implicit classification via group membership, never an exposed
boolean). **That's the actual lesson: any custom aura UI needs to let the engine classify
buff/debuff via `AddAuraGroup` candidate filters, never by reading and branching on aura
fields directly in addon code — full stop, not just for nameplates.**

(Side note: the *production* styling code, `StyleAuraItem`, already had this guarded via
`SafeIsBuff`/`IsSecretValue` and would not have crashed — only the debug script's raw
`tostring()` did. So the secrecy finding explains why the architecture is wrong long-term,
but doesn't by itself explain the separate "styling wasn't visibly applying at all" symptom
reported earlier — that remains unexplained, and moot now that the whole approach is shelved.)

## The correct architecture, when this gets picked back up

### 1. Suppress native display — bitfield CVars, not simple booleans

Unlike `raidFramesDisplayBuffs` (compactauras.lua's party/raid CVars, plain 0/1), nameplate
aura visibility per category is **bitfield-encoded**:

| CVar (`NamePlateConstants`) | String | Bits (`Enum.NamePlate*AuraDisplay`) |
|---|---|---|
| `ENEMY_NPC_AURA_DISPLAY_CVAR` | `nameplateEnemyNpcAuraDisplay` | Buffs=1, Debuffs=2, CrowdControl=3 |
| `ENEMY_PLAYER_AURA_DISPLAY_CVAR` | `nameplateEnemyPlayerAuraDisplay` | Buffs=1, Debuffs=2, LossOfControl=3 |
| `FRIENDLY_PLAYER_AURA_DISPLAY_CVAR` | `nameplateFriendlyPlayerAuraDisplay` | Buffs=1, Debuffs=2, LossOfControl=3 |
| `SHOW_DEBUFFS_ON_FRIENDLY_CVAR` | `nameplateShowDebuffsOnFriendly` | plain boolean |

Read/write pattern is Blizzard's own official one — used by the real Interface Options →
Names panel (`Blizzard_SettingsDefinitions_Frame/Nameplates.lua`):
`CVarCallbackRegistry:SetCVarBitfieldMask(cvarName, mask)` to write,
`Settings.GetCVarMask(cvarName, Enum.NamePlate*AuraDisplay)` to read. Same trust level as
`raidFramesDisplayBuffs` — fully addon-writable, not secure/protected. **v1 scope: only clear
the Buffs/Debuffs bits we're replacing; leave CrowdControl/LossOfControl bits alone (native,
untouched)** — CC classification doesn't map cleanly onto available engine candidate filters
(see below), and touching fewer things is less to get wrong.

### 2. Custom container, one per nameplate (not singular like target/focus)

`aurakit.BuildAuraContainer`/`BuildGroupedAuraContainer` should work unmodified against
`"nameplateN"` unit tokens — same engine primitives, no special-casing expected. But
nameplates are a **pool of many simultaneous frames**, reused constantly, unlike target/focus
(one persistent global frame each). Container lifecycle needs to follow the nameplate's own
lifecycle: created/attached on `NAME_PLATE_UNIT_ADDED`, released on `NAME_PLATE_UNIT_REMOVED`
— both already-hooked events in `core/nameplates.lua`.

### 3. Why not create-on-demand per plate: performance, not (just) legality

EllesmereUI's nameplate module (`EllesmereUI/EllesmereUINameplates/EUI_Nameplates_AuraContainers.lua`,
~1861 lines — read in full during this research pass) solves exactly this problem in
production. Their approach and the reasons behind it:

- **Pool of pre-built "bundles"** (a holder frame + up to 3 `AuraContainer`s: debuffs/buffs/cc),
  built incrementally at login through a job scheduler (`AK.QueueBuildJob`), not all at once.
  Plates *attach* (reparent + `SetUnit`) an idle bundle from the pool and *detach* (release
  back to the pool) rather than the addon creating/destroying containers per plate.
- Repeated comments reference build **68914** as when `AddAuraGroup`/container creation
  became combat-legal at all. We target 12.1.0 build ~69875 (past that), so on-demand
  creation is technically legal for us today — but the performance reason below stands
  regardless of legality.
- **Measured performance cost**, their own comment: *"a full synchronous build is ~1200 aura
  buttons (40 bundles × 3 containers × 10-button batches) and measurably extends the loading
  screen; even a bundle-per-frame trickle spiked frames."* This is the same 10-button-per-
  `AddAuraGroup` front-load `compact-frame-auras.md` already documented, just at nameplate
  scale (potentially 10-40 simultaneous plates) instead of a handful of raid-frame slots —
  empirically confirmed to matter, not theoretical.
- **`SetUnit`/`UpdateAllAuras` are synchronous engine parses**, not free — they gate rebinding
  behind an idempotency flag (`_npcBoundUnit`) so a plate keeping the same unit doesn't
  re-parse for nothing; detach clears the flag so the next attach re-binds fresh.
- **One gotcha for later, not relevant to our v1:** once `AddAuraGroup` runs on a container it
  gets a permanent "aspect" (`UntrustedLayoutScriptExecution`) that can't be granted
  retroactively — anything meant to anchor to it (they do this for target-priority arrows)
  must be born with that aspect from creation, or reparenting hard-errors in the field. Only
  matters if we ever anchor extra custom decorations to the container; doesn't block a plain
  buffs+debuffs container.
- Pool sizing is **content-aware**: a smaller baseline pool grows further on
  `PLAYER_ENTERING_WORLD` when `IsInInstance()` reports party/raid.

### 4. Proposed v1 scope (smaller than Ellesmere's, which also handles CC rows, buff-splitting
by dispel type, 5 configurable slot positions, class-power push — years of scope we don't need)

- Bundle = **2 containers** (debuffs + buffs only), not 3.
- Modest pool built incrementally at `PLAYER_LOGIN` (simple `C_Timer.After` spacing is
  probably enough at our smaller scale — no general job-queue scheduler exists in
  `aurakit.lua` today, and shouldn't be built unless testing shows it's actually needed),
  sized for typical open-world visibility (~10-15), grown further entering a party/raid
  instance.
- Attach on `NAME_PLATE_UNIT_ADDED`, detach on `NAME_PLATE_UNIT_REMOVED`, pulling from the
  pool; queue-and-wait if the pool is empty (mirrors Ellesmere's `waiting` table).
- Suppress only the Buffs/Debuffs bitfield bits per nameplate category (see table above);
  leave CrowdControl/LossOfControl native.

## Reference

- Blizzard source (this addon's usual mirror): `Blizzard_NamePlates/Blizzard_NamePlateAuras.lua`
  + `.xml` (the mixins/templates), `Blizzard_NamePlateConstants.lua` (CVar name strings),
  `Blizzard_SettingsDefinitions_Frame/Nameplates.lua` (Blizzard's own settings-panel
  read/write pattern for the bitfield CVars — copy this, don't reinvent it),
  `Blizzard_APIDocumentationGenerated/SecretPredicatesDocumentation.lua` (the general secrecy
  rulebook — worth rereading for any future secret-value mystery, not just this one).
- EllesmereUI reference (local clone, `D:\github\EllesmereUI` per this addon's usual
  citation style / `~/code/lua/EllesmereUI` on this machine):
  `EllesmereUINameplates/EUI_Nameplates_AuraContainers.lua`.

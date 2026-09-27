# Nameplate aura styling

Status: **implemented 2026-09-27** as `core/nameplateauras.lua` (off by default: "Uber UI
Nameplate Auras" on the Nameplates options page; aura style options use the `nameplate`
location). Not yet verified in game. See "Implementation" at the end for what was built and
where it differs from Blizzard. Everything above that section is the research that led to it
(first attempt, secret-value finding, pool cost tests), kept for reference. See
[`compact-frame-auras.md`](compact-frame-auras.md) for the sibling project this most
resembles in spirit and scope.

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

## Pool test results (2026-09-27, `/uuidebugnppool`)

A test harness now exists: `/uuidebugnppool` in `core/uuidebug.lua` (usage in its header).
It builds "bundles" of 4 `CustomAuraContainer`s per nameplate using **Blizzard's own nameplate
rules** (`Blizzard_NamePlateAuras.lua`, 12.1), without touching the CVars or Blizzard's plates:

| Container | Groups (filter / candidate filters) | Max | Buttons up front |
|---|---|---|---|
| debuffs | `HARMFUL\|INCLUDE_NAME_PLATE_ONLY\|!CROWD_CONTROL\|PLAYER`, `nameplateShowPersonal` (unless the show-all-personal CVar), `nameplateShowAll = false` | 12 | 10 |
| buffs | `...\|IMPORTANT`; `...\|!IMPORTANT` + `isStealable` (Blizzard: enemy buffs only if stealable or important) | 2 | 20 |
| cc | `HARMFUL\|CROWD_CONTROL`; `HARMFUL\|!CROWD_CONTROL` + `nameplateShowAll` (Blizzard's `IsAuraCrowdControl`) | 2 | 20 |
| bigdebuff | 1 slot, `HARMFUL\|CROWD_CONTROL` -- stand-in: Blizzard's loss-of-control icon reads `C_LossOfControl`, which containers can't | 1 | 1 |

Per plate at attach: enemy debuffs require `PLAYER`, friendly buffs require `PLAYER` (Blizzard's
`requireSourceIsLocalPlayer`), and each category is shown/hidden from Blizzard's per-unit-type
bitfield CVars. "OR" rules cost a whole extra group each (10 buttons).

**Build cost, 40 bundles (2,040 buttons), inside `PLAYER_LOGIN` = loading-screen time:**

| Button setup | Retail 12.1 | Forever 1.60.1 | Memory / bundle (retail, after GC) |
|---|---|---|---|
| lean (icon + count only) | 153 ms (3.8 ms/bundle) | -- | 8 KB |
| full (`aurakit.InitAuraButton`) | 235 ms (5.9) | 518 ms (12.9) | 13 KB |
| styled (full + `ApplyAuraButtonStyle`) | 470-482 ms (11.8-12.0, slowest ~24) | -- | 37 KB |
| lazy (full; styling deferred) | 246 ms (6.1) | -- | 14 KB |

- The engine floor is ~3.8 ms/bundle (its 10-button batches); aurakit's button setup adds ~2 ms;
  **styling every button at build doubles the cost** -- it styles/creates border frames for
  buttons that will mostly never be used. Forever is ~2x slower than retail on the same build.
- Building one bundle mid-game costs 6-24 ms (a dropped frame or two), so bundles must be
  **prebuilt** (loading screen, or trickled when idle), never built on `NAME_PLATE_UNIT_ADDED`.
- **Attach is cheap: ~0.1-0.2 ms per plate** (per-unit filters + `SetUnit` parse), and works
  **in combat** (SetUnit, SetShown, anchoring all fine mid-fight).

**Verified visually (`attach show`, retail, in combat):** containers attach to every visible
plate, follow it, and show the correct auras with our styling (dotted enemies' debuffs appeared
in our debuff row as well as Blizzard's).

**Hard facts learned:**
- **Button visibility is unreadable to addons** -- every container button's `IsShown` comes back
  secret/refused, even out of combat (anti-fingerprinting). "Did the filter match?" can't be
  checked in code; only visually. `GetAuraGroupFrameCount` returns *allocated* frames (10/group),
  not active auras.
- **Anchoring to a nameplate requires `DisableUntrustedLayoutScriptsTemplate` at creation.** A
  plain frame anchored to a 12.1 nameplate hard-errors: "Anchoring disallowed as dependent object
  would inherit forbidden aspects: UntrustedLayoutScriptExecution". Same for anything anchored to
  a container after `AddAuraGroup`. Give every holder/decoration that template when it's created.
- "Style a button when it first shows an aura" isn't possible: the engine initializes buttons in
  batches of 10 and hides which are in use.
- **Hooks on a container's `UpdateAllAuras` / `UpdateAuraGroup` / `ApplyLayout` only fire when
  OUR code calls those methods.** The engine's own updates (e.g. the parse after `SetUnit`, or a
  `UNIT_AURA`) run on the container's private side and never reach the hooked public object --
  the `lazy` variant's first-attach styling never ran (0 buttons styled across 3 attaches).
  Target/Focus are unaffected only because their own update code calls `UpdateAllAuras`
  itself. Don't rely on these hooks to react to engine-driven aura changes.
- So styling can't be deferred to "first use" for free: it's a fixed ~6 ms per bundle (styled
  minus full). Doing it at first attach would hitch exactly when a pack's plates appear
  (8 plates ~ 50 ms).

- **A `/reload` in combat does not put `PLAYER_LOGIN` code in combat lockdown.** Tested
  2026-09-27: reloaded mid-fight (report header `in combat: true` two seconds after load), the
  25-bundle styled build ran with `InCombatLockdown()` false and no group/slot refused. So the
  pool can always be built at load; no combat fallback path is needed.

- **Live lifecycle verified** (`/uuidebugnppool live on`, retail, open world, pool of 40
  styled): 39 attaches / 32 releases / 7 in use at report time (39 - 32 = 7 -- every bundle
  returned and reused), **peak 13 in use**, 0 plates without a bundle. Attach avg 0.14 ms
  (slowest 0.23), release avg 0.10 ms. Attach deferred a frame from `NAME_PLATE_UNIT_ADDED`,
  release immediate on `NAME_PLATE_UNIT_REMOVED`, with a per-token sequence number so a token
  removed and re-added before the deferred attach runs doesn't attach stale.

**Chosen design (user decisions 2026-09-27) -- mimic EllesmereUI's profiled baseline:**

- **Scaling pool, not a big fixed one** (a big pool at load wastes memory -- ~37 KB per styled
  bundle -- when it may never be needed). EllesmereUI (`EUI_Nameplates_AuraContainers.lua`):
  `POOL_SIZE = 16` built at login ("covers 5-man content with margin"); on
  `PLAYER_ENTERING_WORLD` into a `party`/`raid` instance it tops up to
  `POOL_TARGET_INSTANCE = 25` during the zoning screen ("M+ trash pulls are the heaviest
  sustained plate counts in the game"); when the pool is empty an attach queues one more bundle
  per waiting plate -- **even in combat** -- and the plate is serviced when it builds. The pool
  never shrinks (engine frames are never freed). Use the same numbers as a starting point.
  Cost for us: ~12 ms per styled bundle, so an on-demand growth is a one-off hitch on the first
  oversized pull of a session, never a missing-auras state.
- Build styled, attach on `NAME_PLATE_UNIT_ADDED` (~0.1 ms/plate, deferred a frame), release on
  `NAME_PLATE_UNIT_REMOVED`; restyle only when aura settings change. Every holder/decoration
  created with `DisableUntrustedLayoutScriptsTemplate`. The setting's tooltip should say it
  "may slightly increase loading screen times".
- **Keep Blizzard's two either/or rules as two groups each** (EllesmereUI does): enemy buffs =
  important OR stealable, CC row = crowd control OR "show to all". **But don't use an
  `isStealable` candidate filter** -- EllesmereUI found enemy aura data is secret in instanced
  PvP, where that compare fails for every buff and the group shows nothing. Use the engine's
  `DISPELLABLE` filter token instead (evaluated in C, works under restriction): one group
  `HELPFUL|INCLUDE_NAME_PLATE_ONLY|DISPELLABLE`, one `...|IMPORTANT|!DISPELLABLE`.
  (`DISPELLABLE` is class-independent and slightly broader than stealable -- includes enrages.)
  The test harness still uses `isStealable`; fix it there too if it's reused.

## Implementation (2026-09-27)

`core/nameplateauras.lua`, following the chosen design above:

- **Pool:** 16 bundles at `PLAYER_LOGIN`, topped up to 25 on `PLAYER_ENTERING_WORLD` into a
  party/raid instance, one more built synchronously when an attach finds the pool empty. Built
  only while the option is on (turning it on live builds the pool then and there). Never
  shrinks. After a login/reload every bundle is restyled once, one bundle per frame: the
  pool is built behind the loading screen, where aura data is secret and the engine refuses
  aurakit's dispel-border registrations; the style pass retries them.
- **Bundle:** holder (`DisableUntrustedLayoutScriptsTemplate`) + 3 containers. Blizzard's
  loss-of-control icon (players) stays native -- it reads `C_LossOfControl`.
  - debuffs: `HARMFUL|INCLUDE_NAME_PLATE_ONLY|!CROWD_CONTROL[|PLAYER]`, candidates
    `nameplateShowAll = false`, `nameplateShowPersonal` (dropped when the show-all-personal CVar
    is on, via `SetAuraGroupCandidateFilters`), max 12.
  - buffs: `...|IMPORTANT` + `...|!IMPORTANT|DISPELLABLE` (falls back to an `isStealable`
    candidate filter if a client ever refuses the token); friends: one group
    `HELPFUL|INCLUDE_NAME_PLATE_ONLY|PLAYER`. Max 2 per group.
  - cc: `HARMFUL|INCLUDE_NAME_PLATE_ONLY|CROWD_CONTROL` + `...|!CROWD_CONTROL` with
    `nameplateShowAll = true`. Max 2 per group.
- **Placement:** holder parented to the plate's `AurasFrame` (so Blizzard's show/hide for
  simplified / name-only / widgets-only plates, the plate fade and scale all apply); each
  container anchored to the matching Blizzard list frame (debuffs BOTTOMLEFT, buffs RIGHT,
  cc LEFT) and scaled by `AurasFrame.auraItemScale`; debuff rows use Blizzard's own
  `DebuffListFrame.stride`. 22px icons + 3px spacing = Blizzard's 25px pitch.
- **Blizzard's icons:** the three list frames get `SetAlpha(0)` while a bundle is attached,
  restored (deferred, and only if no new bundle took the plate) on release.
- **Categories per unit:** read from the same CVars as Blizzard's `Update*AuraFrames`.
- **Re-evaluation:** per-instance `hooksecurefunc` on each plate's `AurasFrame`
  `UpdateShownState` (unit, friend/enemy, player, simplified, every display CVar) and
  `UpdateAuraScale`, installed the first time a bundle attaches to that frame, deferred and
  coalesced.
- **Lifecycle:** attach deferred a frame from `NAME_PLATE_UNIT_ADDED` with a per-token
  sequence number; release immediate on `NAME_PLATE_UNIT_REMOVED` (our frames only).

- **Pandemic highlight** (debuffs, on by default): a per-button host frame handed to
  `CustomAuraButton:AddPandemicRegion` (retail and Forever). The engine shows it only inside the
  real pandemic window (`expiration - (GetRefreshExtendedDuration - GetAuraBaseDuration)` to
  expiration), so only refreshable auras light up, and it works while aura data is secret. Its
  Shown is secret-aspected -- we only style its children: the border in the chosen shape
  (rounded = color masked by the ring atlas; square = SB strips at dispel thickness) or a looping
  FlipBook glow (`UI-HUD-ActionBar-Proc-Loop-Flipbook` / `RotationHelper_Ants_Flipbook`, 6x5,
  30 frames, padding from EllesmereUI_Glows.lua). EllesmereUI never found this API (their notes
  call nameplate pandemic impossible).

Known differences from Blizzard:
- Buffs and CC are two groups of max 2 each, so up to 4 can show where Blizzard caps the list
  at 2.
- The engine's `PLAYER` token includes pet/vehicle auras. Forever's Blizzard lists do too;
  retail's only take the player's own.
- Enemy buffs use `DISPELLABLE` (includes enrages) instead of `isStealable`.
- Duration text: engine-bound (`SetDurationText`), whole seconds rounded up in the Cooldown's
  countdown font. One color curve on REMAINING duration (the binding takes one curve): expiring
  color below the threshold (1-10 s option), normal color to 60 s, transparent above -- so a long
  aura shows its number in its last minute, where Blizzard hides numbers on any aura over 60 s total.
  Colors come from Blizzard's settings color swatch (`opt.AddColorSwatch`, hex strings); a change
  re-registers each button's text (the curve is copied at registration).
- Pandemic is the engine's real refresh window, like the Cooldown Manager: auras with no
  carry-over (e.g. Flame Shock on Forever, a flat 12 s) never light up.
- Purgeable-buff highlight is a thin white border (aurakit `stealableRing`, also used by Target):
  rounded = a white texture masked by the rounded border atlas, engine-gated to stealable
  buffs; square = square borders' white strips. Blizzard's round stealable glow reaches past the
  icon onto the health bar. Buffs and CC sit `SIDE_GAP` (3px) further out from the health bar
  than Blizzard's lists for the same reason (our borders are outside the icon).
- Blizzard's faded icons keep their mouse area, so a tooltip may come from the Blizzard icon
  underneath ours (same aura in practice).

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

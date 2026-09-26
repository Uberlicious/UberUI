# UberUI — agent notes

WoW addon that darkens/restyles Blizzard's default UI. One package supports
both retail (`WOW_PROJECT_MAINLINE`) and "WoW Forever" (internal Camelot
build, interface 10600) — check both when touching shared frames, since APIs
sometimes differ between them (e.g. retail 12.1 lacks some Forever-only
delegates like `UnitFrameUtil.UpdateUnitPvPIndicator`).

## Hard rules

**Never call Blizzard's own frame-update functions directly** from this
addon's insecure code — no `CompactUnitFrame_SetUnit(...)`,
`TargetFrame:Update()`, `SomeFrame:Setup()`-as-a-forced-refresh, etc. Only
`hooksecurefunc`/`HookScript` (react *after* Blizzard's own call) is safe.
Defer nameplate/frame writes made from a hook via `C_Timer.After(0, ...)` to
fully detach from Blizzard's synchronous update chain. Violating this has
caused real taint crashes in production (e.g. calling
`CompactUnitFrame_SetUnit` from a test tool crashed inside Blizzard's own
`UnitInRange()` on an Arena-classified frame).

**Don't install `hooksecurefunc`/`HookScript` unconditionally for optional,
user-toggleable features.** A hook can never be removed once installed, so
gate the *installation* on the setting being enabled — check once, and if
it's off, don't call `hooksecurefunc` at all. Wire an idempotent
`EnsureXHook()` that gets (re-)called from wherever the feature's own
reactive code already runs safely (an event handler, or the function the
options\ page checkbox/dropdown's `onChange` already calls) so enabling the
setting later, live, without a reload, still installs the hook.
`core/nameplates.lua`'s `MaybeRegisterRaidTargetScaleHooks` is the reference
implementation of this pattern. Core/always-on baseline behavior (frame
darkening, health-bar coloring) doesn't need this — only gate hooks that
back something with its own on/off toggle.

**Gotcha:** don't check `uuidb.general.someSetting` at file-load top level
(bare code outside any event handler/function body) to decide whether to
install a hook. `uuidb` is still `config.lua`'s empty placeholder table at
that point — this addon's own `ADDON_LOADED`/`PLAYER_LOGIN` handler, which
swaps in the real SavedVariables table and populates `uuidb.general`, hasn't
run yet. This has caused a real crash
(`attempt to index field 'general' (a nil value)`). Always defer the check
into a function called from an event handler or the feature's own
already-safe entry point.

## Repo quirks

- **`.gitignore` excludes all `*.md` files** except `README.md` and
  `changelog.txt`. Any new doc under `docs/` needs `git add -f <path>`
  explicitly, and don't trust `git status`/`git add -A` alone to have picked
  it up — verify with `git status --porcelain` afterward. This has already
  caused a doc to go silently uncommitted across two checkpoints.
- Versioning is decoupled from the WoW patch number (see `changelog.txt`'s
  `1.0.0` entry) — check the `.toc`'s `## Interface:` line for actual client
  compatibility instead. Git tags keep `-Alpha`/`-Beta`/`-Release` suffixes
  for the CurseForge release hook.

## Reference repos (local clones, not part of this repo)

- `/Users/uber/code/lua/wow-ui-source` — mirror of Blizzard's actual UI
  source, `origin/live` (retail) and `origin/forever` (WoW Forever) branches.
  Check this before hooking/assuming the behavior of any Blizzard
  function/mixin/global, especially anything that might differ between
  clients — don't guess from memory or retail-only API docs.
- `/Users/uber/code/lua/EllesmereUI` — a separate, mature addon (the user
  also contributes to it) that builds its own custom nameplates from
  scratch. Useful as *design* reference for problems this addon also faces
  (nameplate auras, arena nameplate numbering), but its code is never a
  literal port — UberUI skins Blizzard's native frames via hooks instead of
  building its own.

## Further research docs

`docs/` has deeper write-ups worth reading before touching related code:
`square-borders.md` (planned pixel-depth aura border feature + open bug
report on Cooldown Manager border coloring), `nameplate-auras.md` (why
nameplate aura styling was shelved, and the architecture to use if resumed),
`compact-frame-auras.md`, `aura-caster-classification-bug.md`.

# Source Flavor Decoupling Design

## Context

The repository currently mixes three separate concerns:

1. Firmware feature selection such as `FW3` and `FW4`
2. Upstream source selection such as `coolsnowwolf/lede` and `VIKINGYFY/immortalwrt`
3. Source-specific filesystem mutations inside shared scripts

This shows up most clearly in `Scripts/diy_config.sh` and `Scripts/Packages.sh`, where `lean` is inferred from repository layout such as `package/lean/default-settings/files/zzz-default-settings`, then used to gate both common and source-specific behavior. The workflow layer already has explicit source inputs, but the shell layer still falls back to local directory heuristics, so the same concept is represented inconsistently.

The goal of this change is to decouple source selection from firmware feature selection and make `VIKINGYFY` a first-class source flavor without breaking the current entrypoints.

## Goals

- Use explicit source input from `WRT_REPO_URL` as the single source of truth for source selection
- Introduce stable source flavor values: `lean`, `VIKINGYFY`, `generic`
- Keep existing script entrypoints and workflow wiring broadly intact
- Separate common OpenWrt behavior from source-specific mutations
- Preserve current `FW3` and `FW4` config-layer behavior
- Add tests around source flavor resolution and the new script boundaries

## Non-Goals

- Rework all package replacement logic in one pass
- Generalize all ImmortalWrt forks into one shared flavor
- Change the meaning of existing `FW3` and `FW4` config files
- Remove current workflow support for manual source override

## Source Selection Model

Source flavor is resolved only from explicit upstream metadata, not from repository layout.

Resolution rules:

- `lean`: `WRT_REPO_URL` matches `coolsnowwolf/lede`
- `VIKINGYFY`: `WRT_REPO_URL` matches `VIKINGYFY/immortalwrt`
- `generic`: any other non-lean source

This resolution should be available to scripts through a small shared helper so the workflow layer and shell layer do not drift.

## Diy Config Design

`Scripts/diy_config.sh` remains the entrypoint, but its behavior is organized into flavor layers:

- `common`: source-agnostic behavior
- `lean`: only logic that depends on `lean`-specific paths or file layouts
- `VIKINGYFY`: source-specific deltas for `VIKINGYFY/immortalwrt`
- `generic`: non-lean fallback behavior for other sources

### Common Layer

The common layer owns behavior that should not care about upstream layout, including:

- default LAN IP and hostname changes
- theme selection
- `ipk` vs `apk` package manager toggles
- LuCI menu adjustments that use common feed paths
- OpenVPN defaults
- `.config` option maintenance
- other feed or package toggles that are not tied to `lean`-only paths

### Lean Layer

The lean layer owns only behavior that depends on `lean`-specific filesystem layout, including:

- `package/lean/default-settings/files/zzz-default-settings`
- `package/lean/autocore/...`
- `package/base-files/luci2/bin/config_generate`
- any runtime injection that only exists because lean ships those paths

### VIKINGYFY Layer

The `VIKINGYFY` layer is introduced now even if it starts nearly empty. It exists to hold source-specific behavior only when that behavior is confirmed to be required for `VIKINGYFY/immortalwrt` and not appropriate for `common`.

This avoids repeating the current pattern where one large `non-lean` branch silently accumulates unrelated assumptions.

### Generic Layer

The generic layer is the fallback for any non-lean source that is not `VIKINGYFY`. It should use the existing non-lean runtime defaults approach such as `uci-defaults/99-lin-defaults`, but it must not contain behavior that is actually specific to `VIKINGYFY`.

## Packages Design

`Scripts/Packages.sh` remains the entrypoint and keeps its generic package management helpers, but the source-specific package replacement list is split by flavor.

### Shared Helpers

Shared helpers remain responsible for:

- deleting existing package directories
- cloning package repositories
- extracting a subpackage from a monorepo
- safe replacement and rollback
- version update utilities

### Flavor-Specific Package Lists

Flavor-specific sections own only the package overrides that are required for that source flavor:

- `lean`: package overrides confirmed to be needed for `coolsnowwolf/lede`
- `VIKINGYFY`: package overrides confirmed to be needed for `VIKINGYFY/immortalwrt`
- `generic`: minimal fallback behavior for other sources

The current `is_code_lean` heuristic based on local directory presence is removed. `Packages.sh` should receive or derive `source_flavor` from explicit upstream metadata instead.

## Workflow Design

Workflow behavior is split into two independent axes:

- config layer: `FW3`, `FW4`, overlays, general config resolution
- source layer: resolved from `WRT_REPO_URL`

Required workflow changes:

- replace the current boolean `WRT_IS_LEAN` decision logic with `SOURCE_FLAVOR` resolution
- keep `FW3` and `FW4` auto-selection logic for general configs
- stop implying that `FW3` or `FW4` determines which upstream repository is used
- pass explicit source flavor metadata down into shell scripts

`WRT_IS_LEAN` may be retained only as a compatibility variable during migration, but `SOURCE_FLAVOR` becomes the authoritative value.

## Testing Plan

Minimum test coverage for this refactor:

1. Add a small source flavor resolution test that verifies:
   - `coolsnowwolf/lede` -> `lean`
   - `VIKINGYFY/immortalwrt` -> `VIKINGYFY`
   - another repository -> `generic`
2. Update `Scripts/test_diy_config_structure.sh` so it asserts the new flavor boundary functions exist.
3. Keep current package manager tests for `apk` and `ipk` untouched.
4. Add at least one lightweight `Packages.sh` flavor-resolution test if the package override execution remains too broad to test immediately.

## Migration Plan

1. Add a shared source flavor resolver helper.
2. Refactor `diy_config.sh` to use explicit source flavor input.
3. Move existing `lean`-only path mutations out of common flow.
4. Move current non-lean fallback logic into `generic`.
5. Introduce an empty or near-empty `VIKINGYFY` layer.
6. Refactor `Packages.sh` to use the same source flavor helper.
7. Update workflows to emit and pass `SOURCE_FLAVOR`.
8. Adjust README wording so source selection is described via `WRT_REPO_URL`, not `FW3` or `FW4`.
9. Run shell tests covering structure and source flavor resolution.

## Risks And Controls

- Risk: common logic may still accidentally reference lean-only paths.
  Control: isolate path-sensitive mutations into flavor functions and test for their presence.

- Risk: workflow and shell logic may diverge during migration.
  Control: resolve source flavor with one shared rule set and pass it explicitly.

- Risk: existing non-lean behavior may change unintentionally.
  Control: move current non-lean fallback into `generic` first, then add `VIKINGYFY` deltas incrementally.

## Expected Outcome

After this refactor, `FW3` and `FW4` continue to describe feature/config combinations, while source behavior is controlled explicitly by `WRT_REPO_URL` through `source_flavor=lean|VIKINGYFY|generic`.

This creates a stable path for supporting `VIKINGYFY/immortalwrt` without keeping `lean` assumptions embedded in shared code paths.

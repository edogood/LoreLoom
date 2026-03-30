# LoreLoom architecture note (current checkout)

## What is preserved
- The monorepo root configuration is preserved (`workspaces`, root scripts, shared TypeScript base config).
- Local-first intent remains preserved (SQLite + Prisma, local media directory, PowerShell launcher strategy) as documented in `README.md`.
- Existing launcher and setup documentation are preserved, with one safety guard added.

## What is removed or cleaned up
- No functional app modules were removed in this change, because this checkout only includes root-level scaffolding files.
- Log/runtime artifacts are now ignored to avoid noisy commits (`dev-server.out.log`, `dev-server.err.log`, `dev-server.pid`).

## What is added
- Root scripts now fail-safe when workspace folders are absent in the checkout, instead of hard-failing with npm workspace errors.
- Launcher now performs an early, explicit workspace existence check and returns a clear error message.

## Why these changes first
- In this repository state, `apps/web` and `packages/*` source code are not present, so large UX refactors cannot be applied safely.
- The highest-impact minimal fix is to make the local workflow robust and transparent in this incomplete checkout:
  - commands are deterministic,
  - errors are actionable,
  - CI/setup does not fail with misleading workspace errors.

## Refactor path once full source is available
1. Establish a persistent workspace shell (left rail + top command + center canvas + right inspector).
2. Keep route internals but unify UX as a single preserved-layout application surface.
3. Consolidate shared domain model in `packages/domain` and consume it across graph/map/wiki/timeline/media.
4. Integrate graph/map/timeline selection state through one inspector model.
5. Add command palette + global search + keyboard shortcuts against unified entities.

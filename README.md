# Loreloom Studio

Local-first worldbuilding workspace built with Next.js 15, TypeScript, Tailwind CSS, shadcn-style UI primitives, Prisma, SQLite, Zustand, TanStack Query, React Flow, Tiptap, Konva, d3, and zod.

## What ships in this V1

- Multi-module workspace shell with dashboard, world overview, entities, graph, world maps, city maps, wiki, media, and settings routes
- Prisma-backed local data model for worlds, entities, relations, graph views, maps, wiki pages, media, and tags
- Interactive graph studio with persisted node/edge state via React Flow
- Deterministic world and city procedural generators with editable semantic layers
- Tiptap-based entity and wiki content editing
- Local file-backed media uploads with metadata persisted in SQLite
- JSON import/export routes for whole-world bundles and client-side PNG/JSON export for maps
- Seeded demo world: `Aurelian Reach`

## Folder shape

```text
apps/web/src/
  app/
  components/
    entities/
    graph/
    maps/
    media/
    shell/
    ui/
    wiki/
  features/
    maps/
    shell/
  hooks/
  lib/
    validation/
  server/
    procedural/
    repositories/
    services/
  types/

packages/db/
  prisma/
  src/

packages/domain/
  src/
```

## Local setup

1. Install dependencies:

```bash
npm install
```

2. Bootstrap the SQLite file.

Prisma client generation works normally:

```bash
npm run db:generate
```

The SQLite schema is already represented in `packages/db/prisma/schema.prisma`.

In this current Windows/OneDrive environment Prisma's schema engine was unstable for `db push` / `migrate dev`, so the checked-in local bootstrap uses:

- `data/loreloom.db` as the SQLite database file
- `packages/db/prisma/seed.ts` for demo data

If Prisma `db:migrate` works cleanly in your environment, use:

```bash
npm run db:migrate
```

If not, keep the existing `data/loreloom.db` or recreate the schema file locally and then run the seed:

```bash
npm run db:seed
```

3. Start the app locally.

Stable local mode is the default and is recommended in this Windows/OneDrive workspace because it uses `build + next start` instead of the more fragile dev watcher:

```bash
npm run start:local
```

You can still run pure development mode explicitly:

```bash
npm run start:dev
```

Or use the Windows launcher directly:

```powershell
.\start-loreloom.cmd
```

Optional flags:

```powershell
.\start-loreloom.ps1 -Background -OpenBrowser
npm run start:local -- -Background

.\start-loreloom.ps1 -Mode Dev -Background
npm run start:dev -- -Background

.\start-loreloom.ps1 -ForceBuild
```

If you specifically want the raw Next dev watcher:

```bash
npm run dev
npm run start:local -- -Background
```

4. Open:

```text
http://localhost:3000/dashboard
```

## Verification

Validated in this workspace:

- `npm run typecheck`
- `npm run build`
- local SQLite seed contents verified in `data/loreloom.db`

## Useful scripts

```bash
npm run dev
npm run start:local
npm run start:dev
npm run build
npm run typecheck
npm run db:generate
npm run db:migrate
npm run db:push
npm run db:seed
npm run db:reset
```

## Environment

`apps/web/.env.local`

```env
DATABASE_URL="file:C:/Users/BUONOED1/OneDrive - Reti/Documenti/Python/Personale/Loreloom/data/loreloom.db"
LORELOOM_MEDIA_DIR="../../data/media"
```

`packages/db/.env`

```env
DATABASE_URL="file:C:/Users/BUONOED1/OneDrive - Reti/Documenti/Python/Personale/Loreloom/data/loreloom.db"
```

## Local file storage strategy

- Database: `data/loreloom.db`
- Uploaded media binaries: `data/media/<world-slug>/...`
- Media metadata table: `MediaAsset`
- Media file serving route: `/api/media/[assetId]/file`

## Demo seed

The seed creates:

- 1 world
- 12 entities
- 12 entity relations
- 1 graph view
- 1 world map
- 1 city map
- 8 wiki pages
- 1 timeline route backed by event entities and temporal overlays

## Extending the generators

World generator extension points:

- replace the current coarse height-sample field with denser Voronoi or hex tessellation
- add true coastline extraction, erosion, climate bands, and route pathfinding
- promote settlements into a richer semantic settlement table if you want independent CRUD

City generator extension points:

- replace the current warped Voronoi district pass with street-first block generation
- add parcel subdivision, wall topology editing, and landmark placement heuristics
- derive market, temple, dock, and residential districts from economy/faction models instead of seeded labels

## Notes

- The UI is dark-first and intentionally editorial rather than game-like.
- PNG export is client-side from the Konva stages.
- World JSON export is route-based via `/api/worlds/[worldSlug]/export`.
- World JSON import is route-based via `/api/import/world`.
- In this Windows/OneDrive path, `npm run dev` may leave `.next` in an inconsistent state. The launcher defaults to stable local mode to avoid that and reuses the last good production build unless you pass `-ForceBuild`.

# Frontend Stack and Configuration Studio

Phase 3. Independent of the backend — it rarely blocks start-up, so do it last.

## §1. Stack

```jsonc
"@shesha-io/reactjs": "0.46.0",
"react":      "^19.2.4",   "react-dom":          "^19.2.4",
"next":       "^16.3.1",   "antd":               "^6.6.2",
"antd-style": "^4.1.0",    "@ant-design/icons":  "^6.3.2",
"next-navigation-guard": "^0.2.0"
```

```jsonc
"overrides": {
  "@shesha-io/reactjs": "$@shesha-io/reactjs",
  "@antv/component": "2.1.7",              // 2.1.11 has a broken internal export that fatally fails the rollup build
  "next-navigation-guard": { "next": "$next" }
}
```

**Key rule:** regenerating `package-lock.json` drifts transitive versions. Pin anything that breaks via `overrides` rather than hand-editing the lock.

## §2. Next 16

### Turbopack is the default — add `--webpack`

```jsonc
"dev":           "next dev --webpack",
"build":         "next build --webpack",
"build:analyze": "ANALYZE=true next build --webpack"
```

The webpack config comes entirely from `@next/bundle-analyzer`. Without the flag, Next warns once and `build:analyze` **silently stops analysing anything** — it does not fail.

### `publicRuntimeConfig` and `next/config` are removed

Read configuration directly (env vars or a module constant). Strip `publicRuntimeConfig` from `next.config.js` and every `getConfig()` call.

### `tsconfig.json`

```jsonc
"jsx": "react-jsx",              // was "preserve"
"moduleResolution": "bundler",   // was "node"
"include": [..., ".next/dev/types/**/*.ts"]
```

`next-env.d.ts` regenerates itself — commit the result.

## §3. Configuration Studio

Consolidates four standalone admin pages. **Delete** these routes:

```
src/app/settings/entity-configs/configurator/page.tsx
src/app/settings/theme/page.tsx
src/app/shesha/forms-designer/page.tsx
src/app/shesha/settings/page.tsx
```

Add `src/app/configuration-studio/page.tsx` rendering `ConfigurationStudio` via `PageWithLayout`, then two wiring changes:

- **Root layout** — wrap in `NavigationGuardProvider` (from `next-navigation-guard`); the studio requires it.
- **App provider** — the studio must render **outside `MainLayout`**. Add its route to `fullScreenRoutes` / `withoutMainLayout`, and add `AttachmentsEditorProvider`, which 0.46.0 expects.

Reference implementation: PR shesha-io/shesha-framework#4905.

**Watch for** a malformed backend URL fallback such as `"https:localhost:44362"` — missing `//` after the protocol throws `Invalid URL` rather than falling back.

## §4. Package workspaces

Sibling packages under `packages/` need the same reactjs bump plus their own API migration:

- Settings files → `SettingsFormMarkupFactory` with the typed builder
- Form-builder and ajax helpers that were removed from reactjs now need local equivalents under `src/utils/`

**Key rules:**
- The root app and each workspace typecheck independently. Root-clean does not imply workspace-clean.
- `IToolboxComponent` variance and `IConfigurableFormComponent<IStyleValue>` mismatches (e.g. `Border<string|number>` vs `IBorderValue`) are genuine API changes, not oversights — they need per-component work.
- Fix pre-existing typing bugs you uncover, but list them separately: `IUseMutateResponseFixedEndpoint<T>` with the response in the *input* slot should be `<void, T>`.

## §5. Windows gotchas

- Ports **21021** and **44362** may sit in Windows' excluded port range — `netsh int ipv4 show excludedportrange protocol=tcp`. Nothing can bind them; they show as held by PID 4 (System). Use another port rather than hunting a phantom process.
- `dotnet run` leaves `*.Web.Host.exe` alive after its wrapper exits, holding both `bin/` (MSB3021) and the port. Kill strays before rebuilding.
- `MSB3021` in a repo with Visual Studio open is almost always a file lock, not a regression. Retry before investigating.
- npm `file:` specs break on paths containing spaces.

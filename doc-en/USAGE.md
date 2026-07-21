# Usage

## Recommended workflow

1. Load your application and its dependencies into the same Lisp process.
2. Set package scope and project-owned prefixes.
3. Optionally load an architecture policy file.
4. Start Malkuth or run headless analysis.
5. Press `/` or `Ctrl+F` to locate a package.
6. Use filters `2`, `3` and `7` to focus on project code, risk and policy violations.
7. Select a package and press `I` to switch between symbols and dependencies.
8. Press `V` to isolate the direct neighborhood and `F` to favorite important packages.
9. To explain connectivity, mark a source with `M`, select a target and press `N`.
10. Press `B` before a change to capture a baseline.
11. After reloading code or plugins, press `F5`, open `T` and use filter `6` to isolate changes.
12. Export `C` for a package dossier, `U` for a path, `Y` for baseline comparison or `X` for the complete bundle.

## Interface regions

### Overview

Shows package and symbol totals, health score, cycles, isolated packages, warnings, visible nodes and favorites.

### Search

The top search box queries all packages in the current snapshot. Activate it by clicking, `/` or `Ctrl+F`. Results update while typing. Use arrows or `Tab` to navigate and `Enter` to open. `Esc` closes search without closing Malkuth.

### Map

Each node is a package and each edge is a `USE-PACKAGE` relationship. Additional rings communicate state:

- gold: favorite;
- magenta: changed since baseline;
- red: involved in a policy violation;
- pink: part of the active architecture path.

### Inspector

The **Symbols** tab lists owned symbols by category. The **Dependencies** tab separates outgoing (`USES`) and incoming (`USED BY`) relationships and displays local risk for related packages.

### Policies panel

`L` opens the loaded rules and violations. Filter `7` restricts the map to packages involved in violations.

### Path panel

`M` stores the selected package as the source. Select the target and press `N`. Filter `8` isolates the route and `Z` clears it.

### Evolution panel

`T` shows baseline comparison and history trends: health, cycles, warnings, package counts and largest risk increases.

## Refreshing the image

`F5` saves the previous state to history, rebuilds the snapshot, reevaluates policies, recomputes trends, attempts to rebuild an active path by stable package names, preserves the current selection where possible and reports added/removed/changed packages.

## Interactive exports

- `P`: quick `malkuth-live.svg`;
- `X`: full SVG, JSON, DOT, Markdown, manifest, CSV, policy and trend bundle;
- `Y`: baseline comparison in Markdown and JSON;
- `C`: selected-package Markdown and DOT dossier;
- `U`: active path in Markdown and DOT.

## Pagination and navigation

`Page Up` and `Page Down` scroll the active inspector tab. `J`, `K` and `Tab` navigate packages accepted by the current visual filter.

See [Policies](POLICIES.md), [Paths](PATHS.md), [History](HISTORY-AND-COMPARISON.md), [Search](SEARCH.md) and [Filters](FILTERS-AND-FAVORITES.md).

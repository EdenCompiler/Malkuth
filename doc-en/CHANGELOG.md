# Changelog

## 0.6.1 — Bilingual documentation and cleanup

- Reorganized documentation into `doc-ptbr/` and `doc-en/`.
- Added complete Brazilian Portuguese and English documentation trees.
- Reworked the root README into two complete halves: English and pt-BR.
- Moved the shared interface screenshot to `assets/` to avoid language-tree duplication.
- Audited source-code comments and kept them in Brazilian Portuguese.
- Removed the obsolete `docs/` tree and the unused duplicate SDL smoke-test launcher.
- Updated links, ASDF version metadata, and packaging to 0.6.1.

## 0.6.0 — Policies, paths, and monitoring

- Declarative architecture policy engine using safe S-expressions.
- Rules for forbidden/required dependencies, limits, cycles, and layers.
- Policy panel, filter `7`, and violation rings on the map.
- Shortest package path with `:outgoing`, `:incoming`, and `:either` directions.
- Route panel, filter `8`, edge highlighting, and Markdown/DOT export.
- Trend analysis from persisted history.
- CSV, JSON, and Markdown trend exports.
- Cooperative `malkuth.monitor` module and `watch.lisp` launcher.
- Policy/trend integration with `analyze.lisp` and complete report bundles.
- New tests for policies, paths, trends, monitoring, and exports.

## 0.5.0 — Baseline, history, and regressions

- Safe structural snapshot persistence and rotating history.
- Interactive baseline capture with `B`.
- Evolution panel with `T` for health, cycles, warnings, and risk.
- Filter `6` and visual markers for changed packages.
- Markdown and JSON baseline comparison export with `Y`.
- Package and dependency CSV tables in complete bundles.
- CI gates for new cycles, health regression, and risk increases.
- Public `malkuth.history` API and `compare-architectures`.

## 0.4.1 — Package text search

- Always-visible search box activated by click, `/`, or `Ctrl+F`.
- Unicode input through `SDL_EVENT_TEXT_INPUT` and IME positioning.
- Real-time relevance-ranked results.
- Keyboard and mouse navigation.
- Public `search-nodes` API.
- Optional initial query through `MALKUTH_INITIAL_SEARCH`.

## 0.4.0 — Filters, favorites, and focused investigation

- Visual filters for all/project/risk/favorites/neighborhood packages.
- Persistent favorites stored as validated safe S-expressions.
- Dependency inspector tab with incoming and outgoing relations.
- Focused package dossier in Markdown and Graphviz DOT.
- Public dependency/dependent/neighbor queries.
- Configurable visual risk threshold.
- Expanded comments, docstrings, tests, and documentation.
- Snapshot schema updated to `1.1`.

## 0.3.1 — Brazilian Portuguese documentation and localization

- Rewrote README and documentation in Brazilian Portuguese.
- Localized source comments, docstrings, operational messages, reports, and UI text.
- Preserved public API names, environment variables, and JSON keys for compatibility.
- Added accent normalization for the embedded vector font.
- Removed generated captures/reports, obsolete migration material, and duplicate test launchers.
- Added `.gitignore` rules and reorganized documentation.

## 0.3.0 — Production-oriented analysis

- Snapshot schema metadata, validation, and deterministic fingerprints.
- Fan-in/out, degree, hubs, isolated packages, cycles, local risk, and heuristic health.
- Tarjan strongly connected component detection.
- Snapshot comparison for live-image refresh.
- `F5`, `G`, `X`, and paginated symbol navigation.
- Package-prefix scoping with optional direct boundary dependencies.
- Atomic SVG, JSON, DOT, Markdown, and manifest exports.
- `analyze.lisp` for CI with stable exit codes.
- ASDF-integrated tests and SDL3 smoke validation.

## 0.2.1 — Readability

- Minimum vector-font scale.
- Width-aware text fitting.
- Responsive panel and label clipping.

## 0.2.0 — Malkuth

- Complete project rename to Malkuth.
- Three-region interface: overview, map, and inspector.

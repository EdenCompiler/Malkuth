# Exports

## Complete bundle

Press `X` or use the export API to produce the complete report set. Depending on available state, it can include:

```text
malkuth.svg
malkuth.json
malkuth.dot
malkuth-report.md
malkuth-manifest.txt
malkuth-pacotes.csv
malkuth-dependencias.csv
malkuth.sarif
malkuth.prom
malkuth.mmd
malkuth-impacto.md
malkuth-politicas.md
malkuth-politicas.json
malkuth-tendencia.csv
malkuth-tendencia.json
malkuth-tendencia.md
```

## Baseline comparison

`Y` exports `malkuth-comparacao.md` and `malkuth-comparacao.json` with additions, removals, changed packages, new/resolved cycles, health changes and risk increases.

## Architecture policies

When policies are loaded, Markdown and JSON reports list rules, severities and violations.

## Package path

`U` exports the active architecture route in Markdown and Graphviz DOT.

## Historical trend

Trend exports contain time-ordered health, package count, edge count, symbols, cycles, warnings and fingerprints.

## Package dossier

`C` exports a focused Markdown and DOT report for the selected package, including metrics, dependencies, dependents, cycle participation and owned-symbol samples.

## Production integrations

- `malkuth.sarif`: SARIF 2.1.0 findings using logical package locations;
- `malkuth.prom`: Prometheus exposition-format health and per-package metrics;
- `malkuth.mmd`: Mermaid `flowchart LR` dependency graph;
- `malkuth-impacto.md`: package ranking by transitive dependents, instability and risk.

## CSV

- `malkuth-pacotes.csv`: one row per package with direct and transitive architectural metrics;
- `malkuth-dependencias.csv`: directed `USE-PACKAGE` origin/destination pairs.

## JSON

Snapshot schema `1.2` adds `transitiveDependencies`, `transitiveDependents`, `blastRadius`, and `instability` per package.

JSON keys are stable English API identifiers even when human-facing documentation is localized. This avoids breaking downstream automation.

## Atomic writes

Automation-oriented exports are written to a temporary file in the destination directory and then replaced atomically where the platform allows it. This reduces the chance that interrupted runs leave apparently complete partial reports.

## API

```lisp
(malkuth.export:export-bundle snapshot #P"build/malkuth/")
(malkuth.export:export-csv-bundle snapshot #P"build/malkuth/")
(malkuth.export:export-comparison-bundle baseline snapshot #P"build/malkuth/")
(malkuth.export:export-policy-bundle policy-result #P"build/malkuth/")
(malkuth.export:export-sarif snapshot #P"build/malkuth/malkuth.sarif")
(malkuth.export:export-prometheus snapshot #P"build/malkuth/malkuth.prom")
(malkuth.export:export-mermaid snapshot #P"build/malkuth/malkuth.mmd")
```

See exported package definitions in `src/package.lisp` for the complete public surface.

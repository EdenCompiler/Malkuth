# Impact analysis and production integrations

## Transitive reachability

Malkuth now follows the `USE-PACKAGE` graph beyond direct neighbors. For any package it can return all reachable dependencies and all packages that depend on it, optionally limited by depth.

```lisp
(malkuth.model:node-transitive-dependencies snapshot "MEU-APP.CORE")
(malkuth.model:node-transitive-dependents snapshot "MEU-APP.CORE")
(malkuth.model:reachable-node-ids snapshot "MEU-APP.CORE"
                                  :direction :outgoing :max-depth 2)
```

## Blast radius

`node-metrics-blast-radius` is the number of transitive dependents. A package with a high blast radius sits upstream of many other packages, so changes to its contracts deserve broader regression testing and review.

Filter `9` shows packages at or above `MALKUTH_IMPACT_THRESHOLD`:

```bash
MALKUTH_IMPACT_THRESHOLD=10 sbcl --script run.lisp
```

The default threshold is `5`.

## Instability

Malkuth reports package instability as:

```text
fan-out / (fan-in + fan-out) × 100
```

A value near 100 means the package mostly depends on others; a value near 0 means others mostly depend on it. This is a structural heuristic, not a quality score by itself.

## SARIF 2.1.0

`malkuth.sarif` carries analysis warnings and, when supplied to the bundle exporter, declarative policy violations. Because Malkuth analyzes a live image rather than source lines, results use SARIF logical locations named after packages.

```lisp
(malkuth.export:export-sarif snapshot #P"build/malkuth/malkuth.sarif"
                              :analysis analysis
                              :policy-report policy-report)
```

## Prometheus

`malkuth.prom` exposes global and per-package gauges, including health, package/dependency totals, cycle count, warning count, local risk, blast radius and instability. It can be published by a textfile collector or transformed by your monitoring pipeline.

## Mermaid

`malkuth.mmd` is a Markdown-friendly `flowchart LR` representation. Nodes include risk and impact values and are classified as project, runtime, tooling or library packages.

## Impact report

`malkuth-impacto.md` ranks packages by transitive dependents, instability and local risk. Use it to identify packages that deserve contract tests, compatibility review and cautious rollout strategies.

## JSON schema and CSV columns

Snapshot schema `1.2` adds these package metrics:

- `transitiveDependencies`;
- `transitiveDependents`;
- `blastRadius`;
- `instability`.

The package CSV contains equivalent columns. Existing fields remain available.

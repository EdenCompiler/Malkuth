# Use cases

## Long-running Common Lisp services

Malkuth is especially useful when the running image can diverge from the source checkout because of runtime compilation, hot fixes, plugin loading or REPL changes.

## Architecture governance

Versioned policies can enforce boundaries such as “domain must not depend on UI”, fan-out limits, layer order and cycle restrictions in both the interactive tool and CI.

## Transitive dependency investigation

Shortest-path analysis explains how two apparently distant packages are connected through `USE-PACKAGE` relationships.

## Package-boundary review

Fan-in, fan-out, symbol counts, hubs and focused dossiers help identify packages that are growing into oversized responsibilities or becoming accidental central dependencies.

## Game engines and editors

Projects with package families such as ECS, renderer, editor, assets, scripting, audio and physics benefit from visualizing layer boundaries and detecting editor/runtime coupling.

## Plugin systems

Capture a baseline before loading a plugin, refresh afterward and inspect added packages, changed topology, new cycles and policy violations.

## Library integration

Load a third-party library in the same image and use scope/boundary nodes to understand which packages appeared and where they connect to the application.

## Onboarding

The graph and reports provide a high-level map of package ownership and dependency direction before a new contributor reads the entire codebase.

## Trend and audit

Persist historical snapshots or exported trend series to observe whether package count, coupling, warnings, cycles or health are improving or degrading across releases.

## Poor fits

Malkuth is not a CPU profiler, allocation profiler, function call graph, debugger, security scanner, static type checker or complete dependency manager. Its graph is primarily package-level and based on `USE-PACKAGE` relationships.

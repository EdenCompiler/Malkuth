# Development

## ASDF systems

- `malkuth/core`: portable model, analysis, policies, history, monitoring and exports;
- `malkuth`: SDL3/CFFI interactive application;
- `malkuth/tests`: regression suite.

## Commands

```bash
make run
make svg
make analyze
make watch
make test
make smoke
make watch-smoke
make validate
make clean
```

## Conventions

- Source comments and docstrings are written in Brazilian Portuguese.
- Stable public API identifiers, package names, environment variables and JSON keys remain unchanged for compatibility.
- The portable core must not acquire an SDL3/CFFI dependency.
- Exports used by automation should remain deterministic and use safe/atomic writes where applicable.
- Snapshot changes that affect external readers require a schema-version review.

## Test coverage

The suite covers snapshot validation, deterministic fingerprints, architecture metrics, cycles, comparisons, persistence round-trips, search, relationships, focused exports, policies, dependency paths, historical trends and monitoring. Separate smoke tests cover SDL3 startup and native text input.

## Adding a policy rule

1. Add and validate the new rule type in `src/policy.lisp`.
2. Export required public symbols in `src/package.lisp`.
3. Add exact synthetic-topology tests in `tests/suite.lisp`.
4. Update both `doc-ptbr/POLICIES.md` and `doc-en/POLICIES.md`.
5. Document any new configuration or CI behavior.

## Adding an analysis heuristic

Keep the heuristic transparent and documented. Prefer metrics that can be explained from snapshot data. Do not present heuristic scores as correctness or security guarantees.

## Adding an export

Use deterministic ordering, escape the destination format correctly, write automation artifacts atomically, and test both content and failure cleanup.

## Adding a UI panel

Keep analysis logic outside `src/app.lisp`; the application should consume core data rather than duplicate it. Respect responsive dimensions and the minimum readable vector-font scale.

## Localization

Human documentation lives in two parallel trees:

- `doc-ptbr/`: Brazilian Portuguese;
- `doc-en/`: English.

The root `README.md` contains a complete English half followed by a complete Brazilian Portuguese half.

## Source-code comments

Comments should explain intent, contracts, invariants and non-obvious tradeoffs rather than restating syntax. Source comments remain in pt-BR even when English documentation is added.

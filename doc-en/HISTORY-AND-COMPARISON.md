# History, comparison and trends

## Interactive baseline

Press `B` to save the current architecture as a baseline:

```text
output/malkuth-linha-de-base.sexp
```

The file contains structural snapshot data, not live Lisp objects. Loading disables `*READ-EVAL*` and validates the reconstructed snapshot.

## Evolution panel

Press `T` to compare the current snapshot against the baseline. The panel summarizes:

- health-score delta;
- added, removed and changed packages;
- new and resolved cycles;
- warning-count changes;
- largest local-risk increases.

## Rotating history

Before an interactive `F5` refresh, the previous snapshot is written to `output/historico/`. Retention is configurable:

```bash
MALKUTH_HISTORY_RETENTION=50 sbcl --script run.lisp
```

## Trend analysis

Historical snapshots can be converted into a chronological series containing health, package count, edge count, symbol count, cycles, warnings and fingerprints.

Exports:

```text
malkuth-tendencia.csv
malkuth-tendencia.json
malkuth-tendencia.md
```

## Comparison export

Press `Y` to generate:

```text
malkuth-comparacao.md
malkuth-comparacao.json
```

These reports describe regressions and improvements relative to the baseline.

## Continuous integration

```bash
MALKUTH_BASELINE_FILE="$PWD/ci/malkuth-baseline.sexp" \
MALKUTH_FAIL_ON_NEW_CYCLES=true \
MALKUTH_MAX_HEALTH_REGRESSION=5 \
MALKUTH_MAX_RISK_INCREASES=3 \
MALKUTH_SAVE_HISTORY=true \
MALKUTH_EXPORT_TRENDS=true \
sbcl --script analyze.lisp
```

To update an approved baseline:

```bash
MALKUTH_BASELINE_FILE="$PWD/ci/malkuth-baseline.sexp" \
MALKUTH_UPDATE_BASELINE=true \
sbcl --script analyze.lisp
```

Treat health and risk as heuristics. Establish a stable baseline before turning thresholds into hard gates.

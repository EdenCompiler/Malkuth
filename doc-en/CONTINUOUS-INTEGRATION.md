# Continuous integration

## Basic run

```bash
MALKUTH_SCOPE_PREFIXES='MEU-APP' \
MALKUTH_USER_PREFIXES='MEU-APP' \
MALKUTH_OUTPUT_DIR="$PWD/build/malkuth/" \
sbcl --script analyze.lisp
```

## Absolute policies

Environment thresholds can enforce minimum health, maximum warnings and current-cycle restrictions:

```bash
MALKUTH_MIN_HEALTH=80 \
MALKUTH_MAX_WARNINGS=5 \
MALKUTH_FAIL_ON_CYCLES=true \
sbcl --script analyze.lisp
```

## Versioned declarative policies

```bash
MALKUTH_POLICY_FILE="$PWD/malkuth-politicas.sexp" \
MALKUTH_FAIL_ON_POLICY=true \
sbcl --script analyze.lisp
```

Keep the policy file under version control so architecture intent evolves through code review.

## Baseline and regression policies

```bash
MALKUTH_BASELINE_FILE="$PWD/ci/malkuth-baseline.sexp" \
MALKUTH_FAIL_ON_NEW_CYCLES=true \
MALKUTH_MAX_HEALTH_REGRESSION=5 \
MALKUTH_MAX_RISK_INCREASES=3 \
sbcl --script analyze.lisp
```

Regression policies are useful when a legacy system already contains debt that cannot be eliminated immediately: the build can reject new debt without failing on every historical issue.

## History and trends in CI

```bash
MALKUTH_HISTORY_DIR="$PWD/build/history/" \
MALKUTH_SAVE_HISTORY=true \
MALKUTH_EXPORT_TRENDS=true \
MALKUTH_TREND_LIMIT=100 \
sbcl --script analyze.lisp
```

Persist the history or trend artifacts in CI storage if cross-build evolution matters.

## Controlled baseline updates

```bash
MALKUTH_BASELINE_FILE="$PWD/ci/malkuth-baseline.sexp" \
MALKUTH_UPDATE_BASELINE=true \
sbcl --script analyze.lisp
```

Update only after the architecture change is reviewed and intentionally accepted.

## Gradual adoption

Start by collecting reports without blocking builds. Observe normal score variation, warnings and cycles. Then add regression-only gates, followed by declarative policies for critical boundaries.


## SARIF and code scanning

Every complete bundle writes `malkuth.sarif`. The file follows SARIF 2.1.0 and represents architecture warnings and optional policy violations as logical package locations, so CI systems can archive or upload it to code-scanning interfaces.

```bash
MALKUTH_SCOPE_PREFIXES='MEU-APP' \
MALKUTH_POLICY_FILE="$PWD/malkuth-politicas.sexp" \
sbcl --script analyze.lisp
# upload build output/malkuth.sarif with the CI provider's SARIF action
```

## Exit codes

- `0`: analysis approved;
- `1`: operational/configuration failure;
- `2`: architecture policy or configured quality gate failed.

## Generic job example

```bash
set -e
sbcl --script analyze.lisp
mkdir -p artifacts/malkuth
cp -a build/malkuth/. artifacts/malkuth/
```

## Privacy

Reports may contain internal package and symbol names. Treat exported artifacts according to the confidentiality level of the analyzed codebase.

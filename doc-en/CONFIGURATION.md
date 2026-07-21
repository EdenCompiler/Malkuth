# Configuration

## Interface and snapshot

| Variable | Default | Description |
|---|---:|---|
| `MALKUTH_WIDTH` | `1600` | Initial width; effective minimum 1280 |
| `MALKUTH_HEIGHT` | `900` | Initial height; effective minimum 760 |
| `MALKUTH_OUTPUT_DIR` | `output/` | Reports, favorites, baseline and history |
| `MALKUTH_SCOPE_PREFIXES` | unset | Package prefixes included in the snapshot |
| `MALKUTH_USER_PREFIXES` | scope | Prefixes treated as project-owned |
| `MALKUTH_INCLUDE_DEPENDENCIES` | `true` with scope | Includes direct boundary dependencies |
| `MALKUTH_INCLUDE_EMPTY` | `false` | Includes packages without owned symbols |
| `MALKUTH_AUTO_ORBIT` | `true` | Starts automatic orbit |
| `MALKUTH_RISK_THRESHOLD` | `20` | Visual risk-filter threshold, 0–100 |
| `MALKUTH_INITIAL_SEARCH` | unset | Opens search with an initial query |
| `MALKUTH_INITIAL_PANEL` | `visao-geral` | `visao-geral`, `diagnosticos`, `evolucao` or `politicas` |
| `MALKUTH_POLICY_FILE` | unset | Architecture policy file |
| `MALKUTH_HISTORY_RETENTION` | `20` | Maximum interactive history snapshots |
| `MALKUTH_MAX_FRAMES` | unset | Frame limit for automated tests |

## Headless analysis and CI

| Variable | Default | Description |
|---|---:|---|
| `MALKUTH_MIN_HEALTH` | unset | Minimum accepted health score |
| `MALKUTH_FAIL_ON_CYCLES` | `false` | Fails when current state contains cycles |
| `MALKUTH_MAX_WARNINGS` | unset | Maximum accepted warnings |
| `MALKUTH_FAIL_ON_POLICY` | `true` when policies exist | Fails on `:error` policy violations |
| `MALKUTH_BASELINE_FILE` | unset | Structural baseline file |
| `MALKUTH_UPDATE_BASELINE` | `false` | Updates baseline after an approved analysis |
| `MALKUTH_FAIL_ON_NEW_CYCLES` | `false` | Fails when new cycles appear |
| `MALKUTH_MAX_HEALTH_REGRESSION` | unset | Maximum allowed health decrease |
| `MALKUTH_MAX_RISK_INCREASES` | unset | Maximum packages with increased risk |
| `MALKUTH_HISTORY_DIR` | `<output>/historico/` | History directory used by analysis |
| `MALKUTH_SAVE_HISTORY` | `false` | Saves current snapshot to history |
| `MALKUTH_EXPORT_TRENDS` | `true` when history exists | Exports CSV/JSON/Markdown trends |
| `MALKUTH_TREND_LIMIT` | `100` | Maximum historical points used |

## Continuous monitor

| Variable | Default | Description |
|---|---:|---|
| `MALKUTH_BOOTSTRAP_FILE` | unset | Loads the monitored application |
| `MALKUTH_WATCH_INTERVAL` | `5` | Seconds between checks |
| `MALKUTH_WATCH_ITERATIONS` | infinite | Maximum checks |
| `MALKUTH_EXPORT_ON_CHANGE` | `true` | Exports reports when topology changes |
| `MALKUTH_HISTORY_RETENTION` | `50` in monitor | Monitor history retention |

## Lisp startup

`QUICKLISP_SETUP` may point explicitly to `quicklisp/setup.lisp` when CFFI is not directly discoverable by ASDF.

Accepted true-like values include `1`, `true`, `yes`, `on`, `sim`, `verdadeiro` and `ligado`.

## Examples

Focused interface with policies:

```bash
MALKUTH_SCOPE_PREFIXES='MEU-APP' \
MALKUTH_USER_PREFIXES='MEU-APP' \
MALKUTH_POLICY_FILE="$PWD/malkuth-politicas.sexp" \
MALKUTH_INITIAL_PANEL=politicas \
sbcl --script run.lisp
```

Headless analysis with history and trends:

```bash
MALKUTH_SCOPE_PREFIXES='MEU-APP' \
MALKUTH_OUTPUT_DIR="$PWD/build/architecture/" \
MALKUTH_SAVE_HISTORY=true \
MALKUTH_EXPORT_TRENDS=true \
sbcl --script analyze.lisp
```

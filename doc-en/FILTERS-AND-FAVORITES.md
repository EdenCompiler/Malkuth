# Filters, focus and favorites

## Visual filters

| Key | Filter |
|---|---|
| `1` | All packages |
| `2` | Project packages |
| `3` | Packages above the risk threshold |
| `4` | Favorites |
| `5` | Direct neighborhood of the selected package |
| `6` | Packages changed since baseline |
| `7` | Packages involved in policy violations |
| `8` | Packages in the active architecture path |

The selected package is kept visible when possible so switching filters does not destroy navigation context.

## Neighborhood focus

`V` toggles quickly between the direct neighborhood and the full map. Neighborhood mode includes the selected package, outgoing dependencies and incoming dependents.

## Persistent favorites

Press `F` to toggle the selected package as a favorite. Favorites are stored in:

```text
<output-directory>/malkuth-favoritos.sexp
```

Loading is performed with `*READ-EVAL*` disabled and the file is validated as a simple list of package names.

## Risk threshold

```bash
MALKUTH_RISK_THRESHOLD=35 sbcl --script run.lisp
```

Accepted range: `0` to `100`. This value controls the visual risk filter only; it does not redefine the global health score.

## Changed since baseline

After a baseline is captured with `B`, filter `6` isolates added or modified packages. Changed packages receive a magenta ring and may simultaneously carry favorite, policy or path indicators.

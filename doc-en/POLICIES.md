# Architecture policies

Policies turn architecture expectations into versionable, reproducible rules evaluated against the live package snapshot.

## Activation

Copy and edit the example:

```bash
cp malkuth-politicas.exemplo.sexp malkuth-politicas.sexp
```

Run with:

```bash
MALKUTH_SCOPE_PREFIXES='MEU-APP' \
MALKUTH_USER_PREFIXES='MEU-APP' \
MALKUTH_POLICY_FILE="$PWD/malkuth-politicas.sexp" \
sbcl --script run.lisp
```

## Format

The file contains S-expressions read with `*READ-EVAL*` disabled. Example:

```lisp
(:id "domain-without-ui"
 :type :forbid-dependency
 :severity :error
 :from "MEU-APP.DOMINIO*"
 :to "MEU-APP.UI*"
 :message "The domain layer must not depend on the UI.")
```

Each rule should have a stable `:id`. Severity can be used to distinguish advisory findings from build-breaking errors.

## Patterns

Package selectors accept literal names and simple prefix patterns ending in `*`, such as `MEU-APP.DOMINIO*`.

## Rule types

### Forbidden dependency

`:forbid-dependency` reports matching outgoing package dependencies.

### Required dependency

`:require-dependency` requires packages matching `:from` to depend on at least one package matching `:to`.

### Limits

`:max-fan-out`, `:max-fan-in`, `:max-risk` and `:max-symbols` enforce local thresholds.

### Forbidden cycles

`:forbid-cycle` reports matching packages that participate in a strongly connected dependency component.

### Layer order

`:layer-order` defines an ordered list of package patterns. Earlier layers are considered more fundamental; dependencies that point upward to a later layer are violations.

## CI

```bash
MALKUTH_POLICY_FILE="$PWD/malkuth-politicas.sexp" \
MALKUTH_FAIL_ON_POLICY=true \
sbcl --script analyze.lisp
```

Policy errors can produce exit code `2` while operational failures use exit code `1`.

## API

```lisp
(defparameter *rules*
  (malkuth.policy:load-policy-file #P"malkuth-politicas.sexp"))

(defparameter *evaluation*
  (malkuth.policy:evaluate-policies
   *snapshot* *rules* :analysis *analysis*))

(malkuth.export:export-policy-bundle *evaluation* #P"build/malkuth/")
```

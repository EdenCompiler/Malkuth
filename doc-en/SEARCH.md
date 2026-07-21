# Package search

## Activation

The search box is always visible in the top bar. Activate it by clicking the field, pressing `/`, or pressing `Ctrl+F`.

## Controls

| Input | Action |
|---|---|
| Typing | Updates results in real time |
| `Up` / `Down` | Moves through results |
| `Tab` | Selects the next result |
| `Enter` | Opens the selected package |
| `Backspace` | Removes the last character |
| Mouse click | Opens a result directly |
| `Esc` | Closes search |

Global shortcuts are suspended while text input is active so typed letters are not interpreted as commands.

## Relevance ranking

Results are ranked by match quality:

1. exact package name;
2. package-name prefix;
3. prefix of a dot-separated segment;
4. contiguous substring;
5. character subsequence.

Matching is case-insensitive.

## Relationship with filters

Search scans the entire snapshot, including packages hidden by the active visual filter. Opening a result keeps the current filter but ensures the selected package remains visible so context is not lost.

## Unicode and IME

The SDL3 interface uses `SDL_EVENT_TEXT_INPUT` for committed UTF-8 text. Text input starts only while search is active and stops when search closes. The field rectangle is reported to SDL3 so input-method candidate windows can be positioned near the search box.

## Initial query

```bash
MALKUTH_INITIAL_SEARCH='MEU-APP.CORE' sbcl --script run.lisp
```

## Programmatic API

```lisp
(asdf:load-system "malkuth/core")
(defparameter *snapshot* (malkuth.model:build-snapshot))

(malkuth.model:search-nodes *snapshot* "render" :limit 10)
```

Restrict candidates with a predicate:

```lisp
(malkuth.model:search-nodes
 *snapshot* "app"
 :predicate (lambda (node)
              (eq (malkuth.model:node-kind node) :user)))
```

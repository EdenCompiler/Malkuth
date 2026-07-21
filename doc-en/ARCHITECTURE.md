# Internal architecture

## Overview

Malkuth separates a portable analysis core from the optional SDL3 interface. The central data object is a deterministic snapshot of loaded packages and `USE-PACKAGE` edges. Analysis, history, policies, exports and monitoring all consume the same snapshot model.

```text
Live Lisp image
      |
      v
 malkuth.model ----> snapshot ----> analysis / policies / history
      |                                  |
      |                                  +--> JSON / DOT / Markdown / CSV
      +--> layout / SVG                  +--> monitoring / CI
      |
      +--> SDL3 application
```

## `malkuth.model`

Reflects loaded packages, classifies owned symbols, builds stable node IDs and directed package edges, validates snapshots, searches packages and computes direct relationships and shortest dependency paths.

Only symbols whose home package is the inspected package count as owned symbols; inherited symbols do not inflate ownership metrics.

## `malkuth.analysis`

Computes fan-in, fan-out, total degree, hubs, isolated packages, strongly connected components, warnings, local risk and the heuristic global health score. It also compares two snapshots and derives historical trend points.

## `malkuth.policy`

Loads safe declarative policy S-expressions, validates rules and evaluates architecture constraints against a snapshot and its analysis.

## `malkuth.history`

Serializes structural snapshots as safe S-expressions, reconstructs and validates them, rotates history files and provides deterministic persistence for baseline comparisons.

## `malkuth.monitor`

Provides cooperative polling for long-running Lisp images. It detects fingerprint changes, preserves previous valid snapshots and can export comparison artifacts when architecture changes.

## `malkuth.layout`

Implements the deterministic three-dimensional force-directed layout using repulsion, springs, central gravity, damping and bounded velocities.

## `malkuth.svg`

Produces a self-contained SVG dashboard from the same snapshot and metrics used by the interactive interface.

## `malkuth.export`

Generates global reports, focused package dossiers, policy reports, path reports, comparisons, trend series and CSV tables. Automation-oriented files use atomic replacement to reduce partial-artifact risk.

## `malkuth.app`

Owns transient UI state: camera, selection, filters, favorites, search, panels, baseline, policies, active route and SDL3 drawing. Core architecture data remains in the portable modules.

## `malkuth.sdl3`

Contains the deliberately small CFFI binding surface required by Malkuth: window/renderer lifecycle, input events, text input, keyboard state and vector drawing primitives.

## Vector font

`malkuth.vector-font` embeds a 5x7 vector font to avoid external font-file deployment. Accent normalization maps unsupported accented letters to readable base glyphs.

## Compatibility decisions

- Public package names, environment variables and JSON keys remain stable English identifiers for API compatibility.
- Human-facing UI and Portuguese documentation remain localized independently of those identifiers.
- `malkuth/core` does not depend on SDL3 or CFFI.
- Snapshot IDs are deterministic within the sorted package set, making exports and fingerprints reproducible.
- The graph intentionally models `USE-PACKAGE`, not every fully-qualified symbol reference or runtime call.

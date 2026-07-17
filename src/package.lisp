;;;; Pacotes públicos do Malkuth
;;;;
;;;; Este arquivo concentra os contratos entre o núcleo portátil, a análise,
;;;; os exportadores e a interface SDL3. Manter as exportações aqui reduz o
;;;; acoplamento acidental entre os módulos e facilita a evolução da API.

(defpackage #:malkuth.math
  (:use #:cl)
  (:export #:clamp #:lerp #:smoothstep #:hash-unit #:hash-signed
           #:v3 #:v3-x #:v3-y #:v3-z #:v3+ #:v3- #:v3* #:v3-length
           #:v3-normalize #:rotate-yx #:project-point #:projected
           #:projected-x #:projected-y #:projected-depth #:projected-visible-p))

(defpackage #:malkuth.model
  (:use #:cl #:malkuth.math)
  (:export #:node #:node-id #:node-name #:node-package #:node-kind
           #:node-internal #:node-external #:node-functions #:node-generics
           #:node-macros #:node-classes #:node-variables #:node-position
           #:node-velocity #:node-radius #:node-heat #:node-screen-x
           #:node-screen-y #:node-depth #:node-visible-p
           #:edge #:edge-from #:edge-to #:edge-weight
           #:snapshot #:snapshot-nodes #:snapshot-edges #:snapshot-created-at
           #:snapshot-schema-version #:snapshot-total-symbols
           #:snapshot-total-functions #:snapshot-total-generics
           #:snapshot-total-macros #:snapshot-total-classes
           #:snapshot-total-variables #:snapshot-implementation
           #:snapshot-features #:build-snapshot #:refresh-node-profile!
           #:node-symbol-lines #:find-node-by-name #:search-nodes #:snapshot-summary
           #:node-dependency-ids #:node-dependent-ids #:node-neighbor-ids
           #:node-dependencies #:node-dependents #:node-neighbors
           #:snapshot-fingerprint #:validate-snapshot))

(defpackage #:malkuth.layout
  (:use #:cl #:malkuth.math #:malkuth.model)
  (:export #:seed-layout! #:relax-layout! #:reheat-layout!
           #:update-projection! #:sorted-visible-nodes #:nearest-node))


(defpackage #:malkuth.history
  (:use #:cl #:malkuth.model)
  (:export #:+history-format-version+ #:snapshot-record #:snapshot-from-record
           #:save-snapshot-file #:load-snapshot-file
           #:history-files #:prune-history! #:save-history-snapshot
           #:latest-history-file #:latest-history-snapshot))

(defpackage #:malkuth.analysis
  (:use #:cl #:malkuth.model)
  (:export #:node-metrics #:node-metrics-node-id #:node-metrics-name
           #:node-metrics-fan-in #:node-metrics-fan-out
           #:node-metrics-total-degree #:node-metrics-symbols
           #:node-metrics-risk-score
           #:analysis-warning #:analysis-warning-severity
           #:analysis-warning-code #:analysis-warning-package
           #:analysis-warning-message
           #:analysis-report #:analysis-report-metrics
           #:analysis-report-cycles #:analysis-report-orphans
           #:analysis-report-hubs #:analysis-report-warnings
           #:analysis-report-health-score #:analysis-report-fingerprint
           #:analyze-snapshot #:metrics-for-node #:analysis-summary
           #:package-change #:package-change-name #:package-change-symbol-delta
           #:package-change-function-delta #:package-change-macro-delta
           #:package-change-class-delta
           #:snapshot-diff #:snapshot-diff-added-packages
           #:snapshot-diff-removed-packages #:snapshot-diff-changed-packages
           #:snapshot-diff-symbol-delta #:snapshot-diff-function-delta
           #:snapshot-diff-macro-delta #:snapshot-diff-class-delta
           #:compare-snapshots
           #:risk-change #:risk-change-name #:risk-change-old-risk
           #:risk-change-new-risk #:risk-change-delta
           #:architecture-diff #:architecture-diff-snapshot-diff
           #:architecture-diff-health-delta #:architecture-diff-warning-delta
           #:architecture-diff-new-cycles #:architecture-diff-resolved-cycles
           #:architecture-diff-risk-increases #:architecture-diff-risk-decreases
           #:compare-architectures #:architecture-diff-summary))

(defpackage #:malkuth.svg
  (:use #:cl #:malkuth.math #:malkuth.model #:malkuth.layout #:malkuth.analysis)
  (:export #:export-svg))

(defpackage #:malkuth.export
  (:use #:cl #:malkuth.model #:malkuth.analysis)
  (:import-from #:malkuth.svg #:export-svg)
  (:export #:export-json #:export-dot #:export-markdown #:export-bundle
           #:export-packages-csv #:export-dependencies-csv #:export-csv-bundle
           #:export-comparison-json #:export-comparison-markdown
           #:export-comparison-bundle
           #:export-package-markdown #:export-package-dot #:export-package-bundle
           #:atomic-write-file))

(defpackage #:malkuth.font
  (:use #:cl)
  (:export #:glyph-rows #:draw-vector-text #:vector-text-width))

(defpackage #:malkuth.sdl3
  (:use #:cl)
  (:export #:with-sdl3 #:sdl-window #:sdl-renderer #:poll-events #:poll-quit-p
           #:start-text-input #:stop-text-input #:set-text-input-area
           #:keyboard-down-p #:mouse-state #:window-size #:set-window-minimum-size
           #:ticks #:delay #:clear #:present #:set-color #:line #:fill-rect
           #:outline-rect #:point #:circle #:filled-circle #:set-vsync #:last-error
           #:+sc-return+ #:+sc-escape+ #:+sc-backspace+ #:+sc-space+ #:+sc-slash+ #:+sc-tab+ #:+sc-h+ #:+sc-r+ #:+sc-p+
           #:+sc-o+ #:+sc-w+ #:+sc-a+ #:+sc-s+ #:+sc-d+ #:+sc-q+ #:+sc-e+
           #:+sc-b+ #:+sc-c+ #:+sc-f+ #:+sc-i+ #:+sc-t+ #:+sc-v+ #:+sc-y+
           #:+sc-j+ #:+sc-k+ #:+sc-g+ #:+sc-x+ #:+sc-f5+
           #:+sc-1+ #:+sc-2+ #:+sc-3+ #:+sc-4+ #:+sc-5+ #:+sc-6+
           #:+sc-pageup+ #:+sc-pagedown+ #:+sc-up+ #:+sc-down+
           #:+sc-left-control+ #:+sc-right-control+ #:+mouse-left+))

(defpackage #:malkuth.app
  (:use #:cl #:malkuth.math #:malkuth.model #:malkuth.layout)
  (:import-from #:malkuth.svg #:export-svg)
  (:import-from #:malkuth.export
                #:export-bundle #:export-package-bundle #:export-comparison-bundle
                #:atomic-write-file)
  (:import-from #:malkuth.history
                #:save-snapshot-file #:load-snapshot-file #:save-history-snapshot)
  (:import-from #:malkuth.analysis
                #:analyze-snapshot #:analysis-report-health-score
                #:analysis-report-cycles #:analysis-report-orphans
                #:analysis-report-warnings #:analysis-report-hubs
                #:analysis-warning-message #:analysis-warning-severity
                #:node-metrics-name #:node-metrics-fan-in
                #:node-metrics-fan-out #:node-metrics-total-degree
                #:node-metrics-risk-score
                #:metrics-for-node #:compare-snapshots #:compare-architectures
                #:architecture-diff-health-delta #:architecture-diff-warning-delta
                #:architecture-diff-new-cycles #:architecture-diff-resolved-cycles
                #:architecture-diff-risk-increases #:architecture-diff-risk-decreases
                #:architecture-diff-snapshot-diff #:risk-change-name
                #:risk-change-old-risk #:risk-change-new-risk #:risk-change-delta
                #:snapshot-diff-added-packages #:snapshot-diff-removed-packages
                #:snapshot-diff-changed-packages)
  (:import-from #:malkuth.font #:draw-vector-text #:vector-text-width)
  (:export #:run #:render-preview))

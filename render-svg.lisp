;;;; Exportador rápido de um único mapa SVG
;;;;
;;;; Diferentemente de ANALYZE.LISP, este script não aplica políticas nem grava
;;;; formatos auxiliares. Ele existe para documentação visual e testes manuais.

(require :asdf)
(asdf:load-asd (merge-pathnames "malkuth.asd" *load-truename*))
(asdf:load-system "malkuth/core")
;; O instantâneo é construído uma única vez para manter contagens e grafo coerentes.
(let* ((snapshot (malkuth.model:build-snapshot))
       (output (merge-pathnames "output/malkuth.svg" *load-truename*)))
  (format t "~&Instantâneo: ~S~%" (malkuth.model:snapshot-summary snapshot))
  (malkuth.svg:export-svg snapshot output)
  (format t "Arquivo gerado: ~A~%" output))

;;;; Teste curto da integração SDL3
;;;;
;;;; A quantidade limitada de quadros verifica criação, desenho, eventos e
;;;; encerramento sem exigir interação humana. Em CI, execute sob Xvfb.

(require :asdf)
(asdf:load-asd (merge-pathnames "../malkuth.asd" *load-truename*))
(asdf:load-system "malkuth")
(malkuth.app:run :width 1280 :height 760 :max-frames 8)
(format t "~&Teste de fumaça SDL3 do MALKUTH aprovado.~%")
(quit)

;;;; Inicializador portátil da suíte de regressão
;;;;
;;;; Mantém o comando de teste independente do registro global do ASDF.

(require :asdf)
(asdf:load-asd (merge-pathnames "../malkuth.asd" *load-truename*))
(asdf:test-system "malkuth/tests")

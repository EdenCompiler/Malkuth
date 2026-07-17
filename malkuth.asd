;;;; MALKUTH — definição dos sistemas ASDF

(asdf:defsystem "malkuth/core"
  :description "Observatório da imagem Common Lisp e analisador de arquitetura orientado a uso em produção."
  :author "Bruno"
  :license "MIT"
  :version "0.5.0"
  :in-order-to ((asdf:test-op (asdf:test-op "malkuth/tests")))
  :serial t
  :components ((:file "src/package")
               (:file "src/math")
               (:file "src/model")
               (:file "src/layout")
               (:file "src/history")
               (:file "src/analysis")
               (:file "src/svg")
               (:file "src/export")))

(asdf:defsystem "malkuth"
  :description "Interface interativa SDL3 do Malkuth."
  :author "Bruno"
  :license "MIT"
  :version "0.5.0"
  :in-order-to ((asdf:test-op (asdf:test-op "malkuth/tests")))
  :depends-on ("malkuth/core" "cffi")
  :serial t
  :components ((:file "src/vector-font")
               (:file "src/sdl3")
               (:file "src/app")))

(asdf:defsystem "malkuth/tests"
  :description "Suíte automatizada de testes do Malkuth."
  :depends-on ("malkuth/core")
  :serial t
  :components ((:file "tests/suite"))
  :perform (asdf:test-op (operation component)
             (declare (ignore operation component))
             (uiop:symbol-call :malkuth.tests :run-tests)))

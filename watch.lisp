;;;; Monitor contínuo do Malkuth sem interface gráfica
;;;;
;;;; Este inicializador é indicado para serviços Lisp que carregam extensões em
;;;; tempo de execução. Ele observa a própria imagem do processo, preserva o
;;;; histórico e gera uma comparação sempre que a arquitetura muda.

(require :asdf)

(defun env-value (name)
  (let ((value (uiop:getenv name)))
    (and value (plusp (length value)) value)))

(defun env-integer (name default)
  (let ((value (env-value name)))
    (if value (or (parse-integer value :junk-allowed t) default) default)))

(defun env-real (name default)
  "Lê um número real do ambiente sem permitir avaliação pelo leitor Lisp."
  (let ((value (env-value name)))
    (if value
        (handler-case
            (let ((*read-eval* nil))
              (multiple-value-bind (parsed position)
                  (read-from-string value nil nil)
                (if (and (realp parsed)
                         (= position (length value)))
                    (coerce parsed 'double-float)
                    default)))
          (error () default))
        default)))

(defun env-boolean (name default)
  (let ((value (env-value name)))
    (if (null value)
        default
        (not (null (member (string-downcase value)
                           '("1" "true" "yes" "on" "sim" "verdadeiro" "ligado")
                           :test #'string=))))))

(defun split-prefixes (text)
  (when text
    (remove-if (lambda (item) (zerop (length item)))
               (uiop:split-string text :separator '(#\, #\Space #\Tab)))))

(defun prefix-predicate (prefixes)
  (when prefixes
    (lambda (package)
      (some (lambda (prefix)
              (let ((name (package-name package)))
                (and (<= (length prefix) (length name))
                     (string-equal prefix name :end2 (length prefix)))))
            prefixes))))

(defun project-root ()
  (uiop:pathname-directory-pathname *load-truename*))

(handler-case
    (progn
      (asdf:load-asd (merge-pathnames "malkuth.asd" (project-root)))
      (asdf:load-system "malkuth/core")
      ;; Um arquivo de bootstrap permite carregar a aplicação monitorada antes da
      ;; primeira fotografia, sem acoplar o Malkuth ao Quicklisp ou ao projeto.
      (let ((bootstrap (env-value "MALKUTH_BOOTSTRAP_FILE")))
        (when bootstrap
          (format t "Carregando bootstrap: ~A~%" bootstrap)
          (load bootstrap))))
  (error (condition)
    (format *error-output* "~&FALHA AO INICIAR O MONITOR DO MALKUTH: ~A~%" condition)
    (uiop:quit 1)))

(handler-case
    (let* ((scope (split-prefixes (env-value "MALKUTH_SCOPE_PREFIXES")))
           (users (or (split-prefixes (env-value "MALKUTH_USER_PREFIXES")) scope))
           (output (pathname (or (env-value "MALKUTH_OUTPUT_DIR")
                                 (namestring (merge-pathnames "output/monitor/"
                                                              (project-root))))))
           (interval (env-real "MALKUTH_WATCH_INTERVAL" 5.0d0))
           (iterations (let ((value (env-value "MALKUTH_WATCH_ITERATIONS")))
                         (and value (parse-integer value :junk-allowed t))))
           (builder
             (lambda ()
               (malkuth.model:build-snapshot
                :package-predicate (prefix-predicate scope)
                :user-package-predicate (prefix-predicate users)
                :include-dependencies (and scope
                                           (env-boolean
                                            "MALKUTH_INCLUDE_DEPENDENCIES" t)))))
           (monitor
             (malkuth.monitor:make-architecture-monitor
              :snapshot-builder builder
              :output-directory output
              :retention (max 1 (env-integer "MALKUTH_HISTORY_RETENTION" 50))
              :export-on-change (env-boolean "MALKUTH_EXPORT_ON_CHANGE" t))))
      (format t "MALKUTH 0.6.0 / monitor ativo / intervalo ~,2Fs / saída ~A~%"
              interval output)
      (malkuth.monitor:run-monitor
       monitor :interval interval :iterations iterations
       :on-poll
       (lambda (state changed-p diff snapshot)
         (declare (ignore diff))
         (format t "[~D] ~:[sem alteração~;arquitetura alterada~] / ~A / ~D pacotes~%"
                 (malkuth.monitor:architecture-monitor-poll-count state)
                 changed-p
                 (malkuth.model:snapshot-fingerprint snapshot)
                 (length (malkuth.model:snapshot-nodes snapshot)))))
      (format t "Monitor encerrado: ~D leituras, ~D alterações.~%"
              (malkuth.monitor:architecture-monitor-poll-count monitor)
              (malkuth.monitor:architecture-monitor-change-count monitor)))
  (error (condition)
    (format *error-output* "~&FALHA NO MONITOR DO MALKUTH: ~A~%" condition)
    (uiop:quit 1)))

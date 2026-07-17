;;;; Relatório de arquitetura do Malkuth sem interface gráfica
;;;;
;;;; Este inicializador é adequado a servidores e integração contínua: carrega
;;;; somente o núcleo portátil, constrói um instantâneo validado, grava o pacote
;;;; de relatórios e aplica políticas arquiteturais com códigos de saída estáveis.

(require :asdf)

;; Normaliza variáveis ausentes e vazias para NIL.
(defun env-value (name)
  (let ((value (uiop:getenv name)))
    (and value (plusp (length value)) value)))


(defun env-integer (name default)
  (let ((text (env-value name)))
    (if text (or (parse-integer text :junk-allowed t) default) default)))

(defun env-boolean (name default)
  (let ((value (env-value name)))
    (if (null value)
        default
        (not (null (member (string-downcase value)
                           '("1" "true" "yes" "on" "sim" "verdadeiro" "ligado") :test #'string=))))))

(defun split-prefixes (text)
  (when text
    (remove-if (lambda (item) (zerop (length item)))
               (uiop:split-string text :separator '(#\, #\Space #\Tab)))))

;; Constrói um predicado reutilizável pelo modelo sem acoplar o núcleo ao ambiente.
(defun prefix-predicate (prefixes)
  (when prefixes
    (lambda (package)
      (let ((name (package-name package)))
        (some (lambda (prefix)
                (and (<= (length prefix) (length name))
                     (string-equal prefix name :end2 (length prefix))))
              prefixes)))))

(defun project-root ()
  (uiop:pathname-directory-pathname *load-truename*))

;; Falhas de carga são operacionais e encerram com código 1.
(handler-case
    (progn
      (asdf:load-asd (merge-pathnames "malkuth.asd" (project-root)))
      (asdf:load-system "malkuth/core"))
  (error (condition)
    (format *error-output* "~&FALHA AO CARREGAR O NÚCLEO DO MALKUTH: ~A~%" condition)
    (uiop:quit 1)))

;; A análise e a avaliação das políticas ficam na mesma barreira para garantir
;; uma mensagem final única e adequada a registros de CI.
(handler-case
    (let* ((scope-prefixes (split-prefixes (env-value "MALKUTH_SCOPE_PREFIXES")))
           (user-prefixes (or (split-prefixes (env-value "MALKUTH_USER_PREFIXES"))
                              scope-prefixes))
           (predicate (prefix-predicate scope-prefixes))
           (user-predicate (prefix-predicate user-prefixes))
           (snapshot (malkuth.model:build-snapshot
                      :package-predicate predicate
                      :user-package-predicate user-predicate
                      :include-dependencies (and scope-prefixes
                                                 (env-boolean "MALKUTH_INCLUDE_DEPENDENCIES" t))))
           (analysis (malkuth.analysis:analyze-snapshot snapshot))
           (output (pathname (or (env-value "MALKUTH_OUTPUT_DIR")
                                 (namestring (merge-pathnames "output/report/"
                                                              (project-root)))))))
      (when (zerop (length (malkuth.model:snapshot-nodes snapshot)))
        (error "O escopo de pacotes configurado não correspondeu a nenhum pacote carregado."))
      (malkuth.model:validate-snapshot snapshot :errorp t)
      (malkuth.export:export-bundle snapshot output :analysis analysis)
      (format t "~&Relatório do MALKUTH concluído.~%Instantâneo: ~S~%Análise: ~S~%Saída: ~A~%"
              (malkuth.model:snapshot-summary snapshot)
              (malkuth.analysis:analysis-summary analysis)
              output)
      ;; Políticas são opcionais. Valores negativos mantêm cada regra desativada.
      (let ((violations '())
            (minimum-health (env-integer "MALKUTH_MIN_HEALTH" -1))
            (maximum-warnings (env-integer "MALKUTH_MAX_WARNINGS" -1)))
        (when (and (>= minimum-health 0)
                   (< (malkuth.analysis:analysis-report-health-score analysis)
                      minimum-health))
          (push (format nil "a pontuação de saúde ~D está abaixo do mínimo exigido de ~D"
                        (malkuth.analysis:analysis-report-health-score analysis)
                        minimum-health)
                violations))
        (when (and (env-boolean "MALKUTH_FAIL_ON_CYCLES" nil)
                   (plusp (length (malkuth.analysis:analysis-report-cycles analysis))))
          (push (format nil "~D ciclo(s) de dependência detectado(s)"
                        (length (malkuth.analysis:analysis-report-cycles analysis)))
                violations))
        (when (and (>= maximum-warnings 0)
                   (> (length (malkuth.analysis:analysis-report-warnings analysis))
                      maximum-warnings))
          (push (format nil "~D avisos excedem o máximo de ~D"
                        (length (malkuth.analysis:analysis-report-warnings analysis))
                        maximum-warnings)
                violations))
        (when violations
          (format *error-output* "~&FALHA NA POLÍTICA DO MALKUTH:~%~{  - ~A~%~}" (nreverse violations))
          (uiop:quit 2))))
  (error (condition)
    (format *error-output* "~&FALHA NA ANÁLISE DO MALKUTH: ~A~%" condition)
    (uiop:quit 1)))

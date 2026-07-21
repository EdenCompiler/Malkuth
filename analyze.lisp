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
                                                              (project-root))))))
           (baseline-path (let ((value (env-value "MALKUTH_BASELINE_FILE")))
                            (and value (pathname value))))
           (baseline-snapshot (and baseline-path (probe-file baseline-path)
                                   (malkuth.history:load-snapshot-file baseline-path)))
           (baseline-analysis (and baseline-snapshot
                                   (malkuth.analysis:analyze-snapshot baseline-snapshot)))
           (architecture-diff (and baseline-snapshot
                                   (malkuth.analysis:compare-architectures
                                    baseline-snapshot snapshot
                                    :old-analysis baseline-analysis
                                    :new-analysis analysis)))
           (policy-path (let ((value (env-value "MALKUTH_POLICY_FILE")))
                          (and value (pathname value))))
           (policy-rules (and policy-path
                              (malkuth.policy:load-policy-file policy-path)))
           (policy-report (and policy-rules
                               (malkuth.policy:evaluate-policies
                                snapshot policy-rules :analysis analysis)))
           (history-directory
             (pathname (or (env-value "MALKUTH_HISTORY_DIR")
                           (namestring (merge-pathnames "historico/" output)))))
           (trend-report nil))
      (when (zerop (length (malkuth.model:snapshot-nodes snapshot)))
        (error "O escopo de pacotes configurado não correspondeu a nenhum pacote carregado."))
      (malkuth.model:validate-snapshot snapshot :errorp t)
      (malkuth.export:export-bundle snapshot output :analysis analysis :policy-report policy-report)
      (when architecture-diff
        (malkuth.export:export-comparison-bundle
         baseline-snapshot snapshot output
         :old-analysis baseline-analysis :new-analysis analysis
         :diff architecture-diff))
      (when policy-report
        (malkuth.export:export-policy-bundle policy-report output))
      (when (env-boolean "MALKUTH_SAVE_HISTORY" nil)
        (malkuth.history:save-history-snapshot
         snapshot history-directory
         :retention (max 1 (env-integer "MALKUTH_HISTORY_RETENTION" 50))
         :label "analise-ci"))
      (when (env-boolean "MALKUTH_EXPORT_TRENDS" nil)
        (setf trend-report
              (malkuth.analysis:analyze-history
               history-directory :current-snapshot snapshot
               :limit (max 1 (env-integer "MALKUTH_TREND_LIMIT" 100))))
        (malkuth.export:export-trend-bundle trend-report output))
      (format t "~&Relatório do MALKUTH concluído.~%Instantâneo: ~S~%Análise: ~S~%Saída: ~A~%"
              (malkuth.model:snapshot-summary snapshot)
              (malkuth.analysis:analysis-summary analysis)
              output)
      (when policy-report
        (format t "Políticas: ~S~%" (malkuth.policy:policy-report-summary policy-report)))
      (when trend-report
        (format t "Tendência: ~S~%" (malkuth.analysis:trend-report-summary trend-report)))
      ;; Políticas são opcionais. Valores negativos mantêm cada regra desativada.
      (let ((violations '())
            (minimum-health (env-integer "MALKUTH_MIN_HEALTH" -1))
            (maximum-warnings (env-integer "MALKUTH_MAX_WARNINGS" -1))
            (maximum-health-regression
              (env-integer "MALKUTH_MAX_HEALTH_REGRESSION" -1))
            (maximum-risk-increases
              (env-integer "MALKUTH_MAX_RISK_INCREASES" -1)))
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
        (when (and architecture-diff
                   (env-boolean "MALKUTH_FAIL_ON_NEW_CYCLES" nil)
                   (plusp (length
                           (malkuth.analysis:architecture-diff-new-cycles
                            architecture-diff))))
          (push (format nil "~D novo(s) ciclo(s) surgiram desde a linha de base"
                        (length
                         (malkuth.analysis:architecture-diff-new-cycles
                          architecture-diff)))
                violations))
        (when (and architecture-diff (>= maximum-health-regression 0)
                   (< (malkuth.analysis:architecture-diff-health-delta architecture-diff)
                      (- maximum-health-regression)))
          (push (format nil "a saúde regrediu ~D ponto(s), acima do máximo de ~D"
                        (- (malkuth.analysis:architecture-diff-health-delta architecture-diff))
                        maximum-health-regression)
                violations))
        (when (and architecture-diff (>= maximum-risk-increases 0)
                   (> (length
                       (malkuth.analysis:architecture-diff-risk-increases
                        architecture-diff))
                      maximum-risk-increases))
          (push (format nil "~D aumentos de risco excedem o máximo de ~D"
                        (length
                         (malkuth.analysis:architecture-diff-risk-increases
                          architecture-diff))
                        maximum-risk-increases)
                violations))
        (when (and policy-report
                   (env-boolean "MALKUTH_FAIL_ON_POLICY" t)
                   (not (malkuth.policy:policy-report-passed-p policy-report)))
          (push (format nil "~D violação(ões) de política com severidade erro"
                        (malkuth.policy:policy-report-error-count policy-report))
                violations))
        (when violations
          (format *error-output* "~&FALHA NA POLÍTICA DO MALKUTH:~%~{  - ~A~%~}" (nreverse violations))
          (uiop:quit 2))
        (when (and baseline-path (env-boolean "MALKUTH_UPDATE_BASELINE" nil))
          (malkuth.history:save-snapshot-file
           snapshot baseline-path :label "linha-de-base-ci")
          (format t "Linha de base atualizada em ~A.~%" baseline-path))))
  (error (condition)
    (format *error-output* "~&FALHA NA ANÁLISE DO MALKUTH: ~A~%" condition)
    (uiop:quit 1)))

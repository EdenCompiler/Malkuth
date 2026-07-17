;;;; Políticas arquiteturais declarativas
;;;;
;;;; Este módulo transforma expectativas de arquitetura em regras versionadas e
;;;; reproduzíveis. O formato usa S-expressions lidas com *READ-EVAL* desativado,
;;;; seguindo o mesmo modelo de segurança adotado pelo histórico do Malkuth.

(in-package #:malkuth.policy)

(defparameter +policy-format-version+ 1)

(defstruct policy-rule
  (id "regra-sem-id" :type string)
  (type :forbid-dependency :type keyword)
  (severity :error :type keyword)
  from
  to
  package
  value
  layers
  message)

(defstruct policy-violation
  (rule-id "" :type string)
  (type :unknown :type keyword)
  (severity :error :type keyword)
  package
  target
  (message "" :type string))

(defstruct policy-report
  (rules nil :type list)
  (violations nil :type list)
  (error-count 0 :type fixnum)
  (warning-count 0 :type fixnum)
  (fingerprint "" :type string))

(defun policy-report-passed-p (report)
  "Retorna verdadeiro quando nenhuma violação de severidade :ERROR foi encontrada."
  (zerop (policy-report-error-count report)))

(defun policy-value (record key &optional default)
  "Lê KEY de uma lista de propriedades sem confundir NIL com ausência."
  (let ((marker (gensym "AUSENTE")))
    (let ((value (getf record key marker)))
      (if (eq value marker) default value))))

(defun normalize-severity (value)
  (let ((severity (if (keywordp value)
                      value
                      (intern (string-upcase (princ-to-string value)) :keyword))))
    (unless (member severity '(:info :warning :error))
      (error "Severidade de política inválida: ~S" value))
    severity))

(defun normalize-rule-type (value)
  (let ((type (if (keywordp value)
                  value
                  (intern (string-upcase (princ-to-string value)) :keyword))))
    (unless (member type '(:forbid-dependency :require-dependency
                           :max-fan-out :max-fan-in :max-risk :max-symbols
                           :forbid-cycle :layer-order))
      (error "Tipo de política desconhecido: ~S" value))
    type))

(defun wildcard-match-p (pattern value)
  "Compara VALUE com PATTERN usando * para qualquer sequência e ? para um caractere.

A comparação ignora diferenças entre maiúsculas e minúsculas. O algoritmo usa
programação dinâmica para evitar a explosão exponencial de implementações
recursivas ingênuas."
  (let* ((pattern (string-upcase (princ-to-string pattern)))
         (value (string-upcase (princ-to-string value)))
         (rows (1+ (length pattern)))
         (columns (1+ (length value)))
         (table (make-array (list rows columns) :element-type 'bit
                                                 :initial-element 0)))
    (setf (aref table 0 0) 1)
    (loop for i from 1 below rows
          when (char= (char pattern (1- i)) #\*)
            do (setf (aref table i 0) (aref table (1- i) 0)))
    (loop for i from 1 below rows
          for pchar = (char pattern (1- i))
          do (loop for j from 1 below columns
                   for vchar = (char value (1- j))
                   do (setf (aref table i j)
                            (if (char= pchar #\*)
                                (if (or (= 1 (aref table (1- i) j))
                                        (= 1 (aref table i (1- j)))) 1 0)
                                (if (and (or (char= pchar #\?)
                                             (char= pchar vchar))
                                         (= 1 (aref table (1- i) (1- j))))
                                    1 0)))))
    (= 1 (aref table (1- rows) (1- columns)))))

(defun ensure-pattern (value field rule-id)
  (unless (and value (plusp (length (princ-to-string value))))
    (error "A regra ~A exige o campo ~A." rule-id field))
  (princ-to-string value))

(defun policy-from-record (record)
  "Valida e converte um registro de regra em POLICY-RULE."
  (unless (listp record)
    (error "Regra de política inválida: ~S" record))
  (let* ((id (princ-to-string (policy-value record :id "regra-sem-id")))
         (type (normalize-rule-type (policy-value record :type nil)))
         (severity (normalize-severity (policy-value record :severity :error)))
         (from (policy-value record :from nil))
         (to (policy-value record :to nil))
         (package (policy-value record :package nil))
         (value (policy-value record :value nil))
         (layers (policy-value record :layers nil))
         (message (policy-value record :message nil)))
    (case type
      ((:forbid-dependency :require-dependency)
       (setf from (ensure-pattern from :from id)
             to (ensure-pattern to :to id)))
      ((:max-fan-out :max-fan-in :max-risk :max-symbols)
       (setf package (ensure-pattern (or package "*") :package id))
       (unless (and (integerp value) (>= value 0))
         (error "A regra ~A exige :VALUE inteiro não negativo." id)))
      (:forbid-cycle
       (setf package (ensure-pattern (or package "*") :package id)))
      (:layer-order
       (unless (and (listp layers) (>= (length layers) 2)
                    (every (lambda (item)
                             (and item (plusp (length (princ-to-string item)))))
                           layers))
         (error "A regra ~A exige pelo menos duas camadas em :LAYERS." id))
       (setf layers (mapcar #'princ-to-string layers))))
    (make-policy-rule :id id :type type :severity severity
                      :from (and from (princ-to-string from))
                      :to (and to (princ-to-string to))
                      :package (and package (princ-to-string package))
                      :value value :layers layers
                      :message (and message (princ-to-string message)))))

(defun policy-record (rules &key label)
  "Cria o documento de políticas persistível a partir de RULES."
  (list :malkuth-policy t
        :format-version +policy-format-version+
        :label label
        :rules
        (mapcar (lambda (rule)
                  (list :id (policy-rule-id rule)
                        :type (policy-rule-type rule)
                        :severity (policy-rule-severity rule)
                        :from (policy-rule-from rule)
                        :to (policy-rule-to rule)
                        :package (policy-rule-package rule)
                        :value (policy-rule-value rule)
                        :layers (policy-rule-layers rule)
                        :message (policy-rule-message rule)))
                rules)))

(defun rules-from-document (document)
  "Valida o cabeçalho do documento e devolve suas regras normalizadas."
  (unless (and (listp document)
               (policy-value document :malkuth-policy nil)
               (= (policy-value document :format-version -1)
                  +policy-format-version+))
    (error "O arquivo não contém políticas compatíveis do Malkuth."))
  (mapcar #'policy-from-record (policy-value document :rules '())))

(defun load-policy-file (pathname)
  "Carrega políticas de PATHNAME com avaliação de leitura desativada."
  (with-open-file (stream pathname :direction :input :external-format :utf-8)
    (let ((*read-eval* nil))
      (rules-from-document (read stream nil nil)))))

(defun save-policy-file (rules pathname &key label)
  "Grava RULES de forma atômica usando a infraestrutura segura do histórico."
  (malkuth.history::atomic-write-history-file
   pathname
   (lambda (stream)
     (let ((*print-pretty* t)
           (*print-readably* t)
           (*print-circle* nil))
       (write (policy-record rules :label label) :stream stream)
       (terpri stream)))))

(defun example-policy-record ()
  "Retorna um exemplo completo que pode ser gravado como malkuth-politicas.sexp."
  (list :malkuth-policy t
        :format-version +policy-format-version+
        :label "políticas de exemplo"
        :rules
        '((:id "dominio-sem-ui"
           :type :forbid-dependency :severity :error
           :from "MEU-APP.DOMINIO*" :to "MEU-APP.UI*"
           :message "A camada de domínio não pode depender da interface.")
          (:id "fanout-controlado"
           :type :max-fan-out :severity :warning
           :package "MEU-APP.*" :value 8)
          (:id "risco-local"
           :type :max-risk :severity :warning
           :package "MEU-APP.*" :value 45)
          (:id "ordem-das-camadas"
           :type :layer-order :severity :error
           :layers ("MEU-APP.DOMINIO*" "MEU-APP.APLICACAO*" "MEU-APP.UI*")))))

(defun node-matches-p (node pattern)
  (and pattern (wildcard-match-p pattern (node-name node))))

(defun violation-message (rule default)
  (or (policy-rule-message rule) default))

(defun make-rule-violation (rule package message &optional target)
  (make-policy-violation
   :rule-id (policy-rule-id rule)
   :type (policy-rule-type rule)
   :severity (policy-rule-severity rule)
   :package package :target target
   :message (violation-message rule message)))

(defun cycle-member-p (analysis name)
  (some (lambda (cycle) (member name cycle :test #'string-equal))
        (analysis-report-cycles analysis)))

(defun node-layer-index (node layers)
  (position-if (lambda (pattern) (node-matches-p node pattern)) layers))

(defun evaluate-policy-rule (snapshot analysis rule)
  "Avalia uma regra isolada e devolve todas as violações encontradas."
  (let ((nodes (snapshot-nodes snapshot))
        (violations '()))
    (labels ((emit (package message &optional target)
               (push (make-rule-violation rule package message target) violations)))
      (case (policy-rule-type rule)
        (:forbid-dependency
         (loop for edge across (snapshot-edges snapshot)
               for from = (aref nodes (edge-from edge))
               for to = (aref nodes (edge-to edge))
               when (and (node-matches-p from (policy-rule-from rule))
                         (node-matches-p to (policy-rule-to rule)))
                 do (emit (node-name from)
                          (format nil "~A não pode depender de ~A."
                                  (node-name from) (node-name to))
                          (node-name to))))
        (:require-dependency
         (loop for node across nodes
               when (node-matches-p node (policy-rule-from rule))
                 do (unless (some (lambda (dependency)
                                    (node-matches-p dependency (policy-rule-to rule)))
                                  (node-dependencies snapshot node))
                      (emit (node-name node)
                            (format nil "~A deve depender de um pacote compatível com ~A."
                                    (node-name node) (policy-rule-to rule))))))
        ((:max-fan-out :max-fan-in :max-risk :max-symbols)
         (loop for node across nodes
               do (when (node-matches-p node (policy-rule-package rule))
                    (let* ((metric (metrics-for-node analysis node))
                           (actual (ecase (policy-rule-type rule)
                                     (:max-fan-out (node-metrics-fan-out metric))
                                     (:max-fan-in (node-metrics-fan-in metric))
                                     (:max-risk (node-metrics-risk-score metric))
                                     (:max-symbols (+ (node-internal node)
                                                      (node-external node))))))
                      (when (> actual (policy-rule-value rule))
                        (emit (node-name node)
                              (format nil "~A possui valor ~D, acima do limite ~D para ~A."
                                      (node-name node) actual (policy-rule-value rule)
                                      (policy-rule-type rule))))))))
        (:forbid-cycle
         (loop for node across nodes
               when (and (node-matches-p node (policy-rule-package rule))
                         (cycle-member-p analysis (node-name node)))
                 do (emit (node-name node)
                          (format nil "~A participa de um ciclo proibido."
                                  (node-name node)))))
        (:layer-order
         ;; Camadas anteriores são fundamentais. Uma aresta de índice menor para
         ;; índice maior representa dependência ascendente e viola a direção.
         (loop for edge across (snapshot-edges snapshot)
               for from = (aref nodes (edge-from edge))
               for to = (aref nodes (edge-to edge))
               for from-layer = (node-layer-index from (policy-rule-layers rule))
               for to-layer = (node-layer-index to (policy-rule-layers rule))
               when (and from-layer to-layer (< from-layer to-layer))
                 do (emit (node-name from)
                          (format nil "~A, na camada ~D, depende da camada superior ~D por meio de ~A."
                                  (node-name from) from-layer to-layer (node-name to))
                          (node-name to)))))
      (nreverse violations))))

(defun evaluate-policies (snapshot rules &key analysis)
  "Avalia RULES sobre SNAPSHOT e devolve um relatório determinístico."
  (let* ((analysis (or analysis (analyze-snapshot snapshot)))
         (rules (mapcar (lambda (rule)
                          (etypecase rule
                            (policy-rule rule)
                            (list (policy-from-record rule))))
                        rules))
         (violations
           (loop for rule in rules append (evaluate-policy-rule snapshot analysis rule)))
         (violations
           (stable-sort violations
                        (lambda (left right)
                          (let ((left-package (or (policy-violation-package left) ""))
                                (right-package (or (policy-violation-package right) "")))
                            (if (string= left-package right-package)
                                (string< (policy-violation-rule-id left)
                                         (policy-violation-rule-id right))
                                (string< left-package right-package)))))))
    (make-policy-report
     :rules rules :violations violations
     :error-count (count :error violations :key #'policy-violation-severity)
     :warning-count (count :warning violations :key #'policy-violation-severity)
     :fingerprint (snapshot-fingerprint snapshot))))

(defun violating-package-names (report)
  "Lista nomes de pacotes envolvidos em violações, sem duplicatas."
  (sort (remove-duplicates
         (loop for violation in (policy-report-violations report)
               append (remove nil (list (policy-violation-package violation)
                                        (policy-violation-target violation))))
         :test #'string-equal)
        #'string<))

(defun policy-report-summary (report)
  "Resume REPORT em uma lista de propriedades adequada a logs e automação."
  (list :passed (policy-report-passed-p report)
        :rules (length (policy-report-rules report))
        :violations (length (policy-report-violations report))
        :errors (policy-report-error-count report)
        :warnings (policy-report-warning-count report)
        :packages (length (violating-package-names report))
        :fingerprint (policy-report-fingerprint report)))

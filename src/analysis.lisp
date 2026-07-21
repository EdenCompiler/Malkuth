;;;; Análise arquitetural da topologia de pacotes
;;;;
;;;; Este módulo calcula graus, componentes fortemente conexos, avisos, risco
;;;; local e uma pontuação heurística global. As métricas orientam revisão humana.

(in-package #:malkuth.analysis)

(defstruct node-metrics
  (node-id 0 :type fixnum)
  (name "" :type string)
  (fan-in 0 :type fixnum)
  (fan-out 0 :type fixnum)
  (total-degree 0 :type fixnum)
  (symbols 0 :type fixnum)
  ;; Métricas transitivas revelam impacto arquitetural que fan-in/fan-out direto
  ;; não capturam. BLAST-RADIUS representa quantos pacotes podem ser afetados
  ;; indiretamente por uma alteração neste pacote.
  (transitive-dependencies 0 :type fixnum)
  (transitive-dependents 0 :type fixnum)
  (blast-radius 0 :type fixnum)
  (instability 0 :type fixnum)
  (risk-score 0 :type fixnum))

(defstruct analysis-warning
  (severity :info :type keyword)
  (code :unknown :type keyword)
  package
  (message "" :type string))

(defstruct analysis-report
  (metrics #() :type vector)
  (cycles nil :type list)
  (orphans nil :type list)
  (hubs nil :type list)
  (warnings nil :type list)
  (health-score 100 :type fixnum)
  (fingerprint "" :type string))

(defstruct package-change
  (name "" :type string)
  (symbol-delta 0 :type integer)
  (function-delta 0 :type integer)
  (macro-delta 0 :type integer)
  (class-delta 0 :type integer))

(defstruct snapshot-diff
  (added-packages nil :type list)
  (removed-packages nil :type list)
  (changed-packages nil :type list)
  (symbol-delta 0 :type integer)
  (function-delta 0 :type integer)
  (macro-delta 0 :type integer)
  (class-delta 0 :type integer))

(defun build-degree-tables (snapshot)
  (let* ((count (length (snapshot-nodes snapshot)))
         (fan-in (make-array count :element-type 'fixnum :initial-element 0))
         (fan-out (make-array count :element-type 'fixnum :initial-element 0)))
    (loop for edge across (snapshot-edges snapshot)
          do (incf (aref fan-out (edge-from edge)))
             (incf (aref fan-in (edge-to edge))))
    (values fan-in fan-out)))

(defun adjacency-vector (snapshot)
  (let ((adjacency (make-array (length (snapshot-nodes snapshot))
                               :initial-element nil)))
    (loop for edge across (snapshot-edges snapshot)
          do (push (edge-to edge) (aref adjacency (edge-from edge))))
    adjacency))

(defun strongly-connected-components (snapshot)
  "Calcula componentes fortemente conexos pelo algoritmo de Tarjan e retorna listas de identificadores de nós."
  (let* ((adjacency (adjacency-vector snapshot))
         (count (length adjacency))
         (index 0)
         (indices (make-array count :initial-element -1))
         (lowlinks (make-array count :initial-element 0))
         (on-stack (make-array count :initial-element nil))
         (stack '())
         (components '()))
    (labels ((visit (vertex)
               (setf (aref indices vertex) index
                     (aref lowlinks vertex) index)
               (incf index)
               (push vertex stack)
               (setf (aref on-stack vertex) t)
               (dolist (target (aref adjacency vertex))
                 (cond
                   ((minusp (aref indices target))
                    (visit target)
                    (setf (aref lowlinks vertex)
                          (min (aref lowlinks vertex) (aref lowlinks target))))
                   ((aref on-stack target)
                    (setf (aref lowlinks vertex)
                          (min (aref lowlinks vertex) (aref indices target))))))
               (when (= (aref lowlinks vertex) (aref indices vertex))
                 (let ((component '()))
                   (loop
                     for current = (pop stack)
                     do (setf (aref on-stack current) nil)
                        (push current component)
                     until (= current vertex))
                   (push (nreverse component) components)))))
      (dotimes (vertex count)
        (when (minusp (aref indices vertex))
          (visit vertex))))
    (nreverse components)))

(defun self-loop-p (snapshot node-id)
  (loop for edge across (snapshot-edges snapshot)
        thereis (and (= (edge-from edge) node-id)
                     (= (edge-to edge) node-id))))

(defun cycle-components (snapshot)
  (let ((nodes (snapshot-nodes snapshot)))
    (loop for component in (strongly-connected-components snapshot)
          when (or (> (length component) 1)
                   (and (= (length component) 1)
                        (self-loop-p snapshot (first component))))
            collect (sort (mapcar (lambda (id) (node-name (aref nodes id))) component)
                          #'string<))))

(defun risk-score-for (node fan-in fan-out cyclic-p)
  (let ((symbols (+ (node-internal node) (node-external node)))
        (risk 0))
    (when (> symbols 800) (incf risk 12))
    (when (> symbols 2000) (incf risk 12))
    (when (> fan-out 8) (incf risk 10))
    (when (> fan-out 16) (incf risk 10))
    (when (> fan-in 16) (incf risk 8))
    (when cyclic-p (incf risk 28))
    (min 100 risk)))

(defun make-warning-for-large-package (node)
  (let ((symbols (+ (node-internal node) (node-external node))))
    (when (> symbols 2000)
      (make-analysis-warning
       :severity :warning :code :large-package :package (node-name node)
       :message (format nil "~A possui ~:D símbolos; considere dividir suas responsabilidades."
                        (node-name node) symbols)))))

(defun make-warning-for-fan-out (node fan-out)
  (when (> fan-out 12)
    (make-analysis-warning
     :severity :warning :code :high-fan-out :package (node-name node)
     :message (format nil "~A usa diretamente ~D pacotes; sua superfície de dependências é ampla."
                      (node-name node) fan-out))))

(defun analyze-snapshot (snapshot &key (hub-limit 8) (warning-kinds '(:user)) (health-kinds '(:user)))
  "Calcula acoplamento entre pacotes, ciclos, avisos de arquitetura e uma pontuação heurística."
  (multiple-value-bind (valid-p validation-problems) (validate-snapshot snapshot)
    (multiple-value-bind (fan-in fan-out) (build-degree-tables snapshot)
      (let* ((nodes (snapshot-nodes snapshot))
             (all-cycles (cycle-components snapshot))
             (cycles (remove-if-not
                      (lambda (cycle)
                        (some (lambda (name)
                                (let ((node (find-node-by-name snapshot name)))
                                  (and node (member (node-kind node) health-kinds))))
                              cycle))
                      all-cycles))
             (cyclic-names (make-hash-table :test #'equal))
             (warnings '()))
        (dolist (cycle cycles)
          (dolist (name cycle) (setf (gethash name cyclic-names) t))
          (push (make-analysis-warning
                 :severity :warning :code :dependency-cycle
                 :message (format nil "Ciclo de dependência: ~{~A~^ -> ~}." cycle))
                warnings))
        (dolist (problem validation-problems)
          (push (make-analysis-warning :severity :error :code :invalid-snapshot
                                       :message problem)
                warnings))
        (let ((metrics
                (map 'vector
                     (lambda (node)
                       (let* ((id (node-id node))
                              (in (aref fan-in id))
                              (out (aref fan-out id)))
                         (when (member (node-kind node) warning-kinds)
                           (let ((large (make-warning-for-large-package node))
                                 (wide (make-warning-for-fan-out node out)))
                             (when large (push large warnings))
                             (when wide (push wide warnings))))
                         (let* ((transitive-dependencies
                                  (length (node-transitive-dependency-ids snapshot node)))
                                (transitive-dependents
                                  (length (node-transitive-dependent-ids snapshot node)))
                                (degree (+ in out))
                                (instability (if (zerop degree) 0
                                                 (round (* 100 (/ out degree))))))
                           (make-node-metrics
                            :node-id id :name (node-name node)
                            :fan-in in :fan-out out :total-degree degree
                            :symbols (+ (node-internal node) (node-external node))
                            :transitive-dependencies transitive-dependencies
                            :transitive-dependents transitive-dependents
                            :blast-radius transitive-dependents
                            :instability instability
                            :risk-score (risk-score-for node in out
                                                       (gethash (node-name node) cyclic-names))))))
                     nodes)))
          (let* ((orphans
                   (sort (loop for metric across metrics
                               for node = (aref nodes (node-metrics-node-id metric))
                               when (and (member (node-kind node) health-kinds)
                                         (zerop (node-metrics-total-degree metric)))
                                 collect (node-metrics-name metric))
                         #'string<))
                 (hubs
                   (subseq (sort (coerce metrics 'list) #'>
                                 :key #'node-metrics-total-degree)
                           0 (min hub-limit (length metrics))))
                 (cycle-penalty (min 35 (* 6 (length cycles))))
                 (health-node-count
                   (loop for node across nodes count (member (node-kind node) health-kinds)))
                 (orphan-penalty (if (zerop health-node-count) 0
                                     (min 10 (round (* 25 (/ (length orphans)
                                                              health-node-count))))))
                 (warning-penalty
                   (min 35 (loop for item in warnings
                                 sum (ecase (analysis-warning-severity item)
                                       (:info 0) (:warning 2) (:error 10)))))
                 (health (max 0 (- 100 cycle-penalty orphan-penalty warning-penalty
                                   (if valid-p 0 20)))))
            (make-analysis-report
             :metrics metrics
             :cycles cycles
             :orphans orphans
             :hubs hubs
             :warnings (nreverse warnings)
             :health-score health
             :fingerprint (snapshot-fingerprint snapshot))))))))

(defun metrics-for-node (report node-or-name)
  (let ((name (etypecase node-or-name
                (node (node-name node-or-name))
                (string node-or-name))))
    (find name (analysis-report-metrics report)
          :key #'node-metrics-name :test #'string-equal)))

(defun critical-metrics (report &key (limit 10) (minimum-blast-radius 1))
  "Retorna os pacotes com maior raio de impacto arquitetural.

A ordenação prioriza dependentes transitivos, risco local e grau total. LIMIT
controla o tamanho da lista e MINIMUM-BLAST-RADIUS remove pacotes sem impacto
significativo. O nome funciona como desempate estável."
  (let ((items
          (remove-if (lambda (metric)
                       (< (node-metrics-blast-radius metric) minimum-blast-radius))
                     (coerce (analysis-report-metrics report) 'list))))
    (setf items
          (stable-sort items
                       (lambda (left right)
                         (or (> (node-metrics-blast-radius left)
                                (node-metrics-blast-radius right))
                             (and (= (node-metrics-blast-radius left)
                                     (node-metrics-blast-radius right))
                                  (> (node-metrics-risk-score left)
                                     (node-metrics-risk-score right)))
                             (and (= (node-metrics-blast-radius left)
                                     (node-metrics-blast-radius right))
                                  (= (node-metrics-risk-score left)
                                     (node-metrics-risk-score right))
                                  (> (node-metrics-total-degree left)
                                     (node-metrics-total-degree right)))
                             (and (= (node-metrics-blast-radius left)
                                     (node-metrics-blast-radius right))
                                  (= (node-metrics-risk-score left)
                                     (node-metrics-risk-score right))
                                  (= (node-metrics-total-degree left)
                                     (node-metrics-total-degree right))
                                  (string< (node-metrics-name left)
                                           (node-metrics-name right)))))))
    (subseq items 0 (min limit (length items)))))

(defun analysis-summary (report)
  (list :health-score (analysis-report-health-score report)
        :cycles (length (analysis-report-cycles report))
        :orphans (length (analysis-report-orphans report))
        :warnings (length (analysis-report-warnings report))
        :fingerprint (analysis-report-fingerprint report)
        :top-hubs (mapcar (lambda (metric)
                            (list :name (node-metrics-name metric)
                                  :degree (node-metrics-total-degree metric)
                                  :fan-in (node-metrics-fan-in metric)
                                  :fan-out (node-metrics-fan-out metric)))
                          (analysis-report-hubs report))))

(defun node-counts (node)
  (values (+ (node-internal node) (node-external node))
          (node-functions node) (node-macros node) (node-classes node)))

(defun snapshot-node-table (snapshot)
  (let ((table (make-hash-table :test #'equal)))
    (loop for node across (snapshot-nodes snapshot)
          do (setf (gethash (node-name node) table) node))
    table))

(defun compare-snapshots (old new)
  "Compara dois instantâneos da imagem ativa pelo nome estável dos pacotes."
  (let ((old-table (snapshot-node-table old))
        (new-table (snapshot-node-table new))
        (added '()) (removed '()) (changed '()))
    (maphash (lambda (name new-node)
               (let ((old-node (gethash name old-table)))
                 (if (null old-node)
                     (push name added)
                     (multiple-value-bind (old-symbols old-functions old-macros old-classes)
                         (node-counts old-node)
                       (multiple-value-bind (new-symbols new-functions new-macros new-classes)
                           (node-counts new-node)
                         (let ((symbol-delta (- new-symbols old-symbols))
                               (function-delta (- new-functions old-functions))
                               (macro-delta (- new-macros old-macros))
                               (class-delta (- new-classes old-classes)))
                           (unless (zerop (+ (abs symbol-delta) (abs function-delta)
                                           (abs macro-delta) (abs class-delta)))
                             (push (make-package-change
                                    :name name :symbol-delta symbol-delta
                                    :function-delta function-delta
                                    :macro-delta macro-delta :class-delta class-delta)
                                   changed))))))))
             new-table)
    (maphash (lambda (name old-node)
               (declare (ignore old-node))
               (unless (gethash name new-table) (push name removed)))
             old-table)
    (make-snapshot-diff
     :added-packages (sort added #'string<)
     :removed-packages (sort removed #'string<)
     :changed-packages (sort changed #'string< :key #'package-change-name)
     :symbol-delta (- (snapshot-total-symbols new) (snapshot-total-symbols old))
     :function-delta (- (snapshot-total-functions new) (snapshot-total-functions old))
     :macro-delta (- (snapshot-total-macros new) (snapshot-total-macros old))
     :class-delta (- (snapshot-total-classes new) (snapshot-total-classes old)))))

;;;; Comparação arquitetural entre uma linha de base e o estado corrente

(defstruct risk-change
  (name "" :type string)
  (old-risk 0 :type fixnum)
  (new-risk 0 :type fixnum)
  (delta 0 :type integer))

(defstruct architecture-diff
  snapshot-diff
  (health-delta 0 :type integer)
  (warning-delta 0 :type integer)
  (new-cycles nil :type list)
  (resolved-cycles nil :type list)
  (risk-increases nil :type list)
  (risk-decreases nil :type list))

(defun metric-table (report)
  "Cria um índice por nome para comparar risco entre dois relatórios."
  (let ((table (make-hash-table :test #'equal)))
    (loop for metric across (analysis-report-metrics report)
          do (setf (gethash (node-metrics-name metric) table) metric))
    table))

(defun sorted-cycle-copy (cycles)
  "Normaliza ciclos para comparações independentes da ordem das listas."
  (sort (mapcar (lambda (cycle) (sort (copy-list cycle) #'string<)) cycles)
        #'string< :key (lambda (cycle) (format nil "~{~A~^|~}" cycle))))

(defun compare-architectures (old-snapshot new-snapshot
                              &key old-analysis new-analysis)
  "Compara estrutura, saúde, ciclos e risco local entre dois instantâneos."
  (let* ((old-analysis (or old-analysis (analyze-snapshot old-snapshot)))
         (new-analysis (or new-analysis (analyze-snapshot new-snapshot)))
         (old-cycles (sorted-cycle-copy (analysis-report-cycles old-analysis)))
         (new-cycles (sorted-cycle-copy (analysis-report-cycles new-analysis)))
         (old-table (metric-table old-analysis))
         (new-table (metric-table new-analysis))
         (increases '())
         (decreases '()))
    (maphash
     (lambda (name new-metric)
       (let ((old-metric (gethash name old-table)))
         (when old-metric
           (let* ((old-risk (node-metrics-risk-score old-metric))
                  (new-risk (node-metrics-risk-score new-metric))
                  (delta (- new-risk old-risk)))
             (cond
               ((plusp delta)
                (push (make-risk-change :name name :old-risk old-risk
                                        :new-risk new-risk :delta delta)
                      increases))
               ((minusp delta)
                (push (make-risk-change :name name :old-risk old-risk
                                        :new-risk new-risk :delta delta)
                      decreases)))))))
     new-table)
    (flet ((risk-order (left right)
             (if (= (abs (risk-change-delta left))
                    (abs (risk-change-delta right)))
                 (string< (risk-change-name left) (risk-change-name right))
                 (> (abs (risk-change-delta left))
                    (abs (risk-change-delta right))))))
      (make-architecture-diff
       :snapshot-diff (compare-snapshots old-snapshot new-snapshot)
       :health-delta (- (analysis-report-health-score new-analysis)
                        (analysis-report-health-score old-analysis))
       :warning-delta (- (length (analysis-report-warnings new-analysis))
                         (length (analysis-report-warnings old-analysis)))
       :new-cycles (set-difference new-cycles old-cycles :test #'equal)
       :resolved-cycles (set-difference old-cycles new-cycles :test #'equal)
       :risk-increases (sort increases #'risk-order)
       :risk-decreases (sort decreases #'risk-order)))))

(defun architecture-diff-summary (diff)
  "Resume DIFF em uma lista de propriedades adequada a logs e automação."
  (let ((snapshot-diff (architecture-diff-snapshot-diff diff)))
    (list :health-delta (architecture-diff-health-delta diff)
          :warning-delta (architecture-diff-warning-delta diff)
          :added-packages (length (snapshot-diff-added-packages snapshot-diff))
          :removed-packages (length (snapshot-diff-removed-packages snapshot-diff))
          :changed-packages (length (snapshot-diff-changed-packages snapshot-diff))
          :new-cycles (length (architecture-diff-new-cycles diff))
          :resolved-cycles (length (architecture-diff-resolved-cycles diff))
          :risk-increases (length (architecture-diff-risk-increases diff))
          :risk-decreases (length (architecture-diff-risk-decreases diff)))))

;;;; Série temporal do histórico arquitetural

(defstruct trend-point
  (created-at 0 :type integer)
  (fingerprint "" :type string)
  (packages 0 :type fixnum)
  (dependencies 0 :type fixnum)
  (symbols 0 :type fixnum)
  (health-score 0 :type fixnum)
  (cycles 0 :type fixnum)
  (warnings 0 :type fixnum))

(defstruct trend-report
  (points nil :type list)
  (health-min 0 :type fixnum)
  (health-max 0 :type fixnum)
  (health-delta 0 :type integer)
  (package-delta 0 :type integer)
  (dependency-delta 0 :type integer)
  (symbol-delta 0 :type integer)
  (ignored-files nil :type list))

(defun snapshot-trend-point (snapshot &key analysis)
  "Resume SNAPSHOT em um ponto compacto adequado a gráficos e históricos."
  (let ((analysis (or analysis (analyze-snapshot snapshot))))
    (make-trend-point
     :created-at (snapshot-created-at snapshot)
     :fingerprint (snapshot-fingerprint snapshot)
     :packages (length (snapshot-nodes snapshot))
     :dependencies (length (snapshot-edges snapshot))
     :symbols (snapshot-total-symbols snapshot)
     :health-score (analysis-report-health-score analysis)
     :cycles (length (analysis-report-cycles analysis))
     :warnings (length (analysis-report-warnings analysis)))))

(defun make-trend-report-from-points (points &key ignored-files)
  "Constrói estatísticas agregadas para POINTS já ordenados do mais antigo ao atual."
  (let* ((points (sort (copy-list points) #'< :key #'trend-point-created-at))
         (first (first points))
         (last (car (last points)))
         (health-values (mapcar #'trend-point-health-score points)))
    (make-trend-report
     :points points
     :health-min (if points (reduce #'min health-values) 0)
     :health-max (if points (reduce #'max health-values) 0)
     :health-delta (if points (- (trend-point-health-score last)
                                 (trend-point-health-score first)) 0)
     :package-delta (if points (- (trend-point-packages last)
                                  (trend-point-packages first)) 0)
     :dependency-delta (if points (- (trend-point-dependencies last)
                                     (trend-point-dependencies first)) 0)
     :symbol-delta (if points (- (trend-point-symbols last)
                                 (trend-point-symbols first)) 0)
     :ignored-files ignored-files)))

(defun analyze-history (directory &key current-snapshot (limit 100) (ignore-errors t))
  "Analisa os instantâneos persistidos em DIRECTORY como uma série temporal.

CURRENT-SNAPSHOT pode ser acrescentado ao fim sem gravá-lo. Arquivos corrompidos
são listados em IGNORED-FILES quando IGNORE-ERRORS é verdadeiro; no modo estrito,
o erro de leitura é propagado para CI e manutenção."
  (let ((points '())
        (ignored '())
        (files (subseq (malkuth.history:history-files directory)
                       0 (min (max 0 limit)
                              (length (malkuth.history:history-files directory))))))
    ;; HISTORY-FILES devolve os mais novos primeiro; a ordenação final restaura a
    ;; ordem cronológica e elimina duplicatas de impressão digital.
    (dolist (path files)
      (handler-case
          (push (snapshot-trend-point (malkuth.history:load-snapshot-file path)) points)
        (error (condition)
          (if ignore-errors
              (push (cons path (princ-to-string condition)) ignored)
              (error condition)))))
    (when current-snapshot
      (push (snapshot-trend-point current-snapshot) points))
    (let ((seen (make-hash-table :test #'equal))
          (unique '()))
      (dolist (point (sort points #'< :key #'trend-point-created-at))
        (unless (gethash (trend-point-fingerprint point) seen)
          (setf (gethash (trend-point-fingerprint point) seen) t)
          (push point unique)))
      (make-trend-report-from-points (nreverse unique)
                                     :ignored-files (nreverse ignored)))))

(defun trend-report-summary (report)
  "Resume a tendência arquitetural em propriedades estáveis para logs."
  (list :points (length (trend-report-points report))
        :health-min (trend-report-health-min report)
        :health-max (trend-report-health-max report)
        :health-delta (trend-report-health-delta report)
        :package-delta (trend-report-package-delta report)
        :dependency-delta (trend-report-dependency-delta report)
        :symbol-delta (trend-report-symbol-delta report)
        :ignored-files (length (trend-report-ignored-files report))))

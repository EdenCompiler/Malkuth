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
                         (make-node-metrics
                          :node-id id :name (node-name node)
                          :fan-in in :fan-out out :total-degree (+ in out)
                          :symbols (+ (node-internal node) (node-external node))
                          :risk-score (risk-score-for node in out
                                                     (gethash (node-name node) cyclic-names)))))
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

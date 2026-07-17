;;;; Persistência segura e histórico de instantâneos
;;;;
;;;; O histórico usa S-expressions estritamente estruturadas porque o núcleo do
;;;; Malkuth não depende de uma biblioteca JSON. A leitura sempre desativa
;;;; *READ-EVAL* e valida o instantâneo reconstruído antes de devolvê-lo.

(in-package #:malkuth.history)

(defparameter +history-format-version+ 1)

(defun temporary-history-pathname (pathname)
  "Cria um nome temporário vizinho para substituição atômica."
  (make-pathname :name (format nil "~A.~36R.tmp"
                               (or (pathname-name pathname) "malkuth")
                               (random (expt 36 8)))
                 :type (pathname-type pathname)
                 :defaults pathname))

(defun atomic-write-history-file (pathname writer)
  "Executa WRITER em um temporário e substitui PATHNAME somente ao concluir."
  (let* ((pathname (merge-pathnames pathname (uiop:getcwd)))
         (temporary (temporary-history-pathname pathname)))
    (ensure-directories-exist pathname)
    (unwind-protect
         (progn
           (with-open-file (stream temporary :direction :output
                                            :if-exists :supersede
                                            :if-does-not-exist :create
                                            :external-format :utf-8)
             (funcall writer stream)
             (finish-output stream))
           (uiop:rename-file-overwriting-target temporary pathname)
           pathname)
      (when (probe-file temporary)
        (ignore-errors (delete-file temporary))))))

(defun record-value (record key &optional default)
  "Obtém KEY de uma lista de propriedades e devolve DEFAULT quando ausente."
  (let ((marker (gensym "AUSENTE")))
    (let ((value (getf record key marker)))
      (if (eq value marker) default value))))

(defun node-record (node)
  "Converte NODE em dados portáteis, omitindo referências à imagem Lisp viva."
  (list :id (node-id node)
        :name (node-name node)
        :kind (node-kind node)
        :internal (node-internal node)
        :external (node-external node)
        :functions (node-functions node)
        :generics (node-generics node)
        :macros (node-macros node)
        :classes (node-classes node)
        :variables (node-variables node)))

(defun edge-record (edge)
  "Converte EDGE em uma relação portátil entre identificadores de nós."
  (list :from (edge-from edge)
        :to (edge-to edge)
        :weight (coerce (edge-weight edge) 'double-float)))

(defun snapshot-record (snapshot &key label)
  "Converte SNAPSHOT em um registro legível e estável para persistência."
  (list :malkuth-snapshot t
        :format-version +history-format-version+
        :label label
        :schema-version (snapshot-schema-version snapshot)
        :created-at (snapshot-created-at snapshot)
        :implementation (snapshot-implementation snapshot)
        :features (mapcar #'princ-to-string (snapshot-features snapshot))
        :totals (list :symbols (snapshot-total-symbols snapshot)
                      :functions (snapshot-total-functions snapshot)
                      :generics (snapshot-total-generics snapshot)
                      :macros (snapshot-total-macros snapshot)
                      :classes (snapshot-total-classes snapshot)
                      :variables (snapshot-total-variables snapshot))
        :nodes (map 'list #'node-record (snapshot-nodes snapshot))
        :edges (map 'list #'edge-record (snapshot-edges snapshot))))

(defun record-node (record)
  "Reconstrói um nó estrutural sem apontar para um PACKAGE da imagem atual."
  (malkuth.model::make-node
   :id (record-value record :id 0)
   :name (princ-to-string (record-value record :name ""))
   :kind (record-value record :kind :library)
   :internal (record-value record :internal 0)
   :external (record-value record :external 0)
   :functions (record-value record :functions 0)
   :generics (record-value record :generics 0)
   :macros (record-value record :macros 0)
   :classes (record-value record :classes 0)
   :variables (record-value record :variables 0)))

(defun record-edge (record)
  "Reconstrói uma aresta estrutural a partir de um registro validado."
  (malkuth.model::make-edge
   :from (record-value record :from 0)
   :to (record-value record :to 0)
   :weight (coerce (record-value record :weight 1.0d0) 'double-float)))

(defun snapshot-from-record (record)
  "Reconstrói e valida um instantâneo estrutural previamente persistido."
  (unless (and (listp record)
               (record-value record :malkuth-snapshot nil)
               (= (record-value record :format-version -1)
                  +history-format-version+))
    (error "O arquivo não contém um instantâneo histórico compatível do Malkuth."))
  (let* ((node-records (record-value record :nodes '()))
         (edge-records (record-value record :edges '()))
         (nodes (coerce (mapcar #'record-node node-records) 'vector))
         (edges (coerce (mapcar #'record-edge edge-records) 'vector))
         (totals (record-value record :totals '()))
         (snapshot
           (malkuth.model::make-snapshot
            :nodes nodes
            :edges edges
            :created-at (record-value record :created-at (get-universal-time))
            :schema-version (princ-to-string
                             (record-value record :schema-version "1.1"))
            :total-symbols (record-value totals :symbols 0)
            :total-functions (record-value totals :functions 0)
            :total-generics (record-value totals :generics 0)
            :total-macros (record-value totals :macros 0)
            :total-classes (record-value totals :classes 0)
            :total-variables (record-value totals :variables 0)
            :implementation (princ-to-string
                             (record-value record :implementation "DESCONHECIDA"))
            :features (copy-list (record-value record :features '())))))
    ;; O formato exige IDs densos e na mesma ordem do vetor para manter as arestas
    ;; válidas e permitir comparação determinística entre processos diferentes.
    (loop for node across nodes
          for expected-id from 0
          unless (= (node-id node) expected-id)
            do (error "Identificador de nó fora de ordem no histórico: ~D, esperado ~D."
                      (node-id node) expected-id))
    (validate-snapshot snapshot :errorp t)
    snapshot))

(defun save-snapshot-file (snapshot pathname &key label)
  "Grava SNAPSHOT de modo atômico em PATHNAME e devolve o caminho final."
  (atomic-write-history-file
   pathname
   (lambda (stream)
     (let ((*print-pretty* t)
           (*print-readably* t)
           (*print-circle* nil))
       (write (snapshot-record snapshot :label label) :stream stream)
       (terpri stream)))))

(defun load-snapshot-file (pathname)
  "Lê um instantâneo estrutural com *READ-EVAL* desativado."
  (with-open-file (stream pathname :direction :input :external-format :utf-8)
    (let ((*read-eval* nil))
      (snapshot-from-record (read stream nil nil)))))

(defun history-files (directory)
  "Lista arquivos de histórico do mais recente para o mais antigo."
  (let* ((directory (uiop:ensure-directory-pathname
                     (merge-pathnames directory (uiop:getcwd))))
         (files (directory (merge-pathnames "snapshot-*.sexp" directory))))
    (sort files #'> :key (lambda (path) (or (file-write-date path) 0)))))

(defun prune-history! (directory retention)
  "Mantém somente RETENTION instantâneos recentes e devolve os removidos."
  (let ((retention (max 0 retention))
        (removed '()))
    (loop for path in (nthcdr retention (history-files directory))
          do (when (ignore-errors (delete-file path))
               (push path removed)))
    (nreverse removed)))

(defun history-file-name (snapshot)
  "Produz um nome ordenável e resistente a colisões para SNAPSHOT."
  (format nil "snapshot-~10,'0D-~A.sexp"
          (snapshot-created-at snapshot)
          (snapshot-fingerprint snapshot)))

(defun save-history-snapshot (snapshot directory &key (retention 20) label)
  "Adiciona SNAPSHOT ao histórico, aplica retenção e devolve o arquivo criado."
  (let* ((directory (uiop:ensure-directory-pathname
                     (merge-pathnames directory (uiop:getcwd))))
         (pathname (merge-pathnames (history-file-name snapshot) directory)))
    (ensure-directories-exist pathname)
    (save-snapshot-file snapshot pathname :label label)
    (prune-history! directory retention)
    pathname))

(defun latest-history-file (directory)
  "Retorna o arquivo histórico mais recente ou NIL quando o diretório está vazio."
  (first (history-files directory)))

(defun latest-history-snapshot (directory)
  "Carrega o instantâneo histórico mais recente ou devolve NIL."
  (let ((pathname (latest-history-file directory)))
    (and pathname (load-snapshot-file pathname))))

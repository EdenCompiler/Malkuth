;;;; Modelo refletivo da imagem Common Lisp
;;;;
;;;; O modelo é deliberadamente independente de SDL3 e CFFI. Ele percorre os
;;;; pacotes carregados, transforma o estado vivo do processo em estruturas
;;;; imutáveis para análise e mantém somente os campos mutáveis necessários ao
;;;; arranjo gráfico. Essa separação permite usar o núcleo em servidores e CI.

(in-package #:malkuth.model)

;; A versão do esquema identifica a forma lógica dos instantâneos exportados.
;; Ela só deve mudar quando leitores externos precisarem adaptar sua interpretação.
(defparameter +snapshot-schema-version+ "1.1")

;; Cada NODE representa um pacote da imagem. As contagens descrevem o conteúdo
;; do pacote; posição, velocidade e projeção pertencem somente à visualização.
(defstruct node
  (id 0 :type fixnum)
  (name "" :type string)
  package
  (kind :library :type keyword)
  (internal 0 :type fixnum)
  (external 0 :type fixnum)
  (functions 0 :type fixnum)
  (generics 0 :type fixnum)
  (macros 0 :type fixnum)
  (classes 0 :type fixnum)
  (variables 0 :type fixnum)
  (position (v3 0.0d0 0.0d0 0.0d0))
  (velocity (v3 0.0d0 0.0d0 0.0d0))
  (radius 4.0d0 :type real)
  (heat 1.0d0 :type real)
  (screen-x 0.0d0 :type real)
  (screen-y 0.0d0 :type real)
  (depth 0.0d0 :type real)
  (visible-p nil))

;; Uma EDGE orientada significa: o pacote FROM usa o pacote TO.
(defstruct edge
  (from 0 :type fixnum)
  (to 0 :type fixnum)
  (weight 1.0d0 :type real))

;; SNAPSHOT é o documento central do Malkuth: uma fotografia validável e
;; determinística da topologia de pacotes e de suas contagens principais.
(defstruct snapshot
  (nodes #() :type vector)
  (edges #() :type vector)
  (created-at (get-universal-time))
  (schema-version +snapshot-schema-version+ :type string)
  (total-symbols 0 :type fixnum)
  (total-functions 0 :type fixnum)
  (total-generics 0 :type fixnum)
  (total-macros 0 :type fixnum)
  (total-classes 0 :type fixnum)
  (total-variables 0 :type fixnum)
  (implementation (lisp-implementation-type) :type string)
  (features (copy-list *features*) :type list))

;; A classificação padrão é conservadora. Aplicações podem substituir a
;; identificação de código próprio por USER-PACKAGE-PREDICATE em BUILD-SNAPSHOT.
(defun package-kind (name)
  (cond
    ((or (string= name "COMMON-LISP")
         (string= name "KEYWORD")
         (search "SB-" name :test #'char=)) :runtime)
    ((or (search "ASDF" name :test #'char=)
         (search "UIOP" name :test #'char=)
         (search "CFFI" name :test #'char=)) :tooling)
    ((or (search "MALKUTH" name :test #'char=)
         (search "CL-USER" name :test #'char=)
         (string= name "COMMON-LISP-USER")) :user)
    (t :library)))

;; A ordem desta classificação é importante: macros e classes também podem
;; possuir células de função, portanto precisam ser reconhecidas primeiro.
(defun classify-symbol (symbol)
  (cond
    ((macro-function symbol) :macro)
    ((ignore-errors (find-class symbol nil)) :class)
    ((and (fboundp symbol)
          (ignore-errors (typep (symbol-function symbol) 'generic-function))) :generic)
    ((fboundp symbol) :function)
    ((boundp symbol) :variable)
    (t :symbol)))

;; PROFILE-PACKAGE percorre somente símbolos cujo pacote de origem é PACKAGE.
;; Símbolos herdados via USE-PACKAGE não entram nas contagens de propriedade.
(defun profile-package (package)
  (let ((internal 0) (external 0) (functions 0) (generics 0)
        (macros 0) (classes 0) (variables 0))
    (do-symbols (symbol package)
      (when (eq (symbol-package symbol) package)
        (multiple-value-bind (found status) (find-symbol (symbol-name symbol) package)
          (declare (ignore found))
          (case status
            (:internal (incf internal))
            (:external (incf external)))
          (case (classify-symbol symbol)
            (:macro (incf macros))
            (:generic (incf functions) (incf generics))
            (:function (incf functions))
            (:class (incf classes))
            (:variable (incf variables))))))
    (values internal external functions generics macros classes variables)))

;; Atualiza um nó existente após redefinições no REPL sem trocar sua identidade.
(defun refresh-node-profile! (node)
  (multiple-value-bind (internal external functions generics macros classes variables)
      (profile-package (node-package node))
    (setf (node-internal node) internal
          (node-external node) external
          (node-functions node) functions
          (node-generics node) generics
          (node-macros node) macros
          (node-classes node) classes
          (node-variables node) variables
          (node-radius node) (+ 3.0d0 (* 1.25d0 (log (+ 2 internal external) 2))))
    node))

(defun build-snapshot (&key (include-empty nil) package-predicate user-package-predicate (include-dependencies nil))
  "Reflete a imagem Lisp atual em um instantâneo determinístico e validável.
PACKAGE-PREDICATE recebe cada pacote e pode excluir pacotes privados da
implementação em relatórios com escopo restrito."
  ;; A ordenação por nome torna IDs, exportações e impressões digitais reproduzíveis.
  (let* ((all-packages (sort (copy-list (list-all-packages)) #'string< :key #'package-name))
         (selected (if package-predicate (remove-if-not package-predicate all-packages) all-packages))
         (packages (if (and package-predicate include-dependencies)
                       (remove-duplicates
                        (append selected
                                (loop for package in selected append (package-use-list package)))
                        :test #'eq)
                       selected))
         (packages (sort packages #'string< :key #'package-name))
         (packages (if include-empty packages
                       (remove-if (lambda (package)
                                    (zerop (loop for symbol being the symbols of package
                                                count (eq (symbol-package symbol) package))))
                                  packages)))
         (nodes (make-array (length packages)))
         (index (make-hash-table :test #'eq)))
    ;; Primeira passagem: cria os nós e o índice pacote -> identificador.
    (loop for package in packages
          for id from 0
          for node = (make-node :id id :name (package-name package)
                                :package package
                                :kind (if (and user-package-predicate
                                               (funcall user-package-predicate package))
                                          :user
                                          (package-kind (package-name package))))
          do (refresh-node-profile! node)
             (setf (aref nodes id) node
                   (gethash package index) id))
    ;; Segunda passagem: materializa somente relações cujas duas pontas estão no escopo.
    (let ((edges (make-array 0 :adjustable t :fill-pointer 0)))
      (loop for node across nodes
            do (dolist (used (package-use-list (node-package node)))
                 (let ((target (gethash used index)))
                   (when (integerp target)
                     (vector-push-extend
                      (make-edge :from (node-id node) :to target
                                 :weight (+ 1.0d0 (* 0.15d0 (length (package-used-by-list used)))))
                      edges)))))
      (let ((snapshot (make-snapshot :nodes nodes :edges edges)))
        (setf (snapshot-total-symbols snapshot)
              (loop for node across nodes sum (+ (node-internal node) (node-external node)))
              (snapshot-total-functions snapshot)
              (loop for node across nodes sum (node-functions node))
              (snapshot-total-generics snapshot)
              (loop for node across nodes sum (node-generics node))
              (snapshot-total-macros snapshot)
              (loop for node across nodes sum (node-macros node))
              (snapshot-total-classes snapshot)
              (loop for node across nodes sum (node-classes node))
              (snapshot-total-variables snapshot)
              (loop for node across nodes sum (node-variables node)))
        snapshot))))

(defun find-node-by-name (snapshot name)
  "Localiza um nó pelo nome do pacote sem diferenciar maiúsculas de minúsculas."
  (find name (snapshot-nodes snapshot) :key #'node-name :test #'string-equal))

(defun subsequence-match-cost (needle haystack)
  "Calcula o custo de uma correspondência subsequencial ou retorna NIL.

Caracteres próximos recebem custo menor. Essa etapa permite localizar, por
exemplo, MALKUTH.APP com a consulta MLA, sem substituir correspondências exatas,
por prefixo ou por trecho contínuo, que sempre possuem prioridade maior."
  (let ((position 0)
        (last-position -1)
        (cost 0))
    (loop for character across needle
          for found = (position character haystack :start position :test #'char-equal)
          do (unless found (return-from subsequence-match-cost nil))
             (incf cost (if (minusp last-position) found (- found last-position 1)))
             (setf last-position found
                   position (1+ found)))
    cost))

(defun segment-prefix-position (query name)
  "Retorna a posição de QUERY no começo de algum segmento pontuado de NAME."
  (loop with start = 0
        do (when (and (<= (+ start (length query)) (length name))
                      (string= query name :start2 start :end2 (+ start (length query))))
             (return start))
           (let ((separator (position #\. name :start start)))
             (unless separator (return nil))
             (setf start (1+ separator)))))

(defun node-search-score (node query)
  "Retorna uma pontuação de relevância para NODE e QUERY ou NIL sem resultado.

A ordem de preferência é: nome exato, prefixo do nome, prefixo de um segmento,
trecho contínuo e subsequência. O comprimento residual desempata nomes mais
curtos, tornando os resultados previsíveis em listas extensas de pacotes."
  (let* ((name (string-upcase (node-name node)))
         (query (string-upcase query))
         (substring-position (search query name :test #'char=))
         (segment-position (segment-prefix-position query name)))
    (cond
      ((string= query name) 0)
      ((and (<= (length query) (length name))
            (string= query name :end2 (length query)))
       (+ 10 (- (length name) (length query))))
      (segment-position (+ 30 segment-position (- (length name) (length query))))
      (substring-position (+ 70 substring-position (- (length name) (length query))))
      (t (let ((cost (subsequence-match-cost query name)))
           (and cost (+ 140 cost (- (length name) (length query)))))))))

(defun search-nodes (snapshot query &key limit predicate)
  "Pesquisa pacotes de SNAPSHOT por QUERY e retorna nós ordenados por relevância.

QUERY vazia retorna NIL. LIMIT restringe a quantidade final e PREDICATE permite
que interfaces pesquisem apenas um subconjunto sem duplicar o algoritmo de
classificação. A ordenação usa o nome do pacote como desempate estável."
  (let ((query (string-trim '(#\Space #\Tab #\Newline #\Return) (or query ""))))
    (when (plusp (length query))
      (let ((matches
              (loop for node across (snapshot-nodes snapshot)
                    for score = (and (or (null predicate) (funcall predicate node))
                                     (node-search-score node query))
                    when score collect (cons score node))))
        (setf matches
              (stable-sort matches
                           (lambda (left right)
                             (or (< (car left) (car right))
                                 (and (= (car left) (car right))
                                      (string< (node-name (cdr left))
                                               (node-name (cdr right))))))))
        (let ((nodes (mapcar #'cdr matches)))
          (if limit (subseq nodes 0 (min limit (length nodes))) nodes))))))

(defun normalize-node-id (node-or-id)
  "Converte NODE-OR-ID em identificador numérico e rejeita tipos ambíguos."
  (etypecase node-or-id
    (node (node-id node-or-id))
    (integer node-or-id)))

(defun node-dependency-ids (snapshot node-or-id)
  "Retorna os IDs dos pacotes usados diretamente por NODE-OR-ID.

A lista é ordenada pelo nome do pacote para produzir resultados estáveis em
interfaces, testes e relatórios."
  (let* ((id (normalize-node-id node-or-id))
         (nodes (snapshot-nodes snapshot)))
    (sort (remove-duplicates
           (loop for edge across (snapshot-edges snapshot)
                 when (= (edge-from edge) id)
                   collect (edge-to edge))
           :test #'=)
          #'string< :key (lambda (target) (node-name (aref nodes target))))))

(defun node-dependent-ids (snapshot node-or-id)
  "Retorna os IDs dos pacotes que usam diretamente NODE-OR-ID."
  (let* ((id (normalize-node-id node-or-id))
         (nodes (snapshot-nodes snapshot)))
    (sort (remove-duplicates
           (loop for edge across (snapshot-edges snapshot)
                 when (= (edge-to edge) id)
                   collect (edge-from edge))
           :test #'=)
          #'string< :key (lambda (source) (node-name (aref nodes source))))))

(defun node-neighbor-ids (snapshot node-or-id)
  "Retorna a união estável de dependências e dependentes diretos."
  (let ((nodes (snapshot-nodes snapshot)))
    (sort (remove-duplicates
           (append (node-dependency-ids snapshot node-or-id)
                   (node-dependent-ids snapshot node-or-id))
           :test #'=)
          #'string< :key (lambda (id) (node-name (aref nodes id))))))

(defun ids-to-nodes (snapshot ids)
  "Converte uma lista validada de identificadores em objetos NODE."
  (let ((nodes (snapshot-nodes snapshot)))
    (mapcar (lambda (id) (aref nodes id)) ids)))

(defun node-dependencies (snapshot node-or-id)
  "Retorna os nós usados diretamente por NODE-OR-ID."
  (ids-to-nodes snapshot (node-dependency-ids snapshot node-or-id)))

(defun node-dependents (snapshot node-or-id)
  "Retorna os nós que usam diretamente NODE-OR-ID."
  (ids-to-nodes snapshot (node-dependent-ids snapshot node-or-id)))

(defun node-neighbors (snapshot node-or-id)
  "Retorna todos os vizinhos diretos de NODE-OR-ID, sem duplicatas."
  (ids-to-nodes snapshot (node-neighbor-ids snapshot node-or-id)))

(defun symbol-sort-key (symbol)
  (format nil "~D/~A" (or (position (classify-symbol symbol)
                                     '(:macro :generic :class :function :variable :symbol))
                              99)
          (symbol-name symbol)))

(defun symbol-kind-label (kind)
  (ecase kind
    (:macro "MACRO")
    (:generic "GENÉRICA")
    (:class "CLASSE")
    (:function "FUNÇÃO")
    (:variable "VARIÁVEL")
    (:symbol "SÍMBOLO")))

(defun node-symbol-lines (node &key (limit 18) (offset 0))
  "Produz linhas já classificadas para o navegador de símbolos da interface."
  (let ((symbols '()))
    (do-symbols (symbol (node-package node))
      (when (eq (symbol-package symbol) (node-package node))
        (push symbol symbols)))
    (let* ((sorted (sort symbols #'string< :key #'symbol-sort-key))
           (start (min (max 0 offset) (length sorted)))
           (end (min (length sorted) (+ start (max 0 limit)))))
      (loop for symbol in (subseq sorted start end)
            collect (format nil "~7A  ~A"
                            (symbol-kind-label (classify-symbol symbol))
                            (symbol-name symbol))))))


;;;; Caminhos de dependência

(defun node-designator-id (snapshot node-or-name)
  "Converte um nó, nome de pacote ou identificador em um ID válido do instantâneo."
  (etypecase node-or-name
    (node (node-id node-or-name))
    (string (let ((node (find-node-by-name snapshot node-or-name)))
              (unless node
                (error "Pacote inexistente no instantâneo: ~A" node-or-name))
              (node-id node)))
    (integer (if (<= 0 node-or-name (1- (length (snapshot-nodes snapshot))))
                 node-or-name
                 (error "Identificador de pacote fora do instantâneo: ~D" node-or-name)))))

(defun dependency-adjacency (snapshot direction)
  "Constrói uma lista de adjacência conforme DIRECTION.

:OUTGOING segue USE-PACKAGE da origem para a dependência; :INCOMING percorre a
relação inversa; :EITHER trata a topologia como não orientada para investigação."
  (unless (member direction '(:outgoing :incoming :either))
    (error "Direção de caminho desconhecida: ~S" direction))
  (let* ((count (length (snapshot-nodes snapshot)))
         (adjacency (make-array count :initial-element nil)))
    (loop for edge across (snapshot-edges snapshot)
          for from = (edge-from edge)
          for to = (edge-to edge)
          do (when (member direction '(:outgoing :either))
               (pushnew to (aref adjacency from) :test #'=))
             (when (member direction '(:incoming :either))
               (pushnew from (aref adjacency to) :test #'=)))
    (loop for index below count
          do (setf (aref adjacency index) (sort (aref adjacency index) #'<)))
    adjacency))

(defun shortest-dependency-path-ids (snapshot from to &key (direction :outgoing))
  "Retorna os IDs do menor caminho entre FROM e TO, incluindo as duas pontas.

A busca em largura é determinística porque vizinhos são visitados por ID. NIL
indica que não existe caminho segundo DIRECTION."
  (let* ((source (node-designator-id snapshot from))
         (target (node-designator-id snapshot to)))
    (when (= source target)
      (return-from shortest-dependency-path-ids (list source)))
    (let* ((count (length (snapshot-nodes snapshot)))
           (adjacency (dependency-adjacency snapshot direction))
           (previous (make-array count :initial-element -1))
           (visited (make-array count :element-type 'bit :initial-element 0))
           (queue (make-array count :element-type 'fixnum))
           (head 0)
           (tail 0))
      (setf (aref queue tail) source
            tail (1+ tail)
            (aref visited source) 1)
      (loop while (< head tail)
            for current = (aref queue head)
            do (incf head)
               (dolist (neighbor (aref adjacency current))
                 (when (zerop (aref visited neighbor))
                   (setf (aref visited neighbor) 1
                         (aref previous neighbor) current
                         (aref queue tail) neighbor
                         tail (1+ tail))
                   (when (= neighbor target)
                     (return-from shortest-dependency-path-ids
                       (loop with path = (list target)
                             for cursor = target then (aref previous cursor)
                             until (= cursor source)
                             do (push (aref previous cursor) path)
                             finally (return path)))))))
      nil)))

(defun shortest-dependency-path (snapshot from to &key (direction :outgoing))
  "Retorna os nós do menor caminho de dependência entre FROM e TO."
  (let ((ids (shortest-dependency-path-ids snapshot from to :direction direction))
        (nodes (snapshot-nodes snapshot)))
    (and ids (mapcar (lambda (id) (aref nodes id)) ids))))

(defun dependency-path-edge-p (path edge)
  "Informa se EDGE conecta dois IDs consecutivos de PATH em qualquer orientação."
  (loop for (left right) on path while right
        thereis (or (and (= left (edge-from edge)) (= right (edge-to edge)))
                    (and (= right (edge-from edge)) (= left (edge-to edge))))))

(defun fnv1a-update (hash octet)
  (logand #xffffffffffffffff (* (logxor hash octet) #x100000001b3)))

(defun fnv1a-string (hash string)
  (loop for character across string
        do (setf hash (fnv1a-update hash (logand #xff (char-code character))))
        finally (return hash)))

(defun snapshot-fingerprint (snapshot)
  "Retorna uma impressão digital determinística de 64 bits para a topologia e as contagens dos pacotes."
  (let ((hash #xcbf29ce484222325))
    (loop for node across (snapshot-nodes snapshot)
          do (setf hash (fnv1a-string hash (node-name node)))
             (dolist (value (list (node-internal node) (node-external node)
                                  (node-functions node) (node-generics node)
                                  (node-macros node) (node-classes node)
                                  (node-variables node)))
               (setf hash (fnv1a-string hash (write-to-string value)))))
    (loop for edge across (snapshot-edges snapshot)
          do (setf hash (fnv1a-string hash
                                      (format nil "~D>~D;" (edge-from edge) (edge-to edge)))))
    (format nil "~16,'0X" hash)))

(defun validate-snapshot (snapshot &key (errorp nil))
  "Retorna (values valid-p problems). Sinaliza um erro quando ERRORP for verdadeiro."
  (let* ((nodes (snapshot-nodes snapshot))
         (count (length nodes))
         (problems '())
         (names (make-hash-table :test #'equal)))
    (loop for node across nodes
          for expected from 0
          do (unless (= (node-id node) expected)
               (push (format nil "O nó ~A possui o identificador ~D; era esperado ~D."
                             (node-name node) (node-id node) expected) problems))
             (when (gethash (node-name node) names)
               (push (format nil "Nome de pacote duplicado: ~A." (node-name node)) problems))
             (setf (gethash (node-name node) names) t))
    (loop for edge across (snapshot-edges snapshot)
          unless (and (<= 0 (edge-from edge)) (< (edge-from edge) count)
                      (<= 0 (edge-to edge)) (< (edge-to edge) count))
            do (push (format nil "Aresta inválida: ~D -> ~D." (edge-from edge) (edge-to edge)) problems))
    (flet ((check-total (label accessor total)
             (let ((calculated (loop for node across nodes sum (funcall accessor node))))
               (unless (= calculated total)
                 (push (format nil "O total de ~A é ~D; era esperado ~D." label total calculated)
                       problems)))))
      (check-total "símbolos" (lambda (node) (+ (node-internal node) (node-external node)))
                   (snapshot-total-symbols snapshot))
      (check-total "funções" #'node-functions (snapshot-total-functions snapshot))
      (check-total "funções genéricas" #'node-generics (snapshot-total-generics snapshot))
      (check-total "macros" #'node-macros (snapshot-total-macros snapshot))
      (check-total "classes" #'node-classes (snapshot-total-classes snapshot))
      (check-total "variáveis" #'node-variables (snapshot-total-variables snapshot)))
    (setf problems (nreverse problems))
    (when (and errorp problems)
      (error "Instantâneo do Malkuth inválido:~%~{  - ~A~%~}" problems))
    (values (null problems) problems)))

(defun snapshot-summary (snapshot)
  (list :schema-version (snapshot-schema-version snapshot)
        :fingerprint (snapshot-fingerprint snapshot)
        :implementation (snapshot-implementation snapshot)
        :packages (length (snapshot-nodes snapshot))
        :dependencies (length (snapshot-edges snapshot))
        :symbols (snapshot-total-symbols snapshot)
        :functions (snapshot-total-functions snapshot)
        :generics (snapshot-total-generics snapshot)
        :macros (snapshot-total-macros snapshot)
        :classes (snapshot-total-classes snapshot)
        :variables (snapshot-total-variables snapshot)
        :created-at (snapshot-created-at snapshot)))

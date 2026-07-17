;;;; Aplicação interativa do Malkuth
;;;;
;;;; Este módulo coordena entrada, estado da interface, seleção, filtros,
;;;; persistência de favoritos, atualização da imagem e renderização SDL3.
;;;; O desenho usa primitivas vetoriais simples para evitar dependências de
;;;; fontes externas e manter o executável fácil de distribuir.

(in-package #:malkuth.app)

;; APP-STATE reúne apenas o estado transitório da sessão. O instantâneo e a
;; análise continuam pertencendo ao núcleo; preferências simples, como favoritos,
;; são persistidas separadamente em um arquivo S-expression seguro.
;;;; Estado da sessão

(defstruct app-state
  snapshot
  analysis
  last-diff
  baseline-snapshot
  baseline-analysis
  architecture-diff
  (changes-p nil)
  (history-retention 20 :type fixnum)
  (export-directory #P"output/" :type pathname)
  (include-empty-p nil)
  package-predicate
  user-package-predicate
  (include-dependencies-p nil)
  (selected-index 0 :type fixnum)
  (hover-index -1 :type fixnum)
  (mouse-x 0.0d0 :type real)
  (mouse-y 0.0d0 :type real)
  (yaw 0.45d0 :type real)
  (pitch -0.16d0 :type real)
  (distance 112.0d0 :type real)
  (auto-orbit-p t)
  (paused-p nil)
  (help-p nil)
  (diagnostics-p nil)
  ;; A busca textual mantém estado próprio para não alterar o filtro do mapa até
  ;; que o usuário confirme um resultado.
  (search-active-p nil)
  (search-query "" :type string)
  (search-results nil :type list)
  (search-result-index 0 :type fixnum)
  (search-max-visible 7 :type fixnum)
  (quit-requested-p nil)
  (view-filter :all :type keyword)
  (inspector-tab :symbols :type keyword)
  (risk-threshold 20 :type fixnum)
  (favorites (make-hash-table :test #'equal))
  favorites-path
  (inspector-offset 0 :type fixnum)
  (mouse-was-down-p nil)
  (key-state (make-hash-table :test #'eql))
  (fps 60.0d0 :type real)
  (last-ticks 0 :type integer)
  (frame 0 :type fixnum)
  (status "PRONTO / CLIQUE EM UM PACOTE PARA INSPECIONÁ-LO")
  (status-until 0 :type integer)
  (inspector-lines nil :type list))

;; Paleta de alto contraste centralizada para manter consistência entre painéis.
(defparameter +background+ '(7 12 22 255))
(defparameter +surface+ '(13 22 38 248))
(defparameter +surface-raised+ '(18 29 49 252))
(defparameter +border+ '(49 69 99 255))
(defparameter +border-soft+ '(35 51 76 220))
(defparameter +text-primary+ '(230 239 252 255))
(defparameter +text-secondary+ '(166 187 216 255))
(defparameter +text-muted+ '(111 137 174 255))
(defparameter +accent+ '(124 255 207 255))
(defparameter +accent-dim+ '(79 183 151 255))
(defparameter +minimum-readable-scale+ 1.70d0)

(defun readable-scale (scale)
  (max +minimum-readable-scale+ (float scale 1.0d0)))

(defun rgb-for-kind (kind)
  (ecase kind
    (:runtime (values 105 169 255))
    (:tooling (values 255 188 82))
    (:user (values 108 255 197))
    (:library (values 191 132 255))))

(defun role-name (kind)
  (ecase kind
    (:runtime "AMBIENTE")
    (:tooling "FERRAMENTAS")
    (:user "PROJETO")
    (:library "BIBLIOTECA")))

(defun filter-name (filter)
  "Nome curto apresentado na barra do mapa para FILTER."
  (ecase filter
    (:all "TODOS")
    (:project "PROJETO")
    (:risk "RISCO")
    (:favorites "FAVORITOS")
    (:neighbors "VIZINHANÇA")
    (:changed "ALTERADOS")))

(defun inspector-tab-name (tab)
  "Nome legível da aba ativa do inspetor."
  (ecase tab
    (:symbols "SÍMBOLOS")
    (:dependencies "DEPENDÊNCIAS")))

(defun apply-color (renderer color)
  (destructuring-bind (r g b &optional (a 255)) color
    (malkuth.sdl3:set-color renderer r g b a)))

(defun text (renderer x y value &key (scale 1.15) (color +text-secondary+) (spacing 1.0))
  (let ((scale (readable-scale scale)))
    (apply-color renderer color)
    (draw-vector-text (lambda (px py w h)
                        ;; Escalas menores que um pixel produziam glifos fragmentados em alguns renderizadores.
                        (malkuth.sdl3:fill-rect renderer px py (max 1.0d0 w) (max 1.0d0 h)))
                      x y (string-upcase (princ-to-string value))
                      :scale scale :spacing spacing)))

(defun fit-string (value max-characters)
  (let ((string (princ-to-string value)))
    (if (<= (length string) max-characters)
        string
        (concatenate 'string (subseq string 0 (max 0 (- max-characters 3))) "..."))))

(defun fit-text (value max-width &key (scale 1.15) (spacing 1.0))
  "Retorna VALUE encurtado com reticências para que o texto vetorial caiba em MAX-WIDTH pixels."
  (let* ((string (string-upcase (princ-to-string value)))
         (scale (readable-scale scale))
         (ellipsis "..."))
    (if (<= (vector-text-width string :scale scale :spacing spacing) max-width)
        string
        (loop for end from (length string) downto 0
              for candidate = (concatenate 'string (subseq string 0 end) ellipsis)
              when (<= (vector-text-width candidate :scale scale :spacing spacing) max-width)
                return candidate
              finally (return ellipsis)))))

(defun panel (renderer x y w h &key (raised nil) accent)
  (apply-color renderer (if raised +surface-raised+ +surface+))
  (malkuth.sdl3:fill-rect renderer x y w h)
  (apply-color renderer +border+)
  (malkuth.sdl3:outline-rect renderer x y w h)
  (when accent
    (apply-color renderer accent)
    (malkuth.sdl3:fill-rect renderer x y 4 h)))

(defun separator (renderer x1 y x2)
  (apply-color renderer +border-soft+)
  (malkuth.sdl3:line renderer x1 y x2 y))

(defun badge (renderer x y label &key (foreground +text-primary+)
                                      (background '(28 42 65 255))
                                      (border +border+)
                                      (scale 1.0))
  (let* ((scale (readable-scale scale))
         (padding-x 9.0d0)
         (padding-y 7.0d0)
         (text-width (vector-text-width label :scale scale :spacing 1.0))
         (width (+ text-width (* padding-x 2.0d0)))
         (height (+ (* 7.0d0 scale) (* padding-y 2.0d0))))
    (apply-color renderer background)
    (malkuth.sdl3:fill-rect renderer x y width height)
    (apply-color renderer border)
    (malkuth.sdl3:outline-rect renderer x y width height)
    (text renderer (+ x padding-x) (+ y padding-y) label :scale scale :color foreground)
    width))

;;;; Seleção, filtros e navegação

(defun selected-node (state)
  "Retorna o nó selecionado usando o índice estável do instantâneo corrente."
  (aref (snapshot-nodes (app-state-snapshot state)) (app-state-selected-index state)))

(defun hovered-node (state)
  "Retorna o nó sob o ponteiro ou NIL quando o mapa não possui alvo próximo."
  (when (>= (app-state-hover-index state) 0)
    (aref (snapshot-nodes (app-state-snapshot state)) (app-state-hover-index state))))

(defun favorite-p (state node)
  "Consulta a coleção persistente de pacotes favoritos pelo nome estável."
  (not (null (gethash (node-name node) (app-state-favorites state)))))

(defun changed-package-p (state node)
  "Informa se NODE foi adicionado ou alterado em relação à linha de base."
  (let ((architecture-diff (app-state-architecture-diff state)))
    (when architecture-diff
      (let* ((diff (architecture-diff-snapshot-diff architecture-diff))
             (name (node-name node)))
        (or (member name (snapshot-diff-added-packages diff) :test #'string-equal)
            (find name (snapshot-diff-changed-packages diff)
                  :key #'malkuth.analysis:package-change-name
                  :test #'string-equal))))))

(defun display-node-p (state node)
  "Decide se NODE participa da visão atual.

O nó selecionado permanece visível em qualquer filtro para que o usuário nunca
perca o contexto ao alternar modos."
  (or (eq node (selected-node state))
      (ecase (app-state-view-filter state)
        (:all t)
        (:project (eq (node-kind node) :user))
        (:risk (>= (node-metrics-risk-score
                    (metrics-for-node (app-state-analysis state) node))
                   (app-state-risk-threshold state)))
        (:favorites (favorite-p state node))
        (:neighbors (member (node-id node)
                            (node-neighbor-ids (app-state-snapshot state)
                                               (selected-node state))
                            :test #'=))
        (:changed (changed-package-p state node)))))

(defun display-nodes (state)
  "Lista os nós aceitos pelo filtro atual em ordem de identificador."
  (remove-if-not (lambda (node) (display-node-p state node))
                 (coerce (snapshot-nodes (app-state-snapshot state)) 'list)))

(defun nearest-display-node (state x y &key (max-distance 42.0d0))
  "Localiza o nó exibido mais próximo de X/Y dentro de MAX-DISTANCE."
  (let ((best nil)
        (best-distance max-distance))
    (dolist (node (display-nodes state) best)
      (when (node-visible-p node)
        (let* ((dx (- (node-screen-x node) x))
               (dy (- (node-screen-y node) y))
               (distance (sqrt (+ (* dx dx) (* dy dy)))))
          (when (< distance best-distance)
            (setf best node
                  best-distance distance)))))))

(defun set-selected! (state node)
  "Seleciona NODE e reinicia a paginação do inspetor."
  (when node
    (setf (app-state-selected-index state) (node-id node)
          (app-state-inspector-offset state) 0
          (app-state-inspector-lines state) (node-symbol-lines node :limit 500)
          (app-state-status state) (format nil "PACOTE SELECIONADO: ~A" (node-name node))
          (app-state-status-until state) (+ (malkuth.sdl3:ticks) 2200)))
  node)

(defun set-view-filter! (state filter)
  "Ativa FILTER, limpa o apontamento e informa a nova quantidade visível."
  (setf (app-state-view-filter state) filter
        (app-state-hover-index state) -1)
  (flash-status state
                (format nil "FILTRO ~A / ~D PACOTES VISÍVEIS"
                        (filter-name filter) (length (display-nodes state)))
                2600)
  filter)

(defun next-node! (state delta)
  "Navega somente pelos nós que pertencem ao filtro atual."
  (let* ((nodes (display-nodes state))
         (current (position (selected-node state) nodes :test #'eq)))
    (when nodes
      (set-selected! state
                     (nth (mod (+ (or current 0) delta) (length nodes)) nodes)))))

(defun key-edge-p (state scancode)
  (let* ((now (malkuth.sdl3:keyboard-down-p scancode))
         (before (gethash scancode (app-state-key-state state) nil)))
    (setf (gethash scancode (app-state-key-state state)) now)
    (and now (not before))))

(defun flash-status (state message &optional (milliseconds 1800))
  (setf (app-state-status state) message
        (app-state-status-until state) (+ (malkuth.sdl3:ticks) milliseconds)))

(defun selected-metrics (state)
  (metrics-for-node (app-state-analysis state) (selected-node state)))

(defun set-inspector-offset! (state offset)
  (let* ((count (inspector-item-count state))
         (maximum (max 0 (1- count))))
    (setf (app-state-inspector-offset state) (clamp offset 0 maximum))))

;;;; Busca textual de pacotes

(defun search-box-geometry (width)
  "Retorna X, Y, largura e altura da caixa responsiva de busca."
  (let* ((x (if (< width 1450) 360.0d0 430.0d0))
         (box-width (min 520.0d0 (max 360.0d0 (- width x 370.0d0)))))
    (values x 15.0d0 box-width 46.0d0)))

(defun point-in-rectangle-p (x y rectangle-x rectangle-y width height)
  "Indica se X/Y pertence ao retângulo semiaberto informado."
  (and (>= x rectangle-x) (< x (+ rectangle-x width))
       (>= y rectangle-y) (< y (+ rectangle-y height))))

(defun refresh-search-results! (state &key (preserve-index nil))
  "Recalcula os resultados da consulta atual usando a API estável do núcleo."
  (let* ((before (app-state-search-result-index state))
         (results (search-nodes (app-state-snapshot state)
                                (app-state-search-query state)
                                :limit 200)))
    (setf (app-state-search-results state) results
          (app-state-search-result-index state)
          (if (and preserve-index results)
              (clamp before 0 (1- (length results)))
              0))
    results))

(defun search-visible-window (state)
  "Retorna início e fim da janela de resultados apresentada no menu suspenso."
  (let* ((count (length (app-state-search-results state)))
         (visible (min count (app-state-search-max-visible state)))
         (maximum-start (max 0 (- count visible)))
         (start (clamp (- (app-state-search-result-index state)
                          (floor visible 2))
                       0 maximum-start)))
    (values start (+ start visible))))

(defun update-text-input-area! (state window width)
  "Mantém a janela de sugestões do IME junto ao cursor desenhado pelo Malkuth."
  (multiple-value-bind (x y box-width box-height) (search-box-geometry width)
    (let* ((query-width
             (vector-text-width (app-state-search-query state)
                                :scale (readable-scale 1.22) :spacing 1.0))
           (cursor (min (- box-width 90.0d0) (+ 43.0d0 query-width))))
      (ignore-errors
        (malkuth.sdl3:set-text-input-area window x y box-width box-height cursor)))))

(defun activate-search! (state window width &key (clear nil))
  "Ativa a caixa de busca e solicita eventos Unicode ao SDL3."
  (when clear
    (setf (app-state-search-query state) ""
          (app-state-search-results state) nil
          (app-state-search-result-index state) 0))
  (setf (app-state-search-active-p state) t
        (app-state-help-p state) nil)
  (unless (malkuth.sdl3:start-text-input window)
    (flash-status state (format nil "NÃO FOI POSSÍVEL ATIVAR A DIGITAÇÃO: ~A"
                                (malkuth.sdl3:last-error))
                  4200))
  (update-text-input-area! state window width)
  (flash-status state "BUSCA ATIVA / DIGITE O NOME DE UM PACOTE" 2200)
  state)

(defun deactivate-search! (state window)
  "Fecha a busca, preservando a consulta para reabertura rápida."
  (when (app-state-search-active-p state)
    (ignore-errors (malkuth.sdl3:stop-text-input window)))
  (setf (app-state-search-active-p state) nil)
  state)

(defun append-search-text! (state text-input window width)
  "Acrescenta texto Unicode imprimível e limita consultas excessivamente longas."
  (let* ((filtered (remove-if-not #'graphic-char-p text-input))
         (candidate (concatenate 'string (app-state-search-query state) filtered)))
    (setf (app-state-search-query state)
          (subseq candidate 0 (min 80 (length candidate))))
    (refresh-search-results! state)
    (update-text-input-area! state window width)))

(defun delete-search-character! (state window width)
  "Remove um caractere Lisp completo, preservando pontos de código Unicode."
  (let ((query (app-state-search-query state)))
    (when (plusp (length query))
      (setf (app-state-search-query state) (subseq query 0 (1- (length query))))
      (refresh-search-results! state)
      (update-text-input-area! state window width))))

(defun move-search-result! (state delta)
  "Move a seleção do menu de resultados com retorno circular."
  (let ((count (length (app-state-search-results state))))
    (when (plusp count)
      (setf (app-state-search-result-index state)
            (mod (+ (app-state-search-result-index state) delta) count)))))

(defun choose-search-result! (state window &optional index)
  "Seleciona o resultado indicado, fecha a busca e preserva o filtro corrente."
  (let* ((results (app-state-search-results state))
         (index (or index (app-state-search-result-index state)))
         (node (and (<= 0 index) (< index (length results)) (nth index results))))
    (when node
      (set-selected! state node)
      (deactivate-search! state window)
      (flash-status state (format nil "PACOTE ABERTO PELA BUSCA: ~A" (node-name node)) 3200))
    node))

(defun search-result-at-point (state width x y)
  "Converte uma posição do ponteiro em índice absoluto de resultado ou NIL."
  (multiple-value-bind (box-x box-y box-width box-height) (search-box-geometry width)
    (multiple-value-bind (start end) (search-visible-window state)
      (let* ((row-height 38.0d0)
             (list-y (+ box-y box-height 6.0d0)))
        (when (and (>= x box-x) (< x (+ box-x box-width))
                   (>= y list-y)
                   (< y (+ list-y (* row-height (- end start)))))
          (+ start (floor (- y list-y) row-height)))))))

;;;; Persistência de favoritos e conteúdo do inspetor

(defun favorites-pathname (state)
  "Retorna o arquivo usado para persistir favoritos desta instalação."
  (or (app-state-favorites-path state)
      (output-path state "malkuth-favoritos.sexp")))

(defun save-favorites! (state)
  "Grava nomes de favoritos; o carregamento posterior desativa *READ-EVAL*."
  (let ((names (sort (loop for name being the hash-keys of (app-state-favorites state)
                           collect name)
                     #'string<)))
    (atomic-write-file
     (favorites-pathname state)
     (lambda (stream)
       (format stream ";; Favoritos persistentes do Malkuth.~%")
       (write names :stream stream :pretty t)
       (terpri stream)))))

(defun load-favorites! (state)
  "Carrega uma lista simples de nomes e ignora conteúdo inválido com segurança."
  (let ((path (favorites-pathname state)))
    (when (probe-file path)
      (handler-case
          (with-open-file (stream path :direction :input :external-format :utf-8)
            (let ((*read-eval* nil)
                  (value (read stream nil nil)))
              (when (and (listp value) (every #'stringp value))
                (clrhash (app-state-favorites state))
                (dolist (name value)
                  (setf (gethash name (app-state-favorites state)) t)))))
        (error (condition)
          (format *error-output* "~&Aviso: favoritos não foram carregados: ~A~%" condition)))))
  state)

(defun toggle-favorite! (state)
  "Alterna o pacote selecionado na coleção de favoritos e persiste a mudança."
  (let* ((node (selected-node state))
         (name (node-name node))
         (table (app-state-favorites state)))
    (if (gethash name table)
        (progn
          (remhash name table)
          (flash-status state (format nil "REMOVIDO DOS FAVORITOS: ~A" name)))
        (progn
          (setf (gethash name table) t)
          (flash-status state (format nil "ADICIONADO AOS FAVORITOS: ~A" name))))
    (handler-case (save-favorites! state)
      (error (condition)
        (flash-status state (format nil "FAVORITO ALTERADO, MAS NÃO SALVO: ~A" condition) 5200)))
    (favorite-p state node)))

(defun baseline-pathname (state)
  "Caminho estável da linha de base usada nas comparações interativas."
  (merge-pathnames "malkuth-linha-de-base.sexp"
                   (uiop:ensure-directory-pathname
                    (app-state-export-directory state))))

(defun history-directory (state)
  "Diretório reservado aos instantâneos rotativos da sessão."
  (merge-pathnames "historico/"
                   (uiop:ensure-directory-pathname
                    (app-state-export-directory state))))

(defun recompute-architecture-diff! (state)
  "Recalcula a comparação contra a linha de base carregada, quando disponível."
  (if (app-state-baseline-snapshot state)
      (setf (app-state-architecture-diff state)
            (compare-architectures
             (app-state-baseline-snapshot state)
             (app-state-snapshot state)
             :old-analysis (app-state-baseline-analysis state)
             :new-analysis (app-state-analysis state)))
      (setf (app-state-architecture-diff state) nil)))

(defun load-baseline! (state &key (announce nil))
  "Carrega a linha de base persistida e atualiza a comparação corrente."
  (let ((pathname (baseline-pathname state)))
    (when (probe-file pathname)
      (handler-case
          (let* ((snapshot (load-snapshot-file pathname))
                 (analysis (analyze-snapshot snapshot)))
            (setf (app-state-baseline-snapshot state) snapshot
                  (app-state-baseline-analysis state) analysis)
            (recompute-architecture-diff! state)
            (when announce
              (flash-status state
                            (format nil "LINHA DE BASE CARREGADA: ~A"
                                    (snapshot-fingerprint snapshot))
                            3600))
            snapshot)
        (error (condition)
          (when announce
            (flash-status state (format nil "FALHA AO LER LINHA DE BASE: ~A" condition)
                          5200))
          nil)))))

(defun capture-baseline! (state)
  "Persiste o estado atual como linha de base e inicia uma comparação limpa."
  (let* ((snapshot (app-state-snapshot state))
         (pathname (baseline-pathname state)))
    (save-snapshot-file snapshot pathname :label "linha-de-base")
    (save-history-snapshot snapshot (history-directory state)
                           :retention (app-state-history-retention state)
                           :label "linha-de-base")
    ;; Recarregar pelo formato persistido testa a compatibilidade do arquivo e
    ;; evita que a comparação dependa de objetos PACKAGE da imagem viva.
    (setf (app-state-baseline-snapshot state) (load-snapshot-file pathname)
          (app-state-baseline-analysis state) nil)
    (setf (app-state-baseline-analysis state)
          (analyze-snapshot (app-state-baseline-snapshot state)))
    (recompute-architecture-diff! state)
    (flash-status state
                  (format nil "LINHA DE BASE CAPTURADA: ~A"
                          (snapshot-fingerprint snapshot))
                  4200)
    pathname))

(defun export-current-comparison! (state)
  "Gera relatórios Markdown e JSON da comparação ativa."
  (unless (app-state-baseline-snapshot state)
    (error "Nenhuma linha de base foi capturada. Pressione B primeiro."))
  (let ((paths (export-comparison-bundle
                (app-state-baseline-snapshot state)
                (app-state-snapshot state)
                (app-state-export-directory state)
                :old-analysis (app-state-baseline-analysis state)
                :new-analysis (app-state-analysis state)
                :diff (app-state-architecture-diff state))))
    (flash-status state
                  (format nil "COMPARAÇÃO EXPORTADA: ~A"
                          (namestring (getf paths :markdown)))
                  5200)
    paths))

(defun dependency-rows (state)
  "Monta as linhas da aba de dependências com direção explícita."
  (let* ((snapshot (app-state-snapshot state))
         (node (selected-node state)))
    (append (mapcar (lambda (item) (list :saida item))
                    (node-dependencies snapshot node))
            (mapcar (lambda (item) (list :entrada item))
                    (node-dependents snapshot node)))))

(defun inspector-item-count (state)
  "Quantidade de itens pagináveis na aba ativa do inspetor."
  (ecase (app-state-inspector-tab state)
    (:symbols (length (app-state-inspector-lines state)))
    (:dependencies (length (dependency-rows state)))))

(defun toggle-inspector-tab! (state)
  "Alterna entre símbolos e relações diretas do pacote selecionado."
  (setf (app-state-inspector-tab state)
        (ecase (app-state-inspector-tab state)
          (:symbols :dependencies)
          (:dependencies :symbols))
        (app-state-inspector-offset state) 0)
  (flash-status state (format nil "INSPETOR: ~A"
                              (inspector-tab-name (app-state-inspector-tab state)))))

(defun refresh-image! (state)
  "Reconstrói a imagem ativa preservando pelo nome o pacote selecionado."
  (let* ((old (app-state-snapshot state))
         (_history (ignore-errors
                     (save-history-snapshot
                      old (history-directory state)
                      :retention (app-state-history-retention state)
                      :label "antes-da-atualizacao")))
         (selected-name (node-name (selected-node state)))
         (fresh (build-snapshot :include-empty (app-state-include-empty-p state)
                                :package-predicate (app-state-package-predicate state)
                                :user-package-predicate (app-state-user-package-predicate state)
                                :include-dependencies (app-state-include-dependencies-p state))))
    (declare (ignore _history))
    (validate-snapshot fresh :errorp t)
    (when (zerop (length (snapshot-nodes fresh)))
      (error "A atualização produziu um instantâneo vazio; revise o escopo configurado."))
    (seed-layout! fresh)
    (relax-layout! fresh :iterations 120 :dt 0.024d0)
    (let* ((diff (compare-snapshots old fresh))
           (analysis (analyze-snapshot fresh))
           (selected (or (find-node-by-name fresh selected-name)
                         (and (plusp (length (snapshot-nodes fresh)))
                              (aref (snapshot-nodes fresh) 0)))))
      (setf (app-state-snapshot state) fresh
            (app-state-analysis state) analysis
            (app-state-last-diff state) diff
            (app-state-hover-index state) -1)
      (set-selected! state selected)
      (recompute-architecture-diff! state)
      (when (plusp (length (app-state-search-query state)))
        (refresh-search-results! state :preserve-index t))
      (flash-status
       state
       (format nil "IMAGEM ATUALIZADA / +~D -~D / ~D PACOTES ALTERADOS"
               (length (snapshot-diff-added-packages diff))
               (length (snapshot-diff-removed-packages diff))
               (length (snapshot-diff-changed-packages diff)))
       4200)
      fresh)))

(defun output-path (state filename)
  (merge-pathnames filename (uiop:ensure-directory-pathname
                             (app-state-export-directory state))))

;;;; Entrada e comandos da interface

(defun update-normal-input! (state graph-x graph-y graph-w graph-h dt)
  "Processa ações discretas, controles contínuos e seleção pelo ponteiro."
  ;; Ações de sessão e de visualização.
  (when (key-edge-p state malkuth.sdl3:+sc-space+)
    (setf (app-state-paused-p state) (not (app-state-paused-p state)))
    (flash-status state (if (app-state-paused-p state)
                            "ARRANJO PAUSADO"
                            "ARRANJO RETOMADO")))
  (when (key-edge-p state malkuth.sdl3:+sc-h+)
    (setf (app-state-help-p state) (not (app-state-help-p state))))
  (when (key-edge-p state malkuth.sdl3:+sc-g+)
    (setf (app-state-diagnostics-p state) (not (app-state-diagnostics-p state))
          (app-state-changes-p state) nil)
    (flash-status state (if (app-state-diagnostics-p state)
                            "DIAGNÓSTICOS DE ARQUITETURA ABERTOS"
                            "VISÃO GERAL DA IMAGEM ABERTA")))
  (when (key-edge-p state malkuth.sdl3:+sc-t+)
    (unless (app-state-baseline-snapshot state)
      (load-baseline! state))
    (if (app-state-baseline-snapshot state)
        (progn
          (setf (app-state-changes-p state) (not (app-state-changes-p state))
                (app-state-diagnostics-p state) nil)
          (flash-status state (if (app-state-changes-p state)
                                  "COMPARAÇÃO COM A LINHA DE BASE ABERTA"
                                  "VISÃO GERAL DA IMAGEM ABERTA")))
        (flash-status state "NENHUMA LINHA DE BASE / PRESSIONE B PARA CAPTURAR" 4200)))
  (when (key-edge-p state malkuth.sdl3:+sc-b+)
    (handler-case (capture-baseline! state)
      (error (condition)
        (flash-status state (format nil "FALHA AO CAPTURAR LINHA DE BASE: ~A" condition)
                      5200))))
  (when (key-edge-p state malkuth.sdl3:+sc-i+)
    (toggle-inspector-tab! state))
  (when (key-edge-p state malkuth.sdl3:+sc-v+)
    (set-view-filter! state
                      (if (eq (app-state-view-filter state) :neighbors)
                          :all
                          :neighbors)))
  (when (key-edge-p state malkuth.sdl3:+sc-1+) (set-view-filter! state :all))
  (when (key-edge-p state malkuth.sdl3:+sc-2+) (set-view-filter! state :project))
  (when (key-edge-p state malkuth.sdl3:+sc-3+) (set-view-filter! state :risk))
  (when (key-edge-p state malkuth.sdl3:+sc-4+) (set-view-filter! state :favorites))
  (when (key-edge-p state malkuth.sdl3:+sc-5+) (set-view-filter! state :neighbors))
  (when (key-edge-p state malkuth.sdl3:+sc-6+)
    (if (app-state-architecture-diff state)
        (set-view-filter! state :changed)
        (flash-status state "O FILTRO ALTERADOS EXIGE UMA LINHA DE BASE" 3600)))
  (when (key-edge-p state malkuth.sdl3:+sc-o+)
    (setf (app-state-auto-orbit-p state) (not (app-state-auto-orbit-p state)))
    (flash-status state (if (app-state-auto-orbit-p state)
                            "ÓRBITA AUTOMÁTICA ATIVADA"
                            "ÓRBITA AUTOMÁTICA DESATIVADA")))
  (when (key-edge-p state malkuth.sdl3:+sc-r+)
    (reheat-layout! (app-state-snapshot state))
    (flash-status state "MAPA DE PACOTES REORGANIZADO"))
  (when (key-edge-p state malkuth.sdl3:+sc-f5+)
    (handler-case (refresh-image! state)
      (error (condition)
        (flash-status state (format nil "FALHA AO ATUALIZAR: ~A" condition) 5200))))

  ;; Navegação por teclado respeita o filtro ativo e a aba do inspetor.
  (when (or (key-edge-p state malkuth.sdl3:+sc-tab+)
            (key-edge-p state malkuth.sdl3:+sc-k+))
    (next-node! state 1))
  (when (key-edge-p state malkuth.sdl3:+sc-j+)
    (next-node! state -1))
  (when (key-edge-p state malkuth.sdl3:+sc-pageup+)
    (set-inspector-offset! state (- (app-state-inspector-offset state) 8)))
  (when (key-edge-p state malkuth.sdl3:+sc-pagedown+)
    (set-inspector-offset! state (+ (app-state-inspector-offset state) 8)))

  ;; Exportações: P produz o mapa, X o pacote global e C um dossiê do pacote atual.
  (when (key-edge-p state malkuth.sdl3:+sc-p+)
    (handler-case
        (let ((path (output-path state "malkuth-live.svg")))
          (export-svg (app-state-snapshot state) path :selected (selected-node state))
          (flash-status state (format nil "SVG EXPORTADO: ~A" (namestring path)) 4200))
      (error (condition)
        (flash-status state (format nil "FALHA AO EXPORTAR SVG: ~A" condition) 5200))))
  (when (key-edge-p state malkuth.sdl3:+sc-x+)
    (handler-case
        (progn
          (export-bundle (app-state-snapshot state)
                         (app-state-export-directory state)
                         :selected (selected-node state)
                         :analysis (app-state-analysis state))
          (flash-status state
                        (format nil "PACOTE DE RELATÓRIOS EXPORTADO: ~A"
                                (namestring (app-state-export-directory state)))
                        5200))
      (error (condition)
        (flash-status state (format nil "FALHA AO EXPORTAR O PACOTE: ~A" condition) 5200))))
  (when (key-edge-p state malkuth.sdl3:+sc-y+)
    (handler-case (export-current-comparison! state)
      (error (condition)
        (flash-status state (format nil "FALHA AO EXPORTAR COMPARAÇÃO: ~A" condition) 5200))))
  (when (key-edge-p state malkuth.sdl3:+sc-c+)
    (handler-case
        (let* ((paths (export-package-bundle
                       (app-state-snapshot state)
                       (selected-node state)
                       (app-state-export-directory state)
                       :analysis (app-state-analysis state)))
               (path (getf paths :markdown)))
          (flash-status state (format nil "DOSSIÊ DO PACOTE EXPORTADO: ~A"
                                      (namestring path))
                        5200))
      (error (condition)
        (flash-status state (format nil "FALHA NO DOSSIÊ DO PACOTE: ~A" condition) 5200))))

  ;; Controles contínuos da câmera. O valor DT torna a velocidade independente
  ;; da taxa de quadros e os limites evitam inverter ou atravessar a cena.
  (let ((turn (* 1.2d0 dt))
        (zoom (* 48.0d0 dt)))
    (when (malkuth.sdl3:keyboard-down-p malkuth.sdl3:+sc-a+)
      (decf (app-state-yaw state) turn))
    (when (malkuth.sdl3:keyboard-down-p malkuth.sdl3:+sc-d+)
      (incf (app-state-yaw state) turn))
    (when (malkuth.sdl3:keyboard-down-p malkuth.sdl3:+sc-w+)
      (decf (app-state-pitch state) turn)
      (setf (app-state-pitch state) (clamp (app-state-pitch state) -1.2d0 1.2d0)))
    (when (malkuth.sdl3:keyboard-down-p malkuth.sdl3:+sc-s+)
      (incf (app-state-pitch state) turn)
      (setf (app-state-pitch state) (clamp (app-state-pitch state) -1.2d0 1.2d0)))
    (when (malkuth.sdl3:keyboard-down-p malkuth.sdl3:+sc-q+)
      (setf (app-state-distance state)
            (clamp (+ (app-state-distance state) zoom) 54.0d0 220.0d0)))
    (when (malkuth.sdl3:keyboard-down-p malkuth.sdl3:+sc-e+)
      (setf (app-state-distance state)
            (clamp (- (app-state-distance state) zoom) 54.0d0 220.0d0))))

  ;; Seleção por apontamento e clique considera apenas nós do filtro corrente.
  (multiple-value-bind (mouse-x mouse-y buttons) (malkuth.sdl3:mouse-state)
    (let* ((inside (and (>= mouse-x graph-x) (< mouse-x (+ graph-x graph-w))
                        (>= mouse-y graph-y) (< mouse-y (+ graph-y graph-h))))
           (hover (and inside
                       (nearest-display-node state mouse-x mouse-y :max-distance 42.0d0)))
           (down (logtest malkuth.sdl3:+mouse-left+ buttons)))
      (setf (app-state-mouse-x state) mouse-x
            (app-state-mouse-y state) mouse-y
            (app-state-hover-index state) (if hover (node-id hover) -1))
      (when (and down (not (app-state-mouse-was-down-p state)) hover)
        (set-selected! state hover))
      (setf (app-state-mouse-was-down-p state) down))))

(defun update-input! (state window width graph-x graph-y graph-w graph-h dt text-inputs)
  "Coordena a busca modal e delega os demais comandos à entrada convencional.

Enquanto a busca está ativa, atalhos globais e câmera ficam suspensos para que
letras digitadas não alterem a cena. ESC fecha primeiro a busca e a ajuda; só
então solicita o encerramento da aplicação."
  (let* ((escape-edge (key-edge-p state malkuth.sdl3:+sc-escape+))
         (slash-edge (key-edge-p state malkuth.sdl3:+sc-slash+))
         (f-edge (key-edge-p state malkuth.sdl3:+sc-f+))
         (control-down (or (malkuth.sdl3:keyboard-down-p malkuth.sdl3:+sc-left-control+)
                           (malkuth.sdl3:keyboard-down-p malkuth.sdl3:+sc-right-control+))))
    ;; Eventos SDL_TEXT_INPUT podem trazer mais de um ponto de código, inclusive
    ;; composições confirmadas por métodos de entrada internacionais.
    (when (app-state-search-active-p state)
      (dolist (text-input text-inputs)
        (append-search-text! state text-input window width)))

    (multiple-value-bind (mouse-x mouse-y buttons) (malkuth.sdl3:mouse-state)
      (let* ((down (logtest malkuth.sdl3:+mouse-left+ buttons))
             (click (and down (not (app-state-mouse-was-down-p state))))
             (result-index (and (app-state-search-active-p state)
                                (search-result-at-point state width mouse-x mouse-y))))
        (setf (app-state-mouse-x state) mouse-x
              (app-state-mouse-y state) mouse-y)
        (multiple-value-bind (box-x box-y box-width box-height) (search-box-geometry width)
          (let ((box-click (and click
                                (point-in-rectangle-p mouse-x mouse-y
                                                      box-x box-y box-width box-height))))
            (cond
              ((app-state-search-active-p state)
               (setf (app-state-hover-index state) -1)
               (when result-index
                 (setf (app-state-search-result-index state) result-index))
               (cond
                 (escape-edge
                  (deactivate-search! state window)
                  (flash-status state "BUSCA FECHADA"))
                 ((key-edge-p state malkuth.sdl3:+sc-backspace+)
                  (delete-search-character! state window width))
                 ((or (key-edge-p state malkuth.sdl3:+sc-down+)
                      (key-edge-p state malkuth.sdl3:+sc-tab+))
                  (move-search-result! state 1))
                 ((key-edge-p state malkuth.sdl3:+sc-up+)
                  (move-search-result! state -1))
                 ((key-edge-p state malkuth.sdl3:+sc-return+)
                  (choose-search-result! state window))
                 ((and click result-index)
                  (choose-search-result! state window result-index))
                 ((and click (not box-click))
                  (deactivate-search! state window)))
               (setf (app-state-mouse-was-down-p state) down))

              ((or slash-edge (and f-edge control-down) box-click)
               (activate-search! state window width
                                 :clear (or slash-edge (and f-edge control-down)))
               (setf (app-state-mouse-was-down-p state) down))

              (t
               (when escape-edge
                 (if (app-state-help-p state)
                     (setf (app-state-help-p state) nil)
                     (setf (app-state-quit-requested-p state) t)))
               (when (and f-edge (not control-down))
                 (toggle-favorite! state))
               (update-normal-input! state graph-x graph-y graph-w graph-h dt)))))))))

;;;; Renderização do mapa e dos painéis

(defun draw-background (renderer width height graph-x graph-y graph-w graph-h frame)
  (apply-color renderer +background+)
  (malkuth.sdl3:clear renderer)
  ;; Campo de paralaxe discreto: oferece profundidade sem competir com os rótulos.
  (dotimes (i 90)
    (let* ((x (mod (+ (* i 127) (* 0.045 frame (1+ (mod i 3)))) width))
           (y (mod (+ (* i 67) (* 0.018 frame (1+ (mod i 5)))) height))
           (alpha (+ 20 (* 12 (mod i 4)))))
      (malkuth.sdl3:set-color renderer 109 151 210 alpha)
      (malkuth.sdl3:point renderer x y)))
  ;; Área de visualização do grafo.
  (malkuth.sdl3:set-color renderer 9 17 29 244)
  (malkuth.sdl3:fill-rect renderer graph-x graph-y graph-w graph-h)
  (malkuth.sdl3:set-color renderer 30 46 70 88)
  (loop for x from graph-x to (+ graph-x graph-w) by 56
        do (malkuth.sdl3:line renderer x graph-y x (+ graph-y graph-h)))
  (loop for y from graph-y to (+ graph-y graph-h) by 56
        do (malkuth.sdl3:line renderer graph-x y (+ graph-x graph-w) y))
  (apply-color renderer +border+)
  (malkuth.sdl3:outline-rect renderer graph-x graph-y graph-w graph-h))

(defun projected-radius (node)
  (clamp (* (node-radius node) (/ 128.0d0 (max 1.0d0 (node-depth node)))) 3.0d0 15.0d0))

(defun symbol-category-color (line)
  (cond
    ((search "MACRO" line :end2 (min 9 (length line))) '(255 190 84 235))
    ((search "GENÉRICA" line :end2 (min 9 (length line))) '(95 231 211 235))
    ((search "CLASSE" line :end2 (min 9 (length line))) '(195 132 255 235))
    ((search "FUNÇÃO" line :end2 (min 9 (length line))) '(105 169 255 235))
    ((search "VARIÁVEL" line :end2 (min 9 (length line))) '(255 128 181 235))
    (t '(151 169 194 215))))

(defun symbol-name-from-line (line)
  (let* ((trimmed (string-trim " " line))
         (position (position #\space trimmed :from-end t)))
    (if position (subseq trimmed (1+ position)) trimmed)))

(defun draw-symbol-corona (renderer state)
  (let* ((node (selected-node state))
         (lines (subseq (app-state-inspector-lines state)
                        0 (min 15 (length (app-state-inspector-lines state)))))
         (count (length lines)))
    (when (and (node-visible-p node) (plusp count))
      (loop for entry in lines
            for i from 0
            for angle = (+ (* 0.0009d0 (app-state-frame state))
                           (* 2.0d0 pi (/ i count)))
            for ring = (+ 38.0d0 (* 10.0d0 (mod i 3)))
            for sx = (+ (node-screen-x node) (* ring (cos angle)))
            for sy = (+ (node-screen-y node) (* ring 0.62d0 (sin angle)))
            for color = (symbol-category-color entry)
            do (destructuring-bind (r g b a) color
                 (malkuth.sdl3:set-color renderer r g b 28)
                 (malkuth.sdl3:line renderer (node-screen-x node) (node-screen-y node) sx sy)
                 (malkuth.sdl3:set-color renderer r g b a)
                 (malkuth.sdl3:filled-circle renderer sx sy
                                             (if (zerop (mod i 5)) 2.7d0 1.8d0)))))))

(defun draw-constellation (renderer state graph-x graph-y graph-w graph-h)
  "Desenha somente o subconjunto aceito pelo filtro visual atual."
  (let* ((snapshot (app-state-snapshot state))
         (nodes (snapshot-nodes snapshot))
         (selected (selected-node state))
         (hovered (hovered-node state))
         (graph-right (+ graph-x graph-w))
         (graph-bottom (+ graph-y graph-h))
         (label-ids (make-hash-table :test #'eql))
         (display-list (display-nodes state))
         (label-candidates
           (sort (remove-if-not #'node-visible-p (copy-list display-list))
                 #'> :key #'projected-radius)))
    ;; Para manter o mapa legível, somente os maiores pacotes recebem rótulos
    ;; automáticos. Seleção, apontamento e favoritos continuam identificáveis.
    (loop for node in label-candidates
          repeat (min (if (< graph-w 650.0d0) 6 10) (length label-candidates))
          do (setf (gethash (node-id node) label-ids) t))

    ;; Arestas só aparecem quando as duas pontas pertencem ao filtro. Assim o
    ;; modo de vizinhança produz um diagrama local limpo, sem linhas órfãs.
    (loop for edge across (snapshot-edges snapshot)
          for a = (aref nodes (edge-from edge))
          for b = (aref nodes (edge-to edge))
          when (and (display-node-p state a) (display-node-p state b)
                    (node-visible-p a) (node-visible-p b))
            do (let* ((connected (or (eq a selected) (eq b selected)))
                      (depth (/ (+ (node-depth a) (node-depth b)) 2.0d0))
                      (alpha (if connected 145
                                 (round (clamp (- 72 (* 0.40 depth)) 12 48)))))
                 (if connected
                     (malkuth.sdl3:set-color renderer 112 226 194 alpha)
                     (malkuth.sdl3:set-color renderer 82 139 219 alpha))
                 (malkuth.sdl3:line renderer (node-screen-x a) (node-screen-y a)
                                    (node-screen-x b) (node-screen-y b))))

    ;; A ordem de profundidade evita que nós distantes cubram os mais próximos.
    (dolist (node (remove-if-not (lambda (item) (display-node-p state item))
                                 (sorted-visible-nodes snapshot)))
      (multiple-value-bind (r g b) (rgb-for-kind (node-kind node))
        (let* ((selected-p (eq node selected))
               (hovered-p (and hovered (eq node hovered)))
               (favorite (favorite-p state node))
               (changed (changed-package-p state node))
               (radius (projected-radius node)))
          (when (or selected-p hovered-p)
            (loop for halo from (if selected-p 32 23) downto 13 by 4
                  for alpha from 12 by 10
                  do (malkuth.sdl3:set-color renderer r g b alpha)
                     (malkuth.sdl3:circle renderer (node-screen-x node)
                                          (node-screen-y node) halo :segments 28)))
          ;; Pacotes alterados recebem um anel magenta; favoritos mantêm o anel
          ;; dourado externo. As duas marcações podem coexistir.
          (when changed
            (malkuth.sdl3:set-color renderer 255 112 180 225)
            (malkuth.sdl3:circle renderer (node-screen-x node)
                                 (node-screen-y node) (+ radius 3.0d0) :segments 24))
          ;; Favoritos recebem um anel dourado discreto, visível em qualquer modo.
          (when favorite
            (malkuth.sdl3:set-color renderer 255 204 92 225)
            (malkuth.sdl3:circle renderer (node-screen-x node)
                                 (node-screen-y node) (+ radius 5.0d0) :segments 24))
          (malkuth.sdl3:set-color renderer r g b (if selected-p 92 38))
          (malkuth.sdl3:filled-circle renderer (node-screen-x node)
                                      (node-screen-y node) (+ radius 2.5d0))
          (malkuth.sdl3:set-color renderer 6 14 25 255)
          (malkuth.sdl3:filled-circle renderer (node-screen-x node)
                                      (node-screen-y node) radius)
          (malkuth.sdl3:set-color renderer r g b (if (or selected-p hovered-p) 255 225))
          (malkuth.sdl3:circle renderer (node-screen-x node)
                               (node-screen-y node) radius :segments 24)
          (when (or selected-p hovered-p favorite changed
                    (gethash (node-id node) label-ids))
            (let* ((scale (cond (selected-p 1.42d0) (hovered-p 1.25d0) (t 1.15d0)))
                   (screen-x (node-screen-x node))
                   (screen-y (node-screen-y node))
                   (right-room (max 0.0d0 (- graph-right screen-x radius 12.0d0)))
                   (left-room (max 0.0d0 (- screen-x graph-x radius 12.0d0)))
                   (draw-left-p (> left-room right-room))
                   (room (max 30.0d0 (min 260.0d0 (if draw-left-p left-room right-room))))
                   (prefix (cond ((and favorite changed) "FAV + ALT / ")
                                 (favorite "FAV / ")
                                 (changed "ALT / ")
                                 (t "")))
                   (label (fit-text (concatenate 'string prefix (node-name node)) room :scale scale))
                   (label-width (vector-text-width label :scale (readable-scale scale) :spacing 1.0))
                   (label-x (if draw-left-p
                                (- screen-x radius 8.0d0 label-width)
                                (+ screen-x radius 8.0d0)))
                   (label-y (clamp (- screen-y 5.0d0)
                                   (+ graph-y 68.0d0)
                                   (- graph-bottom 14.0d0))))
              (text renderer label-x label-y label :scale scale
                    :color (cond (selected-p '(235 255 248 255))
                                 (hovered-p '(224 237 252 255))
                                 (favorite '(255 214 112 245))
                                 (changed '(255 151 205 245))
                                 (t '(154 178 211 235)))))))))
    (draw-symbol-corona renderer state)))

(defun stat-card (renderer x y w h label value)
  (apply-color renderer +surface-raised+)
  (malkuth.sdl3:fill-rect renderer x y w h)
  (apply-color renderer +border-soft+)
  (malkuth.sdl3:outline-rect renderer x y w h)
  (text renderer (+ x 12) (+ y 11) (fit-text label (- w 24) :scale 1.15)
        :scale 1.15 :color +text-muted+)
  (text renderer (+ x 12) (+ y 37) (format nil "~:D" value)
        :scale 1.62 :color +text-primary+))

(defun health-color (score)
  (cond ((>= score 85) +accent+)
        ((>= score 65) '(255 202 92 255))
        (t '(255 112 132 255))))

(defun compact-summary-row (renderer x y w label value &key color)
  (text renderer x y (fit-text label (- w 86) :scale 1.08)
        :scale 1.08 :color +text-muted+)
  (let* ((value (princ-to-string value))
         (value-width (vector-text-width value :scale (readable-scale 1.20) :spacing 1.0)))
    (text renderer (- (+ x w) value-width) (- y 1) value
          :scale 1.20 :color (or color +text-primary+))))

(defun draw-overview-panel (renderer state x y w h)
  (text renderer (+ x 20) (+ y 18) "VISÃO GERAL DA IMAGEM" :scale 1.78 :color +text-primary+)
  (text renderer (+ x 20) (+ y 49) "INSTANTÂNEO ATIVO VALIDADO" :scale 1.15 :color +text-muted+)
  (let* ((snapshot (app-state-snapshot state))
         (analysis (app-state-analysis state))
         (gap 10.0d0)
         (card-w (/ (- w 50.0d0 gap) 2.0d0))
         (rows `(("PACOTES" ,(length (snapshot-nodes snapshot)))
                 ("LIGAÇÕES" ,(length (snapshot-edges snapshot)))
                 ("SÍMBOLOS" ,(snapshot-total-symbols snapshot))
                 ("FUNÇÕES" ,(snapshot-total-functions snapshot))
                 ("GENÉRICAS" ,(snapshot-total-generics snapshot))
                 ("MACROS" ,(snapshot-total-macros snapshot))
                 ("CLASSES" ,(snapshot-total-classes snapshot))
                 ("VARIÁVEIS" ,(snapshot-total-variables snapshot)))))
    (loop for (label value) in rows
          for i from 0
          for column = (mod i 2)
          for row = (floor i 2)
          for card-x = (+ x 20 (* column (+ card-w gap)))
          for card-y = (+ y 80 (* row 73))
          do (stat-card renderer card-x card-y card-w 62 label value))
    (separator renderer (+ x 20) (+ y 380) (- (+ x w) 20))
    (text renderer (+ x 20) (+ y 402) "SAÚDE DA ARQUITETURA" :scale 1.24 :color +text-secondary+)
    (let* ((score (analysis-report-health-score analysis))
           (score-label (format nil "~D / 100" score)))
      (badge renderer (+ x 20) (+ y 432) score-label
             :scale 1.18 :foreground (health-color score)
             :background '(18 33 43 255) :border (health-color score)))
    (compact-summary-row renderer (+ x 20) (+ y 486) (- w 40)
                         "CICLOS" (length (analysis-report-cycles analysis)))
    (compact-summary-row renderer (+ x 20) (+ y 518) (- w 40)
                         "PACOTES ISOLADOS" (length (analysis-report-orphans analysis)))
    (compact-summary-row renderer (+ x 20) (+ y 550) (- w 40)
                         "AVISOS" (length (analysis-report-warnings analysis)))
    (when (> h 650)
      (separator renderer (+ x 20) (+ y 579) (- (+ x w) 20))
      (compact-summary-row renderer (+ x 20) (+ y 602) (- w 40)
                           "PACOTES VISÍVEIS" (length (display-nodes state))
                           :color +accent+)
      (compact-summary-row renderer (+ x 20) (+ y 632) (- w 40)
                           "FAVORITOS" (hash-table-count (app-state-favorites state))
                           :color '(255 214 112 255)))
    (when (> h 715)
      (text renderer (+ x 20) (+ y 674)
            (fit-text "1-6 FILTROS / B LINHA DE BASE" (- w 40) :scale 1.02)
            :scale 1.02 :color +accent+)
      (text renderer (+ x 20) (+ y 701)
            (fit-text "T EVOLUÇÃO / Y EXPORTA COMPARAÇÃO" (- w 40) :scale 1.02)
            :scale 1.02 :color +accent+))))

(defun draw-diagnostics-panel (renderer state x y w h)
  (let* ((analysis (app-state-analysis state))
         (score (analysis-report-health-score analysis))
         (hubs (analysis-report-hubs analysis))
         (warnings (analysis-report-warnings analysis)))
    (text renderer (+ x 20) (+ y 18) "DIAGNÓSTICOS" :scale 1.78 :color +text-primary+)
    (text renderer (+ x 20) (+ y 49) "ACOPLAMENTO, CICLOS E RISCO" :scale 1.15 :color +text-muted+)
    (separator renderer (+ x 20) (+ y 77) (- (+ x w) 20))
    (text renderer (+ x 20) (+ y 100) "PONTUAÇÃO DE SAÚDE" :scale 1.15 :color +text-muted+)
    (text renderer (+ x 20) (+ y 130) (format nil "~D / 100" score)
          :scale 2.20 :color (health-color score))
    (text renderer (+ x 20) (+ y 172)
          (fit-text (format nil "ID ~A" (snapshot-fingerprint (app-state-snapshot state)))
                    (- w 40) :scale 1.02)
          :scale 1.02 :color +text-muted+)
    (compact-summary-row renderer (+ x 20) (+ y 208) (- w 40)
                         "CICLOS" (length (analysis-report-cycles analysis)))
    (compact-summary-row renderer (+ x 20) (+ y 238) (- w 40)
                         "ISOLADOS" (length (analysis-report-orphans analysis)))
    (compact-summary-row renderer (+ x 20) (+ y 268) (- w 40)
                         "AVISOS" (length warnings))
    (separator renderer (+ x 20) (+ y 296) (- (+ x w) 20))
    (text renderer (+ x 20) (+ y 318) "PRINCIPAIS CENTROS DE CONECTIVIDADE" :scale 1.18 :color +text-secondary+)
    (loop for metric in hubs
          for row-y from (+ y 352) by 31
          repeat (min 5 (length hubs))
          do (text renderer (+ x 20) row-y
                   (fit-text (node-metrics-name metric) (- w 104) :scale 1.05)
                   :scale 1.05 :color +text-secondary+)
             (let* ((degree (format nil "D~D" (node-metrics-total-degree metric)))
                    (degree-width (vector-text-width degree :scale (readable-scale 1.05) :spacing 1.0)))
               (text renderer (- (+ x w) degree-width 20) row-y degree
                     :scale 1.05 :color +accent+)))
    (separator renderer (+ x 20) (+ y 516) (- (+ x w) 20))
    (text renderer (+ x 20) (+ y 538) "ACHADOS PRIORITÁRIOS" :scale 1.18 :color +text-secondary+)
    (let ((available-rows (max 0 (floor (- h 596) 42))))
      (if warnings
          (loop for item in warnings
                for row-y from (+ y 572) by 42
                repeat (min available-rows (length warnings))
                do (text renderer (+ x 20) row-y
                         (fit-text (analysis-warning-message item) (- w 40) :scale 1.02)
                         :scale 1.02
                         :color (if (eq (analysis-warning-severity item) :error)
                                    '(255 112 132 255) '(255 202 92 255))))
          (text renderer (+ x 20) (+ y 572) "NENHUM AVISO PELAS REGRAS ATUAIS"
                :scale 1.02 :color +accent+)))
    (text renderer (+ x 20) (- (+ y h) 50)
          (fit-text "G VISÃO GERAL / F5 ATUALIZAR" (- w 40) :scale 1.02)
          :scale 1.02 :color +accent+)
    (text renderer (+ x 20) (- (+ y h) 24)
          (fit-text "F FAVORITO / I ALTERNA ABA" (- w 40) :scale 1.02)
          :scale 1.02 :color +accent+)))

(defun delta-color (delta &key (positive-good t))
  "Escolhe uma cor semântica para DELTA conforme a direção desejável."
  (cond ((zerop delta) +text-muted+)
        ((if positive-good (plusp delta) (minusp delta)) +accent+)
        (t '(255 112 132 255))))

(defun draw-changes-panel (renderer state x y w h)
  "Resume a evolução da arquitetura em relação à linha de base persistida."
  (let* ((diff (app-state-architecture-diff state))
         (baseline (app-state-baseline-snapshot state)))
    (text renderer (+ x 20) (+ y 18) "EVOLUÇÃO DA ARQUITETURA"
          :scale 1.70 :color +text-primary+)
    (text renderer (+ x 20) (+ y 49) "COMPARAÇÃO CONTRA A LINHA DE BASE"
          :scale 1.10 :color +text-muted+)
    (separator renderer (+ x 20) (+ y 77) (- (+ x w) 20))
    (if (null diff)
        (progn
          (text renderer (+ x 20) (+ y 112)
                "NENHUMA LINHA DE BASE DISPONÍVEL" :scale 1.20
                :color '(255 202 92 255))
          (text renderer (+ x 20) (+ y 151)
                (fit-text "PRESSIONE B PARA CAPTURAR O ESTADO ATUAL"
                          (- w 40) :scale 1.05)
                :scale 1.05 :color +text-muted+))
        (let* ((snapshot-diff (architecture-diff-snapshot-diff diff))
               (health-delta (architecture-diff-health-delta diff))
               (warning-delta (architecture-diff-warning-delta diff))
               (risk-increases (architecture-diff-risk-increases diff)))
          (text renderer (+ x 20) (+ y 103) "VARIAÇÃO DE SAÚDE"
                :scale 1.12 :color +text-muted+)
          (text renderer (+ x 20) (+ y 134) (format nil "~@D PONTOS" health-delta)
                :scale 2.00 :color (delta-color health-delta))
          (text renderer (+ x 20) (+ y 174)
                (fit-text (format nil "BASE ~A" (snapshot-fingerprint baseline))
                          (- w 40) :scale 1.00)
                :scale 1.00 :color +text-muted+)
          (compact-summary-row renderer (+ x 20) (+ y 214) (- w 40)
                               "PACOTES ADICIONADOS"
                               (length (snapshot-diff-added-packages snapshot-diff))
                               :color +accent+)
          (compact-summary-row renderer (+ x 20) (+ y 246) (- w 40)
                               "PACOTES REMOVIDOS"
                               (length (snapshot-diff-removed-packages snapshot-diff))
                               :color '(255 202 92 255))
          (compact-summary-row renderer (+ x 20) (+ y 278) (- w 40)
                               "PACOTES ALTERADOS"
                               (length (snapshot-diff-changed-packages snapshot-diff))
                               :color +text-primary+)
          (compact-summary-row renderer (+ x 20) (+ y 310) (- w 40)
                               "NOVOS CICLOS"
                               (length (architecture-diff-new-cycles diff))
                               :color (if (architecture-diff-new-cycles diff)
                                          '(255 112 132 255) +accent+))
          (compact-summary-row renderer (+ x 20) (+ y 342) (- w 40)
                               "CICLOS RESOLVIDOS"
                               (length (architecture-diff-resolved-cycles diff))
                               :color +accent+)
          (compact-summary-row renderer (+ x 20) (+ y 374) (- w 40)
                               "VARIAÇÃO DE AVISOS"
                               (format nil "~@D" warning-delta)
                               :color (delta-color warning-delta :positive-good nil))
          (separator renderer (+ x 20) (+ y 410) (- (+ x w) 20))
          (text renderer (+ x 20) (+ y 434) "MAIORES AUMENTOS DE RISCO"
                :scale 1.16 :color +text-secondary+)
          (if risk-increases
              (loop for change in risk-increases
                    for row-y from (+ y 470) by 34
                    repeat (min 5 (length risk-increases))
                    do (text renderer (+ x 20) row-y
                             (fit-text (risk-change-name change) (- w 102) :scale 1.04)
                             :scale 1.04 :color +text-secondary+)
                       (let* ((label (format nil "+~D" (risk-change-delta change)))
                              (label-width (vector-text-width label
                                                              :scale (readable-scale 1.08)
                                                              :spacing 1.0)))
                         (text renderer (- (+ x w) label-width 20) row-y label
                               :scale 1.08 :color '(255 112 132 255))))
              (text renderer (+ x 20) (+ y 470) "NENHUM AUMENTO DE RISCO"
                    :scale 1.04 :color +accent+))
          (when (> h 680)
            (separator renderer (+ x 20) (- (+ y h) 92) (- (+ x w) 20))
            (text renderer (+ x 20) (- (+ y h) 66)
                  (fit-text "6 FILTRA ALTERADOS / Y EXPORTA COMPARAÇÃO"
                            (- w 40) :scale 1.00)
                  :scale 1.00 :color +accent+)
            (text renderer (+ x 20) (- (+ y h) 39)
                  (fit-text "B SUBSTITUI A LINHA DE BASE / T VOLTA"
                            (- w 40) :scale 1.00)
                  :scale 1.00 :color +accent+))))))

(defun draw-left-panel (renderer state x y w h)
  (panel renderer x y w h :accent +accent-dim+)
  (cond
    ((app-state-changes-p state)
     (draw-changes-panel renderer state x y w h))
    ((app-state-diagnostics-p state)
     (draw-diagnostics-panel renderer state x y w h))
    (t
     (draw-overview-panel renderer state x y w h))))

(defun draw-metric-row (renderer x y w label value &key (alternate nil))
  (when alternate
    (apply-color renderer '(20 31 51 210))
    (malkuth.sdl3:fill-rect renderer x (- y 9) w 31))
  (text renderer (+ x 10) y (fit-text label (- w 76) :scale 1.12)
        :scale 1.12 :color +text-muted+)
  (let* ((value-string (format nil "~:D" value))
         (value-width (vector-text-width value-string :scale 1.28 :spacing 1.0)))
    (text renderer (- (+ x w) value-width 10) (- y 2) value-string
          :scale 1.28 :color +text-primary+)))

(defun draw-symbol-tab (renderer state x y w h)
  "Desenha a aba paginada de símbolos próprios do pacote selecionado."
  (let* ((lines (app-state-inspector-lines state))
         (count (length lines))
         (offset (min (app-state-inspector-offset state) (max 0 (1- count))))
         (start-y (+ y 540))
         (row-height 31.0d0)
         (available (- (+ y h) start-y 15.0d0))
         (limit (max 0 (floor available row-height)))
         (end (min count (+ offset limit)))
         (type-x (+ x 20))
         (name-x (+ x (if (< w 390) 126 142)))
         (name-width (- (+ x w) name-x 20)))
    (text renderer (+ x 20) (+ y 477)
          (fit-text (format nil "SÍMBOLOS / ~D-~D DE ~D"
                            (if (zerop count) 0 (1+ offset)) end count)
                    (- w 40) :scale 1.18)
          :scale 1.18 :color +text-secondary+)
    (text renderer type-x (+ y 510) "TIPO" :scale 1.05 :color +text-muted+)
    (text renderer name-x (+ y 510) "NOME" :scale 1.05 :color +text-muted+)
    (loop for line in (subseq lines offset end)
          for row-y from start-y by row-height
          for i from offset
          do (when (oddp i)
               (apply-color renderer '(19 30 50 190))
               (malkuth.sdl3:fill-rect renderer (+ x 10) (- row-y 8) (- w 20) 27))
             (let* ((trimmed (string-trim " " line))
                    (split (position #\space trimmed))
                    (kind (if split (subseq trimmed 0 split) "SÍMBOLO"))
                    (name (symbol-name-from-line line))
                    (color (symbol-category-color line)))
               (text renderer type-x row-y
                     (fit-text kind (- name-x type-x 12) :scale 1.05)
                     :scale 1.05 :color color)
               (text renderer name-x row-y
                     (fit-text name name-width :scale 1.15)
                     :scale 1.15 :color +text-secondary+)))))

(defun draw-dependency-tab (renderer state x y w h)
  "Desenha dependências de saída e dependentes de entrada do pacote atual."
  (let* ((rows (dependency-rows state))
         (count (length rows))
         (offset (min (app-state-inspector-offset state) (max 0 (1- count))))
         (start-y (+ y 540))
         (row-height 36.0d0)
         (available (- (+ y h) start-y 15.0d0))
         (limit (max 0 (floor available row-height)))
         (end (min count (+ offset limit)))
         (direction-x (+ x 20))
         (name-x (+ x 118))
         (risk-x (- (+ x w) 62))
         (name-width (- risk-x name-x 10)))
    (text renderer (+ x 20) (+ y 477)
          (fit-text (format nil "DEPENDÊNCIAS / ~D-~D DE ~D"
                            (if (zerop count) 0 (1+ offset)) end count)
                    (- w 40) :scale 1.18)
          :scale 1.18 :color +text-secondary+)
    (text renderer direction-x (+ y 510) "DIREÇÃO" :scale 1.05 :color +text-muted+)
    (text renderer name-x (+ y 510) "PACOTE" :scale 1.05 :color +text-muted+)
    (text renderer risk-x (+ y 510) "RISCO" :scale 1.05 :color +text-muted+)
    (if (zerop count)
        (text renderer (+ x 20) start-y "NENHUMA RELAÇÃO DIRETA NO INSTANTÂNEO"
              :scale 1.08 :color +accent+)
        (loop for (direction item) in (subseq rows offset end)
              for row-y from start-y by row-height
              for i from offset
              for metric = (metrics-for-node (app-state-analysis state) item)
              for risk = (node-metrics-risk-score metric)
              do (when (oddp i)
                   (apply-color renderer '(19 30 50 190))
                   (malkuth.sdl3:fill-rect renderer (+ x 10) (- row-y 8) (- w 20) 30))
                 (text renderer direction-x row-y
                       (if (eq direction :saida) "USA" "USADO POR")
                       :scale 1.02
                       :color (if (eq direction :saida)
                                  '(105 169 255 235)
                                  '(124 255 207 235)))
                 (text renderer name-x row-y
                       (fit-text (node-name item) name-width :scale 1.10)
                       :scale 1.10 :color +text-secondary+)
                 (text renderer risk-x row-y (format nil "~D" risk)
                       :scale 1.10 :color (if (>= risk (app-state-risk-threshold state))
                                             '(255 202 92 255)
                                             +text-muted+))))))

(defun draw-inspector (renderer state x y w h)
  "Desenha métricas estáveis e delega o conteúdo paginado à aba selecionada."
  (let* ((node (selected-node state))
         (metric (selected-metrics state)))
    (multiple-value-bind (r g b) (rgb-for-kind (node-kind node))
      (panel renderer x y w h :accent (list r g b 255))
      (text renderer (+ x 20) (+ y 18) "DETALHES DO PACOTE" :scale 1.78 :color +text-primary+)
      (text renderer (+ x 20) (+ y 49)
            (format nil "ABA ~A / I ALTERNA" (inspector-tab-name (app-state-inspector-tab state)))
            :scale 1.08 :color +text-muted+)
      (separator renderer (+ x 20) (+ y 77) (- (+ x w) 20))
      (text renderer (+ x 20) (+ y 101)
            (fit-text (node-name node) (- w 40) :scale 1.62)
            :scale 1.62 :color (list r g b 255))
      (let* ((role-width
               (badge renderer (+ x 20) (+ y 137) (role-name (node-kind node))
                      :scale 1.0 :foreground (list r g b 255)
                      :background (list (round (* r 0.12))
                                        (round (* g 0.12))
                                        (round (* b 0.12)) 255)
                      :border (list r g b 170)))
             (next-x (+ x 32 role-width)))
        (when (favorite-p state node)
          (incf next-x (badge renderer next-x (+ y 137) "FAVORITO"
                                :scale 1.0 :foreground '(255 214 112 255)
                                :background '(50 39 18 255)
                                :border '(143 111 47 255)))
          (incf next-x 10))
        (when (and (> w 390) (< next-x (- (+ x w) 130)))
          (badge renderer next-x (+ y 137)
                 (format nil "RISCO ~D" (node-metrics-risk-score metric))
                 :scale 1.0
                 :foreground (if (>= (node-metrics-risk-score metric)
                                     (app-state-risk-threshold state))
                                 '(255 202 92 255)
                                 +text-secondary+))))
      (text renderer (+ x 20) (+ y 188) "CONTEÚDO E ACOPLAMENTO"
            :scale 1.22 :color +text-secondary+)
      (let ((rows `(("SÍMBOLOS INTERNOS" ,(node-internal node))
                    ("SÍMBOLOS EXPORTADOS" ,(node-external node))
                    ("FUNÇÕES" ,(node-functions node))
                    ("FUNÇÕES GENÉRICAS" ,(node-generics node))
                    ("MACROS" ,(node-macros node))
                    ("CLASSES" ,(node-classes node))
                    ("ENTRADA" ,(node-metrics-fan-in metric))
                    ("SAÍDA" ,(node-metrics-fan-out metric)))))
        (loop for (label value) in rows
              for row-y from (+ y 220) by 30
              for alternate = nil then (not alternate)
              do (draw-metric-row renderer (+ x 10) row-y (- w 20) label value
                                  :alternate alternate)))
      (separator renderer (+ x 20) (+ y 454) (- (+ x w) 20))
      (ecase (app-state-inspector-tab state)
        (:symbols (draw-symbol-tab renderer state x y w h))
        (:dependencies (draw-dependency-tab renderer state x y w h))))))

(defun draw-map-toolbar (renderer state graph-x graph-y graph-w)
  "Exibe contexto do filtro e estados de simulação sem cobrir o grafo."
  (text renderer (+ graph-x 18) (+ graph-y 17) "MAPA DE PACOTES"
        :scale 1.78 :color +text-primary+)
  (text renderer (+ graph-x 18) (+ graph-y 49)
        (fit-text (format nil "FILTRO ~A / ~D DE ~D PACOTES"
                          (filter-name (app-state-view-filter state))
                          (length (display-nodes state))
                          (length (snapshot-nodes (app-state-snapshot state))))
                  (- graph-w 430) :scale 1.05)
        :scale 1.05 :color +text-muted+)
  (let* ((physics-label (if (app-state-paused-p state) "PAUSADO" "ARRANJO ATIVO"))
         (orbit-label (if (app-state-auto-orbit-p state) "ÓRBITA ATIVA" "ÓRBITA INATIVA"))
         (score (analysis-report-health-score (app-state-analysis state)))
         (health-label (format nil "SAÚDE ~D" score))
         (scale 1.0d0)
         (health-width (vector-text-width health-label :scale (readable-scale scale) :spacing 1.0))
         (orbit-width (vector-text-width orbit-label :scale (readable-scale scale) :spacing 1.0))
         (physics-width (vector-text-width physics-label :scale (readable-scale scale) :spacing 1.0))
         (right (+ graph-x graph-w -18))
         (physics-x (- right physics-width 18))
         (orbit-x (- physics-x orbit-width 42))
         (health-x (- orbit-x health-width 42)))
    (when (> graph-w 760.0d0)
      (badge renderer health-x (+ graph-y 13) health-label
             :scale scale :foreground (health-color score)
             :background '(18 33 43 255) :border (health-color score)))
    (when (> graph-w 560.0d0)
      (badge renderer orbit-x (+ graph-y 13) orbit-label
             :scale scale :foreground +text-secondary+))
    (badge renderer physics-x (+ graph-y 13) physics-label
           :scale scale
           :foreground (if (app-state-paused-p state) '(255 191 99 255) +accent+)
           :background (if (app-state-paused-p state) '(55 38 20 255) '(18 43 43 255))
           :border (if (app-state-paused-p state) '(126 89 42 255) '(48 104 92 255)))))

(defun draw-hover-tooltip (renderer state graph-x graph-y graph-w graph-h)
  "Resume papel, tamanho, risco e estado de favorito do nó apontado."
  (let ((node (hovered-node state)))
    (when node
      (let* ((metric (metrics-for-node (app-state-analysis state) node))
             (mouse-x (app-state-mouse-x state))
             (mouse-y (app-state-mouse-y state))
             (w 330.0d0)
             (h 118.0d0)
             (x (clamp (+ mouse-x 18.0d0) (+ graph-x 8.0d0)
                       (- (+ graph-x graph-w) w 8.0d0)))
             (y (clamp (+ mouse-y 18.0d0) (+ graph-y 72.0d0)
                       (- (+ graph-y graph-h) h 8.0d0))))
        (multiple-value-bind (r g b) (rgb-for-kind (node-kind node))
          (panel renderer x y w h :raised t :accent (list r g b 255))
          (text renderer (+ x 15) (+ y 14)
                (fit-text (node-name node) (- w 30) :scale 1.32)
                :scale 1.32 :color +text-primary+)
          (text renderer (+ x 15) (+ y 45)
                (fit-text (format nil "~A / ~:D SÍMBOLOS / RISCO ~D"
                                  (role-name (node-kind node))
                                  (+ (node-internal node) (node-external node))
                                  (node-metrics-risk-score metric))
                          (- w 30) :scale 1.08)
                :scale 1.08 :color +text-muted+)
          (text renderer (+ x 15) (+ y 71)
                (if (favorite-p state node) "FAVORITO / F REMOVE" "F ADICIONA AOS FAVORITOS")
                :scale 1.05 :color '(255 214 112 255))
          (text renderer (+ x 15) (+ y 94) "CLIQUE PARA ABRIR OS DETALHES"
                :scale 1.08 :color (list r g b 255)))))))

(defun draw-header (renderer state width)
  (text renderer 26 14 "MALKUTH" :scale 3.05 :color +accent+ :spacing 1.7)
  (multiple-value-bind (search-x search-y search-width search-height)
      (search-box-geometry width)
    (declare (ignore search-y search-width search-height))
    (text renderer 27 56
          (fit-text "0.5.0 / OBSERVATÓRIO DA ARQUITETURA LISP"
                    (- search-x 54.0d0) :scale 1.12)
          :scale 1.12 :color +text-muted+))
  (let* ((implementation (format nil "~A ~A"
                                 (lisp-implementation-type)
                                 (lisp-implementation-version)))
         (fps (format nil "~,0F FPS" (app-state-fps state)))
         (scale 1.0d0)
         (fps-width (vector-text-width fps :scale (readable-scale scale) :spacing 1.0))
         (implementation-label (fit-text implementation 255 :scale scale))
         (implementation-width (vector-text-width implementation-label :scale (readable-scale scale) :spacing 1.0))
         (right (- width 26.0d0))
         (fps-x (- right fps-width 18.0d0))
         (implementation-x (- fps-x implementation-width 40.0d0))
         (search-right (multiple-value-bind (x y w h) (search-box-geometry width)
                         (declare (ignore y h))
                         (+ x w))))
    (when (> implementation-x (+ search-right 22.0d0))
      (badge renderer implementation-x 18 implementation-label :scale scale))
    (badge renderer fps-x 18 fps :scale scale
           :foreground +accent+
           :background '(18 43 43 255)
           :border '(48 104 92 255))))

(defun draw-search-box (renderer state width)
  "Desenha a busca, o cursor e o menu de resultados sobre a interface."
  (multiple-value-bind (x y box-width box-height) (search-box-geometry width)
    (let* ((active (app-state-search-active-p state))
           (query (app-state-search-query state))
           (results (app-state-search-results state))
           (text-x (+ x 43.0d0))
           (count-label (and (plusp (length query))
                             (format nil "~D" (length results))))
           (count-width (if count-label
                            (vector-text-width count-label
                                               :scale (readable-scale 1.02) :spacing 1.0)
                            0.0d0))
           (text-width (- box-width 62.0d0 count-width)))
      (apply-color renderer (if active '(18 31 50 255) +surface+))
      (malkuth.sdl3:fill-rect renderer x y box-width box-height)
      (apply-color renderer (if active +accent+ +border+))
      (malkuth.sdl3:outline-rect renderer x y box-width box-height)
      ;; Lupa vetorial independente da fonte.
      (apply-color renderer (if active +accent+ +text-muted+))
      (malkuth.sdl3:circle renderer (+ x 20) (+ y 20) 7 :segments 20)
      (malkuth.sdl3:line renderer (+ x 25) (+ y 25) (+ x 31) (+ y 31))
      (text renderer text-x (+ y 12)
            (fit-text (if (plusp (length query))
                          query
                          "BUSCAR PACOTE... / OU CTRL+F")
                      text-width :scale 1.18)
            :scale 1.18
            :color (if (plusp (length query)) +text-primary+ +text-muted+))
      (when count-label
        (text renderer (- (+ x box-width) count-width 14.0d0) (+ y 12)
              count-label :scale 1.02
              :color (if results +accent+ '(255 139 139 255))))
      ;; O cursor pisca em uma frequência baixa para permanecer visível sem
      ;; produzir ruído durante a leitura do mapa.
      (when (and active (evenp (floor (/ (app-state-frame state) 28))))
        (let* ((visible-query (fit-text query text-width :scale 1.18))
               (cursor-x (+ text-x
                            (vector-text-width visible-query
                                               :scale (readable-scale 1.18)
                                               :spacing 1.0)
                            3.0d0)))
          (apply-color renderer +accent+)
          (malkuth.sdl3:fill-rect renderer cursor-x (+ y 9) 2.0d0 25.0d0)))

      (when active
        (let ((list-y (+ y box-height 6.0d0))
              (row-height 38.0d0))
          (cond
            ((zerop (length query))
             (panel renderer x list-y box-width 58.0d0 :raised t :accent +accent-dim+)
             (text renderer (+ x 15) (+ list-y 17)
                   "DIGITE PARTE DO NOME / ENTER ABRE / ESC FECHA"
                   :scale 1.08 :color +text-secondary+))
            ((null results)
             (panel renderer x list-y box-width 58.0d0 :raised t :accent '(255 113 113 255))
             (text renderer (+ x 15) (+ list-y 17)
                   "NENHUM PACOTE ENCONTRADO"
                   :scale 1.12 :color '(255 166 166 255)))
            (t
             (multiple-value-bind (start end) (search-visible-window state)
               (let ((height (* row-height (- end start))))
                 (panel renderer x list-y box-width height :raised t :accent +accent-dim+)
                 (loop for absolute-index from start below end
                       for node = (nth absolute-index results)
                       for row from 0
                       for row-y = (+ list-y (* row row-height))
                       for selected-p = (= absolute-index
                                           (app-state-search-result-index state))
                       for metric = (metrics-for-node (app-state-analysis state) node)
                       do (when selected-p
                            (apply-color renderer '(28 61 67 255))
                            (malkuth.sdl3:fill-rect renderer (+ x 4) (+ row-y 3)
                                                           (- box-width 8) (- row-height 6)))
                          (multiple-value-bind (r g b) (rgb-for-kind (node-kind node))
                            (apply-color renderer (list r g b 255))
                            (malkuth.sdl3:fill-rect renderer (+ x 10) (+ row-y 10) 4 18)
                            (text renderer (+ x 24) (+ row-y 10)
                                  (fit-text (node-name node) (- box-width 155) :scale 1.12)
                                  :scale 1.12
                                  :color (if selected-p +text-primary+ +text-secondary+))
                            (text renderer (- (+ x box-width) 126) (+ row-y 10)
                                  (fit-text (role-name (node-kind node)) 72 :scale 1.0)
                                  :scale 1.0 :color (list r g b 255))
                            (text renderer (- (+ x box-width) 45) (+ row-y 10)
                                  (format nil "~D" (node-metrics-risk-score metric))
                                  :scale 1.0
                                  :color (if (>= (node-metrics-risk-score metric)
                                                  (app-state-risk-threshold state))
                                             '(255 202 92 255)
                                             +text-muted+)))))))))))))

(defun draw-footer (renderer state graph-x graph-w height)
  (let* ((status (if (< (malkuth.sdl3:ticks) (app-state-status-until state))
                     (app-state-status state)
                     "/ BUSCA / 1-6 FILTRAM / B BASE / T EVOLUÇÃO / X RELATÓRIOS"))
         (label (fit-text status graph-w :scale 1.08)))
    (text renderer graph-x (- height 29) label
          :scale 1.08
          :color (if (< (malkuth.sdl3:ticks) (app-state-status-until state))
                     +accent+
                     +text-muted+))))

(defun help-row (renderer x y key title description max-width)
  (let* ((key-width (badge renderer x (- y 9) key
                           :scale 1.0
                           :foreground +accent+
                           :background '(18 43 43 255)
                           :border '(48 104 92 255)))
         (text-x (+ x key-width 18))
         (available (- max-width key-width 18)))
    (text renderer text-x y (fit-text title available :scale 1.22)
          :scale 1.22 :color +text-primary+)
    (text renderer text-x (+ y 27) (fit-text description available :scale 1.08)
          :scale 1.08 :color +text-muted+)))

(defun draw-help (renderer width height)
  "Mostra um guia de tarefas com os recursos essenciais da versão atual."
  (apply-color renderer '(3 7 14 238))
  (malkuth.sdl3:fill-rect renderer 0 0 width height)
  (let* ((w (min 1120.0d0 (- width 70.0d0)))
         (h (min 700.0d0 (- height 60.0d0)))
         (x (/ (- width w) 2.0d0))
         (y (/ (- height h) 2.0d0)))
    (panel renderer x y w h :raised t :accent +accent-dim+)
    (text renderer (+ x 32) (+ y 26) "GUIA DO MALKUTH 0.5.0"
          :scale 1.92 :color +accent+)
    (text renderer (+ x 32) (+ y 66)
          (fit-text "FILTRE, INVESTIGUE, FAVORITE E EXPORTE A ARQUITETURA DA IMAGEM ATIVA"
                    (- w 64) :scale 1.16)
          :scale 1.16 :color +text-secondary+)
    (separator renderer (+ x 32) (+ y 99) (- (+ x w) 32))
    (text renderer (+ x 32) (+ y 123) "FLUXO RECOMENDADO"
          :scale 1.32 :color +text-primary+)
    (loop for (number line) in
          '(("1" "PRESSIONE / OU CTRL+F E DIGITE PARTE DO NOME PARA ABRIR UM PACOTE")
            ("2" "USE 1-6 PARA REDUZIR O MAPA A PROJETO, RISCO, FAVORITOS OU VIZINHANÇA")
            ("3" "ALTERNE O INSPETOR COM I E EXPORTE A SELEÇÃO COM C"))
          for row-y from (+ y 162) by 47
          do (badge renderer (+ x 32) (- row-y 9) number
                    :scale 1.0 :foreground +accent+
                    :background '(18 43 43 255) :border '(48 104 92 255))
             (text renderer (+ x 78) row-y
                   (fit-text line (- w 118) :scale 1.16)
                   :scale 1.16 :color +text-secondary+))
    (separator renderer (+ x 32) (+ y 313) (- (+ x w) 32))
    (text renderer (+ x 32) (+ y 338) "RECURSOS PRINCIPAIS"
          :scale 1.32 :color +text-primary+)
    (let* ((column-gap 28.0d0)
           (column-w (/ (- w 64.0d0 column-gap) 2.0d0))
           (left (+ x 32))
           (right (+ left column-w column-gap)))
      (help-row renderer left (+ y 378) "/" "BUSCA DE PACOTES"
                "DIGITAR, NAVEGAR COM SETAS E ABRIR COM ENTER" column-w)
      (help-row renderer left (+ y 438) "1-6" "FILTROS DO MAPA"
                "TODOS, PROJETO, RISCO, FAVORITOS, VIZINHANÇA E ALTERADOS" column-w)
      (help-row renderer left (+ y 498) "F" "FAVORITO PERSISTENTE"
                "MARCAR OU DESMARCAR O PACOTE SELECIONADO" column-w)
      (help-row renderer left (+ y 558) "B" "LINHA DE BASE"
                "CAPTURAR O ESTADO PARA COMPARAÇÕES FUTURAS" column-w)
      (help-row renderer right (+ y 378) "T" "PAINEL DE EVOLUÇÃO"
                "VER REGRESSÕES, CICLOS E ALTERAÇÕES DE RISCO" column-w)
      (help-row renderer right (+ y 438) "Y" "EXPORTAR COMPARAÇÃO"
                "GERAR MARKDOWN E JSON CONTRA A LINHA DE BASE" column-w)
      (help-row renderer right (+ y 498) "X" "RELATÓRIOS COMPLETOS"
                "EXPORTAR SVG, JSON, DOT, MARKDOWN E CSV" column-w)
      (help-row renderer right (+ y 558) "F5" "ATUALIZAR IMAGEM"
                "SALVAR HISTÓRICO, RECONSTRUIR E COMPARAR" column-w))
    (separator renderer (+ x 32) (- (+ y h) 60) (- (+ x w) 32))
    (text renderer (+ x 32) (- (+ y h) 35)
          "WASD CÂMERA / B BASE / T EVOLUÇÃO / Y EXPORTA / G DIAGNÓSTICOS / H VOLTA"
          :scale 1.02 :color +accent+)))

;;;; Composição responsiva e ciclo principal

(defun layout-geometry (width height)
  (let* ((margin 20.0d0)
         (header-h 78.0d0)
         (footer-h 44.0d0)
         (gap 14.0d0)
         (left-w (cond ((< width 1100) 220.0d0)
                       ((< width 1500) 300.0d0)
                       (t 320.0d0)))
         (right-w (cond ((< width 1100) 310.0d0)
                        ((< width 1500) 365.0d0)
                        (t 420.0d0)))
         (graph-x (+ margin left-w gap))
         (graph-y header-h)
         (right-x (- width margin right-w))
         (graph-w (max 300.0d0 (- right-x graph-x gap)))
         (graph-h (max 400.0d0 (- height graph-y footer-h))))
    (values margin graph-x graph-y graph-w graph-h right-x left-w right-w)))

(defun draw-frame (renderer state width height)
  (multiple-value-bind (left-x graph-x graph-y graph-w graph-h right-x left-w right-w)
      (layout-geometry width height)
    (update-projection! (app-state-snapshot state) graph-w graph-h
                        (app-state-yaw state) (app-state-pitch state)
                        (app-state-distance state)
                        :offset-x graph-x :offset-y graph-y :fov 900.0d0)
    (draw-background renderer width height graph-x graph-y graph-w graph-h
                     (app-state-frame state))
    (draw-constellation renderer state graph-x graph-y graph-w graph-h)
    ;; A barra de ferramentas e a dica flutuante são desenhadas sobre o mapa para orientação imediata.
    (draw-map-toolbar renderer state graph-x graph-y graph-w)
    (draw-hover-tooltip renderer state graph-x graph-y graph-w graph-h)
    (draw-left-panel renderer state left-x graph-y left-w graph-h)
    (draw-inspector renderer state right-x graph-y right-w graph-h)
    (draw-header renderer state width)
    (draw-search-box renderer state width)
    (draw-footer renderer state graph-x graph-w height)
    (when (app-state-help-p state)
      (draw-help renderer width height))))

(defun initial-selected-index (snapshot)
  (let ((node (or (find-node-by-name snapshot "MALKUTH.APP")
                  (find-if (lambda (candidate) (eq (node-kind candidate) :user))
                           (coerce (snapshot-nodes snapshot) 'list))
                  (aref (snapshot-nodes snapshot) 0))))
    (node-id node)))

(defun run (&key (width 1600) (height 900) max-frames
                       (include-empty nil) (export-directory #P"output/")
                       (auto-orbit t) package-predicate user-package-predicate
                       (include-dependencies nil) (risk-threshold 20)
                       (history-retention 20) initial-search
                       (initial-panel :overview))
  "Executa o observatório interativo da imagem ativa do Malkuth.

MAX-FRAMES atende aos testes de fumaça. EXPORT-DIRECTORY recebe relatórios e
favoritos e histórico. RISK-THRESHOLD controla o filtro visual de risco sem
alterar a pontuação arquitetural calculada pelo núcleo. HISTORY-RETENTION limita
a quantidade de fotografias rotativas. INITIAL-SEARCH abre a caixa já
preenchida e INITIAL-PANEL escolhe :OVERVIEW, :DIAGNOSTICS ou :CHANGES, o que também facilita inicializadores e testes visuais."
  (let* ((snapshot (build-snapshot :include-empty include-empty
                                   :package-predicate package-predicate
                                   :user-package-predicate user-package-predicate
                                   :include-dependencies include-dependencies))
         (analysis (analyze-snapshot snapshot))
         (state (make-app-state :snapshot snapshot :analysis analysis
                                :include-empty-p include-empty
                                :package-predicate package-predicate
                                :user-package-predicate user-package-predicate
                                :include-dependencies-p include-dependencies
                                :export-directory (pathname export-directory)
                                :risk-threshold (max 0 (min 100 risk-threshold))
                                :history-retention (max 1 history-retention)
                                :auto-orbit-p auto-orbit)))
    (validate-snapshot snapshot :errorp t)
    (when (zerop (length (snapshot-nodes snapshot)))
      (error "O Malkuth não encontrou pacotes na imagem Lisp atual."))
    (seed-layout! snapshot)
    (relax-layout! snapshot :iterations 180 :dt 0.025d0)
    ;; O pacote inicial é escolhido antes de carregar favoritos para que todos os
    ;; filtros possuam um ponto de referência válido desde o primeiro quadro.
    (setf (app-state-selected-index state) (initial-selected-index snapshot)
          (app-state-inspector-lines state)
          (node-symbol-lines (selected-node state) :limit 500))
    (load-favorites! state)
    ;; Uma linha de base existente é carregada silenciosamente para que o filtro
    ;; de alterações e o painel de evolução estejam disponíveis imediatamente.
    (load-baseline! state)
    (ecase initial-panel
      (:overview nil)
      (:diagnostics (setf (app-state-diagnostics-p state) t))
      (:changes (when (app-state-baseline-snapshot state)
                  (setf (app-state-changes-p state) t))))
    (when initial-search
      (setf (app-state-search-query state) (princ-to-string initial-search))
      (refresh-search-results! state))
    (malkuth.sdl3:with-sdl3 (window renderer :title "MALKUTH / OBSERVATÓRIO DA ARQUITETURA LISP ATIVA"
                                             :width width :height height)
      (malkuth.sdl3:set-window-minimum-size window 1280 760)
      (malkuth.sdl3:set-vsync renderer 1)
      (when (and initial-search (plusp (length (app-state-search-query state))))
        (activate-search! state window width))
      (setf (app-state-last-ticks state) (malkuth.sdl3:ticks))
      (loop
        for now = (malkuth.sdl3:ticks)
        for elapsed-ms = (max 1 (- now (app-state-last-ticks state)))
        for dt = (min 0.05d0 (/ elapsed-ms 1000.0d0))
        do (setf (app-state-last-ticks state) now
                 (app-state-fps state)
                 (lerp (app-state-fps state) (/ 1000.0d0 elapsed-ms) 0.08d0))
           (multiple-value-bind (quit-event-p text-inputs)
               (malkuth.sdl3:poll-events)
             (when quit-event-p (return))
             (multiple-value-bind (actual-width actual-height)
                 (malkuth.sdl3:window-size window)
               (multiple-value-bind (left-x graph-x graph-y graph-w graph-h right-x left-w right-w)
                   (layout-geometry actual-width actual-height)
                 (declare (ignore left-x right-x left-w right-w))
                 (update-input! state window actual-width
                                graph-x graph-y graph-w graph-h dt text-inputs)
                 (when (app-state-quit-requested-p state) (return))
                 (when (and (app-state-auto-orbit-p state)
                            (not (app-state-search-active-p state)))
                   (incf (app-state-yaw state) (* 0.085d0 dt)))
                 (unless (app-state-paused-p state)
                   (relax-layout! (app-state-snapshot state) :iterations 1 :dt 0.018d0))
                 (draw-frame renderer state actual-width actual-height))))
           (malkuth.sdl3:present renderer)
           (incf (app-state-frame state))
           (when (and max-frames (>= (app-state-frame state) max-frames))
             (return))
           (malkuth.sdl3:delay 1)))
    state))

(defun render-preview (&optional (pathname #P"malkuth.svg"))
  (let ((snapshot (build-snapshot)))
    (export-svg snapshot pathname)
    pathname))

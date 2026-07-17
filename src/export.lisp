;;;; Exportadores e escrita segura de artefatos
;;;;
;;;; Todos os formatos são gerados sem bibliotecas de serialização adicionais.
;;;; Arquivos destinados a automação são escritos primeiro em um temporário no
;;;; mesmo diretório e só então substituem o destino, evitando relatórios parciais.

(in-package #:malkuth.export)

;; O temporário permanece no mesmo sistema de arquivos do destino para que a
;; renomeação final tenha semântica atômica nas plataformas suportadas.
(defun temporary-pathname-for (pathname)
  (make-pathname :name (format nil ".~A-~D-~D"
                               (or (pathname-name pathname) "malkuth")
                               (get-universal-time) (random 1000000))
                 :type "tmp"
                 :defaults pathname))

(defun atomic-write-file (pathname writer)
  "Grava PATHNAME por meio de um arquivo temporário vizinho e depois o substitui de forma atômica."
  (let* ((target (merge-pathnames pathname (uiop:getcwd)))
         (temporary (temporary-pathname-for target)))
    (ensure-directories-exist target)
    (unwind-protect
         (progn
           (with-open-file (stream temporary :direction :output
                                            :if-exists :supersede
                                            :if-does-not-exist :create
                                            :external-format :utf-8)
             (funcall writer stream)
             (finish-output stream))
           (uiop:rename-file-overwriting-target temporary target)
           target)
      (when (probe-file temporary)
        (ignore-errors (delete-file temporary))))))

(defun iso-8601-time (universal-time)
  (multiple-value-bind (second minute hour day month year)
      (decode-universal-time universal-time 0)
    (format nil "~4,'0D-~2,'0D-~2,'0DT~2,'0D:~2,'0D:~2,'0DZ"
            year month day hour minute second)))

;; Serializador mínimo de strings JSON. A implementação intencionalmente pequena
;; reduz dependências do núcleo e cobre todos os caracteres de controle exigidos.
(defun json-string (value stream)
  (write-char #\" stream)
  (loop for character across (princ-to-string value)
        for code = (char-code character)
        do (case character
             (#\" (write-string "\\\"" stream))
             (#\\ (write-string "\\\\" stream))
             (#\Backspace (write-string "\\b" stream))
             (#\Page (write-string "\\f" stream))
             (#\Newline (write-string "\\n" stream))
             (#\Return (write-string "\\r" stream))
             (#\Tab (write-string "\\t" stream))
             (otherwise
              (if (< code 32)
                  (format stream "\\u~4,'0X" code)
                  (write-char character stream)))))
  (write-char #\" stream))

(defun json-key (key stream)
  (json-string key stream)
  (write-char #\: stream))

(defun json-array (items writer stream)
  (write-char #\[ stream)
  (loop for item in items
        for first = t then nil
        do (unless first (write-char #\, stream))
           (funcall writer item stream))
  (write-char #\] stream))

(defun severity-name (severity)
  (string-downcase (symbol-name severity)))

;; O JSON usa chaves estáveis em inglês para preservar compatibilidade de API;
;; textos destinados a pessoas permanecem em pt-BR nos demais formatos.
(defun export-json (snapshot pathname &key analysis)
  "Exporta um instantâneo estável de arquitetura em JSON, sem dependências adicionais."
  (let ((analysis (or analysis (analyze-snapshot snapshot))))
    (atomic-write-file
     pathname
     (lambda (out)
       (write-char #\{ out)
       (json-key "schemaVersion" out) (json-string (snapshot-schema-version snapshot) out)
       (write-char #\, out)
       (json-key "generatedAt" out) (json-string (iso-8601-time (snapshot-created-at snapshot)) out)
       (write-char #\, out)
       (json-key "fingerprint" out) (json-string (snapshot-fingerprint snapshot) out)
       (write-char #\, out)
       (json-key "implementation" out) (json-string (snapshot-implementation snapshot) out)
       (write-char #\, out)
       (json-key "summary" out)
       (format out "{\"packages\":~D,\"dependencies\":~D,\"symbols\":~D,\"functions\":~D,\"generics\":~D,\"macros\":~D,\"classes\":~D,\"variables\":~D}"
               (length (snapshot-nodes snapshot)) (length (snapshot-edges snapshot))
               (snapshot-total-symbols snapshot) (snapshot-total-functions snapshot)
               (snapshot-total-generics snapshot) (snapshot-total-macros snapshot)
               (snapshot-total-classes snapshot) (snapshot-total-variables snapshot))
       (write-char #\, out)
       (json-key "health" out)
       (format out "{\"score\":~D,\"cycleCount\":~D,\"orphanCount\":~D,\"warningCount\":~D}"
               (analysis-report-health-score analysis)
               (length (analysis-report-cycles analysis))
               (length (analysis-report-orphans analysis))
               (length (analysis-report-warnings analysis)))
       (write-char #\, out)
       (json-key "packages" out)
       (json-array
        (coerce (snapshot-nodes snapshot) 'list)
        (lambda (node stream)
          (let ((metric (metrics-for-node analysis node)))
            (write-char #\{ stream)
            (json-key "id" stream) (princ (node-id node) stream)
            (write-char #\, stream) (json-key "name" stream) (json-string (node-name node) stream)
            (write-char #\, stream) (json-key "kind" stream)
            (json-string (string-downcase (symbol-name (node-kind node))) stream)
            (format stream ",\"internal\":~D,\"external\":~D,\"functions\":~D,\"generics\":~D,\"macros\":~D,\"classes\":~D,\"variables\":~D,\"fanIn\":~D,\"fanOut\":~D,\"riskScore\":~D"
                    (node-internal node) (node-external node) (node-functions node)
                    (node-generics node) (node-macros node) (node-classes node)
                    (node-variables node) (node-metrics-fan-in metric)
                    (node-metrics-fan-out metric) (node-metrics-risk-score metric))
            (write-char #\} stream)))
        out)
       (write-char #\, out)
       (json-key "dependencies" out)
       (json-array
        (coerce (snapshot-edges snapshot) 'list)
        (lambda (edge stream)
          (format stream "{\"from\":~D,\"to\":~D,\"weight\":~,4F}"
                  (edge-from edge) (edge-to edge) (edge-weight edge)))
        out)
       (write-char #\, out)
       (json-key "cycles" out)
       (json-array
        (analysis-report-cycles analysis)
        (lambda (cycle stream)
          (json-array cycle #'json-string stream))
        out)
       (write-char #\, out)
       (json-key "orphans" out)
       (json-array (analysis-report-orphans analysis) #'json-string out)
       (write-char #\, out)
       (json-key "warnings" out)
       (json-array
        (analysis-report-warnings analysis)
        (lambda (item stream)
          (write-char #\{ stream)
          (json-key "severity" stream) (json-string (severity-name (analysis-warning-severity item)) stream)
          (write-char #\, stream) (json-key "code" stream)
          (json-string (string-downcase (symbol-name (analysis-warning-code item))) stream)
          (when (analysis-warning-package item)
            (write-char #\, stream) (json-key "package" stream)
            (json-string (analysis-warning-package item) stream))
          (write-char #\, stream) (json-key "message" stream)
          (json-string (analysis-warning-message item) stream)
          (write-char #\} stream))
        out)
       (write-char #\} out)
       (terpri out)))))

(defun dot-escape (string)
  (with-output-to-string (out)
    (loop for character across string
          do (case character
               (#\" (write-string "\\\"" out))
               (#\\ (write-string "\\\\" out))
               (otherwise (write-char character out))))))

(defun export-dot (snapshot pathname &key analysis)
  "Exporta Graphviz DOT para integração contínua, documentação e análises adicionais do grafo."
  (let ((analysis (or analysis (analyze-snapshot snapshot))))
    (atomic-write-file
     pathname
     (lambda (out)
       (format out "digraph malkuth {~%  graph [overlap=false, splines=true, rankdir=LR, bgcolor=\"#07111e\"];~%")
       (format out "  node [shape=box, style=\"rounded,filled\", fontname=\"monospace\", fontcolor=\"#edf4ff\", color=\"#314563\", fillcolor=\"#0d1626\"];~%")
       (format out "  edge [color=\"#527fc0\", arrowsize=0.65];~%")
       (loop for node across (snapshot-nodes snapshot)
             for metric = (metrics-for-node analysis node)
             for color = (ecase (node-kind node)
                           (:runtime "#69a9ff") (:tooling "#ffbc52")
                           (:user "#6cffc5") (:library "#bf84ff"))
             do (format out "  n~D [label=\"~A\\n~D símbolos | entrada ~D | saída ~D\", color=\"~A\", penwidth=~D];~%"
                        (node-id node) (dot-escape (node-name node))
                        (+ (node-internal node) (node-external node))
                        (node-metrics-fan-in metric) (node-metrics-fan-out metric)
                        color (if (> (node-metrics-risk-score metric) 30) 3 1)))
       (loop for edge across (snapshot-edges snapshot)
             do (format out "  n~D -> n~D;~%" (edge-from edge) (edge-to edge)))
       (format out "}~%")))))

(defun markdown-warning-line (item)
  (format nil "- **~A / ~A**~@[ (`~A`)~]: ~A"
          (string-upcase (symbol-name (analysis-warning-severity item)))
          (string-upcase (symbol-name (analysis-warning-code item)))
          (analysis-warning-package item)
          (analysis-warning-message item)))

(defun export-markdown (snapshot pathname &key analysis)
  "Exporta um relatório legível de arquitetura e riscos."
  (let ((analysis (or analysis (analyze-snapshot snapshot))))
    (atomic-write-file
     pathname
     (lambda (out)
       (format out "# Análise da imagem pelo Malkuth~%~%")
       (format out "Gerado em: **~A**  ~%Impressão digital: `~A`  ~%Esquema: `~A`~%~%"
               (iso-8601-time (snapshot-created-at snapshot))
               (snapshot-fingerprint snapshot) (snapshot-schema-version snapshot))
       (format out "## Resumo executivo~%~%")
       (format out "- Pontuação de saúde da arquitetura: **~D/100** (heurística)~%"
               (analysis-report-health-score analysis))
       (format out "- Pacotes: **~:D**~%" (length (snapshot-nodes snapshot)))
       (format out "- Dependências: **~:D**~%" (length (snapshot-edges snapshot)))
       (format out "- Símbolos: **~:D**~%" (snapshot-total-symbols snapshot))
       (format out "- Ciclos: **~:D**~%" (length (analysis-report-cycles analysis)))
       (format out "- Pacotes isolados: **~:D**~%~%" (length (analysis-report-orphans analysis)))
       (format out "## Pacotes com maior conectividade~%~%")
       (format out "| Pacote | Grau total | Entrada | Saída | Símbolos | Risco |~%")
       (format out "|---|---:|---:|---:|---:|---:|~%")
       (dolist (metric (analysis-report-hubs analysis))
         (format out "| `~A` | ~D | ~D | ~D | ~:D | ~D |~%"
                 (node-metrics-name metric) (node-metrics-total-degree metric)
                 (node-metrics-fan-in metric) (node-metrics-fan-out metric)
                 (node-metrics-symbols metric) (node-metrics-risk-score metric)))
       (format out "~%## Ciclos de dependência~%~%")
       (if (analysis-report-cycles analysis)
           (dolist (cycle (analysis-report-cycles analysis))
             (format out "- ~{`~A`~^ -> ~}~%" cycle))
           (format out "Nenhum ciclo de uso entre pacotes foi detectado.~%"))
       (format out "~%## Avisos~%~%")
       (if (analysis-report-warnings analysis)
           (dolist (item (analysis-report-warnings analysis))
             (format out "~A~%" (markdown-warning-line item)))
           (format out "Nenhum aviso foi gerado pelas regras heurísticas atuais.~%"))
       (format out "~%## Interpretação~%~%")
       (format out "A pontuação de saúde é um auxílio de navegação, não uma prova de correção. Avalie ciclos, pacotes grandes e saídas amplas no contexto da arquitetura pretendida para a aplicação.~%")))))


(defun nome-seguro-para-arquivo (nome)
  "Converte NOME em uma base de arquivo portátil e previsível."
  (let ((resultado
          (with-output-to-string (saida)
            (loop for caractere across (string-downcase nome)
                  do (write-char (if (or (alphanumericp caractere)
                                         (member caractere '(#\- #\_)))
                                     caractere
                                     #\-)
                                 saida)))))
    (string-trim "-" resultado)))

(defun pacote-em-ciclo-p (analysis node)
  "Informa se NODE participa de algum ciclo registrado em ANALYSIS."
  (some (lambda (ciclo)
          (member (node-name node) ciclo :test #'string-equal))
        (analysis-report-cycles analysis)))

(defun export-package-markdown (snapshot node pathname &key analysis)
  "Exporta um relatório focado em NODE, suas métricas e relações diretas."
  (let* ((analysis (or analysis (analyze-snapshot snapshot)))
         (metric (metrics-for-node analysis node))
         (dependencies (node-dependencies snapshot node))
         (dependents (node-dependents snapshot node)))
    (atomic-write-file
     pathname
     (lambda (out)
       (format out "# Pacote `~A`~%~%" (node-name node))
       (format out "Relatório focado gerado pelo Malkuth em **~A**.  ~%" 
               (iso-8601-time (get-universal-time)))
       (format out "Impressão digital da imagem: `~A`~%~%" (snapshot-fingerprint snapshot))
       (format out "## Resumo~%~%")
       (format out "- Papel: **~A**~%" (string-downcase (symbol-name (node-kind node))))
       (format out "- Símbolos próprios: **~:D**~%" (+ (node-internal node) (node-external node)))
       (format out "- Símbolos exportados: **~:D**~%" (node-external node))
       (format out "- Funções: **~:D**; genéricas: **~:D**; macros: **~:D**~%"
               (node-functions node) (node-generics node) (node-macros node))
       (format out "- Classes: **~:D**; variáveis: **~:D**~%"
               (node-classes node) (node-variables node))
       (format out "- Entrada: **~D**; saída: **~D**; grau total: **~D**~%"
               (node-metrics-fan-in metric) (node-metrics-fan-out metric)
               (node-metrics-total-degree metric))
       (format out "- Risco heurístico local: **~D/100**~%" (node-metrics-risk-score metric))
       (format out "- Participa de ciclo: **~:[não~;sim~]**~%~%"
               (pacote-em-ciclo-p analysis node))
       (format out "## Dependências diretas usadas por este pacote~%~%")
       (if dependencies
           (dolist (item dependencies)
             (let ((item-metric (metrics-for-node analysis item)))
               (format out "- `~A` — ~:D símbolos, entrada ~D, saída ~D~%"
                       (node-name item)
                       (+ (node-internal item) (node-external item))
                       (node-metrics-fan-in item-metric)
                       (node-metrics-fan-out item-metric))))
           (format out "Este pacote não usa outro pacote presente no instantâneo.~%"))
       (format out "~%## Pacotes que dependem diretamente deste pacote~%~%")
       (if dependents
           (dolist (item dependents)
             (let ((item-metric (metrics-for-node analysis item)))
               (format out "- `~A` — ~:D símbolos, entrada ~D, saída ~D~%"
                       (node-name item)
                       (+ (node-internal item) (node-external item))
                       (node-metrics-fan-in item-metric)
                       (node-metrics-fan-out item-metric))))
           (format out "Nenhum pacote do instantâneo depende diretamente deste pacote.~%"))
       (format out "~%## Símbolos próprios~%~%")
       (let ((linhas (node-symbol-lines node :limit 200)))
         (if linhas
             (dolist (linha linhas)
               (format out "- `~A`~%" (string-trim " " linha)))
             (format out "Nenhum símbolo próprio foi encontrado.~%")))
       (format out "~%## Observação~%~%")
       (format out "As relações acima representam `USE-PACKAGE`. Referências com nomes totalmente qualificados podem existir sem aparecer como arestas.~%")))))

(defun export-package-dot (snapshot node pathname &key analysis)
  "Exporta um grafo DOT reduzido ao pacote selecionado e à sua vizinhança direta."
  (declare (ignore analysis))
  (let* ((ids (remove-duplicates
               (cons (node-id node) (node-neighbor-ids snapshot node))
               :test #'=))
         (id-set (make-hash-table :test #'eql))
         (nodes (snapshot-nodes snapshot)))
    (dolist (id ids)
      (setf (gethash id id-set) t))
    (atomic-write-file
     pathname
     (lambda (out)
       (format out "digraph pacote_malkuth {~%  graph [rankdir=LR, bgcolor=\"#07111e\"];~%")
       (format out "  node [shape=box, style=\"rounded,filled\", fontname=\"monospace\", fontcolor=\"#edf4ff\", fillcolor=\"#0d1626\"];~%")
       (format out "  edge [color=\"#527fc0\", arrowsize=0.7];~%")
       (dolist (id ids)
         (let* ((item (aref nodes id))
                (selected-p (= id (node-id node)))
                (color (if selected-p "#6cffc5" "#8faed8")))
           (format out "  n~D [label=\"~A\", color=\"~A\", penwidth=~D];~%"
                   id (dot-escape (node-name item)) color (if selected-p 3 1))))
       (loop for edge across (snapshot-edges snapshot)
             when (and (gethash (edge-from edge) id-set)
                       (gethash (edge-to edge) id-set))
               do (format out "  n~D -> n~D;~%" (edge-from edge) (edge-to edge)))
       (format out "}~%")))))

(defun export-package-bundle (snapshot node directory &key analysis)
  "Gera Markdown e DOT para revisão isolada do pacote NODE."
  (let* ((directory (uiop:ensure-directory-pathname
                     (merge-pathnames directory (uiop:getcwd))))
         (analysis (or analysis (analyze-snapshot snapshot)))
         (candidate (nome-seguro-para-arquivo (node-name node)))
         (base (if (plusp (length candidate)) candidate "pacote"))
         (markdown (merge-pathnames (format nil "pacote-~A.md" base) directory))
         (dot (merge-pathnames (format nil "pacote-~A.dot" base) directory)))
    (export-package-markdown snapshot node markdown :analysis analysis)
    (export-package-dot snapshot node dot :analysis analysis)
    (list :markdown markdown :dot dot)))

(defun atomic-export-svg (snapshot pathname &key selected)
  (let* ((pathname (merge-pathnames pathname (uiop:getcwd)))
         (temporary (temporary-pathname-for pathname)))
    (ensure-directories-exist pathname)
    (unwind-protect
         (progn
           (export-svg snapshot temporary :selected selected)
           (uiop:rename-file-overwriting-target temporary pathname)
           pathname)
      (when (probe-file temporary) (ignore-errors (delete-file temporary))))))

(defun export-bundle (snapshot directory &key selected analysis)
  "Grava SVG, JSON, DOT, Markdown, CSV e manifesto como um pacote coerente."
  (let* ((directory (uiop:ensure-directory-pathname
                     (merge-pathnames directory (uiop:getcwd))))
         (analysis (or analysis (analyze-snapshot snapshot)))
         (svg (merge-pathnames "malkuth.svg" directory))
         (json (merge-pathnames "malkuth.json" directory))
         (dot (merge-pathnames "malkuth.dot" directory))
         (markdown (merge-pathnames "malkuth-report.md" directory))
         (manifest (merge-pathnames "malkuth-manifest.txt" directory))
         (csv-paths (export-csv-bundle snapshot directory :analysis analysis))
         (packages-csv (getf csv-paths :packages-csv))
         (dependencies-csv (getf csv-paths :dependencies-csv)))
    (ensure-directories-exist svg)
    (atomic-export-svg snapshot svg :selected selected)
    (export-json snapshot json :analysis analysis)
    (export-dot snapshot dot :analysis analysis)
    (export-markdown snapshot markdown :analysis analysis)
    (atomic-write-file
     manifest
     (lambda (out)
       (format out "Pacote de relatórios do Malkuth~%")
       (format out "schema=~A~%" (snapshot-schema-version snapshot))
       (format out "fingerprint=~A~%" (snapshot-fingerprint snapshot))
       (format out "generated_at=~A~%" (iso-8601-time (snapshot-created-at snapshot)))
       (format out "health_score=~D~%" (analysis-report-health-score analysis))
       (format out "files=malkuth.svg,malkuth.json,malkuth.dot,malkuth-report.md,malkuth-pacotes.csv,malkuth-dependencias.csv~%")))
    (list :svg svg :json json :dot dot :markdown markdown :manifest manifest
          :packages-csv packages-csv :dependencies-csv dependencies-csv)))

;;;; Exportações tabulares e comparação contra linha de base

(defun csv-field (value stream)
  "Grava VALUE como campo CSV compatível com RFC 4180."
  (let ((text (princ-to-string value)))
    (write-char #\" stream)
    (loop for character across text
          do (when (char= character #\") (write-char #\" stream))
             (write-char character stream))
    (write-char #\" stream)))

(defun csv-row (values stream)
  "Grava uma linha CSV com todos os campos devidamente escapados."
  (loop for value in values
        for first = t then nil
        do (unless first (write-char #\, stream))
           (csv-field value stream))
  (terpri stream))

(defun export-packages-csv (snapshot pathname &key analysis)
  "Exporta métricas de pacote em CSV para planilhas e ferramentas de BI."
  (let ((analysis (or analysis (analyze-snapshot snapshot))))
    (atomic-write-file
     pathname
     (lambda (out)
       (csv-row '("id" "nome" "papel" "internos" "externos" "simbolos"
                  "funcoes" "genericas" "macros" "classes" "variaveis"
                  "fan_in" "fan_out" "grau_total" "risco") out)
       (loop for node across (snapshot-nodes snapshot)
             for metric = (metrics-for-node analysis node)
             do (csv-row
                 (list (node-id node) (node-name node)
                       (string-downcase (symbol-name (node-kind node)))
                       (node-internal node) (node-external node)
                       (+ (node-internal node) (node-external node))
                       (node-functions node) (node-generics node)
                       (node-macros node) (node-classes node)
                       (node-variables node) (node-metrics-fan-in metric)
                       (node-metrics-fan-out metric)
                       (node-metrics-total-degree metric)
                       (node-metrics-risk-score metric))
                 out))))))

(defun export-dependencies-csv (snapshot pathname)
  "Exporta as relações USE-PACKAGE em CSV usando nomes estáveis."
  (let ((nodes (snapshot-nodes snapshot)))
    (atomic-write-file
     pathname
     (lambda (out)
       (csv-row '("origem" "destino" "peso") out)
       (loop for edge across (snapshot-edges snapshot)
             do (csv-row
                 (list (node-name (aref nodes (edge-from edge)))
                       (node-name (aref nodes (edge-to edge)))
                       (format nil "~,4F" (edge-weight edge)))
                 out))))))

(defun export-csv-bundle (snapshot directory &key analysis)
  "Gera as tabelas de pacotes e dependências no diretório indicado."
  (let* ((directory (uiop:ensure-directory-pathname
                     (merge-pathnames directory (uiop:getcwd))))
         (packages (merge-pathnames "malkuth-pacotes.csv" directory))
         (dependencies (merge-pathnames "malkuth-dependencias.csv" directory)))
    (export-packages-csv snapshot packages :analysis analysis)
    (export-dependencies-csv snapshot dependencies)
    (list :packages-csv packages :dependencies-csv dependencies)))

(defun export-comparison-markdown (old-snapshot new-snapshot pathname
                                   &key old-analysis new-analysis diff)
  "Exporta uma revisão humana das mudanças entre a linha de base e o estado atual."
  (let* ((old-analysis (or old-analysis (analyze-snapshot old-snapshot)))
         (new-analysis (or new-analysis (analyze-snapshot new-snapshot)))
         (diff (or diff (compare-architectures old-snapshot new-snapshot
                                               :old-analysis old-analysis
                                               :new-analysis new-analysis)))
         (snapshot-diff (architecture-diff-snapshot-diff diff)))
    (atomic-write-file
     pathname
     (lambda (out)
       (format out "# Comparação arquitetural do Malkuth~%~%")
       (format out "- Linha de base: `~A`~%" (snapshot-fingerprint old-snapshot))
       (format out "- Estado atual: `~A`~%" (snapshot-fingerprint new-snapshot))
       (format out "- Variação de saúde: **~@D** pontos (~D → ~D)~%"
               (architecture-diff-health-delta diff)
               (analysis-report-health-score old-analysis)
               (analysis-report-health-score new-analysis))
       (format out "- Variação de avisos: **~@D**~%~%"
               (architecture-diff-warning-delta diff))
       (format out "## Pacotes~%~%")
       (format out "- Adicionados: **~D**~%" (length (snapshot-diff-added-packages snapshot-diff)))
       (format out "- Removidos: **~D**~%" (length (snapshot-diff-removed-packages snapshot-diff)))
       (format out "- Alterados: **~D**~%~%" (length (snapshot-diff-changed-packages snapshot-diff)))
       (flet ((write-name-list (title items)
                (format out "### ~A~%~%" title)
                (if items
                    (dolist (item items) (format out "- `~A`~%" item))
                    (format out "Nenhum item.~%"))
                (terpri out)))
         (write-name-list "Pacotes adicionados" (snapshot-diff-added-packages snapshot-diff))
         (write-name-list "Pacotes removidos" (snapshot-diff-removed-packages snapshot-diff)))
       (format out "### Pacotes com contagens alteradas~%~%")
       (if (snapshot-diff-changed-packages snapshot-diff)
           (dolist (change (snapshot-diff-changed-packages snapshot-diff))
             (format out "- `~A`: símbolos ~@D, funções ~@D, macros ~@D, classes ~@D~%"
                     (package-change-name change)
                     (package-change-symbol-delta change)
                     (package-change-function-delta change)
                     (package-change-macro-delta change)
                     (package-change-class-delta change)))
           (format out "Nenhum pacote teve suas contagens principais alteradas.~%"))
       (format out "~%## Ciclos~%~%")
       (format out "### Novos ciclos~%~%")
       (if (architecture-diff-new-cycles diff)
           (dolist (cycle (architecture-diff-new-cycles diff))
             (format out "- ~{`~A`~^ → ~}~%" cycle))
           (format out "Nenhum ciclo novo.~%"))
       (format out "~%### Ciclos resolvidos~%~%")
       (if (architecture-diff-resolved-cycles diff)
           (dolist (cycle (architecture-diff-resolved-cycles diff))
             (format out "- ~{`~A`~^ → ~}~%" cycle))
           (format out "Nenhum ciclo resolvido.~%"))
       (format out "~%## Variações de risco local~%~%")
       (format out "| Pacote | Antes | Agora | Variação |~%|---|---:|---:|---:|~%")
       (let ((changes (append (architecture-diff-risk-increases diff)
                              (architecture-diff-risk-decreases diff))))
         (if changes
             (dolist (change changes)
               (format out "| `~A` | ~D | ~D | ~@D |~%"
                       (risk-change-name change) (risk-change-old-risk change)
                       (risk-change-new-risk change) (risk-change-delta change)))
             (format out "| _Nenhuma alteração_ | — | — | — |~%")))
       (format out "~%## Interpretação~%~%")
       (format out "Mudanças de risco e saúde são heurísticas. Use este relatório para orientar revisão de código, não como decisão automática isolada.~%")))))

(defun export-comparison-json (old-snapshot new-snapshot pathname
                               &key old-analysis new-analysis diff)
  "Exporta a comparação arquitetural em JSON estável para automação."
  (let* ((old-analysis (or old-analysis (analyze-snapshot old-snapshot)))
         (new-analysis (or new-analysis (analyze-snapshot new-snapshot)))
         (diff (or diff (compare-architectures old-snapshot new-snapshot
                                               :old-analysis old-analysis
                                               :new-analysis new-analysis)))
         (snapshot-diff (architecture-diff-snapshot-diff diff)))
    (atomic-write-file
     pathname
     (lambda (out)
       (format out "{\"schemaVersion\":\"1.0\",\"baselineFingerprint\":")
       (json-string (snapshot-fingerprint old-snapshot) out)
       (format out ",\"currentFingerprint\":")
       (json-string (snapshot-fingerprint new-snapshot) out)
       (format out ",\"health\":{\"before\":~D,\"after\":~D,\"delta\":~D}"
               (analysis-report-health-score old-analysis)
               (analysis-report-health-score new-analysis)
               (architecture-diff-health-delta diff))
       (format out ",\"warningDelta\":~D" (architecture-diff-warning-delta diff))
       (format out ",\"packages\":{\"added\":")
       (json-array (snapshot-diff-added-packages snapshot-diff) #'json-string out)
       (format out ",\"removed\":")
       (json-array (snapshot-diff-removed-packages snapshot-diff) #'json-string out)
       (format out ",\"changed\":")
       (json-array
        (snapshot-diff-changed-packages snapshot-diff)
        (lambda (change stream)
          (format stream "{\"name\":")
          (json-string (package-change-name change) stream)
          (format stream ",\"symbolDelta\":~D,\"functionDelta\":~D,\"macroDelta\":~D,\"classDelta\":~D}"
                  (package-change-symbol-delta change)
                  (package-change-function-delta change)
                  (package-change-macro-delta change)
                  (package-change-class-delta change)))
        out)
       (format out "},\"newCycles\":")
       (json-array (architecture-diff-new-cycles diff)
                   (lambda (cycle stream) (json-array cycle #'json-string stream)) out)
       (format out ",\"resolvedCycles\":")
       (json-array (architecture-diff-resolved-cycles diff)
                   (lambda (cycle stream) (json-array cycle #'json-string stream)) out)
       (format out ",\"riskChanges\":")
       (json-array
        (append (architecture-diff-risk-increases diff)
                (architecture-diff-risk-decreases diff))
        (lambda (change stream)
          (format stream "{\"name\":")
          (json-string (risk-change-name change) stream)
          (format stream ",\"before\":~D,\"after\":~D,\"delta\":~D}"
                  (risk-change-old-risk change)
                  (risk-change-new-risk change)
                  (risk-change-delta change)))
        out)
       (format out "}~%")))))

(defun export-comparison-bundle (old-snapshot new-snapshot directory
                                 &key old-analysis new-analysis diff)
  "Gera Markdown e JSON da comparação contra uma linha de base."
  (let* ((directory (uiop:ensure-directory-pathname
                     (merge-pathnames directory (uiop:getcwd))))
         (markdown (merge-pathnames "malkuth-comparacao.md" directory))
         (json (merge-pathnames "malkuth-comparacao.json" directory)))
    (export-comparison-markdown old-snapshot new-snapshot markdown
                                :old-analysis old-analysis
                                :new-analysis new-analysis :diff diff)
    (export-comparison-json old-snapshot new-snapshot json
                            :old-analysis old-analysis
                            :new-analysis new-analysis :diff diff)
    (list :markdown markdown :json json)))

;;;; Relatórios de políticas arquiteturais

(defun export-policy-markdown (report pathname)
  "Exporta um relatório humano das políticas e violações avaliadas."
  (atomic-write-file
   pathname
   (lambda (out)
     (format out "# Políticas arquiteturais do Malkuth~%~%")
     (format out "- Instantâneo: `~A`~%" (policy-report-fingerprint report))
     (format out "- Regras avaliadas: **~D**~%" (length (policy-report-rules report)))
     (format out "- Violações: **~D**~%" (length (policy-report-violations report)))
     (format out "- Erros: **~D**; avisos: **~D**~%" (policy-report-error-count report)
             (policy-report-warning-count report))
     (format out "- Resultado: **~:[REPROVADO~;APROVADO~]**~%~%"
             (policy-report-passed-p report))
     (format out "## Regras~%~%")
     (if (policy-report-rules report)
         (dolist (rule (policy-report-rules report))
           (format out "- `~A` — **~A** / ~A~%"
                   (policy-rule-id rule)
                   (string-upcase (symbol-name (policy-rule-severity rule)))
                   (string-downcase (symbol-name (policy-rule-type rule)))))
         (format out "Nenhuma regra foi configurada.~%"))
     (format out "~%## Violações~%~%")
     (if (policy-report-violations report)
         (dolist (item (policy-report-violations report))
           (format out "- **~A** `~A`~@[ em `~A`~]~@[ → `~A`~]: ~A~%"
                   (string-upcase (symbol-name (policy-violation-severity item)))
                   (policy-violation-rule-id item)
                   (policy-violation-package item)
                   (policy-violation-target item)
                   (policy-violation-message item)))
         (format out "Nenhuma violação foi encontrada.~%")))))

(defun export-policy-json (report pathname)
  "Exporta políticas e violações em JSON estável para CI e painéis externos."
  (atomic-write-file
   pathname
   (lambda (out)
     (format out "{\"schemaVersion\":\"1.0\",\"fingerprint\":")
     (json-string (policy-report-fingerprint report) out)
     (format out ",\"passed\":~:[false~;true~],\"summary\":{\"rules\":~D,\"violations\":~D,\"errors\":~D,\"warnings\":~D},\"violations\":"
             (policy-report-passed-p report)
             (length (policy-report-rules report))
             (length (policy-report-violations report))
             (policy-report-error-count report)
             (policy-report-warning-count report))
     (json-array
      (policy-report-violations report)
      (lambda (item stream)
        (format stream "{\"ruleId\":")
        (json-string (policy-violation-rule-id item) stream)
        (format stream ",\"type\":")
        (json-string (string-downcase (symbol-name (policy-violation-type item))) stream)
        (format stream ",\"severity\":")
        (json-string (string-downcase (symbol-name (policy-violation-severity item))) stream)
        (when (policy-violation-package item)
          (format stream ",\"package\":")
          (json-string (policy-violation-package item) stream))
        (when (policy-violation-target item)
          (format stream ",\"target\":")
          (json-string (policy-violation-target item) stream))
        (format stream ",\"message\":")
        (json-string (policy-violation-message item) stream)
        (write-char #\} stream))
      out)
     (format out "}~%"))))

(defun export-policy-bundle (report directory)
  "Gera Markdown e JSON para um POLICY-REPORT."
  (let* ((directory (uiop:ensure-directory-pathname
                     (merge-pathnames directory (uiop:getcwd))))
         (markdown (merge-pathnames "malkuth-politicas.md" directory))
         (json (merge-pathnames "malkuth-politicas.json" directory)))
    (export-policy-markdown report markdown)
    (export-policy-json report json)
    (list :markdown markdown :json json)))

;;;; Caminhos entre pacotes

(defun export-path-markdown (snapshot path pathname &key (direction :either))
  "Exporta um caminho de dependência já resolvido como documentação Markdown."
  (unless path
    (error "Não existe caminho para exportar."))
  (atomic-write-file
   pathname
   (lambda (out)
     (format out "# Caminho de dependência do Malkuth~%~%")
     (format out "- Direção da busca: **~A**~%" (string-downcase (symbol-name direction)))
     (format out "- Saltos: **~D**~%" (max 0 (1- (length path))))
     (format out "- Instantâneo: `~A`~%~%" (snapshot-fingerprint snapshot))
     (format out "## Rota~%~%")
     (loop for node in path
           for index from 1
           do (format out "~D. `~A`~%" index (node-name node)))
     (format out "~%## Observação~%~%")
     (format out "No modo `either`, a rota representa conectividade arquitetural e pode atravessar uma relação no sentido inverso de `USE-PACKAGE`.~%"))))

(defun export-path-dot (snapshot path pathname)
  "Exporta somente os nós e arestas que formam PATH em Graphviz DOT."
  (unless path
    (error "Não existe caminho para exportar."))
  (let* ((ids (mapcar #'node-id path))
         (id-set (make-hash-table :test #'eql)))
    (dolist (id ids) (setf (gethash id id-set) t))
    (atomic-write-file
     pathname
     (lambda (out)
       (format out "digraph caminho_malkuth {~%  graph [rankdir=LR, bgcolor=\"#07111e\"];~%")
       (format out "  node [shape=box, style=\"rounded,filled\", fontname=\"monospace\", fontcolor=\"#edf4ff\", fillcolor=\"#0d1626\", color=\"#6cffc5\"];~%")
       (format out "  edge [color=\"#ff72b5\", penwidth=3, arrowsize=0.8];~%")
       (dolist (node path)
         (format out "  n~D [label=\"~A\"];~%" (node-id node)
                 (dot-escape (node-name node))))
       (loop for (left right) on ids while right
             for direct = (find-if (lambda (edge)
                                     (and (= (edge-from edge) left)
                                          (= (edge-to edge) right)))
                                   (coerce (snapshot-edges snapshot) 'list))
             do (if direct
                    (format out "  n~D -> n~D;~%" left right)
                    (format out "  n~D -> n~D [dir=back, style=dashed];~%" right left)))
       (format out "}~%")))))

(defun export-path-bundle (snapshot path directory &key (direction :either))
  "Gera Markdown e DOT para o caminho arquitetural PATH."
  (let* ((directory (uiop:ensure-directory-pathname
                     (merge-pathnames directory (uiop:getcwd))))
         (markdown (merge-pathnames "malkuth-caminho.md" directory))
         (dot (merge-pathnames "malkuth-caminho.dot" directory)))
    (export-path-markdown snapshot path markdown :direction direction)
    (export-path-dot snapshot path dot)
    (list :markdown markdown :dot dot)))

;;;; Tendências históricas

(defun export-trend-csv (report pathname)
  "Exporta a série temporal arquitetural em CSV."
  (atomic-write-file
   pathname
   (lambda (out)
     (csv-row '("created_at" "fingerprint" "packages" "dependencies" "symbols"
                "health" "cycles" "warnings") out)
     (dolist (point (trend-report-points report))
       (csv-row (list (iso-8601-time (trend-point-created-at point))
                      (trend-point-fingerprint point)
                      (trend-point-packages point)
                      (trend-point-dependencies point)
                      (trend-point-symbols point)
                      (trend-point-health-score point)
                      (trend-point-cycles point)
                      (trend-point-warnings point))
                out)))))

(defun export-trend-json (report pathname)
  "Exporta a tendência histórica em JSON."
  (atomic-write-file
   pathname
   (lambda (out)
     (format out "{\"schemaVersion\":\"1.0\",\"summary\":{\"points\":~D,\"healthMin\":~D,\"healthMax\":~D,\"healthDelta\":~D,\"packageDelta\":~D,\"dependencyDelta\":~D,\"symbolDelta\":~D},\"points\":"
             (length (trend-report-points report))
             (trend-report-health-min report) (trend-report-health-max report)
             (trend-report-health-delta report) (trend-report-package-delta report)
             (trend-report-dependency-delta report) (trend-report-symbol-delta report))
     (json-array
      (trend-report-points report)
      (lambda (point stream)
        (format stream "{\"createdAt\":")
        (json-string (iso-8601-time (trend-point-created-at point)) stream)
        (format stream ",\"fingerprint\":")
        (json-string (trend-point-fingerprint point) stream)
        (format stream ",\"packages\":~D,\"dependencies\":~D,\"symbols\":~D,\"health\":~D,\"cycles\":~D,\"warnings\":~D}"
                (trend-point-packages point) (trend-point-dependencies point)
                (trend-point-symbols point) (trend-point-health-score point)
                (trend-point-cycles point) (trend-point-warnings point)))
      out)
     (format out ",\"ignoredFiles\":~D}~%" (length (trend-report-ignored-files report))))))

(defun export-trend-markdown (report pathname)
  "Exporta um relatório legível da evolução arquitetural."
  (atomic-write-file
   pathname
   (lambda (out)
     (format out "# Tendência arquitetural do Malkuth~%~%")
     (format out "- Pontos analisados: **~D**~%" (length (trend-report-points report)))
     (format out "- Saúde mínima/máxima: **~D / ~D**~%"
             (trend-report-health-min report) (trend-report-health-max report))
     (format out "- Variação de saúde: **~@D**~%" (trend-report-health-delta report))
     (format out "- Variação de pacotes: **~@D**~%" (trend-report-package-delta report))
     (format out "- Variação de ligações: **~@D**~%" (trend-report-dependency-delta report))
     (format out "- Variação de símbolos: **~@D**~%~%" (trend-report-symbol-delta report))
     (format out "| Data | Saúde | Pacotes | Ligações | Símbolos | Ciclos | Avisos |~%")
     (format out "|---|---:|---:|---:|---:|---:|---:|~%")
     (dolist (point (trend-report-points report))
       (format out "| ~A | ~D | ~D | ~D | ~D | ~D | ~D |~%"
               (iso-8601-time (trend-point-created-at point))
               (trend-point-health-score point) (trend-point-packages point)
               (trend-point-dependencies point) (trend-point-symbols point)
               (trend-point-cycles point) (trend-point-warnings point)))
     (when (trend-report-ignored-files report)
       (format out "~%## Arquivos ignorados~%~%")
       (dolist (entry (trend-report-ignored-files report))
         (format out "- `~A`: ~A~%" (car entry) (cdr entry)))))))

(defun export-trend-bundle (report directory)
  "Gera CSV, JSON e Markdown para uma série temporal arquitetural."
  (let* ((directory (uiop:ensure-directory-pathname
                     (merge-pathnames directory (uiop:getcwd))))
         (csv (merge-pathnames "malkuth-tendencia.csv" directory))
         (json (merge-pathnames "malkuth-tendencia.json" directory))
         (markdown (merge-pathnames "malkuth-tendencia.md" directory)))
    (export-trend-csv report csv)
    (export-trend-json report json)
    (export-trend-markdown report markdown)
    (list :csv csv :json json :markdown markdown)))

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
  "Grava SVG, JSON, Graphviz DOT, Markdown e um manifesto como um único pacote de relatórios."
  (let* ((directory (uiop:ensure-directory-pathname
                     (merge-pathnames directory (uiop:getcwd))))
         (analysis (or analysis (analyze-snapshot snapshot)))
         (svg (merge-pathnames "malkuth.svg" directory))
         (json (merge-pathnames "malkuth.json" directory))
         (dot (merge-pathnames "malkuth.dot" directory))
         (markdown (merge-pathnames "malkuth-report.md" directory))
         (manifest (merge-pathnames "malkuth-manifest.txt" directory)))
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
       (format out "files=malkuth.svg,malkuth.json,malkuth.dot,malkuth-report.md~%")))
    (list :svg svg :json json :dot dot :markdown markdown :manifest manifest)))

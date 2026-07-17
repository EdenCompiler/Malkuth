;;;; Testes de regressão do núcleo portátil
;;;;
;;;; A suíte usa uma topologia sintética para resultados exatos e uma fotografia
;;;; da imagem real para validar reflexão, exportação e integração entre módulos.

(defpackage #:malkuth.tests
  (:use #:cl)
  (:export #:run-tests))

(in-package #:malkuth.tests)

(defun check (condition format-control &rest arguments)
  (unless condition
    (error (apply #'format nil format-control arguments))))

(defun synthetic-cycle-snapshot ()
  (let* ((nodes (vector
                 (malkuth.model::make-node :id 0 :name "APP.A" :kind :user)
                 (malkuth.model::make-node :id 1 :name "APP.B" :kind :user)
                 (malkuth.model::make-node :id 2 :name "APP.C" :kind :user)
                 (malkuth.model::make-node :id 3 :name "APP.ORPHAN" :kind :user)))
         (edges (vector
                 (malkuth.model::make-edge :from 0 :to 1)
                 (malkuth.model::make-edge :from 1 :to 2)
                 (malkuth.model::make-edge :from 2 :to 0))))
    (malkuth.model::make-snapshot :nodes nodes :edges edges)))

(defun synthetic-baseline-snapshot ()
  "Cria a topologia anterior ao fechamento do ciclo APP.C -> APP.A."
  (let* ((nodes (vector
                 (malkuth.model::make-node :id 0 :name "APP.A" :kind :user)
                 (malkuth.model::make-node :id 1 :name "APP.B" :kind :user)
                 (malkuth.model::make-node :id 2 :name "APP.C" :kind :user)
                 (malkuth.model::make-node :id 3 :name "APP.ORPHAN" :kind :user)))
         (edges (vector
                 (malkuth.model::make-edge :from 0 :to 1)
                 (malkuth.model::make-edge :from 1 :to 2))))
    (malkuth.model::make-snapshot :nodes nodes :edges edges)))

(defun file-contains-p (pathname needle)
  (with-open-file (stream pathname :direction :input :external-format :utf-8)
    (let ((text (make-string (file-length stream))))
      (read-sequence text stream)
      (not (null (search needle text :test #'char-equal))))))

(defun run-live-snapshot-test ()
  (let* ((snapshot (malkuth.model:build-snapshot))
         (fingerprint (malkuth.model:snapshot-fingerprint snapshot)))
    (multiple-value-bind (valid problems) (malkuth.model:validate-snapshot snapshot)
      (check valid "A validação do instantâneo ativo falhou: ~S" problems))
    (check (> (length (malkuth.model:snapshot-nodes snapshot)) 10)
           "Eram esperados mais de dez pacotes.")
    (check (> (malkuth.model:snapshot-total-symbols snapshot) 1000)
           "Eram esperados mais de mil símbolos.")
    (check (= (length fingerprint) 16) "A impressão digital não é hexadecimal de 64 bits: ~A" fingerprint)
    (check (string= fingerprint (malkuth.model:snapshot-fingerprint snapshot))
           "A impressão digital mudou sem alteração do instantâneo.")
    snapshot))

(defun run-analysis-test ()
  (let* ((snapshot (synthetic-cycle-snapshot))
         (analysis (malkuth.analysis:analyze-snapshot snapshot))
         (diff (malkuth.analysis:compare-snapshots snapshot snapshot))
         (node-a (aref (malkuth.model:snapshot-nodes snapshot) 0)))
    (check (= 1 (length (malkuth.analysis:analysis-report-cycles analysis)))
           "Era esperado um ciclo sintético de dependência.")
    (check (equal '("APP.ORPHAN") (malkuth.analysis:analysis-report-orphans analysis))
           "Era esperado que APP.ORPHAN estivesse isolado.")
    (check (< (malkuth.analysis:analysis-report-health-score analysis) 100)
           "O ciclo e o pacote isolado deveriam reduzir a pontuação heurística de saúde.")
    (check (null (malkuth.analysis:snapshot-diff-added-packages diff))
           "Instantâneos idênticos não devem relatar pacotes adicionados.")
    (check (null (malkuth.analysis:snapshot-diff-changed-packages diff))
           "Instantâneos idênticos não devem relatar pacotes alterados.")
    (check (equal '(1) (malkuth.model:node-dependency-ids snapshot node-a))
           "APP.A deveria usar diretamente APP.B.")
    (check (equal '(2) (malkuth.model:node-dependent-ids snapshot node-a))
           "APP.C deveria usar diretamente APP.A.")
    (check (equal '(1 2) (malkuth.model:node-neighbor-ids snapshot node-a))
           "A vizinhança direta de APP.A deveria conter APP.B e APP.C.")
    (check (equal '("APP.B")
                  (mapcar #'malkuth.model:node-name
                          (malkuth.model:node-dependencies snapshot node-a)))
           "A consulta por nós deveria retornar APP.B como dependência de APP.A.")
    (check (equal '("APP.C")
                  (mapcar #'malkuth.model:node-name
                          (malkuth.model:node-dependents snapshot node-a)))
           "A consulta por nós deveria retornar APP.C como dependente de APP.A.")
    (check (string= "APP.A"
                    (malkuth.model:node-name
                     (first (malkuth.model:search-nodes snapshot "app.a"))))
           "A busca exata deveria priorizar APP.A.")
    (check (equal '("APP.A" "APP.B" "APP.C" "APP.ORPHAN")
                  (mapcar #'malkuth.model:node-name
                          (malkuth.model:search-nodes snapshot "app")))
           "A busca por prefixo deveria ser estável e ordenar nomes equivalentes.")
    (check (equal '("APP.ORPHAN")
                  (mapcar #'malkuth.model:node-name
                          (malkuth.model:search-nodes snapshot "orphan")))
           "A busca por segmento deveria localizar APP.ORPHAN.")
    (check (null (malkuth.model:search-nodes snapshot "pacote-inexistente"))
           "Uma consulta sem correspondência deveria retornar NIL.")))

(defun run-history-and-comparison-test ()
  (let* ((baseline (synthetic-baseline-snapshot))
         (current (synthetic-cycle-snapshot))
         (directory (merge-pathnames "output/test-history/" (uiop:getcwd)))
         (baseline-path (merge-pathnames "baseline.sexp" directory))
         (saved (malkuth.history:save-snapshot-file baseline baseline-path
                                                     :label "teste"))
         (loaded (malkuth.history:load-snapshot-file saved))
         (baseline-analysis (malkuth.analysis:analyze-snapshot loaded))
         (current-analysis (malkuth.analysis:analyze-snapshot current))
         (diff (malkuth.analysis:compare-architectures
                loaded current :old-analysis baseline-analysis
                :new-analysis current-analysis))
         (comparison (malkuth.export:export-comparison-bundle
                      loaded current directory
                      :old-analysis baseline-analysis
                      :new-analysis current-analysis :diff diff))
         (csv (malkuth.export:export-csv-bundle current directory
                                                :analysis current-analysis)))
    (check (string= (malkuth.model:snapshot-fingerprint baseline)
                    (malkuth.model:snapshot-fingerprint loaded))
           "A persistência alterou a impressão digital do instantâneo.")
    (check (= 1 (length (malkuth.analysis:architecture-diff-new-cycles diff)))
           "A comparação deveria detectar o novo ciclo sintético.")
    (check (minusp (malkuth.analysis:architecture-diff-health-delta diff))
           "O novo ciclo deveria reduzir a saúde arquitetural.")
    (check (probe-file (getf comparison :markdown))
           "O relatório Markdown de comparação não foi criado.")
    (check (probe-file (getf comparison :json))
           "O JSON de comparação não foi criado.")
    (check (file-contains-p (getf comparison :json) "\"newCycles\"")
           "O JSON de comparação não contém novos ciclos.")
    (check (probe-file (getf csv :packages-csv))
           "O CSV de pacotes não foi criado.")
    (check (probe-file (getf csv :dependencies-csv))
           "O CSV de dependências não foi criado.")))

(defun run-export-test (snapshot)
  (let* ((directory (merge-pathnames "output/test-report/" (uiop:getcwd)))
         (paths (malkuth.export:export-bundle snapshot directory))
         (json (getf paths :json))
         (dot (getf paths :dot))
         (markdown (getf paths :markdown))
         (selected (aref (malkuth.model:snapshot-nodes snapshot) 0))
         (focused (malkuth.export:export-package-bundle snapshot selected directory))
         (focused-markdown (getf focused :markdown))
         (focused-dot (getf focused :dot)))
    (dolist (key '(:svg :json :dot :markdown :manifest :packages-csv :dependencies-csv))
      (check (probe-file (getf paths key)) "Exportação ausente: ~A" key))
    (check (file-contains-p json "\"schemaVersion\":\"1.1\"")
           "O JSON não declara o esquema 1.1 esperado.")
    (check (file-contains-p dot "digraph malkuth") "A exportação DOT está malformada.")
    (check (file-contains-p markdown "Pontuação de saúde da arquitetura")
           "O relatório Markdown não contém o resumo executivo.")
    (check (probe-file focused-markdown) "O dossiê Markdown do pacote não foi exportado.")
    (check (probe-file focused-dot) "O grafo DOT focado do pacote não foi exportado.")
    (check (file-contains-p focused-markdown "Dependências diretas")
           "O dossiê do pacote não descreve suas dependências.")
    (check (file-contains-p focused-markdown (malkuth.model:node-name selected))
           "O dossiê não identifica claramente o pacote selecionado.")
    (check (file-contains-p focused-dot "digraph pacote_malkuth")
           "O DOT focado está malformado.")))

(defun run-tests ()
  (let ((snapshot (run-live-snapshot-test)))
    (run-analysis-test)
    (run-history-and-comparison-test)
    (run-export-test snapshot)
    (format t "~&Suíte de testes do MALKUTH aprovada: ~S~%"
            (malkuth.model:snapshot-summary snapshot))
    t))

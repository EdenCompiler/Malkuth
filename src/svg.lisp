;;;; Renderizador SVG autocontido
;;;;
;;;; O SVG compartilha o mesmo instantâneo e as mesmas métricas da interface SDL3,
;;;; permitindo documentação portátil sem depender de uma janela gráfica.

(in-package #:malkuth.svg)

(defun xml-escape (value)
  (with-output-to-string (out)
    (loop for ch across (princ-to-string value)
          do (case ch
               (#\& (write-string "&amp;" out))
               (#\< (write-string "&lt;" out))
               (#\> (write-string "&gt;" out))
               (#\" (write-string "&quot;" out))
               (t (write-char ch out))))))

(defun color-for-kind (kind)
  (ecase kind
    (:runtime "#69a9ff")
    (:tooling "#ffbc52")
    (:user "#6cffc5")
    (:library "#bf84ff")))

(defun role-label (kind)
  (ecase kind
    (:runtime "AMBIENTE LISP")
    (:tooling "FERRAMENTAS")
    (:user "CÓDIGO DO PROJETO")
    (:library "BIBLIOTECA")))

(defun edge-alpha (depth)
  (clamp (- 0.32d0 (* 0.0027d0 depth)) 0.05d0 0.22d0))

(defun approximate-text-width (text size &key mono)
  (* (length (princ-to-string text)) size (if mono 0.62d0 0.57d0)))

(defun fit-svg-text (value max-width size &key mono)
  "Encurta VALUE para que o rótulo SVG renderizado permaneça dentro de MAX-WIDTH."
  (let* ((text (princ-to-string value))
         (ellipsis "..."))
    (if (<= (approximate-text-width text size :mono mono) max-width)
        text
        (loop for end from (length text) downto 0
              for candidate = (concatenate 'string (subseq text 0 end) ellipsis)
              when (<= (approximate-text-width candidate size :mono mono) max-width)
                return candidate
              finally (return ellipsis)))))

(defun emit-text (stream x y text &key (size 14) (fill "#b9c7db")
                                         (weight 400) (anchor "start"))
  (format stream
          "<text x='~,2F' y='~,2F' fill='~A' font-family='Inter,ui-sans-serif,system-ui,-apple-system,Segoe UI,sans-serif' font-size='~D' font-weight='~D' text-anchor='~A'>~A</text>~%"
          x y fill size weight anchor (xml-escape text)))

(defun emit-mono-text (stream x y text &key (size 14) (fill "#b9c7db")
                                              (weight 400) (anchor "start"))
  (format stream
          "<text x='~,2F' y='~,2F' fill='~A' font-family='ui-monospace,SFMono-Regular,Menlo,Consolas,monospace' font-size='~D' font-weight='~D' text-anchor='~A'>~A</text>~%"
          x y fill size weight anchor (xml-escape text)))

(defun emit-panel (stream x y w h &key (fill "#0d1626") (stroke "#314563")
                                           (radius 14) accent)
  (format stream "<rect x='~F' y='~F' width='~F' height='~F' rx='~D' fill='~A' stroke='~A'/>~%"
          x y w h radius fill stroke)
  (when accent
    (format stream "<rect x='~F' y='~F' width='5' height='~F' rx='2.5' fill='~A'/>~%"
            x y h accent)))

(defun emit-pill (stream x y text &key (fill "#16243a") (stroke "#314563")
                                         (foreground "#b9c7db") (width 132))
  (format stream "<rect x='~F' y='~F' width='~F' height='34' rx='9' fill='~A' stroke='~A'/>~%"
          x y width fill stroke)
  (emit-text stream (+ x (/ width 2.0d0)) (+ y 23) text :size 12
             :fill foreground :weight 700 :anchor "middle"))

(defun emit-stat-card (stream x y w label value)
  (format stream "<rect x='~F' y='~F' width='~F' height='76' rx='10' fill='#121f33' stroke='#273b58'/>~%"
          x y w)
  (emit-text stream (+ x 13) (+ y 25)
             (fit-svg-text label (- w 26) 12)
             :size 12 :fill "#8198b8" :weight 650)
  (emit-text stream (+ x 13) (+ y 59) (format nil "~:D" value)
             :size 25 :fill "#edf4ff" :weight 780))

(defun export-svg (snapshot pathname &key (width 1800) (height 1000) selected)
  (let* ((margin 20.0d0)
         (header-h 82.0d0)
         (footer-h 44.0d0)
         (gap 14.0d0)
         (left-w 320.0d0)
         (right-w 430.0d0)
         (graph-x (+ margin left-w gap))
         (graph-y header-h)
         (right-x (- width margin right-w))
         (graph-w (- right-x graph-x gap))
         (graph-h (- height graph-y footer-h))
         (graph-right (+ graph-x graph-w))
         (graph-bottom (+ graph-y graph-h))
         (analysis (analyze-snapshot snapshot))
         (selected (or selected
                       (find-node-by-name snapshot "MALKUTH.MODEL")
                       (find-node-by-name snapshot "MALKUTH.APP")
                       (find-if (lambda (node) (eq (node-kind node) :user))
                                (coerce (snapshot-nodes snapshot) 'list))
                       (aref (snapshot-nodes snapshot) 0))))
    (seed-layout! snapshot)
    (relax-layout! snapshot :iterations 260 :dt 0.024d0)
    (update-projection! snapshot graph-w graph-h 0.52d0 -0.18d0 112.0d0
                        :offset-x graph-x :offset-y graph-y :fov 900.0d0)
    (ensure-directories-exist pathname)
    (with-open-file (out pathname :direction :output :if-exists :supersede
                         :if-does-not-exist :create :external-format :utf-8)
      (format out "<svg xmlns='http://www.w3.org/2000/svg' width='~D' height='~D' viewBox='0 0 ~D ~D'>~%"
              width height width height)
      (format out "<defs>
<linearGradient id='bg' x1='0' y1='0' x2='1' y2='1'><stop offset='0' stop-color='#070c16'/><stop offset='.55' stop-color='#0a1220'/><stop offset='1' stop-color='#080d18'/></linearGradient>
<radialGradient id='halo'><stop offset='0' stop-color='#7cffcf' stop-opacity='.34'/><stop offset='1' stop-color='#7cffcf' stop-opacity='0'/></radialGradient>
<filter id='glow'><feGaussianBlur stdDeviation='3.2' result='b'/><feMerge><feMergeNode in='b'/><feMergeNode in='SourceGraphic'/></feMerge></filter>
<pattern id='grid' width='56' height='56' patternUnits='userSpaceOnUse'><path d='M 56 0 L 0 0 0 56' fill='none' stroke='#263a57' stroke-opacity='.21' stroke-width='1'/></pattern>
<clipPath id='graph-clip'><rect x='~F' y='~F' width='~F' height='~F' rx='14'/></clipPath>
</defs>" graph-x graph-y graph-w graph-h)
      (format out "<rect width='100%' height='100%' fill='url(#bg)'/>~%")

      ;; Cabeçalho.
      (emit-text out 26 39 "MALKUTH" :size 34 :fill "#7cffcf" :weight 820)
      (emit-text out 27 67 "0.4.1 / OBSERVATÓRIO DA ARQUITETURA DA IMAGEM" :size 14 :fill "#8198b8" :weight 650)
      (let ((implementation (fit-svg-text
                             (format nil "~A ~A" (lisp-implementation-type)
                                     (lisp-implementation-version))
                             250 12)))
        (emit-pill out (- width 286) 21 implementation :width 260)
        (emit-pill out (- width 438) 21 "INSTANTÂNEO SVG" :width 136
                   :fill "#122b2b" :stroke "#30685c" :foreground "#7cffcf"))

      ;; Regiões principais.
      (emit-panel out margin graph-y left-w graph-h :accent "#4fb797")
      (emit-panel out graph-x graph-y graph-w graph-h :fill "#09111d")
      (format out "<rect x='~F' y='~F' width='~F' height='~F' rx='14' fill='url(#grid)'/>~%"
              graph-x graph-y graph-w graph-h)
      (emit-panel out right-x graph-y right-w graph-h
                  :accent (color-for-kind (node-kind selected)))

      ;; Visão geral à esquerda.
      (emit-text out (+ margin 20) (+ graph-y 35) "VISÃO GERAL DA IMAGEM" :size 20
                 :fill "#edf4ff" :weight 760)
      (emit-text out (+ margin 20) (+ graph-y 63) "INSTANTÂNEO ATIVO VALIDADO" :size 13
                 :fill "#8198b8" :weight 650)
      (let* ((card-gap 10.0d0)
             (card-w (/ (- left-w 50.0d0 card-gap) 2.0d0))
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
              for x = (+ margin 20 (* column (+ card-w card-gap)))
              for y = (+ graph-y 84 (* row 88))
              do (emit-stat-card out x y card-w label value)))
      (format out "<line x1='~F' y1='~F' x2='~F' y2='~F' stroke='#263a57'/>~%"
              (+ margin 20) (+ graph-y 445) (- (+ margin left-w) 20) (+ graph-y 445))
      (emit-text out (+ margin 20) (+ graph-y 478) "SAÚDE DA ARQUITETURA" :size 15
                 :fill "#b2c5df" :weight 720)
      (let* ((score (analysis-report-health-score analysis))
             (color (cond ((>= score 85) "#7cffcf")
                          ((>= score 65) "#ffca5c")
                          (t "#ff7084"))))
        (emit-pill out (+ margin 20) (+ graph-y 495) (format nil "~D / 100" score)
                   :width 118 :fill "#12212b" :stroke color :foreground color))
      (emit-text out (+ margin 20) (+ graph-y 556)
                 (format nil "CICLOS ~D   ISOLADOS ~D   AVISOS ~D"
                         (length (analysis-report-cycles analysis))
                         (length (analysis-report-orphans analysis))
                         (length (analysis-report-warnings analysis)))
                 :size 12 :fill "#8198b8" :weight 650)
      (format out "<line x1='~F' y1='~F' x2='~F' y2='~F' stroke='#263a57'/>~%"
              (+ margin 20) (+ graph-y 585) (- (+ margin left-w) 20) (+ graph-y 585))
      (emit-text out (+ margin 20) (+ graph-y 618) "LEGENDA DE CORES" :size 15
                 :fill "#b2c5df" :weight 720)
      (loop for (kind label) in '((:runtime "AMBIENTE LISP")
                                  (:tooling "FERRAMENTAS DE DESENVOLVIMENTO")
                                  (:user "CÓDIGO DO PROJETO")
                                  (:library "BIBLIOTECAS DE TERCEIROS"))
            for y from (+ graph-y 657) by 39
            do (format out "<circle cx='~F' cy='~F' r='6' fill='~A'/>~%"
                       (+ margin 27) (- y 5) (color-for-kind kind))
               (emit-text out (+ margin 47) y label :size 13 :fill "#b2c5df" :weight 560))

      ;; Barra de ferramentas do mapa.
      (emit-text out (+ graph-x 20) (+ graph-y 37) "MAPA DE PACOTES" :size 19
                 :fill "#edf4ff" :weight 760)
      (emit-text out (+ graph-x 20) (+ graph-y 65)
                 (fit-svg-text "RELAÇÕES ENTRE PACOTES NA IMAGEM LISP EM EXECUÇÃO"
                               (- graph-w 360) 12)
                 :size 12 :fill "#8198b8" :weight 620)
      (let* ((score (analysis-report-health-score analysis))
             (color (cond ((>= score 85) "#7cffcf")
                          ((>= score 65) "#ffca5c")
                          (t "#ff7084"))))
        (emit-pill out (- (+ graph-x graph-w) 430) (+ graph-y 18)
                   (format nil "SAÚDE ~D" score) :width 128
                   :fill "#12212b" :stroke color :foreground color))
      (emit-pill out (- (+ graph-x graph-w) 286) (+ graph-y 18) "LIGAÇÕES SELECIONADAS" :width 140
                 :fill "#122b2b" :stroke "#30685c" :foreground "#7cffcf")
      (emit-pill out (- (+ graph-x graph-w) 136) (+ graph-y 18) "ARRANJO 3D" :width 118)

      ;; O conteúdo do grafo é recortado pelo painel central para impedir que rótulos invadam as barras laterais.
      (format out "<g clip-path='url(#graph-clip)'>~%")
      (loop for edge across (snapshot-edges snapshot)
            for a = (aref (snapshot-nodes snapshot) (edge-from edge))
            for b = (aref (snapshot-nodes snapshot) (edge-to edge))
            when (and (node-visible-p a) (node-visible-p b))
              do (let ((connected (or (eq a selected) (eq b selected))))
                   (format out "<line x1='~,2F' y1='~,2F' x2='~,2F' y2='~,2F' stroke='~A' stroke-opacity='~,3F' stroke-width='~,2F'/>~%"
                           (node-screen-x a) (node-screen-y a)
                           (node-screen-x b) (node-screen-y b)
                           (if connected "#70e2c2" "#699be1")
                           (if connected 0.48d0
                               (edge-alpha (/ (+ (node-depth a) (node-depth b)) 2.0d0)))
                           (if connected 1.5d0
                               (clamp (* 0.45d0 (edge-weight edge)) 0.4d0 1.2d0)))))

      (let* ((label-ids (make-hash-table :test #'eql))
             (candidates
               (sort (remove-if-not #'node-visible-p
                                    (coerce (snapshot-nodes snapshot) 'list))
                     #'>
                     :key (lambda (node)
                            (clamp (* (node-radius node)
                                      (/ 125.0d0 (node-depth node)))
                                   3.0d0 14.0d0)))))
        (loop for node in candidates
              repeat (min 12 (length candidates))
              do (setf (gethash (node-id node) label-ids) t))
        (dolist (node (sorted-visible-nodes snapshot))
          (let* ((selected-p (eq node selected))
                 (radius (clamp (* (node-radius node) (/ 125.0d0 (node-depth node)))
                                3.0d0 14.0d0))
                 (color (color-for-kind (node-kind node))))
            (when selected-p
              (format out "<circle cx='~,2F' cy='~,2F' r='48' fill='url(#halo)' filter='url(#glow)'/>~%"
                      (node-screen-x node) (node-screen-y node)))
            (format out "<circle cx='~,2F' cy='~,2F' r='~,2F' fill='#07111e' stroke='~A' stroke-width='~F'~A/>~%"
                    (node-screen-x node) (node-screen-y node) radius color
                    (if selected-p 2.8d0 1.35d0)
                    (if selected-p " filter='url(#glow)'" ""))
            (when (or selected-p (gethash (node-id node) label-ids))
              (let* ((size (if selected-p 15 11))
                     (sx (node-screen-x node))
                     (sy (clamp (+ (node-screen-y node) 5) (+ graph-y 86) (- graph-bottom 12)))
                     (right-room (max 0.0d0 (- graph-right sx radius 10)))
                     (left-room (max 0.0d0 (- sx graph-x radius 10)))
                     (left-p (> left-room right-room))
                     (room (min 280.0d0 (if left-p left-room right-room)))
                     (label (fit-svg-text (node-name node) room size :mono t))
                     (label-x (if left-p (- sx radius 7) (+ sx radius 7))))
                (emit-mono-text out label-x sy label
                                :size size
                                :fill (if selected-p "#effff9" "#9ab0cd")
                                :weight (if selected-p 760 520)
                                :anchor (if left-p "end" "start")))))))
      (format out "</g>~%")

      ;; Inspetor.
      (let ((color (color-for-kind (node-kind selected))))
        (emit-text out (+ right-x 20) (+ graph-y 35) "DETALHES DO PACOTE" :size 20
                   :fill "#edf4ff" :weight 760)
        (emit-text out (+ right-x 20) (+ graph-y 63) "SELECIONADO NA IMAGEM ATIVA" :size 13
                   :fill "#8198b8" :weight 650)
        (format out "<line x1='~F' y1='~F' x2='~F' y2='~F' stroke='#263a57'/>~%"
                (+ right-x 20) (+ graph-y 82) (- (+ right-x right-w) 20) (+ graph-y 82))
        (emit-mono-text out (+ right-x 20) (+ graph-y 120)
                        (fit-svg-text (node-name selected) (- right-w 40) 22 :mono t)
                        :size 22 :fill color :weight 780)
        (emit-pill out (+ right-x 20) (+ graph-y 140) (role-label (node-kind selected))
                   :width 132 :fill "#121f33" :stroke color :foreground color)
        (emit-text out (+ right-x 20) (+ graph-y 196) "CONTEÚDO DO PACOTE" :size 15
                   :fill "#b2c5df" :weight 720)
        (let ((stats `(("SÍMBOLOS INTERNOS" ,(node-internal selected))
                       ("SÍMBOLOS EXPORTADOS" ,(node-external selected))
                       ("FUNÇÕES" ,(node-functions selected))
                       ("MACROS" ,(node-macros selected))
                       ("CLASSES" ,(node-classes selected))
                       ("VARIÁVEIS" ,(node-variables selected)))))
          (loop for (label value) in stats
                for i from 0
                for row-y from (+ graph-y 235) by 38
                do (when (oddp i)
                     (format out "<rect x='~F' y='~F' width='~F' height='33' rx='5' fill='#121f33'/>~%"
                             (+ right-x 10) (- row-y 24) (- right-w 20)))
                   (emit-text out (+ right-x 20) row-y label :size 13 :fill "#8198b8" :weight 620)
                   (emit-text out (- (+ right-x right-w) 20) row-y (format nil "~:D" value)
                              :size 15 :fill "#edf4ff" :weight 760 :anchor "end")))
        (format out "<line x1='~F' y1='~F' x2='~F' y2='~F' stroke='#263a57'/>~%"
                (+ right-x 20) (+ graph-y 452) (- (+ right-x right-w) 20) (+ graph-y 452))
        (emit-text out (+ right-x 20) (+ graph-y 486) "PRIMEIROS SÍMBOLOS POR TIPO" :size 15
                   :fill "#b2c5df" :weight 720)
        (emit-text out (+ right-x 20) (+ graph-y 520) "TIPO" :size 12
                   :fill "#8198b8" :weight 720)
        (emit-text out (+ right-x 148) (+ graph-y 520) "NOME" :size 12
                   :fill "#8198b8" :weight 720)
        (let* ((start-y (+ graph-y 555))
               (row-height 32.0d0)
               (limit (max 0 (floor (- graph-bottom start-y 18) row-height))))
          (loop for line in (node-symbol-lines selected :limit limit)
                for i from 0
                for row-y from start-y by row-height
                do (when (oddp i)
                     (format out "<rect x='~F' y='~F' width='~F' height='28' rx='4' fill='#121f33'/>~%"
                             (+ right-x 10) (- row-y 20) (- right-w 20)))
                   (let* ((trimmed (string-trim " " line))
                          (split (position #\space trimmed))
                          (kind (if split (subseq trimmed 0 split) "SÍMBOLO"))
                          (name (let ((position (position #\space trimmed :from-end t)))
                                  (if position (subseq trimmed (1+ position)) trimmed)))
                          (kind-color (cond
                                        ((string= kind "MACRO") "#ffbe54")
                                        ((string= kind "GENÉRICA") "#5fe7d3")
                                        ((string= kind "CLASSE") "#c384ff")
                                        ((string= kind "FUNÇÃO") "#69a9ff")
                                        ((string= kind "VARIÁVEL") "#ff80b5")
                                        (t "#97abc5"))))
                     (emit-mono-text out (+ right-x 20) row-y
                                     (fit-svg-text kind 112 12 :mono t)
                                     :size 12 :fill kind-color :weight 720)
                     (emit-mono-text out (+ right-x 148) row-y
                                     (fit-svg-text name (- right-w 176) 13 :mono t)
                                     :size 13 :fill "#b2c5df" :weight 520)))))

      (emit-text out graph-x (- height 18)
                 "O MALKUTH VALIDA, ANALISA E MAPEIA A IMAGEM QUE GEROU ESTE DOCUMENTO"
                 :size 12 :fill "#8198b8" :weight 620)
      (format out "</svg>~%"))
    pathname))

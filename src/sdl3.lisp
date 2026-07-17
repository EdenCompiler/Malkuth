;;;; Ponte mínima e explícita para SDL3
;;;;
;;;; O Malkuth usa somente a pequena superfície de SDL necessária à janela,
;;;; entrada e desenho vetorial. A camada permanece simples para que falhas de
;;;; carregamento da biblioteca nativa sejam fáceis de diagnosticar.

(in-package #:malkuth.sdl3)

(cffi:define-foreign-library sdl3
  (:darwin (:or "libSDL3.dylib" "SDL3"))
  (:unix (:or "libSDL3.so.0" "libSDL3.so"))
  (:windows (:or "SDL3.dll"))
  (t (:default "SDL3")))

;; A biblioteca é carregada sob demanda; o núcleo sem interface nunca executa esta etapa.
(defvar *library-loaded-p* nil)
(defun ensure-library-loaded ()
  (unless *library-loaded-p*
    (cffi:use-foreign-library sdl3)
    (setf *library-loaded-p* t)))

(defconstant +sdl-init-video+ #x00000020)
(defconstant +window-resizable+ #x0000000000000020)
(defconstant +event-quit+ #x100)
(defconstant +event-window-close-requested+ #x210)
(defconstant +event-text-input+ #x303)
(defconstant +blendmode-blend+ #x00000001)
(defconstant +mouse-left+ #x00000001)

;; Códigos de varredura USB utilizados pelo SDL3.
(defconstant +sc-a+ 4)
(defconstant +sc-b+ 5)
(defconstant +sc-c+ 6)
(defconstant +sc-f+ 9)
(defconstant +sc-d+ 7)
(defconstant +sc-e+ 8)
(defconstant +sc-g+ 10)
(defconstant +sc-h+ 11)
(defconstant +sc-i+ 12)
(defconstant +sc-j+ 13)
(defconstant +sc-k+ 14)
(defconstant +sc-t+ 23)
(defconstant +sc-o+ 18)
(defconstant +sc-p+ 19)
(defconstant +sc-q+ 20)
(defconstant +sc-r+ 21)
(defconstant +sc-s+ 22)
(defconstant +sc-v+ 25)
(defconstant +sc-w+ 26)
(defconstant +sc-x+ 27)
(defconstant +sc-y+ 28)
(defconstant +sc-1+ 30)
(defconstant +sc-2+ 31)
(defconstant +sc-3+ 32)
(defconstant +sc-4+ 33)
(defconstant +sc-5+ 34)
(defconstant +sc-6+ 35)
(defconstant +sc-return+ 40)
(defconstant +sc-escape+ 41)
(defconstant +sc-backspace+ 42)
(defconstant +sc-tab+ 43)
(defconstant +sc-space+ 44)
(defconstant +sc-slash+ 56)
(defconstant +sc-f5+ 62)
(defconstant +sc-pageup+ 75)
(defconstant +sc-pagedown+ 78)
(defconstant +sc-down+ 81)
(defconstant +sc-up+ 82)
(defconstant +sc-left-control+ 224)
(defconstant +sc-right-control+ 228)

(cffi:defcstruct f-rect
  (x :float) (y :float) (w :float) (h :float))

(cffi:defcstruct i-rect
  (x :int) (y :int) (w :int) (h :int))

;; SDL_Event é uma união. Como o campo de texto começa no mesmo endereço da
;; união, esta estrutura descreve somente o caso SDL_EVENT_TEXT_INPUT que o
;; Malkuth precisa interpretar. O alinhamento fica a cargo do CFFI.
(cffi:defcstruct text-input-event
  (type :uint32)
  (reserved :uint32)
  (timestamp :uint64)
  (window-id :uint32)
  (text :pointer))

(cffi:defcfun ("SDL_Init" %init) :uint8 (flags :uint32))
(cffi:defcfun ("SDL_Quit" %quit) :void)
(cffi:defcfun ("SDL_CreateWindowAndRenderer" %create-window-and-renderer) :uint8
  (title :string) (width :int) (height :int) (flags :uint64)
  (window :pointer) (renderer :pointer))
(cffi:defcfun ("SDL_DestroyWindow" %destroy-window) :void (window :pointer))
(cffi:defcfun ("SDL_DestroyRenderer" %destroy-renderer) :void (renderer :pointer))
(cffi:defcfun ("SDL_GetError" %get-error) :string)
(cffi:defcfun ("SDL_PollEvent" %poll-event) :uint8 (event :pointer))
(cffi:defcfun ("SDL_GetKeyboardState" %get-keyboard-state) :pointer (count :pointer))
(cffi:defcfun ("SDL_StartTextInput" %start-text-input) :uint8 (window :pointer))
(cffi:defcfun ("SDL_StopTextInput" %stop-text-input) :uint8 (window :pointer))
(cffi:defcfun ("SDL_SetTextInputArea" %set-text-input-area) :uint8
  (window :pointer) (rect :pointer) (cursor :int))
(cffi:defcfun ("SDL_GetMouseState" %get-mouse-state) :uint32 (x :pointer) (y :pointer))
(cffi:defcfun ("SDL_GetWindowSize" %get-window-size) :uint8 (window :pointer) (w :pointer) (h :pointer))
(cffi:defcfun ("SDL_SetWindowMinimumSize" %set-window-minimum-size) :uint8
  (window :pointer) (minimum-width :int) (minimum-height :int))
(cffi:defcfun ("SDL_GetTicks" %get-ticks) :uint64)
(cffi:defcfun ("SDL_Delay" %delay) :void (milliseconds :uint32))
(cffi:defcfun ("SDL_SetRenderVSync" %set-render-vsync) :uint8 (renderer :pointer) (vsync :int))
(cffi:defcfun ("SDL_SetRenderDrawBlendMode" %set-blend-mode) :uint8 (renderer :pointer) (mode :uint32))
(cffi:defcfun ("SDL_SetRenderDrawColor" %set-color) :uint8
  (renderer :pointer) (r :uint8) (g :uint8) (b :uint8) (a :uint8))
(cffi:defcfun ("SDL_RenderClear" %clear) :uint8 (renderer :pointer))
(cffi:defcfun ("SDL_RenderPresent" %present) :uint8 (renderer :pointer))
(cffi:defcfun ("SDL_RenderLine" %line) :uint8
  (renderer :pointer) (x1 :float) (y1 :float) (x2 :float) (y2 :float))
(cffi:defcfun ("SDL_RenderPoint" %point) :uint8 (renderer :pointer) (x :float) (y :float))
(cffi:defcfun ("SDL_RenderFillRect" %fill-rect) :uint8 (renderer :pointer) (rect :pointer))
(cffi:defcfun ("SDL_RenderRect" %outline-rect) :uint8 (renderer :pointer) (rect :pointer))

(defun last-error () (%get-error))

(defmacro with-foreign-float-environment (&body body)
  #+sbcl `(sb-int:with-float-traps-masked (:invalid :divide-by-zero :overflow) ,@body)
  #-sbcl `(progn ,@body))

(defmacro with-sdl3 ((window renderer &key (title "MALKUTH / EXPLORADOR DA IMAGEM LISP")
                                         (width 1440) (height 860)) &body body)
  `(progn
     (ensure-library-loaded)
     (with-foreign-float-environment
       (unless (plusp (%init +sdl-init-video+))
         (error "Falha em SDL_Init: ~A" (last-error)))
       (cffi:with-foreign-objects ((window-slot :pointer) (renderer-slot :pointer))
         (setf (cffi:mem-ref window-slot :pointer) (cffi:null-pointer)
               (cffi:mem-ref renderer-slot :pointer) (cffi:null-pointer))
         (unless (plusp (%create-window-and-renderer ,title ,width ,height +window-resizable+
                                                     window-slot renderer-slot))
           (%quit)
           (error "Falha em SDL_CreateWindowAndRenderer: ~A" (last-error)))
         (let ((,window (cffi:mem-ref window-slot :pointer))
               (,renderer (cffi:mem-ref renderer-slot :pointer)))
           (unwind-protect
                (progn
                  (%set-blend-mode ,renderer +blendmode-blend+)
                  ,@body)
             (unless (cffi:null-pointer-p ,renderer) (%destroy-renderer ,renderer))
             (unless (cffi:null-pointer-p ,window) (%destroy-window ,window))
             (%quit)))))))

;; SDL_PollEvent precisa ser drenado a cada quadro. Além do encerramento, a
;; função copia imediatamente o texto UTF-8 porque a memória do evento pertence
;; ao SDL e só é válida durante o processamento da fila.
(defun poll-events ()
  "Retorna (VALUES ENCERRAR-P TEXTOS), com TEXTOS já copiados para strings Lisp."
  (let ((quit nil)
        (texts '()))
    (cffi:with-foreign-object (event :uint8 128)
      (loop while (plusp (%poll-event event))
            for type = (cffi:mem-ref event :uint32)
            do (cond
                 ((or (= type +event-quit+)
                      (= type +event-window-close-requested+))
                  (setf quit t))
                 ((= type +event-text-input+)
                  (let ((pointer
                          (cffi:foreign-slot-value
                           event '(:struct text-input-event) 'text)))
                    (unless (cffi:null-pointer-p pointer)
                      (push (cffi:foreign-string-to-lisp pointer :encoding :utf-8)
                            texts)))))))
    (values quit (nreverse texts))))

(defun poll-quit-p ()
  "Compatibilidade com clientes antigos que só precisam detectar encerramento."
  (nth-value 0 (poll-events)))

(defun start-text-input (window)
  "Ativa eventos de entrada textual Unicode para WINDOW."
  (plusp (%start-text-input window)))

(defun stop-text-input (window)
  "Desativa eventos de entrada textual para WINDOW."
  (plusp (%stop-text-input window)))

(defun set-text-input-area (window x y width height &optional (cursor 0))
  "Informa ao método de entrada a posição visual da caixa e do cursor."
  (cffi:with-foreign-object (rect '(:struct i-rect))
    (setf (cffi:foreign-slot-value rect '(:struct i-rect) 'x) (round x)
          (cffi:foreign-slot-value rect '(:struct i-rect) 'y) (round y)
          (cffi:foreign-slot-value rect '(:struct i-rect) 'w) (round width)
          (cffi:foreign-slot-value rect '(:struct i-rect) 'h) (round height))
    (plusp (%set-text-input-area window rect (round cursor)))))

;; A consulta por estado permite controles contínuos sem depender de repetição
;; de eventos do sistema operacional.
(defun keyboard-down-p (scancode)
  (cffi:with-foreign-object (count :int)
    (let ((state (%get-keyboard-state count))
          (size  (cffi:mem-ref count :int)))
      (and (not (cffi:null-pointer-p state))
           (<= 0 scancode) (< scancode size)
           (plusp (cffi:mem-aref state :uint8 scancode))))))

(defun mouse-state ()
  (cffi:with-foreign-objects ((x :float) (y :float))
    (let ((buttons (%get-mouse-state x y)))
      (values (cffi:mem-ref x :float) (cffi:mem-ref y :float) buttons))))

(defun window-size (window)
  (cffi:with-foreign-objects ((w :int) (h :int))
    (%get-window-size window w h)
    (values (cffi:mem-ref w :int) (cffi:mem-ref h :int))))

(defun set-window-minimum-size (window width height)
  (plusp (%set-window-minimum-size window width height)))

(defun ticks () (%get-ticks))
(defun delay (milliseconds) (%delay milliseconds))
(defun set-vsync (renderer value) (plusp (%set-render-vsync renderer value)))
(defun clear (renderer) (%clear renderer))
(defun present (renderer) (%present renderer))
(defun set-color (renderer r g b &optional (a 255)) (%set-color renderer r g b a))
(defun line (renderer x1 y1 x2 y2) (%line renderer (float x1 1.0) (float y1 1.0) (float x2 1.0) (float y2 1.0)))
(defun point (renderer x y) (%point renderer (float x 1.0) (float y 1.0)))

(defun fill-rect (renderer x y w h)
  (cffi:with-foreign-object (rect '(:struct f-rect))
    (setf (cffi:foreign-slot-value rect '(:struct f-rect) 'x) (float x 1.0)
          (cffi:foreign-slot-value rect '(:struct f-rect) 'y) (float y 1.0)
          (cffi:foreign-slot-value rect '(:struct f-rect) 'w) (float w 1.0)
          (cffi:foreign-slot-value rect '(:struct f-rect) 'h) (float h 1.0))
    (%fill-rect renderer rect)))

(defun outline-rect (renderer x y w h)
  (cffi:with-foreign-object (rect '(:struct f-rect))
    (setf (cffi:foreign-slot-value rect '(:struct f-rect) 'x) (float x 1.0)
          (cffi:foreign-slot-value rect '(:struct f-rect) 'y) (float y 1.0)
          (cffi:foreign-slot-value rect '(:struct f-rect) 'w) (float w 1.0)
          (cffi:foreign-slot-value rect '(:struct f-rect) 'h) (float h 1.0))
    (%outline-rect renderer rect)))

(defun circle (renderer cx cy radius &key (segments 36))
  (let ((previous-x (+ cx radius)) (previous-y cy))
    (loop for i from 1 to segments
          for angle = (* 2.0 pi (/ i segments))
          for x = (+ cx (* radius (cos angle)))
          for y = (+ cy (* radius (sin angle)))
          do (line renderer previous-x previous-y x y)
             (setf previous-x x previous-y y))))

(defun filled-circle (renderer cx cy radius)
  (loop for iy from (floor (- radius)) to (ceiling radius)
        for half = (sqrt (max 0.0 (- (* radius radius) (* iy iy))))
        do (line renderer (- cx half) (+ cy iy) (+ cx half) (+ cy iy))))

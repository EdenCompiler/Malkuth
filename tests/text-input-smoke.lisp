;;;; Teste de fumaça da entrada textual SDL3
;;;;
;;;; Injeta um SDL_EVENT_TEXT_INPUT real na fila nativa para confirmar que a
;;;; estrutura CFFI, a cópia UTF-8 e o ciclo START/STOP continuam compatíveis
;;;; com a versão de SDL3 instalada no ambiente de validação.

(require :asdf)
(asdf:load-asd (merge-pathnames "../malkuth.asd" *load-truename*))
(asdf:load-system "malkuth")

(cffi:defcfun ("SDL_PushEvent" %push-event-for-test) :uint8
  (event :pointer))

(malkuth.sdl3:with-sdl3 (window renderer :title "MALKUTH / TESTE DE ENTRADA" :width 640 :height 360)
  (when renderer nil)
  (unless (malkuth.sdl3:start-text-input window)
    (error "Falha ao ativar entrada textual: ~A" (malkuth.sdl3:last-error)))
  (cffi:with-foreign-object (event :uint8 128)
    (dotimes (index 128)
      (setf (cffi:mem-aref event :uint8 index) 0))
    (cffi:with-foreign-string (text "MALKUTH.APP" :encoding :utf-8)
      (setf (cffi:foreign-slot-value
             event '(:struct malkuth.sdl3::text-input-event)
             'malkuth.sdl3::type)
            #x303
            (cffi:foreign-slot-value
             event '(:struct malkuth.sdl3::text-input-event)
             'malkuth.sdl3::text)
            text)
      (unless (plusp (%push-event-for-test event))
        (error "SDL_PushEvent falhou: ~A" (malkuth.sdl3:last-error)))
      (multiple-value-bind (quit-p texts) (malkuth.sdl3:poll-events)
        (when quit-p (error "A fila sinalizou encerramento inesperado."))
        (unless (equal texts '("MALKUTH.APP"))
          (error "Texto recebido incorretamente: ~S" texts)))))
  (unless (malkuth.sdl3:stop-text-input window)
    (error "Falha ao desativar entrada textual: ~A" (malkuth.sdl3:last-error))))

(format t "~&Teste de entrada textual SDL3 do MALKUTH aprovado.~%")
(quit)

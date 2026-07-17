;;;; Inicializador do Malkuth para uso em produção
;;;;
;;;; O modo --script não carrega os arquivos de inicialização do usuário no SBCL.
;;;; Por isso este arquivo localiza o Quicklisp explicitamente quando o ASDF não
;;;; consegue enxergar o CFFI, valida a configuração externa e converte variáveis
;;;; de ambiente em argumentos tipados para a aplicação.

(require :asdf)

;; Retorna NIL para variáveis ausentes ou vazias, evitando distinções ambíguas.
(defun env-value (name)
  (let ((value (uiop:getenv name)))
    (and value (plusp (length value)) value)))

;; Converte inteiros e aplica limites defensivos antes de entregá-los à interface.
(defun env-integer (name default &key minimum maximum)
  (let* ((text (env-value name))
         (value (and text (parse-integer text :junk-allowed t))))
    (setf value (or value default))
    (when minimum (setf value (max minimum value)))
    (when maximum (setf value (min maximum value)))
    value))

;; Aceita formas usuais em inglês e português para facilitar automação local.
(defun env-boolean (name default)
  (let ((value (env-value name)))
    (if (null value)
        default
        (member (string-downcase value) '("1" "true" "yes" "on" "sim" "verdadeiro" "ligado") :test #'string=))))

;; Prefixos aceitam vírgula ou espaço; entradas vazias são descartadas.
(defun split-prefixes (text)
  (when text
    (remove-if (lambda (item) (zerop (length item)))
               (uiop:split-string text :separator '(#\, #\Space #\Tab)))))

(defun prefix-predicate (prefixes)
  (when prefixes
    (lambda (package)
      (let ((name (package-name package)))
        (some (lambda (prefix)
                (and (<= (length prefix) (length name))
                     (string-equal prefix name :end2 (length prefix))))
              prefixes)))))

;; A ordem privilegia uma substituição explícita e depois instalações convencionais.
(defun quicklisp-setup-candidates ()
  (remove nil
          (list (let ((override (env-value "QUICKLISP_SETUP")))
                  (and override (pathname override)))
                (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))
                (merge-pathnames ".quicklisp/setup.lisp" (user-homedir-pathname))
                (merge-pathnames ".roswell/lisp/quicklisp/setup.lisp"
                                 (user-homedir-pathname)))))

(defun asdf-system-visible-p (name)
  (not (null (ignore-errors (asdf:find-system name nil)))))

(defun load-first-available-quicklisp ()
  (loop for candidate in (quicklisp-setup-candidates)
        for existing = (ignore-errors (probe-file candidate))
        when existing
          do (format *error-output* "MALKUTH: carregando o Quicklisp de ~A~%" existing)
             (load existing)
             (return existing)))

(defun quickload-system (name)
  (let* ((package (find-package "QL"))
         (symbol (and package (find-symbol "QUICKLOAD" package))))
    (when (and symbol (fboundp symbol))
      (format *error-output* "MALKUTH: carregando pelo Quicklisp ~A~%" name)
      (funcall (symbol-function symbol) name)
      t)))

;; Garante a dependência gráfica antes de carregar o sistema completo. O núcleo
;; continua utilizável separadamente por ANALYZE.LISP sem CFFI nem SDL3.
(defun ensure-cffi-visible ()
  (unless (asdf-system-visible-p "cffi")
    (load-first-available-quicklisp))
  (unless (asdf-system-visible-p "cffi")
    (quickload-system :cffi))
  (unless (asdf-system-visible-p "cffi")
    (error (concatenate
            'string
            "O CFFI não está visível para este script do SBCL.~%"
            "O modo --script do SBCL ignora ~/.sbclrc. Tente:~%"
            "  QUICKLISP_SETUP=/caminho/para/quicklisp/setup.lisp sbcl --script run.lisp~%"
            "ou instale o pacote CFFI fornecido para a sua implementação.~%"))))

(defun project-root ()
  (uiop:pathname-directory-pathname *load-truename*))

;; A primeira barreira trata falhas de descoberta e compilação de dependências.
(handler-case
    (progn
      (ensure-cffi-visible)
      (asdf:load-asd (merge-pathnames "malkuth.asd" (project-root)))
      (asdf:load-system "malkuth"))
  (error (condition)
    (format *error-output* "~&FALHA NA INICIALIZAÇÃO DO MALKUTH: ~A~%" condition)
    (uiop:quit 1)))

;; A segunda barreira separa erros operacionais da aplicação de erros de carga.
(handler-case
    (let* ((scope-prefixes (split-prefixes (env-value "MALKUTH_SCOPE_PREFIXES")))
           (user-prefixes (or (split-prefixes (env-value "MALKUTH_USER_PREFIXES"))
                              scope-prefixes))
           (output (or (env-value "MALKUTH_OUTPUT_DIR")
                       (namestring (merge-pathnames "output/" (project-root)))))
           (width (env-integer "MALKUTH_WIDTH" 1600 :minimum 1280))
           (height (env-integer "MALKUTH_HEIGHT" 900 :minimum 760)))
      (format *error-output*
              "MALKUTH 0.4.1: ~Dx~D / saída ~A~@[ / escopo ~{~A~^, ~}~]~%"
              width height output scope-prefixes)
      (malkuth.app:run
       :width width
       :height height
       :max-frames (let ((text (env-value "MALKUTH_MAX_FRAMES")))
                     (and text (parse-integer text :junk-allowed t)))
       :include-empty (env-boolean "MALKUTH_INCLUDE_EMPTY" nil)
       :auto-orbit (env-boolean "MALKUTH_AUTO_ORBIT" t)
       :risk-threshold (env-integer "MALKUTH_RISK_THRESHOLD" 20 :minimum 0 :maximum 100)
       :initial-search (env-value "MALKUTH_INITIAL_SEARCH")
       :export-directory (pathname output)
       :package-predicate (prefix-predicate scope-prefixes)
       :user-package-predicate (prefix-predicate user-prefixes)
       :include-dependencies (and scope-prefixes
                                  (env-boolean "MALKUTH_INCLUDE_DEPENDENCIES" t))))
  (error (condition)
    (format *error-output* "~&ERRO FATAL DO MALKUTH: ~A~%" condition)
    (uiop:quit 1)))

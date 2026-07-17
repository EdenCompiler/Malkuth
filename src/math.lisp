;;;; Matemática vetorial e projeção da cena
;;;;
;;;; As operações usam números de precisão dupla para manter o arranjo estável.
;;;; Nenhuma função depende da interface gráfica, o que facilita testes isolados.

(in-package #:malkuth.math)

(declaim (inline clamp lerp smoothstep))
(defun clamp (x lo hi) (max lo (min hi x)))
(defun lerp (a b amount) (+ a (* (- b a) amount)))
(defun smoothstep (edge0 edge1 x)
  (let ((u (clamp (/ (- x edge0) (- edge1 edge0)) 0.0 1.0)))
    (* u u (- 3.0 (* 2.0 u)))))

(defun mix32 (x)
  (let ((x (logand #xffffffff x)))
    (setf x (logxor x (ash x -16)))
    (setf x (logand #xffffffff (* x #x7feb352d)))
    (setf x (logxor x (ash x -15)))
    (setf x (logand #xffffffff (* x #x846ca68b)))
    (logand #xffffffff (logxor x (ash x -16)))))

(defun hash-unit (thing &optional (salt 0))
  (/ (float (mix32 (logxor (sxhash thing) salt)) 1.0d0) 4294967295.0d0))

(defun hash-signed (thing &optional (salt 0))
  (- (* 2.0d0 (hash-unit thing salt)) 1.0d0))

(defstruct (v3 (:constructor v3 (x y z)))
  (x 0.0d0 :type real)
  (y 0.0d0 :type real)
  (z 0.0d0 :type real))

(defun v3+ (a b) (v3 (+ (v3-x a) (v3-x b)) (+ (v3-y a) (v3-y b)) (+ (v3-z a) (v3-z b))))
(defun v3- (a b) (v3 (- (v3-x a) (v3-x b)) (- (v3-y a) (v3-y b)) (- (v3-z a) (v3-z b))))
(defun v3* (a scalar) (v3 (* (v3-x a) scalar) (* (v3-y a) scalar) (* (v3-z a) scalar)))
(defun v3-length (a) (sqrt (+ (* (v3-x a) (v3-x a)) (* (v3-y a) (v3-y a)) (* (v3-z a) (v3-z a)))))
(defun v3-normalize (a)
  (let ((length (v3-length a)))
    (if (< length 1.0d-9) (v3 0.0d0 0.0d0 0.0d0) (v3* a (/ 1.0d0 length)))))

(defun rotate-yx (point yaw pitch)
  (let* ((cy (cos yaw)) (sy (sin yaw))
         (cp (cos pitch)) (sp (sin pitch))
         (x (+ (* (v3-x point) cy) (* (v3-z point) sy)))
         (z (+ (* (- (v3-x point)) sy) (* (v3-z point) cy)))
         (y (- (* (v3-y point) cp) (* z sp)))
         (z2 (+ (* (v3-y point) sp) (* z cp))))
    (v3 x y z2)))

(defstruct projected
  (x 0.0d0) (y 0.0d0) (depth 0.0d0) (visible-p nil))

(defun project-point (point width height yaw pitch distance &key (fov 760.0d0) (margin 18.0d0))
  (let* ((rotated (rotate-yx point yaw pitch))
         (depth (+ distance (v3-z rotated))))
    (if (<= depth 0.25d0)
        (make-projected :visible-p nil :depth depth)
        (let* ((scale (/ fov depth))
               (x (+ (* width 0.5d0) (* (v3-x rotated) scale)))
               (y (+ (* height 0.5d0) (* (v3-y rotated) scale))))
          (make-projected :x x :y y :depth depth
                          :visible-p (and (> x (- margin)) (< x (+ width margin))
                                          (> y (- margin)) (< y (+ height margin))))))))

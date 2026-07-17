;;;; Arranjo tridimensional determinístico
;;;;
;;;; O algoritmo combina repulsão, molas e gravidade central. O objetivo não é
;;;; simular física real, mas produzir uma topologia legível e reproduzível.

(in-package #:malkuth.layout)

(defun seed-layout! (snapshot &key (spread 34.0d0))
  (let ((count (max 1 (length (snapshot-nodes snapshot)))))
    (loop for node across (snapshot-nodes snapshot)
          for i from 0
          for phase = (* 2.0d0 pi (/ i count))
          for shell = (+ 0.35d0 (* 0.65d0 (hash-unit (node-name node) #x77)))
          do (setf (node-position node)
                   (v3 (* spread shell (+ (* 0.72d0 (cos phase))
                                          (* 0.28d0 (hash-signed (node-name node) #x11))))
                       (* spread 0.56d0 (hash-signed (node-name node) #x22))
                       (* spread shell (+ (* 0.72d0 (sin phase))
                                          (* 0.28d0 (hash-signed (node-name node) #x33)))))
                   (node-velocity node) (v3 0.0d0 0.0d0 0.0d0)
                   (node-heat node) 1.0d0)))
  snapshot)

(defun add-force! (forces index force)
  (setf (aref forces index) (v3+ (aref forces index) force)))

(defun relax-layout! (snapshot &key (iterations 1) (dt 0.018d0) (repulsion 680.0d0)
                                     (spring 0.18d0) (spring-length 19.0d0)
                                     (gravity 0.032d0) (damping 0.86d0))
  (let* ((nodes (snapshot-nodes snapshot))
         (count (length nodes)))
    (dotimes (iteration iterations)
      (let ((forces (make-array count :initial-element (v3 0.0d0 0.0d0 0.0d0))))
        ;; Separação entre pacotes inspirada na força de Coulomb.
        (loop for i below count
              do (loop for j from (1+ i) below count
                       for a = (aref nodes i)
                       for b = (aref nodes j)
                       for delta = (v3- (node-position b) (node-position a))
                       for distance = (max 0.8d0 (v3-length delta))
                       for direction = (v3* delta (/ 1.0d0 distance))
                       for magnitude = (/ repulsion (* distance distance))
                       for force = (v3* direction magnitude)
                       do (add-force! forces i (v3* force -1.0d0))
                          (add-force! forces j force)))
        ;; Relações USE-PACKAGE funcionam como molas.
        (loop for edge across (snapshot-edges snapshot)
              for a = (aref nodes (edge-from edge))
              for b = (aref nodes (edge-to edge))
              for delta = (v3- (node-position b) (node-position a))
              for distance = (max 0.001d0 (v3-length delta))
              for direction = (v3* delta (/ 1.0d0 distance))
              for magnitude = (* spring (edge-weight edge) (- distance spring-length))
              for force = (v3* direction magnitude)
              do (add-force! forces (node-id a) force)
                 (add-force! forces (node-id b) (v3* force -1.0d0)))
        ;; Uma gravidade central fraca mantém a constelação coesa.
        (loop for node across nodes
              for i from 0
              do (add-force! forces i (v3* (node-position node) (- gravity))))
        ;; Integração de Euler semi-implícita com amortecimento e limite de velocidade.
        (loop for node across nodes
              for i from 0
              for velocity = (v3* (v3+ (node-velocity node)
                                       (v3* (aref forces i) dt))
                                  damping)
              for speed = (v3-length velocity)
              do (when (> speed 8.0d0)
                   (setf velocity (v3* velocity (/ 8.0d0 speed))))
                 (setf (node-velocity node) velocity
                       (node-position node) (v3+ (node-position node) (v3* velocity dt))
                       (node-heat node) (* 0.994d0 (node-heat node)))))))
  snapshot)

(defun reheat-layout! (snapshot)
  (loop for node across (snapshot-nodes snapshot)
        do (setf (node-velocity node)
                 (v3 (* 2.2d0 (hash-signed (node-name node) (get-universal-time)))
                     (* 2.2d0 (hash-signed (node-name node) (+ 17 (get-universal-time))))
                     (* 2.2d0 (hash-signed (node-name node) (+ 31 (get-universal-time)))))
                 (node-heat node) 1.0d0))
  snapshot)

(defun update-projection! (snapshot width height yaw pitch distance
                            &key (offset-x 0.0d0) (offset-y 0.0d0) (fov 760.0d0))
  (loop for node across (snapshot-nodes snapshot)
        for projected = (project-point (node-position node) width height yaw pitch distance :fov fov)
        do (setf (node-screen-x node) (+ offset-x (projected-x projected))
                 (node-screen-y node) (+ offset-y (projected-y projected))
                 (node-depth node) (projected-depth projected)
                 (node-visible-p node) (projected-visible-p projected)))
  snapshot)

(defun sorted-visible-nodes (snapshot)
  (sort (remove-if-not #'node-visible-p (coerce (snapshot-nodes snapshot) 'list))
        #'> :key #'node-depth))

(defun nearest-node (snapshot x y &key (max-distance 28.0d0))
  (let ((best nil) (best-distance max-distance))
    (loop for node across (snapshot-nodes snapshot)
          when (node-visible-p node)
            do (let* ((dx (- x (node-screen-x node)))
                      (dy (- y (node-screen-y node)))
                      (distance (sqrt (+ (* dx dx) (* dy dy)))))
                 (when (< distance best-distance)
                   (setf best node best-distance distance))))
    best))

;;;; Monitoramento contínuo da imagem Lisp
;;;;
;;;; O monitor não cria threads por conta própria: ele oferece uma iteração
;;;; determinística e um laço opcional. Assim, aplicações podem executá-lo na
;;;; thread principal, em uma thread própria ou acioná-lo por um agendador já
;;;; existente, sem o núcleo impor uma biblioteca de concorrência.

(in-package #:malkuth.monitor)

(defstruct (architecture-monitor (:constructor %make-architecture-monitor))
  snapshot-builder
  previous-snapshot
  previous-analysis
  (output-directory #P"output/monitor/" :type pathname)
  (history-directory #P"output/monitor/historico/" :type pathname)
  (retention 50 :type fixnum)
  (poll-count 0 :type fixnum)
  (change-count 0 :type fixnum)
  last-diff
  last-error
  (stopped-p nil)
  (export-on-change-p t)
  on-change)

(defun make-architecture-monitor (&key snapshot-builder initial-snapshot
                                       (output-directory #P"output/monitor/")
                                       history-directory (retention 50)
                                       (export-on-change t) on-change)
  "Cria um monitor com uma fotografia inicial validada.

SNAPSHOT-BUILDER deve devolver um novo instantâneo a cada chamada. Por padrão,
usa BUILD-SNAPSHOT na imagem corrente. ON-CHANGE recebe monitor, estado anterior,
estado atual e ARCHITECTURE-DIFF."
  (let* ((builder (or snapshot-builder #'build-snapshot))
         (snapshot (or initial-snapshot (funcall builder)))
         (output (uiop:ensure-directory-pathname
                  (merge-pathnames output-directory (uiop:getcwd))))
         (history (uiop:ensure-directory-pathname
                   (merge-pathnames (or history-directory
                                        (merge-pathnames "historico/" output))
                                    (uiop:getcwd)))))
    (validate-snapshot snapshot :errorp t)
    (%make-architecture-monitor
     :snapshot-builder builder
     :previous-snapshot snapshot
     :previous-analysis (analyze-snapshot snapshot)
     :output-directory output
     :history-directory history
     :retention (max 1 retention)
     :export-on-change-p export-on-change
     :on-change on-change)))

(defun stop-monitor! (monitor)
  "Solicita o encerramento cooperativo de RUN-MONITOR."
  (setf (architecture-monitor-stopped-p monitor) t)
  monitor)

(defun monitor-poll! (monitor)
  "Executa uma leitura do monitor e retorna (VALUES ALTEROU-P DIFF SNAPSHOT).

Falhas não substituem o último estado válido. A condição é registrada em
LAST-ERROR e propagada para que o chamador decida entre repetição e encerramento."
  (incf (architecture-monitor-poll-count monitor))
  (handler-case
      (let* ((old (architecture-monitor-previous-snapshot monitor))
             (old-analysis (architecture-monitor-previous-analysis monitor))
             (fresh (funcall (architecture-monitor-snapshot-builder monitor))))
        (validate-snapshot fresh :errorp t)
        (setf (architecture-monitor-last-error monitor) nil)
        (if (string= (snapshot-fingerprint old) (snapshot-fingerprint fresh))
            (values nil nil fresh)
            (let* ((fresh-analysis (analyze-snapshot fresh))
                   (diff (compare-architectures
                          old fresh :old-analysis old-analysis
                          :new-analysis fresh-analysis)))
              (save-history-snapshot
               old (architecture-monitor-history-directory monitor)
               :retention (architecture-monitor-retention monitor)
               :label "antes-da-alteracao")
              (when (architecture-monitor-export-on-change-p monitor)
                (export-bundle fresh
                               (architecture-monitor-output-directory monitor)
                               :analysis fresh-analysis)
                (export-comparison-bundle
                 old fresh (architecture-monitor-output-directory monitor)
                 :old-analysis old-analysis :new-analysis fresh-analysis
                 :diff diff))
              (setf (architecture-monitor-previous-snapshot monitor) fresh
                    (architecture-monitor-previous-analysis monitor) fresh-analysis
                    (architecture-monitor-last-diff monitor) diff)
              (incf (architecture-monitor-change-count monitor))
              (when (architecture-monitor-on-change monitor)
                (funcall (architecture-monitor-on-change monitor)
                         monitor old fresh diff))
              (values t diff fresh))))
    (error (condition)
      (setf (architecture-monitor-last-error monitor) condition)
      (error condition))))

(defun run-monitor (monitor &key (interval 5.0) iterations on-poll)
  "Executa MONITOR cooperativamente até STOP-MONITOR!, ITERATIONS ou erro.

ON-POLL recebe monitor, alterou-p, diff e snapshot depois de cada leitura. O
intervalo mínimo de 0,05 segundo evita laços acidentais que monopolizem a CPU."
  (let ((interval (max 0.05 interval))
        (completed 0))
    (setf (architecture-monitor-stopped-p monitor) nil)
    (loop until (architecture-monitor-stopped-p monitor)
          while (or (null iterations) (< completed iterations))
          do (multiple-value-bind (changed-p diff snapshot)
                 (monitor-poll! monitor)
               (incf completed)
               (when on-poll
                 (funcall on-poll monitor changed-p diff snapshot)))
             (when (and (not (architecture-monitor-stopped-p monitor))
                        (or (null iterations) (< completed iterations)))
               (sleep interval)))
    monitor))

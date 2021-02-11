(define-module (ubu-lib inotify)
  #:use-module ((srfi srfi-1) #:select (fold))
  #:export
  (
   ubu-inotify-events
   ubu-inotify-watch-events
   ubu-inotify-watch-until
   ))


(eval-when (compile load eval)
  (load-extension "lib-ubu-inotify" "scm_init_ubu_inotify_c_module")
  (use-modules (ubu inotify c)))


(define ubu-inotify-events (map car c-inotify-events))


;; Watch selected "events" for "pathname" and run "proc" after an
;; event has occured.
;;
;; pathname       File or directory to watch.
;; events         List of events to trigger watch notification.
;; proc           Procedure to run after each notification.
;;
(define (ubu-inotify-watch-events pathname events proc)
  (let* ((fd (c-inotify-open))
         (wd (inotify-add-watch fd pathname events)))
    (let loop-forever ()
      (proc (c-inotify-get-event fd))
      (loop-forever))))


;; Watch selected "events" for "pathname" and run "proc" after an
;; event has occured until "until-proc" return true.
;;
;; "until-cond" is tested before "proc" is run.
;;
;; pathname       File or directory to watch.
;; events         List of events to trigger watch notification.
;; until-cond     Check if exit or not.
;; proc           Procedure to run after each notification.
;;
(define (ubu-inotify-watch-until pathname events until-cond proc)
  (let* ((fd (c-inotify-open))
         (wd (inotify-add-watch fd pathname events)))
    (let loop ()
      (let ((event (c-inotify-get-event fd)))
        (when (not (until-cond event))
          (proc event)
          (loop))))))



;; ------------------------------------------------------------
;; Internal utilities:

(define (inotify-add-watch fd pathname events)
  (c-inotify-add-watch fd
                       pathname
                       (fold +
                             0
                             (map (lambda (event)
                                    (assoc-ref c-inotify-events event))
                                  events))))

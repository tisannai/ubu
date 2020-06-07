(define-module (ubu-lib path)
  #:export (
            map-source-to-target
            ))

(use-modules (ubu))


;; Convert set of files with source extension to set of files with target
;; extension.
;;
;; source-to-target takes either 2 or 3 arguments. First argument is
;; always a list of source files.
;;
;; If 2 arguments are given, the second is replacement extension to
;; replace the source suffices. Target file(s) directory is the same
;; as for source files.
;;
;; If 3 arguments are given, the second argument is a directory for
;; target files and third argument is a replacement extension to
;; replace the source suffices.
;;
;; Arguments:
;;     s-files: Glob pattern for source files.
;;     rest:    Extension pattern only, or directory and extension pattern.
;;
(define (map-source-to-target s-files . rest)
  (cond

   ((= 1 (length rest))
    ;; Map only extension.
    (map (lambda (file)
           (map-files file
                      'dir (file-dir file)
                      'ext (first rest)))
         s-files)
    )

   (else
    ;; Map directory and extension.
    (map-files s-files
               'dir (first rest)
               'ext (second rest)))))

(define-module (ubu-lib path)
  #:export (
            map-source-to-target
            ))

(use-modules (ubu))


;; Convert set of files with source extension to set of files with target
;; extension.
;;
;; map-source-to-target takes either 2 or 3 arguments. First argument is
;; always a list of source files.
;;
;; If 2 arguments are given, the second is replacement extension to
;; replace the source suffices. Target file(s) directory is the same
;; as for source files.
;;
;; If 3 arguments are given, the third argument is a replacement
;; extension to replace the source suffices.
;;
;; Arguments:
;;     s-files: Source files.
;;     rest:    Extension pattern only, or directory and extension pattern.
;;
;; Example: (map-source-to-target (list "foo.c" "bar.c")
;;                                ".o")
;;          (map-source-to-target (list "foo.c" "bar.c")
;;                                ".o"
;;                                "build")
;;
(define (map-source-to-target s-files . rest)
  (cond

   ((= 0 (length rest))
    (ubu-fatal "map-source-to-target: missing mapping specification"))

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
               'dir (second rest)
               'ext (first rest)))))

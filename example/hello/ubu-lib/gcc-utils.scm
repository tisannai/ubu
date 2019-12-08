(define-module (gcc-utils)
  #:export (gcc-compile-files
            gcc-link-files))

(use-modules (ubu))

 ;; GCC: Compile c-files to object-files.
(define (gcc-compile-files c-files o-files)
  (when (ubu-update? c-files o-files)
    ;; Run parallel if enabled.
    (sh-set
     (map
      (lambda (c o)
        (gap
         "gcc -Wall"
         (if (get "gcc-opt") "-O2" "-g")
         "-c" c
         "-o" o))
      c-files
      o-files))))


;; GCC: Link object-files to executables.
(define (gcc-link-files o-files exe-file)
  (when (ubu-update? o-files exe-file)
    (sh "gcc" "-o" exe-file o-files)))

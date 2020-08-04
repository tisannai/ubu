;; GCC: Compile c-files to object-files.
(define (gcc-compile-files c-files o-files)
  ;; Run parallel if enabled.
  (sh-set (ubu-for-updates c-files o-files
                           (lambda (c o)
                             (gap
                              "gcc -Wall"
                              (if (get "gcc-opt") "-O2" "-g")
                              "-c" c
                              "-o" o)))))

;; GCC: Link object-files to executables.
(define (gcc-link-files o-files exe-file)
  (when (ubu-update? o-files exe-file)
    (sh "gcc" "-o" exe-file o-files)))

(define-module (gcc-utils)
  #:export (gcc-compile-files
            gcc-link-files))

(use-modules (ubu))

;; GCC: Compile c-files to object-files.
(define (gcc-compile-files c-files o-files)
  ;; Filter file pairs that actually need updates.
  (ubu-for-updates c-files
                   o-files
                   (lambda (up-c up-o)
                     (sh-set
                      (map
                       (lambda (c o)
                         (gap
                          "gcc -Wall"
                          (if (get "gcc-opt") "-O2" "-g")
                          "-c" c
                          "-o" o))
                       up-c
                       up-o)))))


;; GCC: Link object-files to executables.
(define (gcc-link-files o-files exe-file)
  (when (ubu-update? o-files exe-file)
    (sh "gcc" "-o" exe-file o-files)))

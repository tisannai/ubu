(define-module (ubu-lib guile)
  #:export (
            guile-install-bin
            ))

(use-modules (ubu core))
(use-modules (system base compile))

;; Install guile program as single binary library.
;;
;; Arguments:
;;     program: Program file to install.
;;
;; Example: (guile-install-bin "bin/bas")
;;
(define (guile-install-bin program . libs)
  (let* ((filename (file-name program))
         (go-path (cat (car (string-split (getenv "GUILE_LOAD_PATH") #\:))
                       "/install-bin/"
                       filename))
         (go-bin-path (cat go-path "/bin/" filename ".go"))
         (bin-file-path (cat (getenv "HOME") "/bin/" filename)))
    (compile-file program #:output-file go-bin-path)
    (when (pair? libs)
      (for-each (lambda (lib)
                  (compile-file lib #:output-file (cat go-path "/" lib ".go")))
                libs))
    (when (file-exists? bin-file-path)
      (delete-file bin-file-path))
    (apply file-write-lines
           (append (list bin-file-path
                         "#!/usr/bin/env guile"
                         "-s"
                         "!#")
                   (map (lambda (file)
                          (cat "(load-compiled \"" go-path "/" file ".go\")"))
                        (append libs (list program)))))
    (file-chmod-to-executable bin-file-path)))

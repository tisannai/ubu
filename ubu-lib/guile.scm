(define-module (ubu-lib guile)
  #:export (
            guile-install-bin
            ))

(use-modules (ubu))


;; Install guile program as single binary library.
;;
;; Arguments:
;;     program: Program file to install.
;;
;; Example: (guile-install-bin "bin/bas")
;;
(define (guile-install-bin program)
  (let* ((filename (file-name program))
         (go-file-path (cat (car (string-split (getenv "GUILE_LOAD_PATH") #\:))
                            "/bin/"
                            filename
                            ".go"))
         (bin-file-path (cat (getenv "HOME") "/bin/" filename))
         (file-write-lines bin-file-path
                           "#!/usr/bin/env guile"
                           "-s"
                           "!#"
                           (cat "(load-compiled \"" go-file-path "\")"))
         (file-chmod-to-executable bin-file-path))))

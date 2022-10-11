(define-module (ubu-lib path)
  #:export (
            ))

(use-modules (ubu))


(set "user-install-path" (car (string-split (getenv "GUILE_LOAD_PATH") #\:)))
(set "user-bin-path" (cat (env "HOME") "/bin"))

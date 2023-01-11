(define-module (ubu-lib path)
  #:export (
            path-refresh))

(use-modules (ubu))

;; User must call this function in order to make the variable valid and visible.
(define (path-refresh)
  (set "user-install-path" (car (string-split (getenv "GUILE_LOAD_PATH") #\:)))
  (set "user-bin-path" (cat (env "HOME") "/bin")))

(define-module (ubu-lib path)
  #:export
  (
   path-refresh
   get-user-bin-path
   get-user-install-path
   ))

(use-modules (ubu))

;; User must call this function in order to make the variable valid and visible.
(define (path-refresh)
  (set "user-install-path" (get-user-install-path))
  (set "user-bin-path" (get-user-bin-path)))

(define (get-user-bin-path) (cat (env "HOME") "/bin"))
(define (get-user-install-path) (car (string-split (getenv "GUILE_LOAD_PATH") #\:)))

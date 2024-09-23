(define-module (ubu-lib valgrind)
  #:export (
            valgrind-analyze
            ))

(use-modules (ubu core))

;; Set defaults for Valgrind Variables
(set "valgrind-opts"     "--error-limit=no --leak-check=full")
(set "valgrind-log"      "valgrind.log")
(set "valgrind-supp"     #nil)


;; Perform Valgrind analysis for program.
;;
;; Arguments:
;;     program:   Program executable.
;;     prog-args: Command line arguments for analyzed program.
;;
;; Variables:
;;     valgrind-opts: Valgrind options (default: --error-limit=no --leak-check=full)
;;     valgrind-log:  Valgrind log file name (default: valgrind.log)
;;     valgrind-supp: Valgrind suppressions control file name (default: none)
;;
;; Example: (valgrind-analyze "foobar" (list "-f" "my-file.txt"))
;;
(define (valgrind-analyze program prog-args)
  (sh "valgrind"
      (get "valgrind-opts")
      (cat "--log-file=" (get "valgrind-log"))
      (if (get "valgrind-supp")
          (cat "--suppressions=" (get "valgrind-supp"))
          '())
      program
      prog-args))

(define-module (ubu-lib adoc)
  #:export (
            adoc-build-man
            adoc-install-man
            ))

(use-modules (ubu))
(use-modules (system base compile))

;; Install adoc based documentation (man pages, etc.).
;;
;; User must identify the used program: (set "adoc-prog-name" "<progname>")
;;

;; Default paths:
(define (get-man-path) (cat (env "HOME") "/usr/man"))
(define (get-doc-src) (string-append "doc/" (get "adoc-prog-name") ".adoc"))
(define (get-doc-dst) (string-append "doc/" (string-upcase (get "adoc-prog-name")) ".3"))

;; Build man-page from adoc file.
(define (adoc-build-man)
  (ubu-for-updates (get-doc-src) (get-doc-dst)
                   (lambda (src dst)
                     (sh "a2x --doctype manpage --format manpage" src "-D doc"))))
(ubu-reg-act 'adoc-build-man)

;; Install the build man-page.
(define (adoc-install-man)
  (sh "cp " (get-doc-dst) (cat (get-man-path) "/man3")))
(ubu-reg-act 'adoc-install-man)

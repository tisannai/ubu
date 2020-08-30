(define-module (ubu-lib checksum)
  #:use-module ((ice-9 rdelim) #:select (read-line))
  #:use-module ((srfi srfi-1) #:select (drop))
  #:export (
            file-checksum
            ))


;; Calculate hash based checksum for file content.
;;
;; If key-argument skip-lines is given, as many lines are skipped for
;; checksum calculation. This is useful for generated code where the
;; standard header might have a changing date, but the actual content
;; remains the same.
;;
;; Example: (file-checksum "my-file.txt")
;;          (file-checksum "my-file.txt" 5)
;;
(define* (file-checksum filename #:key (skip-lines 0))
  (string-hash
   (string-concatenate
    (drop
     (call-with-input-file filename
       (lambda (port)
         (let loop ((line (read-line port)))
           (if (eof-object? line)
               '()
               (cons line (loop (read-line port))))))
       #:binary #t)
     skip-lines))))

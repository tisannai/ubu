(define-module (ubu-lib iverilog)
  #:export
  (
   iverilog-compile-command-get
   iverilog-compile-command-set
   iverilog-simulate-files
   iverilog-simulate-subblock
   iverilog-simulate-default
   iverilog-generate-and-simulate-subblock
   iverilog-generate-and-simulate-default
   iverilog-view-waves
   ))

(use-modules (ubu))
(use-modules (tuile utils))
(use-modules (tuile pr))
(use-modules (ubu-lib vlog-gen))


(define iverilog-compile-command "iverilog")

(define (iverilog-compile-command-get)
  iverilog-compile-command)

(define (iverilog-compile-command-set compile-command)
  (set! iverilog-compile-command compile-command)
  compile-command)



(define (iverilog-get-rtl-files)
  (get-files "rtl/*.*v"))

(define (iverilog-get-tb-files)
  (get-files "tb/*.*v"))

(define (iverilog-get-test-file test-name)
;;  (cat "test/" test-name ".v")
  (vlog-gen-get-file "test" test-name))


(define* (iverilog-simulate-files tb-name
                                  test-name
                                  #:key
                                  (rtl-files  #f)
                                  (tb-files   #f)
                                  (test-files #f)
                                  (user-files #f))
  (let ((files (append (or rtl-files  (iverilog-get-rtl-files))
                       (or tb-files   (iverilog-get-tb-files))
                       (or user-files '())
                       (or test-files (list (iverilog-get-test-file test-name))))))
    (use-dir "sim")
    (in-dir "sim"
            (sh (gap (iverilog-compile-command-get) (map (lambda (file) (cat "../" file)) files) "-o" tb-name))
            (sh "vvp" tb-name))
    (pr "Waves in: sim: \"sim/" tb-name ".vcd\"")))


(define (iverilog-simulate-subblock dut-name)
  (let ((ref (vlog-gen-dut-ref-subblock dut-name)))
    (iverilog-simulate-files (ref 'tb-name)
                             (ref 'test-name)
                             #:rtl-files  (ref 'rtl-files)
                             #:tb-files   (ref 'tb-files))))


(define* (iverilog-simulate-default dut-name #:key (user-files '()) (user-files-tb '()) (user-test #f))
  (let ((ref (vlog-gen-dut-ref-default dut-name #:user-files user-files #:user-files-tb user-files-tb)))
    (iverilog-simulate-files (ref 'tb-name)
                             (or user-test (ref 'test-name))
                             #:rtl-files  (ref 'rtl-files)
                             #:tb-files   (ref 'tb-files))))


(define (iverilog-generate-and-simulate-subblock dut-name)
  (vlog-gen-subblock-tb dut-name)
  (iverilog-simulate-subblock dut-name))


(define* (iverilog-generate-and-simulate-default dut-name #:key (user-files '()) (user-files-tb '()) (user-test #f))
  (vlog-gen-default-tb dut-name #:user-files-tb user-files-tb)
  (iverilog-simulate-default dut-name #:user-files user-files #:user-files-tb user-files-tb #:user-test user-test))


(define (iverilog-view-waves dut-name)
  (let ((ref (vlog-gen-dut-ref-subblock dut-name)))
    (sh (ss "gtkwave sim/" (ref 'tb-name) ".vcd &"))))

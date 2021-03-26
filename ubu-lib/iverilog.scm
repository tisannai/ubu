(define-module (ubu-lib iverilog)
  #:export
  (
   iverilog-simulate-files
   iverilog-simulate-subblock
   iverilog-simulate-default
   iverilog-generate-and-simulate-subblock
   iverilog-generate-and-simulate-default
   ))

(use-modules (ubu))
(use-modules (tuile utils))
(use-modules (tuile pr))
(use-modules (ubu-lib vlog-gen))



(define (iverilog-get-rtl-files)
  (get-files "rtl/*.*"))

(define (iverilog-get-tb-files)
  (get-files "tb/*.*"))

(define (iverilog-get-test-file test-name)
  (cat "test/" test-name ".v"))


(define* (iverilog-simulate-files tb-name
                                  test-name
                                  #:key
                                  (rtl-files  #f)
                                  (tb-files   #f)
                                  (test-files #f)
                                  (user-files #f))
  (let ((files (append (if rtl-files  rtl-files  (iverilog-get-rtl-files))
                       (if tb-files   tb-files   (iverilog-get-tb-files))
                       (if user-files user-files '())
                       (if test-files test-files (list (iverilog-get-test-file test-name))))))
    (use-dir "sim")
    (in-dir "sim"
            (sh (gap "iverilog" (map (lambda (file) (cat "../" file)) files) "-o" tb-name))
            (sh "vvp" tb-name))
    (pr "Waves in: sim: \"sim/" tb-name ".vcd\"")))


(define (iverilog-simulate-subblock dut-name)
  (let ((ref (vlog-gen-dut-ref-subblock dut-name)))
    (iverilog-simulate-files (ref 'tb-name)
                             (ref 'test-name)
                             #:rtl-files  (ref 'rtl-files)
                             #:tb-files   (ref 'tb-files))))


(define* (iverilog-simulate-default dut-name #:key (user-files '()))
  (let ((ref (vlog-gen-dut-ref-default dut-name #:user-files user-files)))
    (iverilog-simulate-files (ref 'tb-name)
                             (ref 'test-name)
                             #:rtl-files  (ref 'rtl-files)
                             #:tb-files   (ref 'tb-files))))


(define (iverilog-generate-and-simulate-subblock dut-name)
  (vlog-gen-subblock-tb dut-name)
  (iverilog-simulate-subblock dut-name))


(define* (iverilog-generate-and-simulate-default dut-name #:key (user-files '()))
  (vlog-gen-default-tb dut-name)
  (iverilog-simulate-default dut-name #:user-files user-files))
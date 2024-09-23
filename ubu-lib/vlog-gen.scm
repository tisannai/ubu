(define-module (ubu-lib vlog-gen)
  #:export
  (
   vlog-gen-dut-ref-subblock
   vlog-gen-dut-ref-default
   vlog-gen-clock-and-reset-module
   vlog-gen-wave-dump-module
   vlog-gen-subblock-tb
   vlog-gen-default-tb
   vlog-gen-get-file
   ))


(use-modules (ubu core))
(use-modules (tuile utils))
(use-modules (tuile pr))


(define (vlog-gen-get-file dir basename)
  (let ((dut-file-try (cat dir "/" basename ".v")))
    (if (file-exists? dut-file-try)
        dut-file-try
        (cat dir "/" basename ".sv"))))


(define* (vlog-gen-dut-ref dut-name subblock-info #:key (user-files '()) (user-files-tb '()))
  (let* ((base (list (cons 'dut-name         dut-name)
                     (cons 'dut-file         (vlog-gen-get-file "rtl" dut-name))
                     (cons 'tb-name          (cat dut-name "_tb"))
                     (cons 'tb-file          (cat "tb/" dut-name "_tb.v"))
                     (cons 'clkrst-name      (cat dut-name "_clk_rst"))
                     (cons 'clkrst-file      (cat "tb/" dut-name "_clk_rst.v"))
                     (cons 'test-name        (cat dut-name "_tb_test"))
                     (cons 'test-file        (cat "test/" dut-name "_tb_test.v"))
                     (cons 'waves-file       (cat "tb/" dut-name "_tb_waves.v"))
                     (cons 'user-files-tb    user-files-tb)
                     (cons 'user-files       user-files)))
         (ref  (lambda (key) (assoc-ref base key)))
         (sub-files (append (list (ref 'dut-file)
                                  (ref 'clkrst-file)
                                  (ref 'waves-file)
                                  (ref 'test-file))
                            (ref 'user-files-tb)))
         (comp (list (cons 'rtl-files (if subblock-info
                                          (list (ref 'dut-file))
                                          (append (get-files "rtl/*.*v")
                                                  (ref 'user-files))))
                     (cons 'tb-files  (append (list (ref 'clkrst-file)
                                                    (ref 'waves-file)
                                                    (ref 'tb-file))
                                              (ref 'user-files-tb)))
                     (cons 'sub-files sub-files)
                     (cons 'gen-files (list (ref 'clkrst-file)
                                            (ref 'waves-file)
                                            (ref 'tb-file)))
                     (cons 'all-files (append sub-files (list (ref 'tb-file))))))
         (info (append base comp)))
    (lambda (key) (assoc-ref info key))))


(define (vlog-gen-dut-ref-subblock dut-name)
  (vlog-gen-dut-ref dut-name #t))


(define* (vlog-gen-dut-ref-default dut-name #:key (user-files '()) (user-files-tb '()))
  (vlog-gen-dut-ref dut-name #f #:user-files user-files #:user-files-tb user-files-tb))


(define (vlog-gen-write-file file code)
  (let ((out-thunk (lambda ()
                      (display (string-join code "\n"))
                      (newline))))
    (if (string=? "<stdout>" file)
        (with-output-to-port (current-output-port) out-thunk)
        (with-output-to-file file out-thunk))))


;; Generate clock-and-reset module.
;;
;; Spec parameters (in alist):
;;   module: Module name (default: "clk_rst")
;;   clock:  Pair with clock name and period length (default: ("clk" . 10))
;;   reset:  Pair with reset name and number of reset cycles (default: ("rstn" . 4)).
(define* (vlog-gen-clock-and-reset-module clkrst-name spec #:key (file "<stdout>"))
  (let* ((default-spec (list (cons 'module clkrst-name)
                             (cons 'clock  '("clk"  . 10))
                             (cons 'reset  '("rstn" . 4))))
         (merge-spec (assoc-merge default-spec spec))
         (ref (lambda (k) (assoc-ref merge-spec k)))
         (clock-name (car (ref 'clock)))
         (reset-name (car (ref 'reset)))
         (code (list
                (ss "module " (ref 'module))
                (ss "  (")
                (ss "   " clock-name ",")
                (ss "   " reset-name "")
                (ss "   );")
                (ss "")
                (ss "   output " clock-name ";")
                (ss "   output " reset-name ";")
                (ss "")
                (ss "   reg    " clock-name ";")
                (ss "   reg    " reset-name ";")
                (ss "")
                (ss "   initial begin")
                (ss "      " clock-name " = 1;")
                (ss "      forever begin")
                (ss "         " clock-name " = #" (/ (cdr (ref 'clock)) 2) " !" clock-name ";")
                (ss "      end")
                (ss "   end")
                (ss "")
                (ss "   initial begin")
                (ss "      " reset-name " = 0;")
                (ss "      repeat (" (cdr (ref 'reset)) ") @( negedge " clock-name " );")
                (ss "      " reset-name " = 1;")
                (ss "      @( negedge " clock-name " );")
                (ss "   end")
                (ss "")
                (ss "endmodule")))
         )
    (vlog-gen-write-file file code)))


;; Generate waves dump module.
;;
(define* (vlog-gen-wave-dump-module tb-name #:key (file "<stdout>"))
  (let* ((code (list
                (ss "module " tb-name "_waves")
                (ss "  (")
                (ss "   );")
                (ss "")
                (ss "   initial begin")
                (ss "      $dumpfile( \"" tb-name ".vcd\" );")
                (ss "      $dumpvars( 0, tb );")
                (ss "   end")
                (ss "")
                (ss "endmodule"))))
    (vlog-gen-write-file file code)))


;; Generate testcase template.
;;
(define* (vlog-gen-testcase-template tb-name #:key (file "<stdout>"))
  (let* ((code (list
                (ss "module " tb-name "_test")
                (ss "  (")
                (ss "   clk,")
                (ss "   rstn")
                (ss "   );")
                (ss "")
                (ss "   input                clk;")
                (ss "   input                rstn;")
                (ss "")
                (ss "   initial begin")
                (ss "      // Test sequence here")
;;                (ss "      repeat (4) @( negedge clk );")
                (ss "      @( posedge rstn );")
                (ss "      repeat (4) @( negedge clk );")
                (ss "      $finish;")
                (ss "   end")
                (ss "")
                (ss "endmodule"))))
    (vlog-gen-write-file file code)))


(define (vlog-gen-tb ref)

  (use-dir "tb" "test")

  (unless (file-exists? (ref 'clkrst-file))
    (vlog-gen-clock-and-reset-module (ref 'clkrst-name) '() #:file (ref 'clkrst-file)))

  (unless (file-exists? (ref 'waves-file))
    (vlog-gen-wave-dump-module (ref 'tb-name) #:file (ref 'waves-file)))

  (unless (file-exists? (ref 'test-file))
    (vlog-gen-testcase-template (ref 'tb-name) #:file (ref 'test-file)))

  (unless (file-exists? (ref 'tb-file))
    (sh (gap "vehi"
             (map (lambda (file) (cat "-m " file)) (ref 'sub-files))
             ;; Select default or specific hier (vehi).
             (let ((vehi (cat "tb/" (ref 'tb-name) ".vehi.scm")))
               (if (file-exists? vehi)
                   (cat "-s -i " vehi)
                   "-s -a tb"))
             "-b -o"
             (ref 'tb-file)))))


(define (vlog-gen-subblock-tb dut-name)
  (vlog-gen-tb (vlog-gen-dut-ref-subblock dut-name)))


(define* (vlog-gen-default-tb dut-name #:key (user-files '()) (user-files-tb '()))
  (vlog-gen-tb (vlog-gen-dut-ref-default dut-name #:user-files user-files #:user-files-tb user-files-tb)))

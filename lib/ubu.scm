;; TODO:
;;
;; + time based update
;; + command settings
;; + all actions with clean defs
;; + parallel execution
;; + action listing
;; + module partioning
;; + logging to files
;; - stream direction
;; - flag for del call optimization


(define-module (ubu)

  :use-module (srfi srfi-8)
  ;; Needed for macro to refer the "receive" macro from srfi-8.
  :autoload (srfi srfi-8) (receive)

  #:export (ubu-version
            ubu-version-num
            ubu-exit
            ubu-fatal
            ubu-error
            ubu-warn
            ubu-info
            ubu-var
            ubu-act-list
            ubu-actions
            ubu-variables
            ubu-cli-map
            ubu-hello
            ubu-run
            ubu-run-cli
            ubu-load
            ubu-module
            ubu-file-cache
            ubu-reg-act
            ubu-default
            ubu-pre-run
            ubu-post-run

            action
            action-default
            action-help
            ref
            del
            eva
            for
            times
            pair
            env
            sh
            sh-set
            sh-par
            sh-ser
            set
            get
            add
            cat
            glu
            gap
            cli
            pcs
            get-files
            map-files
            cmd
            dir
            in-dir
            cli-map
            ubu-update?
            ubu-to-update
            ubu-for-updates
            log
            lognl
            with-log
            with-output

            str
            prn
            prnl
            dbg
            errprn
            errprnl
            true
            false
            first
            second
            third
            last
            nth
            empty
            empty?
            regexp-split

            )

  #:re-export (receive)

  )

(use-modules (ice-9 rdelim))
(use-modules (ice-9 popen))
(use-modules (ice-9 regex))
(use-modules (ice-9 ftw))
(use-modules (srfi srfi-1))
(use-modules (srfi srfi-9))
(use-modules (ice-9 threads))
(use-modules (system repl repl))
(use-modules (ice-9 textual-ports))
;; Guile-3.0 does not like this. Removing for now...
;; (use-modules (ice-9 r5rs))
(use-modules (ice-9 eval-string))


(define ubu-version-num '(0 1))
(define ubu-version (glu "." (map number->string ubu-version-num)))


;; ------------------------------------------------------------
;; Utils:


;; Load ubu-library file either from a path-list (colon separated
;; list) or directly from a filename.
;;
;; Examples:
;;
;;     (ubu-load (env "UBU_USER_LIB_PATH")
;;               "ubu-utils.scm")
;;
;;     (ubu-load "/path/ubu-lib/ubu-utils.scm")
;;
;;     (ubu-load "ubu-lib/ubu-utils.scm")
;;
(define (ubu-load file-or-path . rest)

  (if (not (pair? rest))

      ;; Single library file reference.
      (if (file-exists? file-or-path)
          (primitive-load file-or-path)
          (ubu-fatal "Load library missing: " file-or-path))

      ;; Path based library reference.
      (if (string? file-or-path)
          (let ((dirs (regexp-split ":" file-or-path))
                (filename (car rest)))
            (if (let loop ((tail dirs))
                  (if (pair? tail)
                      (if (member filename (list-dir (car tail)) string=?)
                          (primitive-load (string-append (car tail) "/" filename))
                          (loop (cdr tail)))
                      #f))
                #t
                (ubu-fatal "Can't find: \"" filename "\" from: \"" file-or-path "\" ...")))

          (ubu-fatal "Invalid load path ..."))))


;; Use module from path.
;;
;; Example:
;;
;;     (ubu-module "ubu-lib" gcc-utils)
;;
(define-syntax ubu-module
  (syntax-rules ()
    ((ubu-module modpath modname)
     (begin
       (add-to-load-path modpath)
       (use-modules (modname))))))


;; Load values from file if it exists.
;;
;; Example:
;;
;;     (define-values (python_package_dir
;;                     python_include)
;;       (ubu-file-cache ".ubu-cocotb-config"
;;                       (list
;;                        (lambda () (cmd "cocotb-config --prefix"))
;;                        (lambda () (cmd "python3-config --includes")))))
;;
(define (ubu-file-cache filename thunks)
  (if (file-exists? filename)
      (apply values (drop-right
                     (string-split
                      (with-input-from-file filename (lambda () (get-string-all (current-input-port))))
                      #\newline)
                     1))
      (let ((vals (map (lambda (thunk)
                         (thunk))
                       thunks)))
        ;; Write values to file.
        (with-output-to-file
            filename
          (lambda ()
            (for-each (lambda (val)
                        (display val (current-output-port))
                        (newline (current-output-port)))
                      vals)))
        (apply values vals))))


;; List all directory entries, except dot files.
(define (list-dir dir)
  (unless (file-exists? dir)
    (ubu-fatal "Directory missing: " dir))
  (let ((dh (opendir dir)))
    (let loop ((dh dh))
      (let ((entry (readdir dh)))
        (if (eof-object? entry)
            '()
            (cond
             ((or (string=? "."  entry)
                  (string=? ".." entry))
              (loop dh))
             (else
              (cons entry (loop dh)))))))))


;; Return last in list.
(define (last lst)
  (car (last-pair lst)))


;; Return nth in list.
(define (nth lst n)
  (list-ref lst n))


;; Create list of pairs from list.
(define (pair lst)
  (if (pair? lst)
      (cons (list (car lst) (if (pair? (cdr lst)) (cadr lst) '()))
            (pair (cddr lst)))
      '()))


;; Full args flattening.
(define flat-args
  (lambda args
    (if (pair? args)
        (cond
         ((list? (car args))
          (append (car args) (apply flat-args (cdr args))))
         ((empty? (car args))
          (apply flat-args (cdr args)))
         ((null? (car args))
          (apply flat-args (cdr args)))
         ((not (car args))
          (apply flat-args (cdr args)))
         (else
          (cons (car args) (apply flat-args (cdr args)))))
        empty)))


;; One level args flattening.
(define flat-args-1
  (lambda args
    (let once ((tail (car args)))
      (if (pair? tail)
          (cond
           ((list? (car tail))
            (append (car tail) (once (cdr tail))))
           ((empty? (car tail))
            (once (cdr tail)))
           ((null? (car tail))
            (once (cdr tail)))
           ((not (car tail))
            (once (cdr tail)))
           (else
            (cons (car tail) (once (cdr tail)))))
          empty))))



;; Collect matching fields.
(define (regexp-collect re str)
  (map match:substring (list-matches re str)))


;; Split string with regexp.
;;
;; Examples:
;;     guile> (regexp-split "[-x]+" "foo--x--bar---what--")
;;     ("foo" "bar" "what" "")
;;     guile> (regexp-split "[-x]+" "foo--x--bar---what--"  'trim)
;;     ("foo" "bar" "what")
;;     guile> (regexp-split "[-x]+" "foo--x--bar---what"  'keep)
;;     ("foo" "--x--" "bar" "---" "what")
;;
(define (regexp-split regexp str . options)
  (let ((keep #f) (trim #f))
    (when (member 'keep options)
      (set! options (delete 'keep options))
      (set! keep #t))
    (when (member 'trim options)
      (set! options (delete 'trim options))
      (set! trim #t))
    (let* ((matches (apply list-matches regexp str options))
           (indices
            (append '(0)
                    (fold-right
                     (lambda (m acc)
                       (cons (match:start m)
                             (cons (match:end m) acc))) '()
                             matches)
                    (list (string-length str))))
           (substrings
            (pair-fold-right
             (lambda (lst accum)
               (if (or (even? (length lst))
                       (and keep (> (length lst) 1)))
                   (cons (apply substring str (take lst 2)) accum)
                   accum))
             '()
             indices)))
      (if trim
          (reverse! (drop-while
                     string-null?
                     (reverse! (drop-while string-null? substrings))))
          substrings))))


;; Exit ubu cleanly.
(define (ubu-exit . args)
  (let ((code
         (if (pair? args) (car args) 0)))
    (ubu-shutdown)
    ;; (when (not (= code 0))
    ;; (errprnl "Exiting UBU with error(s) ..."))
    (exit code)))
  ;;#t))

;; Fatal error.
(define ubu-fatal
  (lambda args
    (apply errprnl (cons "ubu FATAL: " args))
    (ubu-exit 1)))


;; Normal error.
(define ubu-error
  (lambda args
    (apply errprnl (cons "ubu ERROR: " args))))

;; Warning.
(define ubu-warn
  (lambda args
    (apply errprnl (cons "ubu WARNING: " args))))


;; Display info, i.e. list of lines.
(define ubu-info
  (lambda lines
    (for-each prnl lines)))


;; Command line arugments excluding executable.
(define (current-command-line-arguments)
  (cdr (command-line)))


;; ------------------------------------------------------------
;; Shell commands:

;; Execute shell command and return responses as list.
;;
;; Responses: status-code stdout stderr
(define (capture-shell-command cmd)
  (let* ((stdout #f)
         (stderr #f)
         (status #f))
    (define (command cmd)
      (let ((fh (open-input-pipe cmd)))
        (set! stdout (get-string-all fh))
        (set! status (close-pipe fh))))
    (let ((err-pipe (pipe)))
      (with-error-to-port (cdr err-pipe)
        (lambda ()
          (command cmd)))
      (close-port (cdr err-pipe))
      (set! stderr (get-string-all (car err-pipe))))
    (list (status:exit-val status) stdout stderr)))


;; Execute shell command and display output.
(define (output-shell-command cmd)
  (lognl 'command "* ubu-execute:" cmd)
  (let ((ret (capture-shell-command cmd)))
    (log 'output (second ret))
    (if (= 0 (first ret))
        (when (> (string-length (third ret)) 0)
          ;; Warning only.
          (log 'warning (third ret)))
        (log 'error (third ret)))
    (first ret)))


;; Execute shell command.
(define (sh cmd . rest)
  (let ((cmdstr (apply gap (cons cmd rest))))
    (let ((status (output-shell-command cmdstr)))
      (if (and
           (get ":abort-on-error")
           (not (= status 0)))
          (ubu-exit status)
          0))))


;; Execute shell commands in series or in parallel.
(define (sh-set cmd . rest)
  (if (get ":parallel")
      (apply sh-par (cons cmd rest))
      (apply sh-ser (cons cmd rest))))


;; Run shell commands in parallel.
;;(define (sh-par cmd . rest) #f)
(define (sh-par cmd . rest)
  (let ((lst (flat-args-1 (cons cmd rest))))
    (let ((ths (map (lambda (cmd)
                      (call-with-new-thread
                       (lambda ()
                         (sh cmd))))
                    lst)))
      (for-each join-thread ths))))


;; Run shell commands in series.
(define (sh-ser cmd . rest)
  (let ((lst (flat-args-1 (cons cmd rest))))
    (for-each sh lst)))


;; ------------------------------------------------------------
;; File collections:

;; Flat list to list of pairs.
(define (list->pair-list lst)
  (let loop ((tail lst))
    (if (pair? tail)
        (cons (cons (car tail) (cadr tail)) (loop (cddr tail)))
        empty)))


;; Replace directory.
(define (retarget-dir name new-dir)
  (let* ((fname (basename name)))
    (string-append new-dir "/" fname)))


;; Replace file extension.
(define (retarget-ext name new-ext)
  (define (filename name)
    (car (map match:substring (list-matches "[^.]+" name))))
  (string-append (filename name) new-ext))


;; Map files with new directories and extensions.
;;
;; Example:
;;
;;     (map-files
;;      (get "gcc-compile:hello-source-files")
;;      'dir (get "hello-target-dir")
;;      'ext ".o"))
;;
(define (map-files files . maps)
  (reverse
   (let file-loop ((files (if (list? files) files (list files))))
     (if (pair? files)
         (cons
          (let map-loop ((tmp (car files))
                         (tail (list->pair-list maps)))
            (if (pair? tail)
                (cond
                 ((eq? 'dir (caar tail))
                  (map-loop (retarget-dir tmp (cdar tail)) (cdr tail)))
                 ((eq? 'ext (caar tail))
                  (map-loop (retarget-ext tmp (cdar tail)) (cdr tail)))
                 (else
                  (map-loop tmp (cdr tail))))
                tmp))
          (file-loop (cdr files)))
         empty))))


;; Collect files based on given glob pattern.
;;
;;    (get-files "./src/*.c")
;;
(define (get-files glob-pat)
  (let* ((pcs (string-split glob-pat #\/))
         (dir-pcs (list-head pcs (- (length pcs) 1)))
         (pat (last pcs))
         (dir (cond
               ((= 0 (length dir-pcs))
                ".")
               (else
                (string-join dir-pcs "/")))))
    (map (lambda (file)
           (string-append dir "/" file))
         (glob-dir dir pat))))


;; Run shell command as support command.
(define (cmd shell-command)
  (let ((ret (capture-shell-command shell-command)))
    (if (= (car ret) 0)
        (string-trim-right (second ret) #\newline)
        (ubu-fatal "Failing command: " shell-command))))


;; Ensure that dir is present.
(define (dir ensure-dir . rest)
  (let ((dirs (if (pair? rest) (cons ensure-dir rest) (list ensure-dir))))
    (for-each (lambda (dir)
                (unless (file-exists? dir)
                  (cmd (string-append "mkdir -p " dir))))
              dirs)))


;; Execute in the selected directory and return back to original after
;; execution.
(define-syntax in-dir
  (syntax-rules ()
    ((_ dir code ...)
     (let ((cur-dir (getcwd)))
       (chdir dir)
       code ...
       (chdir cur-dir)))))



;; ------------------------------------------------------------
;; Update conditions:

;; Modification timestamp.
(define (file-or-directory-modify-seconds file)
  (stat:mtime (stat file)))


;; Is a newer files than b, or is b not existing.
(define (newer? a b)
  (unless (file-exists? a)
    (ubu-fatal "Source file does not exist: " a))
  (if (not (file-exists? b))
      #t
      (if (> (file-or-directory-modify-seconds a)
             (file-or-directory-modify-seconds b))
          #t
          #f)))


;; Check if update is needed, i.e. sources are newer than targets.
(define (ubu-update? sources targets)
  (cond

   ((and (list? sources)
         (list? targets))
    (let loop ((s sources)
               (t targets))
      (if (and (pair? s)
               (pair? t))
          (if (newer? (car s) (car t))
              #t
              (loop (cdr s) (cdr t)))
          #f)))

    ((list? targets)
     (newer? sources (car targets)))

    ((list? sources)
     (let loop ((s sources))
       (if (pair? s)
           (if (newer? (car s) targets)
               #t
               (loop (cdr s)))
           #f)))

    (else
     (newer? sources targets))))


;; Reduce the sources and targets to lists that require
;; updating.
;;
;; Return with "values" the updatable: sources, targets.
;;
(define (ubu-to-update sources targets)

  (cond

   ((and (list? sources)
         (list? targets))
    (let loop ((s sources)
               (t targets)
               (up-s '())
               (up-t '()))
      (if (and (pair? s)
               (pair? t))
          (if (newer? (car s) (car t))
              (loop (cdr s) (cdr t) (cons (car s) up-s) (cons (car t) up-t))
              (loop (cdr s) (cdr t) up-s up-t))
          (values up-s up-t))))

   ((list? targets)
    (if (newer? sources (car targets))
        (values sources targets)
        (values #f '())))

   ((list? sources)
    (let loop ((s sources))
      (if (pair? s)
          (if (newer? (car s) targets)
              (values sources targets)
              (loop (cdr s)))
          (values '() #f))))

   (else
    (if (newer? sources targets)
        (values sources targets)
        (values #f #f)))))


;; Call proc for sources and targets that actually require updates.
;;
;; If no files require updates, nothing is done.
;;
;; Example:
;;
;;     (ubu-for-updates c-files o-files
;;                      (lambda (up-c up-o)
;;                        (sh-set
;;                         (map (lambda (c o)
;;                                (gap
;;                                 "gcc -Wall"
;;                                 (if (get "gcc-opt") "-O2" "-g")
;;                                 "-c" c
;;                                 "-o" o))
;;                              up-c
;;                              up-o))))
;;
(define-syntax ubu-for-updates
  (syntax-rules ()
    ((_ sources targets proc)
     (receive (s t)
         (ubu-to-update sources targets)
       (when (and (or (and (list? s) (pair? s)) s)
                  (or (and (list? t) (pair? t)) t))
         (proc s t))))))



;; ------------------------------------------------------------
;; Logging:


;; Hide log-port into a closure.
(define log-port-open #f)
(define log-port-close #f)
(define log-text #f)

(let ((log-port #f))

  (set! log-port-open
    (lambda (portname)
      (cond
       ((string=? portname "<stdout>")
        (set! log-port (current-output-port)))
       (else
        (set! log-port (open-output-file portname))))))

  (set! log-port-close
    (lambda ()
      (when (and (not log-port)
                 (not (equal? log-port (current-output-port))))
        (close-port log-port)
        (set! log-port #f))))

  (set! log-text
    (lambda (txt)
      (display txt log-port))))


;; Logging levels:
;;  0 Quiet
;;  1 Error
;;  2 Warning
;;  3 Command
;;  4 Output
(define (log-to-level level)

  (define (symbol-to-level level)
    (case level
      ((error)   1)
      ((warning) 2)
      ((command) 3)
      ((output)  4)
      (else (ubu-fatal "Log symbol error: " level " ..."))))

  (let ((lvl (cond
              ((symbol? level)
               (symbol-to-level level))
              ((string? level)
               (symbol-to-level (string->symbol level)))
              (else
               level))))
    (if (and (>= lvl 1)
             (<= lvl 4 ))
        lvl
        (ubu-fatal "Log level out of range: " lvl " ..."))))

;; Log messages.
(define (log level  . rest)
  (when ubu-log-out
    (when (<= (log-to-level level)
              (car ubu-log-level))
      (log-text (string-join rest " ")))))

;; Log messages with newline.
(define (lognl level . rest)
  (apply log (append (cons level rest) (list "\n"))))


;; Run code with set logging-level.
(define-syntax with-log
  (syntax-rules ()
    ((_ level code ...)
     (begin
       (ubu-push-log-level (log-to-level level))
       code ...
       (ubu-pop-log-level)))))


;; Run code with output logging-level.
(define-syntax with-output
  (syntax-rules ()
    ((_ code ...)
     (begin
       (ubu-push-log-level (log-to-level 'output))
       code ...
       (ubu-pop-log-level)))))


;; ------------------------------------------------------------
;; Print collections:

;; Arguments to string.
(define str
  (lambda args
    (apply string-append
           (map (lambda (obj)
                  (if (string? obj)
                      obj
                      (object->string obj)))
                args))))


;; Print arguments.
(define prn
  (lambda args
    (display (apply str args))))

;; Print arguments with newline.
(define prnl
  (lambda args
    (display (apply str args))
    (newline)))

;; Debug print arguments.
(define dbg
  (lambda args
    (display (apply str args))
    (newline)))

;; Error print arguments.
(define errprn
  (lambda args
    (display (apply str args) (current-error-port))))

;; Error print arguments with newline.
(define errprnl
  (lambda args
    (display (apply str args) (current-error-port))
    (newline (current-error-port))))


;; Glob pattern to regexp.
(define (glob->regexp pat)
  (let ((len (string-length pat)))
    (string-concatenate
     (append
      (list "^")
      (let loop ((i 0))
        (if (< i len)
            (let ((char (string-ref pat i)))
              (case char
                ((#\*) (cons "[^.]*" (loop (1+ i))))
                ((#\?) (cons "[^.]" (loop (1+ i))))
                ((#\[) (cons "[" (loop (1+ i))))
                ((#\]) (cons "]" (loop (1+ i))))
                ((#\\)
                 (cons (list->string (list char (string-ref pat (1+ i))))
                       (loop (+ i 2))))
                (else
                 (cons (regexp-quote (make-string 1 char))
                       (loop (1+ i))))))
            '()))
      (list "$")))))


;; Glob directory.
(define (glob-dir dir pat)
  (let ((rx (make-regexp (glob->regexp pat))))
    (filter (lambda (x) (regexp-exec rx x)) (list-dir dir))))


;; Hash table has key?
(define (hash-has-key? hsh key)
  (hash-get-handle hsh key))

;; Return list of hash table keys.
(define (hash-keys hsh)
  (hash-map->list (lambda (k v) k) hsh))



;; ------------------------------------------------------------
;; Usability:

(define true  #t)
(define false #f)
(define first car)
(define second cadr)
(define third caddr)
(define empty '())
(define empty? null?)


;; ------------------------------------------------------------
;; Lookup for ordered lookups.

;; Lookup record.
;;
;; Hash table and list of items in order.
(define-record-type <lookup>
  (new-lookup lst hsh)
  lookup?
  (lst     lookup-lst set-lookup-lst!)
  (hsh     lookup-hsh))


;; Make lookup.
(define (make-lookup)
  (new-lookup empty (make-hash-table)))


;; Set value in lookup.
(define (lookup-set! lup key val)
  (unless (hash-has-key? (lookup-hsh lup) key)
    (set-lookup-lst! lup (cons key (lookup-lst lup))))
  (hash-set! (lookup-hsh lup) key val))


;; Reference value in lookup.
(define (lookup-ref lup key)
  (if (hash-has-key? (lookup-hsh lup) key)
      (hash-ref (lookup-hsh lup) key)
      #f))


;; Run proc for each lookup entry.
(define (lookup-each lup proc)
  (for-each proc (reverse (lookup-lst lup))))


;; Return list of lookup keys.
(define (lookup-keys lup)
  (reverse (lookup-lst lup)))



;; ------------------------------------------------------------
;; UBU:

(define ubu-var (make-hash-table))
(define ubu-act (make-lookup))
(define ubu-cli-map-def #f)
(define ubu-default-action #f)
(define ubu-pre-action #f)
(define ubu-post-action #f)
(define ubu-log-out #f)
(define ubu-log-level '())


;; Push log-level to log-level stack.
(define (ubu-push-log-level lvl)
  (set! ubu-log-level (cons lvl ubu-log-level)))

;; Pop log-level from log-level stack.
(define (ubu-pop-log-level)
  (set! ubu-log-level (cdr ubu-log-level)))


;; Return list of ubu actions.
(define (ubu-act-list)
  (lookup-keys ubu-act))


;; Register procedure.
;;
;; Tag can be: symbol, procedure or string.
(define (ubu-reg-act tag)
  (let ((name (cond
               ((string? tag)
                tag)
               ((procedure? tag)
                (procedure-name tag))
               ((symbol? tag)
                (symbol->string tag)))))
    (lookup-set! ubu-act name name)))


;; Set ubu default action.
(define (ubu-default act)
  (set! ubu-default-action act))

;; Add pre-run actions.
(define (ubu-pre-run single-or-list)
  (unless ubu-pre-action
    (set! ubu-pre-action '()))
  (cond
   ((list? single-or-list)
    (set! ubu-pre-action (append ubu-pre-action single-or-list)))
   (else
    (set! ubu-pre-action (append ubu-pre-action (list single-or-list))))))


;; Add post-run actions.
(define (ubu-post-run single-or-list)
  (unless ubu-post-action
    (set! ubu-post-action '()))
  (cond
   ((list? single-or-list)
    (set! ubu-post-action (append ubu-post-action single-or-list)))
   (else
    (set! ubu-post-action (append ubu-post-action (list single-or-list))))))


;; Create value (delayed) reference.
(define-syntax ref
  (syntax-rules ()
    ((ref var)
     (lambda () (get var)))))


;; Delay evaluation.
(define-syntax del
  (syntax-rules ()
    ((del code)
     (lambda () code))))


;; Evaluate:
;;     ((eva '+) 1 2)
(define-syntax eva
  (syntax-rules ()
    ((eva code)
     (eval code (interaction-environment)))))


;; Define action.
;;
;; Example:
;;
;;     (action compile
;;             (gcc-compiles-files
;;              (get "gcc-compile:hello-source-files")
;;              (get "gcc-compile:hello-target-files")))
;;
(define-syntax action
  (syntax-rules ()
    ((action fn-name code ...)
     (begin
       (define fn-name
         (lambda ()
           code ...))
       (ubu-reg-act 'fn-name)))))


;; Define default action.
(define-syntax action-default
  (lambda (x)
    (syntax-case x ()
      ((k code ...)
       #`(begin
           ;; Create symbol "default" on-the-fly.
           (define #,(datum->syntax #'k 'default)
             (lambda ()
               code ...))
           (ubu-reg-act "default")
           (ubu-default "default"))))))


;; Define help action.
(define-syntax action-help
  (lambda (x)
    (syntax-case x ()
      ((k line ...)
       #`(begin
           ;; Create symbol "help" on-the-fly.
           (define #,(datum->syntax #'k 'help)
             (lambda ()
               (ubu-info line ...)))
           (ubu-reg-act "help"))))))


;; For loop for list.
;;
;; Example:
;;
;;     (for (i lst) (prnl i))
;;
(define-syntax for
  (syntax-rules ()
    ((for (var lst) code ...)
     (for-each (lambda (var)
                 code ...)
               lst))))


;; Repeat body n times.
;;
;; Example:
;;
;;     (times (i 10)
;;            (prnl "number: " i))
;;
(define-syntax times
  (lambda (x)
    (syntax-case x ()
      ((_ (var limit) code ...)
       #'(let loop ((var 0))
           (when (< var limit)
             code ...
             (loop (1+ var))))))))


;; Include a file.
;;
;;     (ubu-include "filename")
(define-syntax ubu-include
  (lambda (x)
    (define read-file
      (lambda (fn k)
        (let ([p (open-input-file fn)])
          (let f ([x (read p)])
            (if (eof-object? x)
                (begin (close-port p) '())
                (cons (datum->syntax k x) (f (read p))))))))
    (syntax-case x ()
      [(k filename)
       (let ([fn (syntax->datum #'filename)])
         (with-syntax ([(expr ...) (read-file fn #'k)])
           #'(begin expr ...)))])))


(define-syntax aif
  (lambda (x)
    (syntax-case x ()
      ((_ test then else)
       ;; Invoking syntax-case on the generated syntax object to
       ;; expose it to "syntax".
       (syntax-case (datum->syntax x 'it) ()
         (it
           #'(let ((it test))
               (if it then else))))))))

;; Alias to getenv.
(define env getenv)


;; Set conf value.
(define (set key val . rest)
  (if (pair? rest)
      (for-each (lambda (i)
                  (set (car i) (cadr i)))
                (append (list key val) rest))
      (hash-set! ubu-var key val)))


;; Get conf value.
(define (get key . rest)
  (if (pair? rest)
      (map (lambda (i)
             (get i))
           (cons key rest))
      (hash-ref ubu-var key)))


;; Add to conf value (list type value).
(define (add key val . rest)
  (if (pair? rest)
      (for-each (lambda (i)
                  (add key i))
                (cons val rest))
      (let ((has (hash-has-key? ubu-var key)))
        (if has
            (hash-set! ubu-var key
                       (append (hash-ref ubu-var key) (list val)))
            (hash-set! ubu-var key (list val))))))


;; Concatenate without spacing.
(define cat
  (lambda args
    (string-concatenate (flat-args-1 args))))


;; Concatenate with given separator.
(define (glu sep . rest)
  (string-join (flat-args-1 rest) sep))


;; Concatenate with space.
(define (gap . rest)
  (string-join (flat-args-1 rest) " "))


;; Add option to each argument.
(define (cli opt . rest)
  (let ((args (flat-args-1 rest)))
    (string-join
     (map (lambda (i)
            (string-append opt " " i))
          args)
     " ")))


;; Split string into pieces (separated by space).
(define (pcs str)
  (regexp-split "[ ]+" str))



;; ------------------------------------------------------------
;; CLI:

;; Command line allows to specify switches (false->true), set
;; parameter values (foo=bar), and list actions (clean build).
;;
;; Example:
;;
;;     (cli-map
;;      '(opt
;;        (p :parallel)
;;        (q :quiet))
;;
;;      '(par
;;        (ll :log-level))
;;
;;      '(act
;;        (c  gcc-compile)
;;        (l  gcc-link)
;;        (b  gcc-build)))


;; Storage struct for CLI definitions.
(define-record-type <cli-def>
  (make-cli-def opt par act)
  cli-def?
  (opt     cli-def-opt)
  (par     cli-def-par)
  (act     cli-def-act))


;; Storage for CLI definitions.
(define ubu-cli-maps
  (make-cli-def
   (make-hash-table)
   (make-hash-table)
   (make-hash-table)))


;; Select map from CLI definitions.
(define (ubu-cli-map-sel scope)
  (cond
   ((eq? 'opt scope)
    (cli-def-opt ubu-cli-maps))
   ((eq? 'par scope)
    (cli-def-par ubu-cli-maps))
   ((eq? 'act scope)
    (cli-def-act ubu-cli-maps))))


;; Add entry to selected map.
(define (ubu-cli-map-add scope key val)
  (let ((h (ubu-cli-map-sel scope)))
    (hash-set! h key val)))


;; Refer entry from selected map.
(define (ubu-cli-map-ref scope key)
  (let ((h (ubu-cli-map-sel scope)))
    (let ((sym-key (if (string? key) (string->symbol key) key)))
      (if (hash-has-key? h sym-key)
          (symbol->string (hash-ref h sym-key))
          (symbol->string sym-key)))))


;; Apply user defined mapping to CLI definition storage
;; (ubu-cli-maps).
(define cli-map
  (lambda args
    (set! ubu-cli-map-def args)
    (for-each (lambda (i)
                (for-each (lambda (m)
                            (ubu-cli-map-add (car i) (first m) (second m)))
                          (cdr i)))
              args)))


;; Parse cli (from user).
(define (ubu-parse-cli)
  (let ((cli (make-cli-def empty empty empty))
        (act-list empty))

    (for-each (lambda (i)
                (cond

                 ;; Switch (e.g. "-v").
                 ((eq? #\- (string-ref i 0))
                  (set (ubu-cli-map-ref 'opt (substring i 1 2)) true))

                 ;; Parameter setting (e.g. "foo=bar").
                 ((string-match "=" i)
                  (let* ((pcs (regexp-split "=" i))
                         (var (ubu-cli-map-ref 'par (car pcs)))
                         (raw (cadr pcs))
                         (val (cond

                               ;; Space separated list value.
                               ((> (length (regexp-split " " raw)) 1)
                                (regexp-split " " raw))

                               ;; Number strings to number.
                               ((string->number raw)
                                (string->number raw))

                               ;; Truth values.
                               ((string-match "true|false" raw)
                                (if (equal? "true" raw) #t #f))

                               ;; Literal.
                               (else
                                raw))))

                    (set var val)))

                 ;; Action.
                 (else
                  ;; Store command and trails.
                  (set! act-list (cons (ubu-cli-map-ref 'act i) act-list)))))

              (current-command-line-arguments))

    ;; Return list of collected actions.
    (reverse act-list)))


;; Shutdown sequence.
(define (ubu-shutdown)
  (log-port-close))


;; Run list of actions.
(define (ubu-run lst)

  ;; Resolve some of the settings for better performance.
  (log-port-open (get ":log-file"))
  (set! ubu-log-out (not (get ":quiet")))
  (set! ubu-log-level (list (log-to-level (get ":log-level"))))

  (if (empty? lst)
      (if (not ubu-default-action)
          (ubu-warn "No actions given ...")
          (set! lst (list ubu-default-action))))

  (when ubu-pre-action
    (set! lst (append ubu-pre-action lst)))

  (when ubu-post-action
    (set! lst (append lst ubu-post-action)))

  (for-each (lambda (i)
              (if (lookup-ref ubu-act i)
                  (eval-string (string-append "(" i ")"))
                  (ubu-fatal "Unknown command: " i)))
            lst)

  (ubu-shutdown))


;; Parse cli and run actions.
(define (ubu-run-cli)
  (ubu-run (ubu-parse-cli)))


;; Display registered actions.
(action ubu-actions
        (for (act (lookup-keys ubu-act))
          (prnl "  " act)))


;; Display variables.
(action ubu-variables
        (let ((keys (hash-keys ubu-var)))
          (map (lambda (key)
                 (format #t "  ~30a ~a\n" key (hash-ref ubu-var key)))
               (sort keys string<))))


;; Display cli-map.
(action ubu-cli-map
        (if ubu-cli-map-def
            (begin
              (for-each (lambda (def)
                          (format #t "\n  ~a\n"
                                  (case (car def)
                                    ((opt) "Options:")
                                    ((par) "Parameters:")
                                    ((act) "Action aliases:")))
                          (for-each (lambda (pair)
                                      (format #t "    ~8a ~a\n" (first pair) (second pair)))
                                    (cdr def)))
                        ubu-cli-map-def)
              (format #t "\n"))
            (ubu-warn "No cli-map defined ...")))

(action ubu-hello
        (prnl "hello"))


;; ------------------------------------------------------------
;; UBU default settings:

(set ":quiet" false)
(set ":parallel" false)
(set ":log-file" "<stdout>")
(set ":log-level" "command")
(set ":abort-on-error" true)

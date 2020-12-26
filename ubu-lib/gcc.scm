(define-module (ubu-lib gcc)
  #:export (
            gcc-basic-compile-files
            gcc-basic-compile-exe
            gcc-basic-link-files
            gcc-compile-files
            gcc-compile-exe
            gcc-link-files
            ))

(use-modules (ubu))


;; Compile c-files to o-files (object-files).
;;
;; Files are compiled with "-Wall" option. See below for
;; control options.
;;
;; Arguments:
;;     c-files: One/many c-files.
;;     o-files: One/many o-files.
;;
;; Variables:
;;     gcc-optimize: True if "-O2" needed, else "-g".
;;
;; Example: (gcc-basic-compile-files (list "foo.c" "bar.c")
;;                                   (list "foo.o" "bar.o"))
;;
(define (gcc-basic-compile-files c-files o-files)
  ;; Filter file pairs that actually need updates.
  (sh-set (ubu-for-updates c-files
                           o-files
                           (lambda (c o)
                             (gap
                              "gcc -Wall"
                              (if (get "gcc-optimize") "-O2" "-g")
                              "-c" c
                              "-o" o)))))


;; Compile c-files directly to executable.
;;
;; Files are compiled with "-Wall" option. See below for
;; control options.
;;
;; Arguments:
;;     c-files:  One/many c-files.
;;     exe-file: Executable.
;;
;; Variables:
;;     gcc-optimize: True if "-O2" needed, else "-g".
;;     gcc-libs:     List of required libraries for executable (as given for "-l" option).
;;
;; Example: (gcc-basic-compile-exe (list "foo.c" "bar.c")
;;                                 "foobar")
;;
(define (gcc-basic-compile-exe c-files exe-file)
  (when (ubu-update? c-files exe-file)
    (sh "gcc"
        (gap
         "-Wall"
         (if (get "gcc-optimize") "-O2" "-g"))
        "-o"
        exe-file
        c-files
        (map (lambda (lib)
               (cat "-l" lib))
             (get "gcc-libs")))))


;; Link object-files to executable.
;;
;; Object files are linked with given libraries.
;;
;; Arguments:
;;     o-files:  One/many o-files.
;;     exe-file: Executable.
;;
;; Variables:
;;     gcc-libs:      List of required libraries for executable (as given for "-l" option).
;;
;; Example: (gcc-basic-link-exe (list "foo.o" "bar.o")
;;                              "foobar")
;;
(define (gcc-basic-link-files o-files exe-file)
  (when (ubu-update? o-files exe-file)
    (sh "gcc"
        "-o"
        exe-file
        o-files
        (map (lambda (lib)
               (cat "-l" lib))
             (get "gcc-libs")))))


;; Compile c-files to o-files (object-files).
;;
;; Files are compiled with given options either serially or in
;; parallel (":parallel" option). See below for control options.
;;
;; Arguments:
;;     c-files: One/many c-files.
;;     o-files: One/many o-files.
;;
;; Variables:
;;     gcc-comp-opts: GCC compilation options.
;;
;; Example: (gcc-compile-files (list "foo.c" "bar.c")
;;                             (list "foo.o" "bar.o"))
;;
(define (gcc-compile-files c-files o-files)
  ;; Filter file pairs that actually need updates.
  (sh-set (ubu-for-updates c-files
                           o-files
                           (lambda (c o)
                             (gap
                              "gcc"
                              (get "gcc-comp-opts")
                              "-c" c
                              "-o" o)))))


;; Compile c-files directly to executable.
;;
;; Files are compiled with given options. See below for control
;; options.
;;
;; Arguments:
;;     c-files:  One/many c-files.
;;     exe-file: Executable.
;;
;; Variables:
;;     gcc-comp-opts: GCC compilation options.
;;     gcc-link-opts: GCC linker options.
;;
;; Example: (gcc-compile-exe (list "foo.c" "bar.c")
;;                           "foobar")
;;
(define (gcc-compile-exe c-files exe-file)
  (when (ubu-update? c-files exe-file)
    (sh "gcc"
        (gap
         (get "gcc-comp-opts")
         "-o"
         exe-file
         c-files
         (get "gcc-link-opts")))))


;; Link object-files to executable.
;;
;; Object files are linked with given libraries.
;;
;; Arguments:
;;     o-files:  One/many o-files.
;;     exe-file: Executable.
;;
;; Variables:
;;     gcc-link-opts: GCC linker options.
;;
;; Example: (gcc-link-exe (list "foo.o" "bar.o")
;;                        "foobar")
;;
(define (gcc-link-files o-files exe-file)
  (when (ubu-update? o-files exe-file)
    (sh "gcc"
        "-o"
        exe-file
        o-files
        (get "gcc-link-opts"))))

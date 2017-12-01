;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2017 Jan Nieuwenhuizen <janneke@gnu.org>
;;; Copyright © 2017 Gábor Boskovits <boskovits@gmail.com>
;;;
;;; This file is part of GNU Guix.
;;;
;;; GNU Guix is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; GNU Guix is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Guix.  If not, see <http://www.gnu.org/licenses/>.

(define-module (gnu packages bootstrappable)
  #:use-module ((guix licenses)
                #:select (gpl3+))
  #:use-module (gnu packages)
  #:use-module (gnu packages bootstrap) ; glibc-dynamic-linker
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages llvm)

  #:use-module (gnu packages package-management) ; diffosscope
  #:use-module (gnu packages acl)                ; diffosscope->getfacl
  #:use-module (gnu packages base)               ; diffoscope->cmp
  #:use-module (gnu packages vim)                ; diffosscope->xxd

  #:use-module (guix download)
  #:use-module (guix packages)
  #:use-module (guix build-system trivial)
  #:use-module (guix utils)
  #:use-module (srfi srfi-1))


(define-public gcc-1.4
  (package
    (inherit hello)
    (name "gcc")
    (version "1.40")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://ftp.gnu.org/pub/old-gnu/gcc/gcc-"
                                  version "/gcc-" version ".tar.bz2"))
              (sha256
               (base32
                "0z4wzpc3cdlzn35iwkc8xsykcxz23msxgsc96r8f5s124rncadd8"))))
    (arguments
     `(#:make-flags ("CC=gcc")
       #:phases
       (modify-phases %standard-phases
         (delete 'configure))))))

(define-public gcc-4.7-$ORIGIN
  (package
    (inherit gcc-4.7)
    (name "gcc-$ORIGIN")
    ;; Using $ORIGIN we cannot have a separate "lib" output
    ;; so let's remove lib output
    (outputs '("out"                    ;commands, etc. (60+ MiB)
               "debug"))                ;debug symbols of run-time libraries
    (arguments
     (substitute-keyword-arguments (package-arguments gcc-4.7)
       ((#:configure-flags original-flags)
        ;;--with-stage1-ldflags="-Wl,-rpath,/path/to/isl/lib,-rpath,/path/to/cloog/lib,-rpath,/path/to/gmp/lib"
        ;;`(cons "--with-boot-ldflags=-Wl,-rpath,\\$ORIGIN/../lib" ,original-flags)
        `(cons* "--enable-languages=c"
                "--enable-relocatable"
                "--disable-nls"
                "--disable-rpath"
                ;;"--with-boot-ldflags=-Wl,-rpath,\\$$\\$$ORIGIN/../lib -Wl,-rpath,../lib -Wl,-rpath=../prev-x86_64-unknown-linux-gnu/libstdc++-v3/src/.libs/"
                (delete "--enable-languages=c,c++" ,original-flags)))
       ((#:phases original-phases)
        `(modify-phases ,original-phases
           (replace 'pre-configure
             (lambda* (#:key inputs outputs #:allow-other-keys)
               (let* ((libdir-suffix (or ,(%current-target-system) ""))
                      (libdir (string-append
                               (assoc-ref outputs "out")
                               libdir-suffix))
                      (origin-libdir (string-append "$ORIGIN/.." libdir-suffix))
                      (libc (assoc-ref inputs "libc")))
                 (when libc
                   ;; The following is not performed for `--without-headers'
                   ;; cross-compiler builds.

                   ;; Join multi-line definitions of GLIBC_DYNAMIC_LINKER* into a
                   ;; single line, to allow the next step to work properly.
                   (for-each
                    (lambda (x)
                      (substitute* (find-files "gcc/config"
                                               "^(linux|gnu|sysv4)(64|-elf|-eabi)?\\.h$")
                        (("(#define (GLIBC|GNU_USER)_DYNAMIC_LINKER.*)\\\\\n$" _ line)
                         line)))
                    '(1 2 3))

                   ;; Fix the dynamic linker's file name.
                   (substitute* (find-files "gcc/config"
                                            "^(linux|gnu|sysv4)(64|-elf|-eabi)?\\.h$")
                     (("#define (GLIBC|GNU_USER)_DYNAMIC_LINKER([^ \t]*).*$"
                       _ gnu-user suffix)
                      (format #f "#define ~a_DYNAMIC_LINKER~a \"~a\"~%"
                              gnu-user suffix
                              (string-append libc ,(glibc-dynamic-linker)))))

                   ;; Tell where to find libstdc++, libc, and `?crt*.o', except
                   ;; `crt{begin,end}.o', which come with GCC.
                   (substitute* (find-files "gcc/config"
                                            "^gnu-user.*\\.h$")
                     (("#define GNU_USER_TARGET_LIB_SPEC (.*)$" _ suffix)
                      ;; Help libgcc_s.so be found (see also below.)  Always use
                      ;; '-lgcc_s' so that libgcc_s.so is always found by those
                      ;; programs that use 'pthread_cancel' (glibc dlopens
                      ;; libgcc_s.so when pthread_cancel support is needed, but
                      ;; having it in the application's RUNPATH isn't enough; see
                      ;; <http://sourceware.org/ml/libc-help/2013-11/msg00023.html>.)
                      ;;
                      ;; NOTE: The '-lgcc_s' added below needs to be removed in a
                      ;; later phase of %gcc-static.  If you change the string
                      ;; below, make sure to update the relevant code in
                      ;; %gcc-static package as needed.
                      (format #f "#define GNU_USER_TARGET_LIB_SPEC \
\"-L~a/lib %{!static:-rpath=~a/lib %{!static-libgcc:\
-rpath=~a/lib \
-rpath=~a/gcc \
-rpath=~a/../lib \
-rpath=~a/../gcc \
-rpath=~a/../../lib \
-rpath=~a/../../../lib \
-rpath=~a/../../../../lib \
-lgcc_s}} \" ~a"
                              libc libc
                              origin-libdir origin-libdir origin-libdir origin-libdir
                              origin-libdir origin-libdir origin-libdir
                              suffix))
                     (("#define GNU_USER_TARGET_STARTFILE_SPEC.*$" line)
                      (format #f "#define STANDARD_STARTFILE_PREFIX_1 \"~a/lib\"
#define STANDARD_STARTFILE_PREFIX_2 \"\"
~a"
                              libc line)))

                   ;; The rs6000 (a.k.a. powerpc) config in GCC does not use
                   ;; GNU_USER_* defines.  Do the above for this case.
                   (substitute*
                       "gcc/config/rs6000/sysv4.h"
                     (("#define LIB_LINUX_SPEC (.*)$" _ suffix)
                      (format #f "#define LIB_LINUX_SPEC \
\"-L~a/lib %{!static:-rpath=~a/lib %{!static-libgcc:-rpath=~a/lib -lgcc_s}} \" ~a"
                              libc libc origin-libdir suffix))
                     (("#define	STARTFILE_LINUX_SPEC.*$" line)
                      (format #f "#define STANDARD_STARTFILE_PREFIX_1 \"~a/lib\"
#define STANDARD_STARTFILE_PREFIX_2 \"\"
~a"
                              libc line))))

                 ;; Don't retain a dependency on the build-time sed.
                 (substitute* "fixincludes/fixincl.x"
                   (("static char const sed_cmd_z\\[\\] =.*;")
                    "static char const sed_cmd_z[] = \"sed\";"))

                 ;; Aarch64 support didn't land in GCC until the 4.8 series.
                 (when (file-exists? "gcc/config/aarch64")
                   ;; Force Aarch64 libdir to be /lib and not /lib64
                   (substitute* "gcc/config/aarch64/t-aarch64-linux"
                     (("lib64") "lib")))

                 (when (file-exists? "libbacktrace")
                   ;; GCC 4.8+ comes with libbacktrace.  By default it builds
                   ;; with -Werror, which fails with a -Wcast-qual error in glibc
                   ;; 2.21's stdlib-bsearch.h.  Remove -Werror.
                   (substitute* "libbacktrace/configure"
                     (("WARN_FLAGS=(.*)-Werror" _ flags)
                      (string-append "WARN_FLAGS=" flags)))

                   (when (file-exists? "libsanitizer/libbacktrace")
                     ;; Same in libsanitizer's bundled copy (!) found in 4.9+.
                     (substitute* "libsanitizer/libbacktrace/Makefile.in"
                       (("-Werror")
                        ""))))

                 ;; Add a RUNPATH to libstdc++.so so that it finds libgcc_s.
                 ;; See <https://gcc.gnu.org/bugzilla/show_bug.cgi?id=32354>
                 ;; and <http://bugs.gnu.org/20358>.
                 (substitute* "libstdc++-v3/src/Makefile.in"
                   (("^OPT_LDFLAGS = ")
                    ;;"OPT_LDFLAGS = -Wl,-rpath=$(libdir) "
                    (string-append "OPT_LDFLAGS ="
                                   " '-Wl,-rpath=$" origin-libdir "//lib'"
                                   " '-Wl,-rpath=$" origin-libdir "//gcc'"
                                   " '-Wl,-rpath=$" origin-libdir "//../lib'"
                                   " '-Wl,-rpath=$" origin-libdir "//../gcc' "
                                   " '-Wl,-rpath=$" origin-libdir "//../lib'"
                                   ;; FIXME?
;;; /gnu/store/qxwsck61dm7h3n1pgzzs2psj06ihsslj-repro-gcc-4.7.4/libexec/gcc/x86_64-unknown-linux-gnu/4.7.4/install-tools/fixincl: error: depends on 'libgcc_s.so.1'
                                   " '-Wl,-rpath=$" origin-libdir "//../../lib'"
                                   " '-Wl,-rpath=$" origin-libdir "//../../../lib'"

                                   )))

                 ;; Move libstdc++*-gdb.py to the "lib" output to avoid a
                 ;; circularity between "out" and "lib".  (Note:
                 ;; --with-python-dir is useless because it imposes $(prefix) as
                 ;; the parent directory.)
                 (substitute* "libstdc++-v3/python/Makefile.in"
                   (("pythondir = .*$")
                    (string-append "pythondir = " libdir "/share"
                                   "/gcc-$(gcc_version)/python\n")))

                 ;; Avoid another circularity between the outputs: this #define
                 ;; ends up in auto-host.h in the "lib" output, referring to
                 ;; "out".  (This variable is used to augment cpp's search path,
                 ;; but there's nothing useful to look for here.)
                 (substitute* "gcc/config.in"
                   (("PREFIX_INCLUDE_DIR")
                    "PREFIX_INCLUDE_DIR_isnt_necessary_here")))))

           (replace 'post-configure
             (lambda _
               ;; Don't store configure flags, to avoid retaining references to
               ;; build-time dependencies---e.g., `--with-ppl=/gnu/store/xxx'.
               (substitute* "Makefile"
                 (("^TOPLEVEL_CONFIGURE_ARGUMENTS=(.*)$" _ rest)
                  "TOPLEVEL_CONFIGURE_ARGUMENTS=\n"))))))))))

(define-public repro-gcc-4.7
  (package
    (inherit gcc-4.7-$ORIGIN)
    (source
     (origin
       (inherit (package-source gcc-4.7-$ORIGIN))
       (patches (append ((compose origin-patches package-source) gcc-4.7)
                        (search-patches "gcc-5-reproducibility-drop-profile.patch"
                                        ;;"gcc-4-compile-with-gcc-5.patch"
                                        "gcc-4-build-path-prefix-map.patch")))))
    (name "repro-gcc")
    (version "4.7.4")
    (arguments
     (substitute-keyword-arguments (package-arguments gcc-4.7-$ORIGIN)
       ((#:phases original-phases)
        `(modify-phases ,original-phases
           (add-before 'configure 'build-prefix-path
             (lambda* (#:key inputs #:allow-other-keys)
               (setenv "BUILD_PATH_PREFIX_MAP"
                       (string-append "gcc" "-" ,version "=" (getcwd)))
               (format (current-error-port)
                       "BUILD_PATH_PREFIX_MAP=~s\n"
                       (getenv "BUILD_PATH_PREFIX_MAP"))))
           (add-before 'configure 'set-cflags
             (lambda _ (setenv "CFLAGS" "-g0 -O2")))))))))

(define-public repro-gcc-wrapped-4.7
  (package
    (inherit gcc-4.7-$ORIGIN)
    (source
     (origin
       (inherit (package-source gcc-4.7-$ORIGIN))
       (patches (append ((compose origin-patches package-source) gcc-4.7)
                        (search-patches "gcc-5-reproducibility-drop-profile.patch"
                                        ;;"gcc-4-compile-with-gcc-5.patch"
                                        "gcc-4-build-path-prefix-map.patch"
					"gcc-4-reproducibility-wrapper.patch")))))
    (name "repro-gcc-wrapped")
    (version "4.7.4")
    (arguments
     (substitute-keyword-arguments (package-arguments gcc-4.7-$ORIGIN)
       ((#:phases original-phases)
        `(modify-phases ,original-phases
           (add-before 'configure 'build-prefix-path
             (lambda* (#:key inputs #:allow-other-keys)
               (let ((out (assoc-ref %outputs "out")))
                 (setenv "GUIX_GCC_PREFIX" out)
                 (setenv "GUIX_GCC_STANDARD_EXEC_PREFIX" (string-append out "/lib/gcc"))
                 (setenv "GUIX_GCC_STANDARD_LIBEXEC_PREFIX" (string-append out "/libexec/gcc"))
                 (setenv "GUIX_GCC_STANDARD_BINDIR_PREFIX" (string-append out "/bin"))
                 (setenv "GUIX_GCC_GPLUSPLUS_INCLUDE_DIR" (string-append out "/include/g++"))
                 (setenv "GUIX_GCC_GPLUSPLUS_BACKWARD_INCLUDE_DIR" (string-append out "/include/c++/backward"))
                 (setenv "GUIX_GCC_GPLUSPLUS_TOOL_INCLUDE_DIR" (string-append out "/include/c++/x86_64-unknown-linux-gnu"));fixme, architecture specific
                 (setenv "GUIX_GCC_GCC_INCLUDE_DIR" (string-append out "/lib/gcc/x86_64-unknown-linux-gnu/4.7.4/include"))
                 (setenv "GUIX_GCC_FIXED_INCLUDE_DIR" (string-append out "/lib/gcc/x86_64-unknown-linux-gnu/4.7.4/include-fixed"))
                 (setenv "GUIX_GCC_TOOL_INCLUDE_DIR" (string-append out "/lib/gcc/x86_64-unknown-linux-gnu/4.7.4/../../../../x86_64-unknown-linux-gnu/include")))
               (setenv "BUILD_PATH_PREFIX_MAP"
                       (string-append "gcc" "-" ,version "=" (getcwd)))
               (format (current-error-port)
                       "BUILD_PATH_PREFIX_MAP=~s\n"
                       (getenv "BUILD_PATH_PREFIX_MAP"))))
           (add-before 'configure 'set-cflags
             (lambda _ (setenv "CFLAGS" "-g0 -O2")))))))))

(define-public repro-gcc-wrapped-nodebug-4.7
  (package
    (inherit repro-gcc-wrapped-4.7)
    (name "repro-gcc-wrapped-nodebug")
    (outputs '("out"))))

(define-public repro-gcc-debuggable-4.7
  (package
    (inherit repro-gcc-4.7)
    (name "repro-gcc-debuggable")
    (arguments
     (substitute-keyword-arguments (package-arguments repro-gcc-4.7)
       ((#:phases original-phases)
        `(modify-phases ,original-phases
           (replace 'set-cflags
             (lambda _ (setenv "CFLAGS" "-O0 -g3")))))
       ((#:make-flags original-flags)
        `(cons* "BOOT_CFLAGS=-O0 -g3"
                (delete "BOOT_CFLAGS=-O2 -g0" ,original-flags)))))))

(define-public repro-gcc-wrapped-debuggable-4.7
  (package
    (inherit repro-gcc-wrapped-4.7)
    (name "repro-gcc-wrapped-debuggable")
    (arguments
     (substitute-keyword-arguments (package-arguments repro-gcc-wrapped-4.7)
       ((#:phases original-phases)
        `(modify-phases ,original-phases
           (replace 'set-cflags
             (lambda _ (setenv "CFLAGS" "-O0 -g3")))))
       ((#:make-flags original-flags)
        `(cons* "BOOT_CFLAGS=-O0 -g3"
                (delete "BOOT_CFLAGS=-O2 -g0" ,original-flags)))))))

(define-public repro-gcc-debuggable-nostrip-4.7
  (package
    (inherit repro-gcc-debuggable-4.7)
    (name "repro-gcc-debuggable-nostrip")
    (arguments
     (substitute-keyword-arguments (package-arguments repro-gcc-debuggable-4.7)
        ((#:strip-binaries? _ #f) #f)))))

(define-public repro-gcc-wrapped-debuggable-nostrip-4.7
  (package
    (inherit repro-gcc-wrapped-debuggable-4.7)
    (name "repro-gcc-wrapped-debuggable-nostrip")
    (arguments
     (substitute-keyword-arguments (package-arguments repro-gcc-wrapped-debuggable-4.7)
        ((#:strip-binaries? _ #f) #f)))))

(define-public repr2-gcc-4.7
  (package
    (inherit repro-gcc-4.7)
    (name "repr2-gcc")))

(define-public repr2-gcc-wrapped-4.7
  (package
    (inherit repro-gcc-wrapped-4.7)
    (name "repr2-gcc-wrapped")))

(define-public repr2-gcc-wrapped-nodebug-4.7
  (package
    (inherit repro-gcc-wrapped-nodebug-4.7)
    (name "repr2-gcc-wrapped-nodebug")))

(define-public repr2-gcc-wrapped-debuggable-nostrip-4.7
  (package
    (inherit repro-gcc-wrapped-debuggable-nostrip-4.7)
    (name "repr2-gcc-wrapped-debuggable-nostrip")))

(define-public repro-gcc-7
  (package
    (inherit gcc-4.7-$ORIGIN)
    (source
     (origin
       (inherit (package-source gcc-7))
       (patches (append (search-patches "gcc-5-reproducibility-drop-profile.patch"
                                        "gcc-7-build-path-prefix-map.patch")
                        ((compose origin-patches package-source) gcc-7)))))
    (name "repro-gcc")
    (version "7.2.0")
    (arguments
     (substitute-keyword-arguments (package-arguments gcc-4.7-$ORIGIN)
       ((#:phases original-phases)
        `(modify-phases ,original-phases
           (add-before 'configure 'build-prefix-path
             (lambda* (#:key inputs #:allow-other-keys)
               (setenv "BUILD_PATH_PREFIX_MAP"
                       (string-append "gcc" "-" ,version "=" (getcwd)))
               (format (current-error-port)
                       "BUILD_PATH_PREFIX_MAP=~s\n"
                       (getenv "BUILD_PATH_PREFIX_MAP"))))))))))

(define-public repr2-gcc-7
  (package
    (inherit repro-gcc-7)
    (name "repr2-gcc")))

(define-public clang-gcc-4.7
  (package
    (inherit repro-gcc-wrapped-nodebug-4.7)
    (name "clang-gcc")
    (native-inputs `(("clang" ,clang)
                     ,@(alist-delete "gcc" (package-native-inputs gcc-4.7))))
    (arguments
     (substitute-keyword-arguments (package-arguments repro-gcc-wrapped-nodebug-4.7)
       ((#:phases original-phases)
        `(modify-phases ,original-phases
           (add-before 'configure 'setenvcc
             (lambda* (#:key inputs #:allow-other-keys)
               (let ((clang (assoc-ref inputs "clang")))
                 (setenv "CC" (string-append clang "/bin/clang"))
                 (setenv "CXX" (string-append clang "/bin/clang++")))))))))))

(define-public clang-gcc-7
  (package
    (inherit repro-gcc-7)
    (name "clang-gcc")
    (native-inputs `(("clang" ,clang)
                     ,@(alist-delete "gcc" (package-native-inputs gcc-7))))
    (arguments
     (substitute-keyword-arguments (package-arguments repro-gcc-7)
       ((#:phases original-phases)
        `(modify-phases ,original-phases
           (add-before 'configure 'setenv
             (lambda* (#:key inputs #:allow-other-keys)
               (let ((clang (assoc-ref inputs "clang")))
                 (setenv "CC" (string-append clang "/bin/clang"))
                 (setenv "CXX "(string-append clang "/bin/clang++")))))))))))

(define-public gcc-ddc-gcc+clang
  (package
    (name "gcc-ddc")
    (version "4.7.4")
    (source #f)
    (native-inputs `(;;("clang-gcc" ,clang-gcc-7)
                     ("clang-gcc" ,repr2-gcc-4.7)
                     ("gcc" ,repro-gcc-4.7)

                     ("diffoscope" ,diffoscope)
                     ("acl" ,acl)       ; For diffoscope
                     ("binutils" ,binutils)
                     ("coreutils" ,coreutils)
                     ("diffutils" ,diffutils)
                     ("xxd" ,xxd)))
    (build-system trivial-build-system)
    (arguments
     `(#:modules ((guix build utils))
       #:builder
       (begin
         (use-modules (guix build utils))
         (let* ((diffoscope (assoc-ref %build-inputs "diffoscope"))
                (acl (assoc-ref %build-inputs "acl"))
                (binutils (assoc-ref %build-inputs "binutils"))
                (coreutils (assoc-ref %build-inputs "coreutils"))
                (diffutils (assoc-ref %build-inputs "diffutils"))
                (xxd (assoc-ref %build-inputs "xxd"))
                (gcc (assoc-ref %build-inputs "gcc"))
                (gcc/bin/gcc (string-append gcc "/bin/gcc"))
                (clang-gcc (assoc-ref %build-inputs "clang-gcc"))
                (clang-gcc/bin/gcc (string-append clang-gcc "/bin/gcc")))
           ;; diffoscope.exc.RequiredToolNotFound: cmp
           ;; diffoscope.comparators.directory: 'stat' not found! Is PATH wrong?
           ;; FileNotFoundError: [Errno 2] No such file or directory: 'readelf'
           ;; diffoscope.comparators.directory: Unable to find 'getfacl'
           (setenv "PATH" (string-append diffoscope "/bin:"

                                         acl "/bin:"
                                         binutils "/bin:"
                                         coreutils "/bin:"
                                         diffutils "/bin:"
                                         xxd "/bin:"))
           ;; ?? xxd not available in path. Falling back to Python hexlify.
           ;; diffoscope.presenters.formats: Console is unable to print Unicode characters. Set e.g. PYTHONIOENCODING=utf-8
           (setenv "PYTHONIOENCODING" "utf-8")
           ;; for starters, only check the gcc binary
           (zero? (system* "diffoscope" gcc/bin/gcc clang-gcc/bin/gcc))
           ;;(zero? (system* "diffoscope" gcc clang-gcc))
           ))))
    (synopsis "test gcc+clang DDC property for gcc-4.7.4")
    (description "gcc-dcc is a meta-package that depends on repro-gcc-4.7.4
and on clang-gcc-4.7.4 (the same GCC built with clang).  The builder checks if
both gcc's are bit-for-bit identical and fails if they differ.")
    (home-page "http://bootstrappable.org")
    (license gpl3+)))

(define-public gcc-wrapped-ddc-gcc+clang
  (package
    (name "gcc-wrapped-ddc")
    (version "4.7.4")
    (source #f)
    (native-inputs `(("clang-gcc" ,clang-gcc-4.7)
                     ("gcc" ,repro-gcc-wrapped-nodebug-4.7)

                     ("diffoscope" ,diffoscope)
                     ("acl" ,acl)       ; For diffoscope
                     ("binutils" ,binutils)
                     ("coreutils" ,coreutils)
                     ("diffutils" ,diffutils)
                     ("xxd" ,xxd)))
    (build-system trivial-build-system)
    (arguments
     `(#:modules ((guix build utils))
       #:builder
       (begin
         (use-modules (guix build utils))
         (let* ((diffoscope (assoc-ref %build-inputs "diffoscope"))
                (acl (assoc-ref %build-inputs "acl"))
                (binutils (assoc-ref %build-inputs "binutils"))
                (coreutils (assoc-ref %build-inputs "coreutils"))
                (diffutils (assoc-ref %build-inputs "diffutils"))
                (xxd (assoc-ref %build-inputs "xxd"))
                (gcc (assoc-ref %build-inputs "gcc"))
                (gcc/bin/gcc (string-append gcc "/bin/gcc"))
                (clang-gcc (assoc-ref %build-inputs "clang-gcc"))
                (clang-gcc/bin/gcc (string-append clang-gcc "/bin/gcc")))
           ;; diffoscope.exc.RequiredToolNotFound: cmp
           ;; diffoscope.comparators.directory: 'stat' not found! Is PATH wrong?
           ;; FileNotFoundError: [Errno 2] No such file or directory: 'readelf'
           ;; diffoscope.comparators.directory: Unable to find 'getfacl'
           (setenv "PATH" (string-append diffoscope "/bin:"

                                         acl "/bin:"
                                         binutils "/bin:"
                                         coreutils "/bin:"
                                         diffutils "/bin:"
                                         xxd "/bin:"))
           ;; ?? xxd not available in path. Falling back to Python hexlify.
           ;; diffoscope.presenters.formats: Console is unable to print Unicode characters. Set e.g. PYTHONIOENCODING=utf-8
           (setenv "PYTHONIOENCODING" "utf-8")
           ;; for starters, only check the gcc binary
           (zero? (system* "diffoscope" gcc clang-gcc))
           ;;(zero? (system* "diffoscope" gcc clang-gcc))
           ))))
    (synopsis "test gcc+clang DDC property for gcc-4.7.4")
    (description "gcc-dcc is a meta-package that depends on repro-gcc-wrapped-4.7.4
and on repr2-gcc-wrapped-4.7.4.  The builder checks if
both gcc's are bit-for-bit identical and fails if they differ.")
    (home-page "http://bootstrappable.org")
    (license gpl3+)))

(define-public gcc-wrapped-debuggable-ddc-gcc+clang
  (package
    (name "gcc-wrapped-debuggable-ddc")
    (version "4.7.4")
    (source #f)
    (native-inputs `(("clang-gcc" ,repr2-gcc-wrapped-debuggable-nostrip-4.7)
                     ("gcc" ,repro-gcc-wrapped-debuggable-nostrip-4.7)

                     ("diffoscope" ,diffoscope)
                     ("acl" ,acl)       ; For diffoscope
                     ("binutils" ,binutils)
                     ("coreutils" ,coreutils)
                     ("diffutils" ,diffutils)
                     ("xxd" ,xxd)))
    (build-system trivial-build-system)
    (arguments
     `(#:modules ((guix build utils))
       #:builder
       (begin
         (use-modules (guix build utils))
         (let* ((diffoscope (assoc-ref %build-inputs "diffoscope"))
                (acl (assoc-ref %build-inputs "acl"))
                (binutils (assoc-ref %build-inputs "binutils"))
                (coreutils (assoc-ref %build-inputs "coreutils"))
                (diffutils (assoc-ref %build-inputs "diffutils"))
                (xxd (assoc-ref %build-inputs "xxd"))
                (gcc (assoc-ref %build-inputs "gcc"))
                (gcc/bin/gcc (string-append gcc "/bin/gcc"))
                (clang-gcc (assoc-ref %build-inputs "clang-gcc"))
                (clang-gcc/bin/gcc (string-append clang-gcc "/bin/gcc")))
           ;; diffoscope.exc.RequiredToolNotFound: cmp
           ;; diffoscope.comparators.directory: 'stat' not found! Is PATH wrong?
           ;; FileNotFoundError: [Errno 2] No such file or directory: 'readelf'
           ;; diffoscope.comparators.directory: Unable to find 'getfacl'
           (setenv "PATH" (string-append diffoscope "/bin:"

                                         acl "/bin:"
                                         binutils "/bin:"
                                         coreutils "/bin:"
                                         diffutils "/bin:"
                                         xxd "/bin:"))
           ;; ?? xxd not available in path. Falling back to Python hexlify.
           ;; diffoscope.presenters.formats: Console is unable to print Unicode characters. Set e.g. PYTHONIOENCODING=utf-8
           (setenv "PYTHONIOENCODING" "utf-8")
           ;; for starters, only check the gcc binary
           (zero? (system* "diffoscope" (string-append gcc "/libexec/gcc/x86_64-unknown-linux-gnu/4.7.4/cc1") (string-append clang-gcc "/libexec/gcc/x86_64-unknown-linux-gnu/4.7.4/cc1")))
           ;;(zero? (system* "diffoscope" gcc clang-gcc))
           ))))
    (synopsis "test gcc+clang DDC property for gcc-4.7.4")
    (description "gcc-dcc is a meta-package that depends on repro-gcc-wrapped-4.7.4
and on repr2-gcc-wrapped-4.7.4.  The builder checks if
both gcc's are bit-for-bit identical and fails if they differ.")
    (home-page "http://bootstrappable.org")
    (license gpl3+)))

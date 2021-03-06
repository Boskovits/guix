;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2017, 2018 Ludovic Courtès <ludo@gnu.org>
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

(define-module (test-store-database)
  #:use-module (guix tests)
  #:use-module ((guix store) #:hide (register-path))
  #:use-module (guix store database)
  #:use-module (srfi srfi-26)
  #:use-module (srfi srfi-64))

;; Test the (guix store database) module.

(define %store
  (open-connection-for-tests))


(test-begin "store-database")

(test-assert "register-path"
  (let ((file (string-append (%store-prefix) "/" (make-string 32 #\f)
                             "-fake")))
    (when (valid-path? %store file)
      (delete-paths %store (list file)))
    (false-if-exception (delete-file file))

    (let ((ref (add-text-to-store %store "ref-of-fake" (random-text)))
          (drv (string-append file ".drv")))
      (call-with-output-file file
        (cut display "This is a fake store item.\n" <>))
      (register-path file
                     #:references (list ref)
                     #:deriver drv)

      (and (valid-path? %store file)
           (equal? (references %store file) (list ref))
           (null? (valid-derivers %store file))
           (null? (referrers %store file))))))

(test-end "store-database")

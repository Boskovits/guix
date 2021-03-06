;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2018 Ludovic Courtès <ludo@gnu.org>
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

(define-module (test-store-deduplication)
  #:use-module (guix tests)
  #:use-module (guix store deduplication)
  #:use-module (guix hash)
  #:use-module ((guix utils) #:select (call-with-temporary-directory))
  #:use-module (guix build utils)
  #:use-module (rnrs bytevectors)
  #:use-module (ice-9 binary-ports)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-64))

(test-begin "store-deduplication")

(test-equal "deduplicate"
  (cons* #t #f                                    ;inode comparisons
         2 (make-list 5 6))                       ;'nlink' values

  (call-with-temporary-directory
   (lambda (store)
     (let ((data      (string->utf8 "Hello, world!"))
           (identical (map (lambda (n)
                             (string-append store "/" (number->string n)))
                           (iota 5)))
           (unique    (string-append store "/unique")))
       (for-each (lambda (file)
                   (call-with-output-file file
                     (lambda (port)
                       (put-bytevector port data))))
                 identical)
       (call-with-output-file unique
         (lambda (port)
           (put-bytevector port (string->utf8 "This is unique."))))

       (for-each (lambda (file)
                   (deduplicate file (sha256 data) #:store store))
                 identical)
       (deduplicate unique (nar-sha256 unique) #:store store)

       ;; (system (string-append "ls -lRia " store))
       (cons* (apply = (map (compose stat:ino stat) identical))
              (= (stat:ino (stat unique))
                 (stat:ino (stat (car identical))))
              (stat:nlink (stat unique))
              (map (compose stat:nlink stat) identical))))))

(test-end "store-deduplication")

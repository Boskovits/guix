;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2013, 2014, 2015, 2017 Ludovic Courtès <ludo@gnu.org>
;;; Copyright © 2014 Mark H Weaver <mhw@netris.org>
;;; Copyright © 2018 Tobias Geerinckx-Rice <me@tobias.gr>
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

(define-module (gnu packages avahi)
  #:use-module ((guix licenses) #:select (lgpl2.1+))
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages)
  #:use-module (gnu packages databases)
  #:use-module (gnu packages libdaemon)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages xml))

(define-public avahi
  (package
    (name "avahi")
    (version "0.6.31")
    (home-page "http://avahi.org")
    (source (origin
             (method url-fetch)
             (uri (string-append home-page "/download/avahi-"
                                 version ".tar.gz"))
             (sha256
              (base32
               "0j5b5ld6bjyh3qhd2nw0jb84znq0wqai7fsrdzg7bpg24jdp2wl3"))
             (patches (search-patches "avahi-localstatedir.patch"))))
    (build-system gnu-build-system)
    (arguments
     '(#:configure-flags '("--with-distro=none"
                           "--localstatedir=/var" ; for the DBus socket
                           "--disable-python"
                           "--disable-mono"
                           "--disable-doxygen-doc"
                           "--disable-xmltoman"
                           "--enable-tests"
                           "--disable-qt3" "--disable-qt4"
                           "--disable-gtk" "--disable-gtk3"
                           "--enable-compat-libdns_sd")))
    (inputs
     `(("expat" ,expat)
       ("glib" ,glib)
       ("dbus" ,dbus)
       ("gdbm" ,gdbm)
       ("libcap" ,libcap)            ;to enable chroot support in avahi-daemon
       ("libdaemon" ,libdaemon)))
    (native-inputs
     `(("intltool" ,intltool)
       ("glib" ,glib "bin")
       ("pkg-config" ,pkg-config)))
    (synopsis "Implementation of mDNS/DNS-SD protocols")
    (description
     "Avahi is a system which facilitates service discovery on a local
network.  It is an implementation of the mDNS (for \"Multicast DNS\") and
DNS-SD (for \"DNS-Based Service Discovery\") protocols.")
    (license lgpl2.1+)))

(define-public nss-mdns
  (package
    (name "nss-mdns")
    (version "0.11")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://github.com/lathiat/nss-mdns"
                                  "/releases/download/v" version "/"
                                  name "-" version ".tar.gz"))
              (sha256
               (base32
                "14jwy6mklzgjz3mfmw67mxhszrw9d3d3yjjhg87j4crci6m19i39"))))
    (build-system gnu-build-system)
    (arguments
     ;; The Avahi daemon socket is expected by src/Makefile.am to be at
     ;; "$(localstatedir)/run/avahi-daemon/socket", so set $(localstatedir)
     ;; appropriately.
     '(#:configure-flags '("--localstatedir=/var")))
    (home-page "https://github.com/lathiat/nss-mdns")
    (synopsis "Multicast DNS Name Service Switch (@dfn{NSS}) plug-in")
    (description
     "Nss-mdns is a plug-in for the GNU C Library's Name Service Switch
(@dfn{NSS}) that resolves host names via multicast DNS (@dfn{mDNS}).  It is
most often used in home and other small networks without a local name server,
to resolve host names in the @samp{.local} top-level domain.")
    (license lgpl2.1+)))

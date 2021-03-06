;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2016 Ludovic Courtès <ludo@gnu.org>
;;; Copyright © 2018 Sou Bunnbu <iyzsong@member.fsf.org>
;;; Copyright © 2017, 2018 Ricardo Wurmus <rekado@elephly.net>
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

(define-module (gnu packages monitoring)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system perl)
  #:use-module (guix build-system python)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages admin)
  #:use-module (gnu packages base)
  #:use-module (gnu packages check)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages django)
  #:use-module (gnu packages gd)
  #:use-module (gnu packages image)
  #:use-module (gnu packages mail)
  #:use-module (gnu packages perl)
  #:use-module (gnu packages python)
  #:use-module (gnu packages python-web)
  #:use-module (gnu packages time))

(define-public nagios
  (package
    (name "nagios")
    (version "4.3.4")
    ;; XXX: Nagios 4.2.x and later bundle a copy of AngularJS.
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "mirror://sourceforge/nagios/nagios-4.x/nagios-"
                    version "/nagios-" version ".tar.gz"))
              (sha256
               (base32
                "1wa4m952sb23dqi5w759adimsp21bkhp598rpq9dnhz3v497h2y9"))
              (modules '((guix build utils)))
              (snippet
               ;; Ensure reproducibility.
               '(begin
                  (substitute* (find-files "cgi" "\\.c$")
                    (("__DATE__") "\"1970-01-01\"")
                    (("__TIME__") "\"00:00:00\""))
                  #t))))
    (build-system gnu-build-system)
    (native-inputs
     `(("unzip" ,unzip)))
    (inputs
     `(("zlib" ,zlib)
       ("libpng-apng" ,libpng)
       ("gd" ,gd)
       ("perl" ,perl)
       ("mailutils" ,mailutils)))
    (arguments
     '(#:configure-flags (list "--sysconfdir=/etc"

                               ;; 'include/locations.h.in' defines file
                               ;; locations, and many things go directly under
                               ;; LOCALSTATEDIR, hence the extra '/nagios'.
                               "--localstatedir=/var/nagios"

                               (string-append
                                "--with-mail="
                                (assoc-ref %build-inputs "mailutils")
                                "/bin/mail"))
       #:make-flags '("all")
       #:phases (modify-phases %standard-phases
                  (add-before 'build 'do-not-chown-to-nagios
                    (lambda _
                      ;; Makefiles do 'install -o nagios -g nagios', which
                      ;; doesn't work for us.
                      (substitute* (find-files "." "^Makefile$")
                        (("-o nagios -g nagios")
                         ""))
                      #t))
                  (add-before 'build 'do-not-create-sysconfdir
                    (lambda _
                      ;; Don't try to create /var upon 'make install'.
                      (substitute* "Makefile"
                        (("\\$\\(INSTALL\\).*\\$\\(LOGDIR\\).*$" all)
                         (string-append "# " all))
                        (("\\$\\(INSTALL\\).*\\$\\(CHECKRESULTDIR\\).*$" all)
                         (string-append "# " all))
                        (("chmod g\\+s.*" all)
                         (string-append "# " all)))
                      #t))
                  (add-before 'build 'set-html/php-directory
                    (lambda _
                      ;; Install HTML and PHP files under 'share/nagios/html'
                      ;; instead of just 'share/'.
                      (substitute* '("html/Makefile" "Makefile")
                        (("HTMLDIR=.*$")
                         "HTMLDIR = $(datarootdir)/nagios/html\n"))
                      #t)))
       #:tests? #f))                             ;no 'check' target or similar
    (home-page "https://www.nagios.org/")
    (synopsis "Host, service, and network monitoring program")
    (description
     "Nagios is a host, service, and network monitoring program written in C.
CGI programs are included to allow you to view the current status, history,
etc. via a Web interface.  Features include:

@itemize
@item Monitoring of network services (via SMTP, POP3, HTTP, PING, etc).
@item Monitoring of host resources (processor load, disk usage, etc.).
@item A plugin interface to allow for user-developed service monitoring
  methods.
@item Ability to define network host hierarchy using \"parent\" hosts,
  allowing detection of and distinction between hosts that are down
  and those that are unreachable.
@item Notifications when problems occur and get resolved (via email,
  pager, or user-defined method).
@item Ability to define event handlers for proactive problem resolution.
@item Automatic log file rotation/archiving.
@item Optional web interface for viewing current network status,
  notification and problem history, log file, etc.
@end itemize\n")
    (license license:gpl2)))

(define-public darkstat
  (package
    (name "darkstat")
    (version "3.0.719")
    (source (origin
              (method url-fetch)
              (uri (string-append "https://unix4lyfe.org/darkstat/darkstat-"
                                  version ".tar.bz2"))
              (sha256
               (base32
                "1mzddlim6dhd7jhr4smh0n2fa511nvyjhlx76b03vx7phnar1bxf"))))
    (build-system gnu-build-system)
    (arguments '(#:tests? #f))          ; no tests
    (inputs
     `(("libpcap" ,libpcap)
       ("zlib" ,zlib)))
    (home-page "https://unix4lyfe.org/darkstat/")
    (synopsis "Network statistics gatherer")
    (description
     "@command{darkstat} is a packet sniffer that runs as a background process,
gathers all sorts of statistics about network usage, and serves them over
HTTP.  Features:

@itemize
@item Traffic graphs, reports per host, shows ports for each host.
@item Embedded web-server with deflate compression.
@item Asynchronous reverse DNS resolution using a child process.
@item Small.  Portable.  Single-threaded.  Efficient.
@item Supports IPv6.
@end itemize")
    (license license:gpl2)))

(define-public python-whisper
  (package
    (name "python-whisper")
    (version "1.0.2")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "whisper" version))
       (sha256
        (base32
         "1v1bi3fl1i6p4z4ki692bykrkw6907dn3mfq0151f70lvi3zpns3"))))
    (build-system python-build-system)
    (home-page "http://graphiteapp.org/")
    (synopsis "Fixed size round-robin style database for Graphite")
    (description "Whisper is one of three components within the Graphite
project.  Whisper is a fixed-size database, similar in design and purpose to
RRD (round-robin-database).  It provides fast, reliable storage of numeric
data over time.  Whisper allows for higher resolution (seconds per point) of
recent data to degrade into lower resolutions for long-term retention of
historical data.")
    (license license:asl2.0)))

(define-public python2-whisper
  (package-with-python2 python-whisper))

(define-public python2-carbon
  (package
    (name "python2-carbon")
    (version "1.0.2")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "carbon" version))
       (sha256
        (base32
         "142smpmgbnjinvfb6s4ijazish4vfgzyd8zcmdkh55y051fkixkn"))))
    (build-system python-build-system)
    (arguments
     `(#:python ,python-2   ; only supports Python 2
       #:phases
       (modify-phases %standard-phases
         ;; Don't install to /opt
         (add-after 'unpack 'do-not-install-to-/opt
           (lambda _ (setenv "GRAPHITE_NO_PREFIX" "1") #t)))))
    (propagated-inputs
     `(("python2-whisper" ,python2-whisper)
       ("python2-configparser" ,python2-configparser)
       ("python2-txamqp" ,python2-txamqp)))
    (home-page "http://graphiteapp.org/")
    (synopsis "Backend data caching and persistence daemon for Graphite")
    (description "Carbon is a backend data caching and persistence daemon for
Graphite.  Carbon is responsible for receiving metrics over the network,
caching them in memory for \"hot queries\" from the Graphite-Web application,
and persisting them to disk using the Whisper time-series library.")
    (license license:asl2.0)))

(define-public python2-graphite-web
  (package
    (name "python2-graphite-web")
    (version "1.0.2")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "graphite-web" version))
       (sha256
        (base32
         "0q8bwlj75jqyzmazfsi5sa26xl58ssa8wdxm2l4j0jqyn8xpfnmc"))))
    (build-system python-build-system)
    (arguments
     `(#:python ,python-2               ; only supports Python 2
       #:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'relax-requirements
           (lambda _
             (substitute* "setup.py"
               (("0.4.3") ,(package-version python2-django-tagging))
               (("<1.9.99") (string-append "<="
                             ,(package-version python2-django))))
             #t))
         ;; Don't install to /opt
         (add-after 'unpack 'do-not-install-to-/opt
           (lambda _ (setenv "GRAPHITE_NO_PREFIX" "1") #t)))))
    (propagated-inputs
     `(("python2-cairocffi" ,python2-cairocffi)
       ("python2-pytz" ,python2-pytz)
       ("python2-whisper" ,python2-whisper)
       ("python2-django" ,python2-django)
       ("python2-django-tagging" ,python2-django-tagging)
       ("python2-scandir" ,python2-scandir)
       ("python2-urllib3" ,python2-urllib3)
       ("python2-pyparsing" ,python2-pyparsing)
       ("python2-txamqp" ,python2-txamqp)))
    (home-page "http://graphiteapp.org/")
    (synopsis "Scalable realtime graphing system")
    (description "Graphite is a scalable real-time graphing system that does
two things: store numeric time-series data, and render graphs of this data on
demand.")
    (license license:asl2.0)))

(define-public python-prometheus-client
  (package
    (name "python-prometheus-client")
    (version "0.1.1")
    (source
     (origin
       (method url-fetch)
       (uri (pypi-uri "prometheus_client" version))
       (sha256
        (base32
         "164qzzg8q8awqk0angcm87p2sjiibaj1wgjz0xk6j0klvqi5q2mz"))))
    (build-system python-build-system)
    (arguments
     '(;; No included tests.
       #:tests? #f))
    (home-page
     "https://github.com/prometheus/client_python")
    (synopsis "Python client for the Prometheus monitoring system")
    (description
     "The @code{prometheus_client} package supports exposing metrics from
software written in Python, so that they can be scraped by a Prometheus
service.

Metrics can be exposed through a standalone web server, or through Twisted,
WSGI and the node exporter textfile collector.")
    (license license:asl2.0)))

(define-public python2-prometheus-client
  (package-with-python2 python-prometheus-client))

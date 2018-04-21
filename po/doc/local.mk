# GNU Guix --- Functional package management for GNU
# Copyright © 2018 Julien Lepiller <julien@lepiller.eu>
#
# This file is part of GNU Guix.
#
# GNU Guix is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or (at
# your option) any later version.
#
# GNU Guix is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with GNU Guix.  If not, see <http://www.gnu.org/licenses/>.

EXTRA_DIST = \
  %D%/contributing.fr.po \
  %D%/guix.fr.po

POT_OPTIONS = --package-name "guix" --package-version "$(VERSION)" \
	          --copyright-holder "Ludovic Courtès" \
			  --msgid-bugs-address "ludo@gnu.org"

$(srcdir)/po/doc/guix.%.po: $(srcdir)/po/doc/guix.pot
	@lang=`echo $$(basename "$@") | sed -e 's|^guix.||' -e 's|.po$$||'` ;\
	if test -f "$@"; then \
	  test "$(srcdir)" = . && cdcmd="" || cdcmd="cd $(srcdir) && "; \
	  echo "$${cdcmd}$(MSGMERGE_UPDATE) $(MSGMERGE_OPTIONS) --lang=$${lang} $@ $<"; \
	  cd $(srcdir) \
	    && { case `$(MSGMERGE_UPDATE) --version | sed 1q | sed -e 's,^[^0-9]*,,'` in \
	        '' | 0.[0-9] | 0.[0-9].* | 0.1[0-7] | 0.1[0-7].*) \
	          $(MSGMERGE_UPDATE) $(MSGMERGE_OPTIONS) $@ $<;; \
	        *) \
	          $(MSGMERGE_UPDATE) $(MSGMERGE_OPTIONS) --lang=$${lang} $@ $<;; \
	      esac; \
	    }; \
	  touch "$@"; \
	else \
	     echo "File $@ does not exist. If you are a translator, you can create it through 'msginit'." 1>&2; \
	     exit 1; \
	fi

$(srcdir)/po/doc/contributing.%.po: $(srcdir)/po/doc/contributing.pot
	@lang=`echo $$(basename "$@") | sed -e 's|^contributing.||' -e 's|.po$$||'` ;\
	if test -f "$@"; then \
	  test "$(srcdir)" = . && cdcmd="" || cdcmd="cd $(srcdir) && "; \
	  echo "$${cdcmd}$(MSGMERGE_UPDATE) $(MSGMERGE_OPTIONS) --lang=$${lang} $@ $<"; \
	  cd $(srcdir) \
	    && { case `$(MSGMERGE_UPDATE) --version | sed 1q | sed -e 's,^[^0-9]*,,'` in \
	        '' | 0.[0-9] | 0.[0-9].* | 0.1[0-7] | 0.1[0-7].*) \
	          $(MSGMERGE_UPDATE) $(MSGMERGE_OPTIONS) $@ $<;; \
	        *) \
	          $(MSGMERGE_UPDATE) $(MSGMERGE_OPTIONS) --lang=$${lang} $@ $<;; \
	      esac; \
	    }; \
	  touch "$@"; \
	else \
	     echo "File $@ does not exist. If you are a translator, you can create it through 'msginit'." 1>&2; \
	     exit 1; \
	fi

$(srcdir)/po/doc/contributing.pot-update: doc/contributing.texi
	$(AM_V_PO4A)$(PO4A_UPDATEPO) -M UTF-8 -f texinfo -m "$<" \
		-p "$$(echo $@ | sed 's|-update||')" $(POT_OPTIONS)
	@touch "$$(echo $@ | sed 's|-update||')"

$(srcdir)/po/doc/guix.pot-update: doc/guix.texi
	$(AM_V_PO4A)$(PO4A_UPDATEPO) -M UTF-8 -f texinfo -m "$<" \
		-p "$$(echo $@ | sed 's|-update||')" $(POT_OPTIONS)
	@touch "$$(echo $@ | sed 's|-update||')"

doc-pot-update:
	$(MAKE) $(srcdir)/po/doc/guix.pot-update
	$(MAKE) $(srcdir)/po/doc/contributing.pot-update

# Cockpit Navigator - A File System Browser for Cockpit.
# Copyright (C) 2021 Josh Boudreau <jboudreau@45drives.com>

# This file is part of Cockpit Navigator.
# Cockpit Navigator is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# Cockpit Navigator is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with Cockpit Navigator.  If not, see <https://www.gnu.org/licenses/>.

EL7_DIST=.el7
PACKAGE_NAME=navigator

# i18n - discover available translations
LINGUAS=$(basename $(notdir $(wildcard po/*.po)))

default: po-js

all: default

install:
	mkdir -p $(DESTDIR)/usr/share/cockpit/
	cp -rpf navigator $(DESTDIR)/usr/share/cockpit
ifeq ($(DIST),$(EL7_DIST))
	sed -i "s/pf-c-button/btn/g;s/pf-m-primary/btn-primary/g;s/pf-m-secondary/btn-default/g;s/pf-m-danger/btn-danger/g" $(DESTDIR)/usr/share/cockpit/navigator/index.html
	sed -i "s/pf-c-button/btn/g;s/pf-m-primary/btn-primary/g;s/pf-m-secondary/btn-default/g;s/pf-m-danger/btn-danger/g" $(DESTDIR)/usr/share/cockpit/navigator/components/ModalPrompt.js
endif
ifneq ($(NAV_VERS),)
	echo "export let NAVIGATOR_VERSION = \"$(NAV_VERS)\";" > $(DESTDIR)/usr/share/cockpit/navigator/version.js
endif

uninstall:
	rm -rf $(DESTDIR)/usr/share/cockpit/navigator

install-local:
	mkdir -p $(HOME)/.local/share/cockpit
	cp -rpf navigator $(HOME)/.local/share/cockpit
	find $(HOME)/.local/share/cockpit/navigator -name '*.js' -exec sed -i "s#\"/usr/share/\(cockpit/navigator/scripts/.*\)\"#\"$(HOME)/.local/share/\1\"#g" {} \;
ifneq ($(NAV_VERS),)
	echo "export let NAVIGATOR_VERSION = \"$(NAV_VERS)\";" > $(HOME)/.local/share/cockpit/navigator/version.js
endif

uninstall-local:
	rm -rf $(HOME)/.local/share/cockpit/navigator
# Remote install defaults
REMOTE_HOST ?= 192.168.123.5
REMOTE_USER ?= root
# Where navigator lands on the remote
REMOTE_PREFIX ?= /usr/share/cockpit
REMOTE_DESTDIR ?= $(DESTDIR)
# Restart cockpit on remote after install (1=yes)
RESTART_COCKPIT ?= 1
# Tools
SSH := ssh $(REMOTE_USER)@$(REMOTE_HOST)
RSYNC := rsync -aH --delete

# Remote install (uses ssh + rsync)
install-remote:
	@echo "Installing to $(REMOTE_USER)@$(REMOTE_HOST):$(REMOTE_DESTDIR)$(REMOTE_PREFIX)"
	$(SSH) "mkdir -p $(REMOTE_DESTDIR)$(REMOTE_PREFIX)"
	$(RSYNC) navigator $(REMOTE_USER)@$(REMOTE_HOST):$(REMOTE_DESTDIR)$(REMOTE_PREFIX)/
ifeq ($(DIST),$(EL7_DIST))
	$(SSH) "sed -i 's/pf-c-button/btn/g;s/pf-m-primary/btn-primary/g;s/pf-m-secondary/btn-default/g;s/pf-m-danger/btn-danger/g' $(REMOTE_DESTDIR)$(REMOTE_PREFIX)/navigator/index.html"
	$(SSH) "sed -i 's/pf-c-button/btn/g;s/pf-m-primary/btn-primary/g;s/pf-m-secondary/btn-default/g;s/pf-m-danger/btn-danger/g' $(REMOTE_DESTDIR)$(REMOTE_PREFIX)/navigator/components/ModalPrompt.js"
endif
ifneq ($(NAV_VERS),)
	$(SSH) "printf '%s\n' 'export let NAVIGATOR_VERSION = \"$(NAV_VERS)\";' > $(REMOTE_DESTDIR)$(REMOTE_PREFIX)/navigator/version.js"
endif
ifeq ($(RESTART_COCKPIT),1)
	$(SSH) "systemctl stop cockpit.socket || true; systemctl start cockpit.socket || true"
endif

# Optional convenience target
uninstall-remote:
	$(SSH) "rm -rf $(REMOTE_DESTDIR)$(REMOTE_PREFIX)/navigator"

#
# i18n
#

po/$(PACKAGE_NAME).pot:
	xgettext --default-domain=$(PACKAGE_NAME) --output=$@ --language=JavaScript \
		--keyword=_ --keyword=N_ --keyword=C_:1c,2 --keyword=ngettext:1,2 \
		--add-comments=Translators: \
		--from-code=UTF-8 \
		$$(find navigator/ -name '*.js' ! -path '*/fontawesome/*')
	@# Append manifest.json labels to the POT
	@printf '\n#: navigator/manifest.json\nmsgid "Navigator"\nmsgstr ""\n' >> $@
	@sed -i '/^"POT-Creation-Date:/d' $@

po/LINGUAS:
	echo $(LINGUAS) | tr ' ' '\n' > $@

# Update all existing PO files from the POT
update-po: po/$(PACKAGE_NAME).pot
	@for lang in $(LINGUAS); do \
		printf "Updating $$lang.po... "; \
		msgmerge --add-location=file --backup=none --update po/$$lang.po po/$(PACKAGE_NAME).pot; \
	done

# Generate Cockpit-compatible po.<lang>.js and po.manifest.<lang>.js from each .po file
# po.XX.js        → loaded via <script src="../*/po.js"></script> for JS string translations
# po.manifest.XX.js → loaded by cockpit shell to translate sidebar label
po-js: $(patsubst po/%.po,navigator/po.%.js,$(wildcard po/*.po)) \
       $(patsubst po/%.po,navigator/po.manifest.%.js,$(wildcard po/*.po))

navigator/po.%.js: po/%.po po/po2json.py
	python3 po/po2json.py $< $@

navigator/po.manifest.%.js: po/%.po po/po2json.py navigator/manifest.json
	python3 po/po2json.py $< $@ navigator/manifest.json

# Create a new PO file for a language: make po/XX.po
po/%.po: po/$(PACKAGE_NAME).pot
	@if [ ! -f $@ ]; then \
		msginit --no-translator --locale=$* --input=$< --output-file=$@; \
	else \
		msgmerge --add-location=file --backup=none --update $@ $<; \
	fi

clean-po:
	rm -f navigator/po.*.js
	rm -f po/$(PACKAGE_NAME).pot po/$(PACKAGE_NAME).*.pot po/LINGUAS

.PHONY: all clean install install-local install-remote uninstall uninstall-local uninstall-remote update-po po-js clean-po

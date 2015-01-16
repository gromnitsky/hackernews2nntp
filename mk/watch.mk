watch.mk-mkdir := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

watch.mk-dirs := src template
watch.mk-exclude := -X '*.\#*' -X '.*.d.mk'
watch.mk-cmd := $(watch.mk-mkdir)/watchman-build.sh -c 'make -C ..' -t `tty`

define watch.mk-add-dirs
$(foreach idx,$(1),watchman -n -- watch $(idx); )
endef

define watch.mk-del-dirs
$(foreach idx,$(1),watchman -n -- watch-del "$(idx)"; )
endef

define watch.mk-add-triggers
$(foreach idx,$(1),watchman -n -- trigger "$(idx)" "asset-$(idx)" \
	'*.*' $(watch.mk-exclude) -- $(watch.mk-cmd); )
endef

# log: /tmp/.watchman.$USER.log
.PHONY: watch
watch:
	$(call watch.mk-del-dirs,$(watch.mk-dirs))
	$(call watch.mk-add-dirs,$(watch.mk-dirs))
	$(call watch.mk-add-triggers,$(watch.mk-dirs))

.PHONY: watch-kill
watch-kill:
	killall watchman

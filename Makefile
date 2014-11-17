html :=
clean :=
clobber :=

.PHONY: all
all:

include mk/debug.mk
include mk/readme.mk
include mk/node-modules.mk

all: node_modules $(html)

.PHONY: clean
clean:
	rm -rf $(clean)

.PHONY: clobber
clobber: clean
	rm -rf $(clobber)

.PHONY: test
test: node_modules
	$(MAKE) -C test


define help :=
all     -- Just compile all

clean   -- rm all compiled targets

clobber -- Clean + rm node_modules

test    -- Run tests w/ mocha. Or
           $$ make test TEST_OPTS='-g pattern'
endef

.PHONY: help
help:
	@:
	$(info $(help))
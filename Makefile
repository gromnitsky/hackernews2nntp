html :=
clean :=
clobber :=

.PHONY: all
all:

include mk/debug.mk
include mk/readme.mk
include mk/node.mk
include mk/src.mk

all: node_modules $(html) compile

.PHONY: clean
clean:
	rm -rf $(clean)
	$(MAKE) -C test clean

.PHONY: clobber
clobber: clean
	rm -rf $(clobber)

.PHONY: test
test: node_modules
	$(MAKE) -C test

define help :=
all      -- Just compile all

clean    -- rm all compiled targets

clobber  -- Clean + rm node_modules

test     -- Run tests w/ mocha. Or
            $$ make test TEST_OPTS='-g pattern'

compile  -- compile src/ to lib/

npm-view -- View a would-be npm-package w/o uploading it to the registry

npm      -- Publish a package to npm registry
endef

.PHONY: help
help:
	@:
	$(info $(help))

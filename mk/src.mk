cs_compiler := node_modules/.bin/coffee

js := $(subst src/, lib/, $(patsubst %.coffee, %.js, $(wildcard src/*.coffee)))
json := $(subst src/, lib/, $(wildcard src/*.json))

clean += $(json) $(js)

lib/%.json: src/%.json
	cp $< $@

lib/%.js: src/%.coffee
	$(cs_compiler) -c -o $(dir $@) $<

.PHONY: compile
compile: $(json) $(js)
	@mkdir -p lib

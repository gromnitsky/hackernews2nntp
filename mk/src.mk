cs_compiler := node_modules/.bin/coffee

js := $(subst src/, lib/, $(patsubst %.coffee, %.js, $(wildcard src/*.coffee)))
json := $(subst src/, lib/, $(wildcard src/*.json))

clean += $(json) $(js)

lib/%.json: src/%.json
	@mkdir -p $(dir $@)
	cp $< $@

lib/%.js: src/%.coffee
	@mkdir -p $(dir $@)
	$(cs_compiler) -c -o $(dir $@) $<

.PHONY: compile
compile: $(json) $(js)

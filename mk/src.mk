cs_compiler := node_modules/.bin/coffee

js := $(subst src/, lib/, $(patsubst %.coffee, %.js, $(wildcard src/*.coffee)))
json := $(subst src/, lib/, $(wildcard src/*.json))

clean += $(json) $(js) template/job.txt

lib/%.json: src/%.json
	@mkdir -p $(dir $@)
	cp $< $@

lib/%.js: src/%.coffee
	@mkdir -p $(dir $@)
	$(cs_compiler) -c -o $(dir $@) $<

# npm doesn't pack symlinks :(
template/job.txt: template/story.txt
	cp $< $@

.PHONY: compile
compile: $(json) $(js) template/job.txt

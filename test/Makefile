TEST_OPTS :=
mocha := ../node_modules/.bin/mocha
clean :=

.PHONY:
test: data/json/.target
	$(mocha) --compilers coffee:coffee-script/register \
		-u tdd test_*.coffee $(TEST_OPTS)

clean += data/json

data/json/.target: json-generate
	rm -rf $(dir $@)
	./$<
	echo $< > $@

.PHONY: clean
clean:
	rm -rf $(clean)

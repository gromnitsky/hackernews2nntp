TEST_OPTS :=
mocha := ../node_modules/.bin/mocha
clean :=

.PHONY:
test: data/json
	$(mocha) --compilers coffee:coffee-script/register \
		-u tdd test_*.coffee $(TEST_OPTS)

clean += data/json

data/json:
	./json-generate

.PHONY: clean
clean:
	rm -rf $(clean)

TEST_OPTS :=
mocha := ../node_modules/.bin/mocha

.PHONY:
test:
	$(mocha) --compilers coffee:coffee-script/register \
		-u tdd test_*.coffee $(TEST_OPTS)

clobber += node_modules

node_modules: package.json
	npm install
	touch $@

.PHONY: npm
npm: compile
	rm -f README.html
	npm publish

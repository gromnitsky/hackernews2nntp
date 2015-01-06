clobber += node_modules

node_modules: package.json
	npm install
	touch $@

.PHONY: npm
npm: compile
	rm -f README.html
	npm publish

.PHONY: npm
npm-view: compile
	rm -f README.html hackernews2nntp-*.tgz
	npm pack && less hackernews2nntp-*.tgz
	rm hackernews2nntp-*.tgz

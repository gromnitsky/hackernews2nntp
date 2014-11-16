clobber += node_modules

node_modules: package.json
	npm install
	touch $@

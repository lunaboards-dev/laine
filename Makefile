#The Luna makefile. I can't test this atm.
install:
	curl -L https://github.com/luvit/lit/raw/master/get-lit.sh | sh
	mkdir deps
	luarocks install --tree temp luasql-mysql
	luarocks install --tree temp lustache
	curl https://raw.githubusercontent.com/Dynodzzo/Lua_INI_Parser/master/LIP.lua > deps/LIP.lua
	./lit install creationix/weblit
	cp temp/lib/5.1/luasql dep/luasql
	cp temp/lib/5.1/lustache dep/lustache
	cp temp/lib/5.1/lustache.lua dep/luastache.lua
	rm -rf temp

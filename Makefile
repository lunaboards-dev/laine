install:
	echo 'Cleaning up last setup...'
	rm -rf deps
	rm -rf temp
	rm -rf lustache
	echo 'Downloading Luvit setup...'
	curl -L https://github.com/luvit/lit/raw/master/get-lit.sh | sh
	chmod 755 luvit
	chmod 755 lit
	chmod 755 luvi
	mkdir deps
	echo 'Downloading LuaSQL...'
	luarocks install --tree=temp luasql-mysql MYSQL_INCDIR=/usr/include/mysql
	echo 'Downloading LIP...'
	curl https://raw.githubusercontent.com/Dynodzzo/Lua_INI_Parser/master/LIP.lua > deps/LIP.lua
	echo 'Downloading utf8.lua...'
	curl https://raw.githubusercontent.com/Stepets/utf8.lua/master/utf8.lua > deps/utf8.lua
	echo 'Dowloading Lustache...'
	git clone https://github.com/Olivine-Labs/lustache.git
	echo 'Downloading Weblit...'
	./lit install creationix/weblit
	echo 'Copying deps...'
	cp -r temp/lib/lua/5.1/luasql deps/luasql
	cp -r lustache/src/lustache deps
	cp lustache/src/lustache.lua deps/lustache.lua
	echo 'chmodding deps...'
	sudo chmod -R 755 deps
	echo 'Setting up MySQL tables...'
	cd deps && lua ../setup/setup.lua
	echo 'Cleaning up...'
	rm -rf temp
	rm -rf lustache
	echo 'Setup complete. Run ./luvit main.lua in the terminal to start.'
ubuntu-packages:
	apt install lua5.1
	apt install luarocks
	apt install curl
	apt install libmysqlclient-dev
	apt install mysql-server
	apt install mysql-client

#Include package setups for other distros.

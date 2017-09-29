#The Luna makefile. I can't test this atm.
install:
	echo 'Downloading Luvit setup...'
	curl -L https://github.com/luvit/lit/raw/master/get-lit.sh | sh
	chmod u+x luvit
	chmod u+x lit
	chmod u+x luvi
	mkdir deps
	echo 'Downloading rocks...'
	luarocks install --tree temp luasql-mysql MYSQL_INCDIR=/usr/include/mysql
	luarocks install --tree temp lustache
	echo 'Downloading LIP...'
	curl https://raw.githubusercontent.com/Dynodzzo/Lua_INI_Parser/master/LIP.lua > deps/LIP.lua
	echo 'Downloading utf8.lua...'
	curl https://raw.githubusercontent.com/Stepets/utf8.lua/master/utf8.lua > deps/utf8.lua
	echo 'Downloading Weblit...'
	./lit install creationix/weblit
	echo 'Copying deps from temp folder...'
	cp temp/lib/5.1/luasql deps/luasql
	cp temp/lib/5.1/lustache deps/lustache
	cp temp/lib/5.1/lustache.lua deps/luastache.lua
	echo 'Settiing up MySQL tables...'
	mysql -uroot < setup/setup.sql
	echo 'Cleaning up...'
	rm -rf temp
	echo 'Setup complete. Run ./luvit main.lua in the terminal to test.'
ubuntu:
	apt install lua5.1
	apt install luarocks
	apt install curl
	apt install libmysqlclient-dev
	apt install mysql-server

#Include package setups for other distros.

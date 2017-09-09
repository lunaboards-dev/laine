local cmsgpack=require('cmsgpack')
local xxh32=require('xxhash').xxh32
local magic_number=0xB00B1E
local color = require 'ansicolor'
--local fs=require('fs')
--pathJoin = require('pathjoin').pathJoin
local db_object = {}
local settings = {
	chunksize=5,
	loadall=false,
	defaultval = {
		string = "",
		number = 0,
		table = {},
		["function"] = function() end,
		boolean = false,
		link = "nil/000000000000#0",
		db = "0"
	}
}
--[[local body_meta = {
	__index = function(self, index)
		p(self)
		local cid = self.map[index]
		if (cid ~= nil) then
			if (self.chunks[cid] == nil) then
				self:LoadChunk()
			end
			for i=1, #self.chunks[cid] do
				if (self.chunks[cid][self.headers.index] == index) then
					return self.chunks[cid]
				end
			end
		end
		return nil
	end
}]]
local hex = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"}
local function deepcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepcopy(orig_key)] = deepcopy(orig_value)
		end
		setmetatable(copy, deepcopy(getmetatable(orig)))
	else
		copy = orig
	end
	return copy
end

local LoadDB = function(db_name, headers, options)
	options = options or {}
	local cachedcols = options.cache or {}
	local force = options.force or false
	options.index = options.index or headers[1][1]
	local db = {headers={}, body={}, map={}, chunks={}, chunkcache={}, chunkage={}, dbname="", lchunk="000000000000", hashes={}}
	if (fs.existsSync(db_name) and not force) then
		db.dbname = db_name
		local hashes = cmsgpack.unpack(fs.readFileSync(db_name.."/XXHASH32"))
		local _d = ""
		_d = fs.readFileSync(db_name.."/HEADERS")
		if (xxh32(_d, magic_number) ~= hashes["HEADERS"]) then
			print(color.red "ERROR: Bad hash for HEADERS")
		end
		local head = cmsgpack.unpack(_d)
		_d = fs.readFileSync(db_name.."/CHUNKMAP")
		if (xxh32(_d, magic_number) ~= hashes["CHUNKMAP"]) then
			print(color.red "ERROR: Bad hash for CHUNKMAP")
		end
		local map = cmsgpack.unpack(_d)
		--_d = fs.readFileSync(db_name.."/CHUNKCACHE")
		--if (xxh32(_d, magic_number) ~= hashes["CHUNKCACHE"]) then
		--	print(color.red "ERROR: Bad hash for CHUNKCACHE")
		--end
		--local cache = cmsgpack.unpack(_d)
		_d = nil
		local head = cmsgpack.unpack(fs.readFileSync(db_name.."/HEADERS"))
		local map = cmsgpack.unpack(fs.readFileSync(db_name.."/CHUNKMAP"))
		--local cache = cmsgpack.unpack(fs.readFileSync(db_name.."/CHUNKCACHE"))
		if (#head.col ~= #headers) then
			local oldhead = deepcopy(head.col)
			head.col = headers
			print("Updating database...")
			for f in fs.scandirSync(db_name) do
				if (fs.statSync(db_name.."/"..f).type == "file" and f ~= "HEADERS" and f ~= "CHUNKMAP" and f ~= "CHUNKCACHE" and f ~= "XXHASH32") then
					local data = cmsgpack.unpack(fs.readFileSync(db_name.."/"..f))
					for i=1,#data do
						for x=1,#headers do
							if (type(data[i][x]) ~= headers[x][2]) then
								data[i][x] = settings.defaultval[headers[i]]
							end
						end
					end
					_d = cmsgpack.pack(data)
					hashes[f] = xxh32(_d, magic_number)
					fs.writeFileSync(db_name.."/"..f, _d)
				end
			end
			db.hashes=hashes
			db.headers=head
			db.map=map
			db.chunkcache=cache
			setmetatable(db, {__index = db_object})
			db:CleanUp()
			db:GenerateCache()
			db.lchunk=db:NewChunk()
			return db
		else
			db.headers=head
			db.map=map
			db.chunkcache = cache
			setmetatable(db, {__index = db_object})
			db:CleanUp()
			db:GenerateCache()
			db.lchunk=db:NewChunk()
			return db
		end
	else
		fs.mkdirSync(db_name)
		db.dbname = db_name
		db.headers.col = headers
		db.headers.options = {}
		db.headers.options.chunksize = options.chunksize or settings.chunksize
		db.headers.options.loadall = options.loadall or settings.loadall
		db.headers.version = "2.0"
		db.headers.etc = options
		db.headers.sig = "JRDB2.0"
		db.headers.uuid = math.random(0, (2^32)-1)
		db.headers.cache = {}
		--[[for i=1, #cachedcols do
			for x=1, #headers do
				if (cachedcols[i] == headers[x][1]) then
					db.headers.cache[#db.headers.cache] = x
					break;
				end
			end
		end]]
		db.headers.cache = cachedcols
		db.headers.index = 1
		for i=1, #headers do
			if (options.index == headers[i][1]) then
				db.headers.index = i
				break;
			end
		end
		fs.writeFileSync(db_name.."/HEADERS", cmsgpack.pack(db.headers))
		fs.writeFileSync(db_name.."/CHUNKMAP", cmsgpack.pack(db.map))
		--fs.writeFileSync(db_name.."/CHUNKCACHE", cmsgpack.pack(db.chunkcache))
		db.hashes["HEADERS"] = xxh32(cmsgpack.pack(db.headers), magic_number)
		db.hashes["CHUNKMAP"] = xxh32(cmsgpack.pack(db.map), magic_number)
		--db.hashes["CHUNKCACHE"] = xxh32(cmsgpack.pack(db.map), magic_number)
		fs.writeFileSync(db_name.."/XXHASH32", cmsgpack.pack(db.hashes))
		setmetatable(db, {__index = db_object})
		db.lchunk=db:NewChunk()
		return db
	end
end
function db_object:index(index)
	p('ok')
	local cid = self.map[index]
	--p(self.map)
	--p(index)
	--p(self.map[index])
		if (cid ~= nil) then
			if (self.chunks[cid] == nil) then
				self:LoadChunk(cid)
				--p("loading chunk")
			end
			p(self.chunks)
			if (self.chunks[cid] ~= nil) then
				for i=1, #self.chunks[cid] do
					if (self.chunks[cid][i][self.headers.index] == index) then
						p('we found it')
						p(self.chunks[cid][i])
						return self.chunks[cid][i]
					else
						p(self.chunks[cid][i][self.headers.index])
						p(self.chunks[cid][i][self.headers.index]..'~='..index)
					end
				end
			end
		end
		p('cid is nil')
		return nil
end
function db_object:LoadChunk(chunkid)
	if (chunkid == "HEADERS" or chunkid == "CHUNKMAP" or chunkid == "CHUNKCACHE" and chunkid == "XXHASH32") then
		return nil, "Invalid Chunk ID"
	end
	p(chunkid)
	if (fs.existsSync(chunkid)) then
		p('why')
		local _d = fs.readFileSync(self.dbname.."/"..chunkid)
		if (self.hashes[chunkid] ~= xxh32(_d, magic_number)) then
			print(color.red("ERROR: Bad hash for "..chunkid))
		end
		p(_d)
		self.chunks[chunkid] = cmsgpack.unpack(_d)
		self.chunkage[chunkid] = os.time()
		return true
	end
	return nil, "Invalid Chunk ID"
end
function db_object:NewChunk()
	math.randomseed(math.random(1,2^32)*math.random(1,2^32))
	local id = hex[math.random(1, 16)]..hex[math.random(1, 16)]..hex[math.random(1, 16)]..hex[math.random(1, 16)]..hex[math.random(1, 16)]..hex[math.random(1, 16)]..hex[math.random(1, 16)]..hex[math.random(1, 16)]..hex[math.random(1, 16)]..hex[math.random(1, 16)]..hex[math.random(1, 16)]..hex[math.random(1, 16)]
	while (fs.existsSync(id)) do
		id = hex[math.random(1, 16)]..hex[math.random(1, 16)]..hex[math.random(1, 16)]..hex[math.random(1, 16)]..hex[math.random(1, 16)]..hex[math.random(1, 16)]..hex[math.random(1, 16)]..hex[math.random(1, 16)]..hex[math.random(1, 16)]..hex[math.random(1, 16)]..hex[math.random(1, 16)]..hex[math.random(1, 16)]
	end
	fs.writeFileSync(self.dbname.."/"..id, cmsgpack.pack({}))
	lchunk = id
	self.chunks[id] = {}
	return id
end

function db_object:LoadIndex(index)
	if (self.map[index] ~= nil) then
		local chunkid = self.map[index]
		if (self.chunks[chunkid] ~= nil) then
			--[[if (self.chunkcache[index] == nil and #self.headers.cache > 0) then
				self.chunkcache[index] = {}
				for i=0, #self.headers.cache do
					self.chunkcache[index][i] = self:index(id)[self.headers.cache[i]-]
				end
			end]]
			local here = 0
			for i=1, #self.chunkcache do
				if (self.chunkcache[i][self.headers.index] == index) then
					here = 1
					self.chunkcache[i] = {}
					for x=1, #self.headers.cache do
						self.chunkcache[i][x] = self:index(index)[self.headers.cache[x]]
					end
					break;
				end
			end
			if (here == 0) then
				self.chunkcache[#self.chunkcache+1] = {}
				for x=1, #self.headers.cache do
					self.chunkcache[#self.chunkcache][x] = self:index(index)[self.headers.cache[x]]
				end
			end
			p('wam! return!')
			p(self.map[index])
			p(index)
			return self:index(index)
		else
			p('loading chunk')
			self:LoadChunk(chunkid)
			return self:index(index)
		end
	end
	p('womp womp')
	return nil, "Invalid index."

end
function db_object:CheckData(data)
	if (#self.headers.col ~= #data) then
		print("failed length check", #self.headers.col.."~="..#data)
		return false
	end
	for i=1, #data do
		if (type(data[i]) ~= self.headers.col[i][2]) then
			print("failed type check", type(data[i]).."~="..self.headers.col[i][2], i)
			return false
		end
	end
	return true
end
function db_object:SaveChunk(chunkid)
	if (self.chunks[chunkid] ~= nil) then
		local _d = cmsgpack.pack(self.chunks[chunkid])
		self.hashes[chunkid] = xxh32(_d, magic_number)
		fs.writeFileSync(self.dbname.."/"..chunkid, _d)
	end
end

function db_object:SaveHeaders()
	fs.writeFileSync(self.dbname.."/HEADERS", cmsgpack.pack(self.headers))
	fs.writeFileSync(self.dbname.."/CHUNKMAP", cmsgpack.pack(self.map))
	--fs.writeFileSync(self.dbname.."/CHUNKCACHE", cmsgpack.pack(self.chunkcache))
	self.hashes["HEADERS"] = xxh32(cmsgpack.pack(self.headers), magic_number)
	self.hashes["CHUNKMAP"] = xxh32(cmsgpack.pack(self.map), magic_number)
	--self.hashes["CHUNKCACHE"] = xxh32(cmsgpack.pack(self.map), magic_number)
	fs.writeFileSync(self.dbname.."/XXHASH32", cmsgpack.pack(self.hashes))
end
function db_object:NewIndex(data)
	--p(data)
	--p(self:CheckData(data))
	if (not self:CheckData(data)) then return end
	--p(#self.chunks[lchunk], self.headers.options.chunksize)
	--p(self.headers.options.chunksize)
	if (self.map[data[self.headers.index]] ~= nil) then return end
	p(self.lchunk)
	if (#self.chunks[self.lchunk] >= self.headers.options.chunksize and not self.headers.options.loadall) then
		self:SaveChunk(self.lchunk)
		self:NewChunk()
	end
	--[[if (self.chunkcache[data[self.headers.index]-] == nil and #self.headers.cache > 0) then
		self.chunkcache[data[self.headers.index]-] = {}
		for i=0, #self.headers.cache do
			self.chunkcache[data[self.headers.index]-][i] = data[i]
		end
	end]]
	self.chunkcache[#self.chunkcache+1] = {}
	for x=1, #self.headers.cache do
		self.chunkcache[#self.chunkcache][x] = data[x]
	end
	self.chunks[self.lchunk][#self.chunks[self.lchunk]+1] = data
	--p(self.headers.index)
	--p(data[self.headers.index])
	self.map[data[self.headers.index]] = self.lchunk
	self:SaveChunk(self.lchunk)
	--p(self)
	return lchunk, #self.chunks[self.lchunk]
end
function db_object:DeleteIndex(index)
	local cid = self.map[index]
	if (cid ~= nil) then
		if (self.chunks[cid] == nil) then
			self:LoadChunk(cid)
		end
		for i=1, #self.chunks[cid] do
			if (self.chunks[cid][i][self.headers.index] == index) then
				table.remove(self.chunks[cid], i)
				break;
			end
		end
		self.map[index] = nil
		self.chunkcache[index] = nil
		self:SaveHeaders()
	end
end

function db_object:Size()
	return #self.map
end

function db_object:Truncate()
	for k, v in pairs(self.map) do
		if (fs.existsSync(self.chunks[v])) then
			fs.unlinkSync(self.dbname.."/"..v)
			self.map[k] = nil
		end
	end
	self:SaveHeaders()
end

function db_object:GetColId(name)
	for i=1, #self.headers.col do
		if (name == self.headers.col[i]) then
			return i
		end
	end
end

function db_object:GetChunkId(index)
	return self.map[index]
end

function db_object:GetCache()
	return self.chunkcache
end

function db_object:CollectGarbage()
	for k, v in pairs(self.chunkage) do
		if (v+60*60 < os.time()) then
			self:SaveChunk(k)
			self.chunkage[k] = nil
			self.chunks[k] = nil
		end
	end
end

function db_object:UpdateChunkCache(id)
	for i=1, #self.chunkcache do
		if (self.chunkcache[i][self.headers.index] == id) then
			self.chunkcache[i] = {}
			for x=1, #self.headers.cache do
				self.chunkcache[i][x] = self:index(id)[self.headers.cache[x]]
			end
			break;
		end
	end
end

function db_object:CleanUp()
	print("Cleaning up database chunks...")
	for f in fs.scandirSync(self.dbname) do
		if (fs.statSync(self.dbname.."/"..f).type == "file" and f ~= "HEADERS" and f ~= "CHUNKMAP" and f ~= "CHUNKCACHE" and f ~= "XXHASH32") then
			local data = cmsgpack.unpack(fs.readFileSync(self.dbname.."/"..f))
			if (#data == 0) then
				print("Deleting orphaned chunk "..f)
				fs.unlinkSync(self.dbname.."/"..f)
			end
		end
	end
end
--Only use this for generating the cache initially! This is super taxing on the server!
function db_object:MountAll()
	print("Mounting all chunks...")
	for f in fs.scandirSync(self.dbname) do
		if (fs.statSync(self.dbname.."/"..f).type == "file" and f ~= "HEADERS" and f ~= "CHUNKMAP" and f ~= "CHUNKCACHE" and f ~= "XXHASH32") then
			self:LoadChunk(f)
		end
	end
	print("Mounted.")
end

function db_object:GenerateCache()
	self.chunkcache = {}
	self:MountAll()
	print("Generating cache...")
	for k, _ in pairs(self.map) do
		local in_ = self:index(k)
		--if (in_) then
			self.chunkcache[#self.chunkcache+1] = {}
			for x=1, #self.headers.cache do
				self.chunkcache[#self.chunkcache][x] = in_[self.headers.cache[x]]
			end
		--end
	end
	p(self.chunkcache)
	p(self.headers.cache)
end

return {LoadDB = LoadDB}

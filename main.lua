--Version and requires
_G.version = "0.4.1"
_G.weblit = require('weblit')
_G.static = require('weblit-static')
_G.json = require("json").use_lpeg()
_G.fs = require("fs")
_G.timer = require('timer')
_G.db = require('newdb')
_G.cfg = require('cfg')
_G.CRC32 = require('crc32')
_G.pathJoin = require('pathjoin').pathJoin
_G.thread = require('thread')
_G.utf8 = require('utf8')

--Variables and useful functions.
_G.Mobile = {}
_G.Main = {}
_G.DBManager = {}
_G.boards = {}
_G.bannedips = {}
_G.stats = {}
_G.cache = {}
_G.dbcrc = 0
_G.adminscript = ""
_G.restart = false
_G.pagecache = {}
_G.staff = {}
local adminkey = ""
local function log(s, l)
	l = l or "INFO"
	fs.appendFileSync(pathJoin(module.dir, "access.log"), "["..os.date('%Y-%m-%d %H:%M:%S', os.time()).." "..l.."] "..s.."\r\n")
end
function trim(s)
  -- from PiL2 20.4
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end
function parse_markdown(fstring)
	fstring = fstring or ""
	local of = #fstring
	local f = {fstring:find("(%*%*.-%*%*)")}
	local ic = 0
	while (f[3]) do
		if (ic > of/2) then break end
		local repl = f[3]:gsub("%*%*", "")
		local r = f[3]:gsub("%*%*", "%%*%%*")
		fstring = fstring:gsub(r, "<b>"..repl.."</b>")
		f = {fstring:find("(%*%*.-%*%*)")}
		ic = ic+1
	end
	f = {fstring:find("(%*.-%*)")}
	local ic = 0
	while (f[3]) do
		if (ic > of/2) then break end
		local repl = f[3]:gsub("*", "")
		local r = f[3]:gsub("*", "%%*")
		fstring = fstring:gsub(r, "<i>"..repl.."</i>")
		f = {fstring:find("(%*.-%*)")}
		ic = ic+1
	end
	f = {fstring:find("(_.-_)")}
	local ic = 0
	while (f[3]) do
		if (ic > of/2) then break end
		local repl = f[3]:gsub("_", "")
		fstring = fstring:gsub(f[3], "<u>"..repl.."</u>")
		f = {fstring:find("(_.-_)")}
		ic = ic+1
	end
	f = {fstring:find("(~~.-~~)")}
	local ic = 0
	while (f[3]) do
		if (ic > of/2) then break end
		local repl = f[3]:gsub("~~", "")
		fstring = fstring:gsub(f[3], "<strike>"..repl.."</strike>")
		f = {fstring:find("(~~.-~~)")}
		ic = ic+1
	end
	f = {fstring:find("({#%x%x%x%x%x%x}%(.-%))")}
	local ic = 0
	while (f[3]) do
		if (ic > of/2) then break end
		local r = f[3]:gsub("%(", "%%("):gsub("%)", "%%)")
		local _,_,c = f[3]:find("({#%x%x%x%x%x%x})")
		local _, _, t = f[3]:find("(%(.-%))")
		c = c:sub(2, #c-1)
		if (c == "#000000") then
			c = "#FFFFFF"
		end
		t = t:sub(2, #t-1)
		fstring = fstring:gsub(r, "<span style=\"color:"..c.."\">"..t.."</span>")
		f = {fstring:find("({#%x%x%x%x%x%x}%(.-%))")}
		ic = ic+1
	end
	f = {fstring:find("(%[http(s?)://[%a%d%./%%_%-=%?&]-%]%(.-%))")}
	local ic = 0
	while (f[3]) do
		if (ic > of/2) then break end
		local r = f[3]:gsub("%(", "%%("):gsub("%)", "%%)"):gsub("%[", "%%["):gsub("%]", "%%]")
		local _,_,l = f[3]:find("(%[http(s?)://[%a%d%./%%_%-=%?&]-%])")
		local _, _,t = f[3]:find("(%(.-%))")
		if (l ~= nil) then
			l = l:sub(2, #l-1)
			t = t:sub(2, #t-1)
			fstring = fstring:gsub(r, "<a  target=\"_blank\" class=\"userlink\" href=\""..l.."\">"..t.."</a>")
		end
		f = {fstring:find("(%[.-%]%(.-%))")}
		ic = ic+1
	end
	return fstring
end

function explode(d,p)
   local t, ll
   t={}
   ll=0
   if(#p == 1) then
      return {p}
   end
   while true do
      l = string.find(p, d, ll, true) -- find the next d in the string
      if l ~= nil then -- if "not not" found then..
         table.insert(t, string.sub(p,ll,l-1)) -- Save it in our array.
         ll = l + 1 -- save just after where we found it for searching next time.
      else
         table.insert(t, string.sub(p,ll)) -- Save what's left in our array.
         break -- Break at end, as it should be, according to the lua manual.
      end
   end
   return t
end
local function split(inputstr)
        local t={} ; i=1
        for str in string.gmatch(inputstr, "([^\r\n]+)") do
                t[i] = str
                i = i + 1
        end
        return t
end
string.startsWith = function(self, str)
    return self:find('^' .. str) ~= nil
end
local function escape_html(text)
	return text:gsub("<", "&lt;"):gsub(">", "&gt;")
end
local function parse_text(text)
	local msg = split(text:gsub("%%", "&#37;"))
	for i=1, #msg do
		if (msg[i]:startsWith("&gt;") or msg[i]:startsWith(">")) then
			msg[i] = "<span style=\"color:#A229FF\">"..msg[i].."</span>"
		end
	end
	--p(msg)
	return parse_markdown(table.concat(msg, "<br>\r\n"))
end
local function loadThread(board, id)
	p('reeeeeeeeeeeee')
	return boards[board]:LoadIndex(id)
end
function addReply(board, id, ip, msg, admin)
	--p(board, id)
	local thd, err = loadThread(board, id)
	thd[5] = os.time()
	if (admin) then
		thd[4][#thd[4]+1] = {ip, msg, admin}
	else
		thd[4][#thd[4]+1] = {ip, msg}
	end
	boards[board]:UpdateChunkCache(id)
end
function getReply(board, rid, isAdmin)
	local reply = board[4][rid]
	if (isAdmin) then
		if (#reply == 3) then
			return "<div style=\"color:"..reply[3][2]..";text-align:left;\">&nbsp;&nbsp;&nbsp;"..reply[3][1].." <span style=\"color:white\">"..reply[1].." <i class=\"fa fa-trash\" onclick=\"deleteP('"..rid.."')\"></i> <i class=\"fa fa-ban\" onclick=\"ipban('"..reply[1].."')\"></i></span></div><div class=\"post\">"..reply[2].."</div><br>\n"
		else
			reply[1] = reply[1] or "localhost"
			return "<div style=\"color:white;text-align:left;\">&nbsp;&nbsp;&nbsp;"..reply[1].." <i class=\"fa fa-trash\" onclick=\"deleteP('"..rid.."')\"></i> <i class=\"fa fa-ban\" onclick=\"ipban('"..reply[1].."')\"></i></div><div class=\"post\">"..reply[2].."</div><br>\n"
		end
	else
		if (#reply == 3) then
			return "<div style=\"color:"..reply[3][2]..";text-align:left;\">&nbsp;&nbsp;&nbsp;"..reply[3][1].."</div><div class=\"post\">"..reply[2].."</div><br>\n"
		else
			return "<div class=\"post\">"..reply[2].."</div><br>\n"
		end
	end
end
--Load plugins (Not ready yet)

--TODO actually add plugins maybe?

--Bind the IPs
Main = weblit.app.bind({host = "127.0.0.1", port = 1337})
Main.bind({host = "127.0.0.1", port=2337, tls={cert = module:load("cert.pem"), key = module:load("key.pem")}})
Mobile = weblit.app.bind({host = "127.0.0.1", port = 1338})
Mobile.bind({host = "127.0.0.1", port=2338, tls={cert = module:load("cert.pem"), key = module:load("key.pem")}})
DBManager = weblit.app.bind({host = "127.0.0.1", port=8080})

--Load databases and cached pages
for i = 1, #cfg.boards do
	boards[cfg.boards[i]] = db.LoadDB(pathJoin(module.dir, cfg.boards[i].."_board"), {{"id", "string"}, {"name", "string"}, {"locked", "boolean"}, {"posts", "table"}, {"lastupdated", "number"}, {"marked", "boolean"}, {"op-ip", "string"}, {"pinned", "boolean"}}, {index="id", cache={1,2,3,5,6,7,8}})
	boards[cfg.boards[i]]:SaveHeaders()
end
pagecache = {
	boards = fs.readFileSync(pathJoin(module.dir, "boards.html")),
	threads = fs.readFileSync(pathJoin(module.dir, "threads.html")),
	new = fs.readFileSync(pathJoin(module.dir, "new.html")),
	thread = fs.readFileSync(pathJoin(module.dir, "thread.html")),
	teapot = fs.readFileSync(pathJoin(module.dir, "teapot.html")),
	["404"] = fs.readFileSync(pathJoin(module.dir, "404.html")),
	["blocked"] = fs.readFileSync(pathJoin(module.dir, "blocked.html")),
	["admin"] = fs.readFileSync(pathJoin(module.dir, "admin.html")),
}
adminscript = fs.readFileSync(pathJoin(module.dir, "adminscript.js"))
staff = json.parse(fs.readFileSync(pathJoin(module.dir, "staff.db"))) or {}
ipbans = json.parse(fs.readFileSync(pathJoin(module.dir, "ipbans.db"))) or {}

--Start the main website.
Main.use(function (req, res, go)
	--Custom logging function
	local userAgent = req.headers["user-agent"] or ""
	-- Run all inner layers first.
	go()
	-- And then log after everything is done
	log(string.format("%s %s %s %s %s", req.headers["X-Forwarded-For"] or "localhost", req.method, req.path, userAgent, res.code))
end)
--Load the automatic headers
.use(weblit.autoHeaders)
--Put in custom headers and custom error page
.use(function (req, res, go)
	res.headers["Content-Type"] = "text/html; charset=utf-8"
	res.headers["Board-Software"] = "Laine "..version
	res.headers["X-Powered-By"] = jit.version.." "..jit.arch
	res.headers["Server"] = "Luvit 2.14.2"
	res.body = pagecache["404"]
	return go()
end)
--ROUTE THE ASSETS BEFORE THE BAN MIDDLEWARE
.route({path = "/static/assets/:path:"}, static(pathJoin(module.dir, "assets")))
--Now for the IP Ban middleware
.use(function(req, res, go)
	req.ip = req.headers["X-Forwarded-For"] or "localhost" --Set IP in request as getting peer IP from the socket does not work
	if ((bannedips[req.headers["X-Forwarded-For"] or "localhost"] or {}).ban) then
		if (bannedips[req.headers["X-Forwarded-For"] or "localhost"].unban < os.time() or (req.headers.cookie == adminkey)) then
			if ((req.headers.cookie ~= adminkey)) then
				p("Unbanned "..(req.headers["X-Forwarded-For"] or "localhost"))
				log("Unbanned "..(req.headers["X-Forwarded-For"] or "localhost"), "AUTOBAN")
			end
			bannedips[req.headers["X-Forwarded-For"] or "localhost"].ban = 0
			return go()
		end
		--Banned. Bad.
		bannedips[req.headers["X-Forwarded-For"] or "localhost"].note = bannedips[req.headers["X-Forwarded-For"] or "localhost"].note or ""
		res.body = pagecache["blocked"]:gsub("<TIME />", tostring(bannedips[req.headers["X-Forwarded-For"] or "localhost"].unban)):gsub("<NOTE />", bannedips[req.headers["X-Forwarded-For"] or "localhost"].note)
		res.code = 401
		return
	end
	return go()
end)
--I'm a little teapot short and stout...
.route({
  	path = "/teapot"
}, function (req, res)
	res.body = pagecache.teapot
	res.code = 418
end)
--Access.log for admins.
.route({
  	path = "/access.log"
}, function (req, res)
	if ((req.headers.cookie ~= adminkey)) then return end
	res.body = fs.readFileSync(pathJoin(module.dir, "access.log"))
	res.headers["Content-Type"] = "text/plain; charset=utf-8"
	res.code = 200
end)
--Restart the server (I don't think it works)
.route({
  	path = "/restart"
}, function (req, res)
	--p(req.headers.cookie)
	p(req.headers)
	if ((req.headers.cookie ~= adminkey)) then return end
	_G.restart = true
	p(restart)
	print("aaa")
	res.body = "ok"
	res.headers["Content-Type"] = "text/html; charset=utf-8"
	res.code = 200
end)
--Admin panel. (WIP)
.route({
  	path = "/admin"
}, function (req, res)
	if ((req.headers.cookie ~= adminkey)) then return end
	res.body = pagecache.admin
	res.code = 200
end)
--For the admin panel
.route({
  	path = "/getban"
}, function (req, res)
	if ((req.headers.cookie ~= adminkey)) then return end
	if (req.query) then
		if (req.query.type=="list") then
			res.body = ""
			local arr = {}
			res.headers["Content-Type"] = "application/json; charset=utf-8"
			for k, v in ipairs(bannedips) do
				if (v.ban) then
					arr[#arr+1] = k
				end
			end
			res.body = json.stringify(arr)
			res.code = 200
		elseif (req.query.type=="info") then
			res.body = json.stringify(bannedips[req.query.ip])
			res.headers["Content-Type"] = "application/json; charset=utf-8"
			res.code = 200
		end
	else
		if (req.body) then
			local data = json.parse(req.body)
			local cmd = data.cmd
			if (cmd == "unban") then
				bannedips[data.ip].ban = false
			end
			if (cmd == "reset") then
				bannedips[data.ip] = {
					pcount = 0,
					npost = os.time(),
					crc = CRC32.Hash(""),
					crccount = 0,
					ncrc = os.time(),
					ban = false,
					unban = os.time(),
					nextban = 24*24*60,
					note = ""
				}
			end
			if (cmd == "addnote") then
				bannedips[data.ip].note = data.note
				bannedips[data.ip].note = data.note
			end
			res.body = json.stringify({status=0})
			res.code = 200
		end
	end
end)
.route({
	path="/:board"
}, function(req, res)
	--p(req.params.board)
	if (boards[req.params.board] == nil) then
	local add = ""
		for i = 1, #cfg.boards do
			add = add.."<a href=\"/"..cfg.boards[i].."\">/"..cfg.boards[i].."/ - "..cfg.desc[cfg.boards[i]][1].."</a><br>\n"
		end
		res.body = pagecache.boards:gsub("<VERSION />", version):gsub("<BOARDS />", add)
		res.code = 200
		return
	elseif (boards[req.params.board] ~= nil) then
		local board = boards[req.params.board]
		local data = board:GetCache()
		table.sort(data, function(a, b)
			if (a[7] and b[7]) then return a[4] > b[4] end
			if a[7] then return true end
			if b[7] then return false end
			return a[4] > b[4]
		end)
		local add = ""
		for i=1, #data do
			local class = ""
            p(data[i][3])
			if (data[i][3] == true) then
				class = " class=\"closed_thread\""
			end
			local pinned = ""
			if (data[i][7]) then
				pinned = "<span style=\"color:yellow\">PINNED:</span> "
			end
			local pre = ""
			if (req.headers.cookie == adminkey) then
				if (data[i][3]) then
					pre = "<i onclick=\"unlock('"..data[i][1].."')\" class=\"fa fa-unlock\"></i> <i onclick=\"deleteT('"..data[i][1].."')\" class=\"fa fa-trash\"></i> "
				else
					pre = "<i onclick=\"lock('"..data[i][1].."')\" class=\"fa fa-lock\"></i> <i onclick=\"deleteT('"..data[i][1].."')\" class=\"fa fa-trash\"></i> "
				end
				if (not data[i][7]) then
					pre = pre .. "<i class=\"fa fa-thumb-tack\" style=\"color:white\" onclick=\"pin('"..data[i][1].."')\"></i> "
				else
					pre = pre .. "<i class=\"fa fa-thumb-tack\" style=\"color:yellow\" onclick=\"unpin('"..data[i][1].."')\"></i> "
				end
			end
			add = add..pre.."<a href=\"/"..req.params.board.."/"..data[i][1].."\" x-data-id=\""..data[i][1].."\">"..pinned..data[i][2].."</a><br>\n"
		end
		local as = ""
		if (req.headers.cookie == adminkey) then
			as = adminscript
		end
		--p(req.params.board)
		--p(version)
		--p(add)
		--p(cfg.desc[req.params.board])
		--p(cfg.quip[req.params.board])
		--p(as)
		res.body = pagecache.threads:gsub("<BOARD />", req.params.board):gsub("<VERSION />", version):gsub("<DESC1 />", cfg.desc[req.params.board][1]):gsub("<DESC2 />", cfg.desc[req.params.board][2]):gsub("<THREADS />", add):gsub("<QUIP />", cfg.quip[req.params.board]):gsub("<ADMINSCRIPT />", as)
		res.code = 200
	end
end)
 .route({  path = "/:board/post"}, function (req, res)
	if (req.headers.cookie ~= adminkey) then
		if (not bannedips[req.ip]) then
			bannedips[req.ip] = {
				pcount = 1,
				npost = os.time()+1,
				crc = CRC32.Hash(req.body or ""),
				crccount = 1,
				ncrc = os.time()+30,
				ban = false,
				unban = os.time(),
				nextban = 24*24*60,
				note = ""
			}
		else
			local crc = CRC32.Hash(req.body or "")
			local tim = os.time()
			local bip = bannedips[req.ip]
			if (os.time() > bip.npost) then
				bip.pcount = 1
				bip.npost = os.time()+1
			else
				bip.pcount=bip.pcount+1
				if (bip.pcount == 3) then
					bip.ban = true
					bip.unban = os.time()+bip.nextban
					bip.nextban = bip.nextban*2
					res.body = pagecache["blocked"]:gsub("<TIME />", tostring(bip.unban))
					res.code = 401
					p("Banned "..(req.headers["X-Forwarded-For"] or "localhost"))
					log("Banned "..(req.headers["X-Forwarded-For"] or "localhost"), "AUTOBAN")
					return
				end
			end
			if (os.time() > bip.ncrc) then
				bip.crc = crc
				crccount = 1
			else
				if (crc == bip.crc) then
					bip.crccount=bip.crccount+1
					if (bip.crccount == 5) then
						bip.ban = true
						bip.unban = os.time()+bip.nextban
						bip.nextban = bip.nextban*2
						res.body = pagecache["blocked"]:gsub("<TIME />", tostring(bip.unban))
						res.code = 401
						p("Banned "..(req.headers["X-Forwarded-For"] or "localhost"))
						log("Banned "..(req.headers["X-Forwarded-For"] or "localhost"), "AUTOBAN")
						return
					end
				else
					bip.crc = CRC32.Hash(req.body or "")
					bip.crccount = 1
					bip.ncrc = os.time()+30
				end
			end
		end
	end
	req.headers.cookie = req.headers.cookie or ""
	if (req.headers.cookie == adminkey) then
		local data = json.parse(req.body)
		local thd, err = boards[data.board]:LoadIndex(data.id)
		if (err) then return end
		if (data.content == "@lock") then
			thd[3] = true
			--thd[4][#thd[4]+1]={{"ADMIN.Sam", "#C178FF"}, "<span style=\"color:darkred\">This thread has been locked</span>"}
			addReply(data.board, data.id, req.headers["X-Forwarded-For"], "<span style=\"color:darkred\">This thread has been locked</span>", {"ADMIN.Sam", "#C178FF"})
			res.body = "ok"
			res.code = 200
			return
		end
		if (data.content == "@unlock") then
			thd[3] = false
			--thd[4][#thd[4]+1]={{"ADMIN.Sam", "#C178FF"}, "<span style=\"color:darkred\">This thread has been locked</span>"}
			addReply(data.board, data.id, req.headers["X-Forwarded-For"], "<span style=\"color:green\">This thread has been unlocked.</span>", {"ADMIN.Sam", "#C178FF"})
			res.body = "ok"
			res.code = 200
			return
		end
		if (data.content == "@mark") then
			thd[3] = true
			thd[6] = true
			addReply(data.board, data.id, req.headers["X-Forwarded-For"], "<span style=\"color:darkred\">This thread has been locked and marked for deletion</span>", {"ADMIN.Sam", "#C178FF"})
			res.body = "ok"
			res.code = 200
			return
		end
		if (data.content == "@banip") then
			addReply(data.board, data.id, req.headers["X-Forwarded-For"], "<span style=\"color:darkred\">User with IP "..data.ip:sub(1, 3)..".xxx.xxx.xxx has been banned.</span>", {"ADMIN.Sam", "#C178FF"})
			local bip = bannedips[data.ip]
			bip.ban = true
			bip.unban = os.time()+bip.nextban
			bip.nextban = bip.nextban*2
			res.body = "ok"
			res.code = 200
			return
		end
		if (data.content == "@del") then
			table.remove(thd[4], data.rid)
			res.body = "ok"
			res.code = 200
			return
		end
		if (data.content == "@pin") then
			thd[8] = true
			--thd[4][#thd[4]+1]={{"ADMIN.Sam", "#C178FF"}, "<span style=\"color:darkred\">This thread has been locked</span>"}
			addReply(data.board, data.id, req.headers["X-Forwarded-For"], "<span style=\"color:yellow\">This thread has been pinned</span>", {"ADMIN.Sam", "#C178FF"})
			res.body = "ok"
			res.code = 200
			return
		end
		if (data.content == "@unpin") then
			thd[8] = false
			--thd[4][#thd[4]+1]={{"ADMIN.Sam", "#C178FF"}, "<span style=\"color:darkred\">This thread has been locked</span>"}
			addReply(data.board, data.id, req.headers["X-Forwarded-For"], "<span style=\"color:darkred\">This thread has been unpinned</span>", {"ADMIN.Sam", "#C178FF"})
			res.body = "ok"
			res.code = 200
			return
		end
		if (data.content == "@restart") then
			restart = true
			res.body = "ok"
			res.code = 200
			return
		end
		--thd[4][#thd[4]+1]={{"ADMIN.Sam", "#C178FF"}, parse_text(data.content)}
		addReply(data.board, data.id, req.headers["X-Forwarded-For"], parse_text(data.content), {"ADMIN.Sam", "#C178FF"})
		thd[5] = os.time()
	else
		if (req.body == nil) then
			return
		end
		local data = json.parse(req.body)
		if (data == nil) then
			return
		end
		local thd, err = boards[data.board]:LoadIndex(data.id)
		if (err) then return end
		if (thd[3]) then
			res.body = "ok"
			res.code = 200
			return
		end
		--thd[4][#thd[4]+1]=parse_text(escape_html(data.content))
		if (utf8.len(data.content) > 500) then
			data.content = "i'm a spamfag!"
		end
		addReply(data.board, data.id, req.headers["X-Forwarded-For"], parse_text(escape_html(data.content)))
		thd[5] = os.time()
	end
    res.body = "ok"
    res.code = 200
end)
.route({  path = "/:board/nt"}, function (req, res)
	if (req.headers.cookie ~= adminkey) then
		if (not bannedips[req.ip]) then
			bannedips[req.ip] = {
				pcount = 1,
				npost = os.time()+1,
				crc = CRC32.Hash(req.body or ""),
				crccount = 1,
				ncrc = os.time()+30,
				ban = false,
				unban = os.time(),
				nextban = 24*24*60,
				note = ""
			}
		else
			local crc = CRC32.Hash(req.body or "")
			local tim = os.time()
			local bip = bannedips[req.ip]
			if (os.time() > bip.npost) then
				bip.pcount = 1
				bip.npost = os.time()+1
			else
				bip.pcount=bip.pcount+1
				if (bip.pcount == 3) then
					bip.ban = true
					bip.unban = os.time()+bip.nextban
					bip.nextban = bip.nextban*2
					res.body = pagecache["blocked"]:gsub("<TIME />", tostring(bip.unban))
					res.code = 401
					p("Banned "..(req.headers["X-Forwarded-For"] or "localhost"))
					log("Banned "..(req.headers["X-Forwarded-For"] or "localhost"), "AUTOBAN")
					return
				end
			end
			if (os.time() > bip.ncrc) then
				bip.crc = crc
				crccount = 1
			else
				if (crc == bip.crc) then
					bip.crccount=bip.crccount+1
					if (bip.crccount == 3) then
						bip.ban = true
						bip.unban = os.time()+bip.nextban
						bip.nextban = bip.nextban*2
						res.body = pagecache["blocked"]:gsub("<TIME />", tostring(bip.unban))
						res.code = 401
						p("Banned "..(req.headers["X-Forwarded-For"] or "localhost"))
						log("Banned "..(req.headers["X-Forwarded-For"] or "localhost"), "AUTOBAN")
						return
					end
				else
					bip.crc = CRC32.Hash(req.body or "")
					bip.crccount = 1
					bip.ncrc = os.time()+30
				end
			end
		end
	end
	if (req.body == nil) then
		return
	end
	--p(req.body)
	local data = json.parse(req.body)
	if (data == nil) then
		return
	end
	local id = tostring(math.random(1, 2^32))
	local escaped_title = escape_html(data.title)
	while (boards[data.board]:LoadIndex(id) ~= nil) do
		id = tostring(math.random(1, 2^32))
	end
	req.headers.cookie = req.headers.cookie or ""
	if (req.headers.cookie == adminkey) then
		--boards[data.board]:NewRow({id, escaped_title, false, {}, os.time(), false, req.headers["X-Forwarded-For"], false})
		boards[data.board]:NewIndex({id, escaped_title, false, {}, os.time(), false, req.headers["X-Forwarded-For"], false})
		addReply(data.board, id, req.headers["X-Forwarded-For"], parse_text(data.content), {"ADMIN.Sam", "#C178FF"})
	else
		local escaped_html = parse_text(escape_html(trim(data.content)))
		if (utf8.len(data.content) > 500) then
			escaped_html = "i'm a spamfag!"
		end
		if (#trim(data.content) < 1) then
			escaped_html = "i'm a blankfag!"
		end
		if (utf8.len(data.title) > 40) then
			escaped_title = "help i am a llama and i want some fuck"
		end
		if (#data.title < 1) then
			escaped_title = "hi guys blankfag here"
		end
		if (#data.title < 1 and #trim(data.content) < 1) then
			res.body = ".."
			return
		end
		--p({id, escaped_title, false, {}, os.time(), false, req.ip, false})
		--p(boards[data.board]:NewRow({id, escaped_title, false, {}, os.time(), false, req.ip, false}))
		p(boards[data.board]:NewIndex({id, escaped_title, false, {}, os.time(), false, req.ip, false}))
		addReply(data.board, id, req.headers["X-Forwarded-For"], escaped_html)
	end
    res.body = tostring(id)
    res.code = 200
  end)
  .route({  path = "/:board/new"}, function (req, res)
    res.body = pagecache.new:gsub("<BOARD />", req.params.board):gsub("<VERSION />", version)
    res.code = 200
  end)
.route({ path = "/:board/:id"}, function (req, res)
	local add = "<br>"
		if (boards[req.params.board] == nil) then
			res.body = pagecache["404"]
			return
		end
		local thd, err = boards[req.params.board]:LoadIndex(req.params.id)
		if (err) then
			res.body = pagecache["404"]
			return
		end
		for i = 1, #thd[4] do
			add=add..getReply(thd, i, (req.headers.cookie == adminkey))
		end
		local as = ""
		if (req.headers.cookie == adminkey) then
			as = adminscript
		end
		res.body = pagecache.thread:gsub("<BOARD />", req.params.board):gsub("<POSTS />", add):gsub("<VERSION />", version):gsub("<DESC1 />", cfg.desc[req.params.board][1]):gsub("<DESC2 />", thd[2]):gsub("<ID />", tostring(req.params.id)):gsub("<LOCKED />", tostring(thd[3])):gsub("<ADMINSCRIPT />", as)
		res.code = 200
end)
  .start()

  function threadGC()
	print("Starting thread GC...")
	log("Starting thread GC", "THREAD-GC")
	for i = 1, #cfg.boards do
		local threads = {}
		boards[cfg.boards[i]]:MountAll()
		for k, _ in pairs(boards[cfg.boards[i]].map) do
			local thread = boards[cfg.boards[i]]:index(k)
			if (thread ~= nil) then
				if (not thread[8]) then
					if (thread[6] == false) then
						if (thread[5] < os.time()-(60*60*24) and not thread[3]) then
							thread[3] = true
							print("Locking thread id "..thread[1])
							log("Locking thread id "..thread[1], "THREAD-GC")
							addReply(cfg.boards[i], thread[1], "BOT", "<span style=\"color:darkred\">This thread has been locked automatically by THREAD-GC.</span>", {"SERVER.THREAD-GC", "#FF3175"})
							--thread[4][#thread[4]+1]={{"SERVER.THREAD-GC", "#FF3175"}, "<span style=\"color:darkred\">This thread has been locked automatically by THREAD-GC.</span>"}
						elseif (thread[5] < os.time()-(60*60*24)) then
							print("Deleting thread id "..thread[1])
							log("Deleting thread id "..thread[1], "THREAD-GC")
							boards[cfg.boards[i]]:DeleteIndex(k)
						end
					else
						print("Deleting thread id "..thread[1])
						log("Deleting thread id "..thread[1], "THREAD-GC")
						boards[cfg.boards[i]]:DeleteIndex(k)
					end
				end
			end
		end

		boards[cfg.boards[i]]:GenerateCache()
		--[[for x = 1, #threads do
			if (threads[x] ~= nil) then
				if (not threads[x][8]) then
					if (threads[x][6] == false) then
						if (threads[x][5] < os.time()-(60*60*24) and not threads[x][3]) then
							threads[x][3] = true
							print("Locking thread id "..threads[x][1])
							log("Locking thread id "..threads[x][1], "THREAD-GC")
							addReply(cfg.boards[i], threads[x][1], "BOT", "<span style=\"color:darkred\">This thread has been locked automatically by THREAD-GC.</span>", {"SERVER.THREAD-GC", "#FF3175"})
							--threads[x][4][#threads[x][4]+1]={{"SERVER.THREAD-GC", "#FF3175"}, "<span style=\"color:darkred\">This thread has been locked automatically by THREAD-GC.</span>"}
						elseif (threads[x][5] < os.time()-(60*60*48)) then
							print("Deleting thread id "..threads[x][1])
							log("Deleting thread id "..threads[x][1], "THREAD-GC")
							table.remove(threads, x)
						end
					else
						print("Deleting thread id "..threads[x][1])
						log("Deleting thread id "..threads[x][1], "THREAD-GC")
						table.remove(threads, x)
					end
				end
			end
		end]]
	end
	local val = collectgarbage("count")
	collectgarbage()
	val = val - collectgarbage("count")
	print("Freed "..math.floor(val).."K")
	log("Freed "..math.floor(val).."K", "THREAD-GC")
end

  threadGC()

 timer.setInterval(1800000, function()
	threadGC()
end)

timer.setInterval(100, function()
	if (restart) then
		crashecksdee()
	end
end)

timer.setInterval(10000, function()
	for i = 1, #cfg.boards do
		boards[cfg.boards[i]]:SaveHeaders()
		boards[cfg.boards[i]]:SaveChunk(boards[cfg.boards[i]].lchunk)
	end
	fs.writeFileSync(pathJoin(module.dir, "ipbans.db"), json.stringify(bannedips))
end)

--Reload the HTML files
timer.setInterval(10000, function()
	for k,_ in pairs(pagecache) do
		fs.readFile(pathJoin(module.dir, k..".html"), function(err, data)
			if (err) then
				print(err)
				log(err, "ERROR")
				return
			end
			pagecache[k] = data
		end)
	end
end)

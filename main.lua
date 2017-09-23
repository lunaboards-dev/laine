--Version
local version = "0.5.0 Annabeth"
print("Laine "..version.." starting...")
--Includes
local msqld = require('luasql.mysql')
local mysql = assert(msqld.mysql())
local lustache = require('lustache')
local lip = require('LIP')
local weblit = require('weblit')
local static = require('weblit-static')
local fs = require('fs')
local timer = require('timer')
local pathJoin = require('pathjoin').pathJoin
local thread = require('thread')
local utf8 = require('utf8')
local net = require('net')
local json = require("json").use_lpeg()
local lnutils = require("laine-utils")

--Load config
print("Loading config...")
local cfg = lip.load('config.ini')

--Build board list
local boards = {}
for k, v in pairs(cfg) do
    if k:sub(1,6) == "board_" then
        boards[v.rank] = {id=k:sub(7), desc1=v.desc1, desc2=v.desc2, title=v.title}
    end
end

--Load HTML templates
print("Loading templates...")
local templates = {
    ["boards"] = fs.readFileSync(pathJoin(module.dir, cfg.General.template_dir, "boards.mustache")),
    ["threads"] = fs.readFileSync(pathJoin(module.dir, cfg.General.template_dir, "threads.mustache")),
    ["thread"] = fs.readFileSync(pathJoin(module.dir, cfg.General.template_dir, "thread.mustache")),
    ["new"] = fs.readFileSync(pathJoin(module.dir, cfg.General.template_dir, "new.mustache")),
    ["404"] = fs.readFileSync(pathJoin(module.dir, cfg.General.template_dir, "404.html")),
    ["blocked"] = fs.readFileSync(pathJoin(module.dir, cfg.General.template_dir, "blocked.mustache")),
}

--Connect to database
local con = assert(mysql:connect(cfg.MySQL.db,cfg.MySQL.user,cfg.MySQL.pass, "192.168.1.250"))

--Log function
local function log(s, l)
	l = l or "INFO"
	fs.appendFileSync(pathJoin(module.dir, "access.log"), "["..os.date('%Y-%m-%d %H:%M:%S', os.time()).." "..l.."] "..s.."\r\n")
end

--Bind IPs
weblit.app.bind({host = "127.0.0.1", port = cfg.General.http_port})
.bind({host = "127.0.0.1", port=cfg.General.https_port, tls={cert = module:load("cert.pem"), key = module:load("key.pem")}})
--Log
.use(function (req, res, go)
	--Custom logging function
	local userAgent = req.headers["user-agent"] or ""
	-- Run all inner layers first.
	go()
	-- And then log after everything is done
	log(string.format("%s %s %s %s %s", req.headers["X-Forwarded-For"] or "localhost", req.method, req.path, userAgent, res.code))
end)

--Autoheaders
.use(weblit.autoHeaders)

--Put in custom headers and custom error page
.use(function (req, res, go)
	res.headers["Content-Type"] = "text/html; charset=utf-8"
	res.headers["X-Board-Software"] = "Laine "..version
	res.headers["X-Powered-By"] = jit.version.." "..jit.arch
	res.headers["Server"] = "Luvit 2.14.2"
	res.body = templates["404"]
	return go()
end)

--Static assets.
.route({path = "/static/assets/:path:"}, static(pathJoin(module.dir, cfg.General.static_dir)))

--Board list
.route({
    path = "/:board",
    filter = function(req)
        --Make sure this is the root.
        return req.path == "/"
    end
}, function(req, res)
    --Render!
    res.body = lustache:render(templates["boards"], {boards=boards, version=version})
    res.code = 200
end)

--Thread list
.route({
    path = "/:board",
    filter = function(req)
        return req.path ~= "/"
    end
}, function(req, res)
    --Check if valid board.
    if (cfg["board_"..req.params.board] == nil) then return end
    --Make our request.
    local cur = assert(con:execute("SELECT * FROM threads WHERE board='"..con:escape(req.params.board).."'"))
    local thd = {}
    local row = cur:fetch ({}, "a")
    --Get all the data.
    while row do
        thd[#thd+1] = row
        thd[#thd].locked = thd[#thd].locked ~= "0"
        thd[#thd].pinned = thd[#thd].pinned ~= "0"
        row = cur:fetch({}, "a")
    end

    table.sort(thd, function(a, b)
        if (a.pinned and b.pinned) then return a.lastupdate > b.lastupdate end
        if (a.pinned) then return true end
        if (b.pinned) then return false end
        return a.lastupdate > b.lastupdate
    end)

    --Render!
    res.body = lustache:render(templates["threads"], {threads=thd, board=req.params.board, desc1=cfg["board_"..req.params.board].desc1, desc2=cfg["board_"..req.params.board].desc2, title=cfg["board_"..req.params.board].title, version=version})
    res.code = 200
end)

.route({
    path = "/:board/new",
}, function(req, res)
    --Check if valid board.
    if (cfg["board_"..req.params.board] == nil) then return end
    res.body = lustache:render(templates["new"], {board=req.params.board, version=version})
    res.code = 200
end)

--New Thread
.route({
    path = "/:board/nt",
    method = "POST"
}, function(req, res)
    --Check if valid board.
    if (cfg["board_"..req.params.board] == nil) then return end
    local data = json.parse(req.body)
    --Check if valid board.
    if (cfg["board_"..data.board] == nil) then return end
    --Make sure the title is not too long.
    if (1 > utf8.len(data.title) or 40 < utf8.len(data.title)) then
        data.title="sam likes dick"
    end
    --Make sure the post is not too long.
    if (1 > utf8.len(data.content) or 2000 < utf8.len(data.content)) then
        data.content = "and that's why we should take over poland"
    end
    local t = {}
    local id = math.random(1, 2^32)
    while tl do
        --Make sure the ID doesn't exist
        local cur = assert(con:execute("SELECT name FROM threads WHERE id='"..con:escape(id).."' AND board='"..con:escape(data.board).."'"))
        local t = cur:fetch()
        if (t ~= nil) then
            local id = math.random(1, 2^32)
        else
            --Just to be sure!
            t = nil
        end
    end
    --Insert
    assert(con:execute(string.format("INSERT INTO threads VALUES ('%s', '%s', %d, '%s', %d, 0, 0)", con:escape(data.board), con:escape(data.title), id, con:escape(req.headers["X-Forwarded-For"] or "localhost"), os.time())))
    assert(con:execute(string.format("INSERT INTO posts VALUES (%d, '%s', '%s', '%s', '%s', '')", os.time(), con:escape(data.board), id, con:escape(req.headers["X-Forwarded-For"] or "localhost"), con:escape(lnutils.ptext(lnutils.escape_html(data.content))))))
    res.body = tostring(id) --It took way too long to figure out why this wouldn't work.
    res.code = 200
end)
--Posting
.route({
    path="/:board/post",
    method="POST"
}, function(req, res)
    local data=json.parse(req.body)
    --Do our checks
    if (cfg["board_"..data.board] == nil) then return end
    local cur = assert(con:execute("SELECT name, locked FROM threads WHERE id='"..con:escape(data.id).."' AND board='"..con:escape(data.board).."'"))
    local thdinfo = cur:fetch({}, "a")
    cur:close() --Close it!
    if (thdinfo == nil) then return end
    --Make sure the post is not too long.
    if (1 > utf8.len(data.content) or 2000 < utf8.len(data.content)) then
        data.content = "and that's why we should take over poland"
    end
    assert(con:execute(string.format("INSERT INTO posts VALUES (%d, '%s', '%s', '%s', '%s', '')", os.time(), con:escape(data.board), con:escape(data.id), con:escape(req.headers["X-Forwarded-For"] or "localhost"), con:escape(lnutils.ptext(lnutils.escape_html(data.content))))))
    res.body = "ok"
    res.code = 200
end)

.route({path="/:board/:id"}, function(req, res)
    --Make sure board and ID exist.
    if (cfg["board_"..req.params.board] == nil) then return end
    local cur = assert(con:execute("SELECT name, locked FROM threads WHERE id='"..con:escape(req.params.id).."' AND board='"..con:escape(req.params.board).."'"))
    --Get the name while we're at it.
    local thdinfo = cur:fetch({}, "a")
    cur:close() --Close it!
    if (thdinfo == nil) then return end
    --Get posts
    cur = assert(con:execute("SELECT * FROM posts WHERE id='"..con:escape(req.params.id).."'"))
    --Put them in a nice table.
    local posts = {}
    local r = {}
    while r do
        r = cur:fetch({}, "a")
        if (r ~= nil) then
            posts[#posts+1] = r
        end
    end
    --TODO add admin check and shit

    --Sort by date.
    table.sort(posts, function(a, b)
        return a.date < b.date
    end)
    --Render
    res.body = lustache:render(templates["thread"], {title=thdinfo.name, board=req.params.board, id=req.params.id, locked=thdinfo.locked~="0", posts=posts, desc1=cfg["board_"..req.params.board].desc1, version=version})
    res.code = 200
end)

.start()

--Version
local version = "0.5.0-beta1 Annabeth"
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
local b64 = require("base64_laine")
local xy = require("lxyssl")

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
    ["login"] = fs.readFileSync(pathJoin(module.dir, cfg.General.template_dir, "login.html")),
}

--Connect to database
local con = assert(mysql:connect(cfg.MySQL.db,cfg.MySQL.user,cfg.MySQL.pass, "192.168.1.250"))

--Log function
local function log(s, l)
	l = l or "INFO"
	fs.appendFileSync(pathJoin(module.dir, "access.log"), "["..os.date('%Y-%m-%d %H:%M:%S', os.time()).." "..l.."] "..s.."\r\n")
end

--Has perms function
local function hasperm(a, p)
    return lnutils.has_perm(cfg, a.admin, p)
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

--Put in custom headers and custom error page. Also check for admin privs.
.use(function (req, res, go)
	res.headers["Content-Type"] = "text/html; charset=utf-8"
	res.headers["X-Board-Software"] = "Laine "..version
	res.headers["X-Powered-By"] = jit.version.." "..jit.arch
	res.headers["Server"] = "Luvit 2.14.2"
	res.body = templates["404"]
    req.headers["Cookie"] = req.headers["Cookie"] or "laine.session=nil"
    local r = assert(con:execute("SELECT name, perm, boardperm FROM admins WHERE k='"..con:escape(req.headers["Cookie"]:sub(15)).."'"))
    local f = r:fetch({}, "a")
    if (f ~= nil) then
        req.admin = f
    end
	return go()
end)

--Static assets.
.route({path = "/static/assets/:path:"}, static(pathJoin(module.dir, cfg.General.static_dir)))

.route({
    path="/login",
    method="GET"
}, function(req, res)
    res.body = templates["login"]
    res.code = 200
end)

.route({
    path="/login",
    method="POST"
}, function(req, res)
    local rq = lnutils.explode("&", req.body)
    rq[1] = rq[1]:sub(6)
    rq[2] = rq[2]:sub(6)
    res.headers["Set-Cookie"] = "session.laine="..lnutils.generate_session(con, rq[1], b64.encode(xy.hash("sha2"):digest(rq[2]))).."; HttpOnly"
    res.headers["Location"] = "/"
    res.body = "OK"
    res.code = 301
end)
.route({
    path = "/cmd",
    method = "POST"
}, function(req, res)
    if (req.admin) then
        local admin = "<div class=\"name\" style=\"color:#"..cfg["role_"..req.admin.perm].color.."\">"..cfg["role_"..req.admin.perm].prefix..req.admin.name.."</div>"
        local data = json.parse(req.body)
        if (data.cmd == "mark" and hasperm(req, "mark_thread")) then
            assert(con:execute("UPDATE threads SET marked=1, locked=1 WHERE board='"..con:escape(data.board).."' AND id='"..con:escape(data.id).."'"))
            assert(con:execute(string.format("INSERT INTO posts VALUES (%d, '%s', '%s', '%s', '%s', '%s')", os.time(), con:escape(data.board), con:escape(data.id), con:escape(req.headers["X-Forwarded-For"] or "localhost"), con:escape("<span style=\"color:darkred\">This thread has been locked and marked for deletion.</span>"), con:escape(admin))))
        elseif (data.cmd == "lock" and hasperm(req, "lock_thread")) then
            assert(con:execute("UPDATE threads SET locked=1 WHERE board='"..con:escape(data.board).."' AND id='"..con:escape(data.id).."'"))
            assert(con:execute(string.format("INSERT INTO posts VALUES (%d, '%s', '%s', '%s', '%s', '%s')", os.time(), con:escape(data.board), con:escape(data.id), con:escape(req.headers["X-Forwarded-For"] or "localhost"), con:escape("<span style=\"color:darkred\">This thread has been locked.</span>"), con:escape(admin))))
        elseif (data.cmd == "unlock" and hasperm(req, "lock_thread")) then
            assert(con:execute("UPDATE threads SET locked=0 WHERE board='"..con:escape(data.board).."' AND id='"..con:escape(data.id).."'"))
            assert(con:execute(string.format("INSERT INTO posts VALUES (%d, '%s', '%s', '%s', '%s', '%s')", os.time(), con:escape(data.board), con:escape(data.id), con:escape(req.headers["X-Forwarded-For"] or "localhost"), con:escape("<span style=\"color:green\">This thread has been unlocked.</span>"), con:escape(admin))))
        elseif (data.cmd == "pin" and hasperm(req, "pin")) then
            assert(con:execute("UPDATE threads SET pinned=1 WHERE board='"..con:escape(data.board).."' AND id='"..con:escape(data.id).."'"))
            assert(con:execute(string.format("INSERT INTO posts VALUES (%d, '%s', '%s', '%s', '%s', '%s')", os.time(), con:escape(data.board), con:escape(data.id), con:escape(req.headers["X-Forwarded-For"] or "localhost"), con:escape("<span style=\"color:yellow\">This thread has been pinned.</span>"), con:escape(admin))))
        elseif (data.cmd == "unpin" and hasperm(req, "pin")) then
            assert(con:execute("UPDATE threads SET pinned=0 WHERE board='"..con:escape(data.board).."' AND id='"..con:escape(data.id).."'"))
            assert(con:execute(string.format("INSERT INTO posts VALUES (%d, '%s', '%s', '%s', '%s', '%s')", os.time(), con:escape(data.board), con:escape(data.id), con:escape(req.headers["X-Forwarded-For"] or "localhost"), con:escape("<span style=\"color:darkred\">This thread has been unpinned.</span>"), con:escape(admin))))
        elseif (data.cmd == "banip" and hasperm(req, "ban")) then

        end
        res.body = "ok"
        res.code = 200
    else
        res.body = res.body:gsub("404", "403")
        res.code = 403
    end
end)

--Board list
.route({
    path = "/:board",
    filter = function(req)
        --Make sure this is the root.
        return req.path == "/"
    end
}, function(req, res)
    --Render!
    res.body = lustache:render(templates["boards"], {boards=boards, version=version, admin=req.admin})
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
    local canpin = false
    local canlock = false
    local canmark = false
    if (req.admin) then
        canpin = hasperm(req, "pin")
        canlock = hasperm(req, "lock_thread")
        canmark = hasperm(req, "mark_thread")
    end
    --Render!
    res.body = lustache:render(templates["threads"], {threads=thd, board=req.params.board, desc1=cfg["board_"..req.params.board].desc1, desc2=cfg["board_"..req.params.board].desc2, title=cfg["board_"..req.params.board].title, version=version, admin=req.admin, canpin=canpin, canlock=canlock, canmark=canmark})
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
    local admin = ""
    local html = false
    if (req.admin) then
        admin = "<div class=\"name\" style=\"color:#"..cfg["role_"..req.admin.perm].color.."\">"..cfg["role_"..req.admin.perm].prefix..req.admin.name.."</div>"
        local bperm
    end
    assert(con:execute(string.format("INSERT INTO threads VALUES ('%s', '%s', %d, '%s', %d, 0, 0, 0)", con:escape(data.board), con:escape(data.title), id, con:escape(req.headers["X-Forwarded-For"] or "localhost"), os.time())))
    assert(con:execute(string.format("INSERT INTO posts VALUES (%d, '%s', '%s', '%s', '%s', '%s')", os.time(), con:escape(data.board), id, con:escape(req.headers["X-Forwarded-For"] or "localhost"), con:escape(lnutils.ptext(lnutils.escape_html(data.content, req.admin))), con:escape(admin))))
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
    --Insert
    local admin = ""
    if (req.admin) then
        admin = "<div class=\"name\" style=\"color:#"..cfg["role_"..req.admin.perm].color.."\">"..cfg["role_"..req.admin.perm].prefix..req.admin.name.."</div>"
    end
    assert(con:execute(string.format("INSERT INTO posts VALUES (%d, '%s', '%s', '%s', '%s', '%s')", os.time(), con:escape(data.board), con:escape(data.id), con:escape(req.headers["X-Forwarded-For"] or "localhost"), con:escape(lnutils.ptext(lnutils.escape_html(data.content))), con:escape(admin))))
    assert(con:execute("UPDATE threads SET lastupdate="..os.time().." WHERE board='"..con:escape(data.board).."' AND id='"..con:escape(data.id).."'"))
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
print("Cleaning up threads and starting...")
function threadgc()
    local r = assert(con:execute("SELECT id, board FROM threads WHERE marked=1"))
    local t = r:fetch({}, "a")
    while t do
        assert(con:execute("DELETE FROM posts WHERE id='"..con:escape(t.id).."' AND board='"..con:escape(t.board).."'"))
        print("Deleted /"..t.board.."/"..t.id)
        t = r:fetch({}, "a")
    end
    assert(con:execute("DELETE FROM threads WHERE marked=1"))
    r = assert(con:execute("SELECT id, board FROM threads WHERE lastupdate<"..os.time()-(86400).." AND locked!=1 AND pinned!=1"))
    t = r:fetch({}, "a")
    while t do
        assert(con:execute(string.format("INSERT INTO posts VALUES (%d, '%s', '%s', '%s', '%s', '%s')", os.time(), con:escape(t.board), con:escape(t.id), con:escape("THREAD-GC"), con:escape("<span style=\"color:darkred\">This thread has been locked by Thread-GC.</span>"), con:escape("<div class=\"name\" style=\"color:pink\">THREAD-GC</div>"))))
        assert(con:execute("UPDATE threads SET locked=1 WHERE id="..con:escape(t.id).." AND board='"..con:escape(t.board).."'"))
        print("Locked /"..t.board.."/"..t.id)
        t = r:fetch({}, "a")
    end
    r = assert(con:execute("SELECT id, board FROM threads WHERE lastupdate<"..os.time()-(86400*2).." AND locked=1 AND pinned!=1"))
    t = r:fetch({}, "a")
    while t do
        assert(con:execute("DELETE FROM posts WHERE id='"..con:escape(t.id).."' AND board='"..con:escape(t.board).."'"))
        assert(con:execute("DELETE FROM threads WHERE id='"..con:escape(t.id).."' AND board='"..con:escape(t.board).."'"))
        print("Deleted /"..t.board.."/"..t.id)
        t = r:fetch({}, "a")
    end
    print("Thread-GC Complete.")
end

threadgc()

timer.setInterval(60*60*30, threadgc)

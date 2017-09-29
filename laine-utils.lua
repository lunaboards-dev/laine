local lu = {}

local b64 = require("base64_laine")
local crand = io.open("/dev/urandom")

lu.explode = function(d,p)
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

--Used in purpletext
local function split(inputstr)
        local t={} ; i=1
        for str in string.gmatch(inputstr, "([^\r\n]+)") do
                t[i] = str
                i = i + 1
        end
        return t
end
--Used in purpletext
local startsWith = function(self, str)
    return self:find('^' .. str) ~= nil
end
--Escape HTML
lu.escape_html = function(post)
    return post:gsub("<", "&lt;"):gsub(">", "&gt;")
end
--Scan and put our purpletext in.
lu.ptext = function(post)
    local p_ = split(post)
    for i=1,#p_ do
        if (startsWith(p_[i], "&gt;")) then
            p_[i] = "<span style=\"color:#A229FF\">"..p_[i].."</span>"
        end
    end
    return table.concat(p_, "<br>\r\n")
end
--Generate a session token
lu.generate_session = function(con, user, pass)
    p(con)
    local r = assert(con:execute("SELECT * FROM admins WHERE name='"..con:escape(user).."' AND phash='"..con:escape(pass).."'"))
    local f = r:fetch({}, "a")
    if (f == nil) then
        return false
    end
    local sk = b64.encode(crand:read(32))
    con:execute("UPDATE admins SET k='"..con:escape(sk).."' WHERE name='"..con:escape(user).."' AND phash='"..con:escape(pass).."'")
    return sk
end
--Check if admin table has permission to do x
lu.has_perm = function(c, a, s)
    local p = c["role_"..a.perm]
    return p[s]
end

return lu

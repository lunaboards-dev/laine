local lu = {}

local function split(inputstr)
        local t={} ; i=1
        for str in string.gmatch(inputstr, "([^\r\n]+)") do
                t[i] = str
                i = i + 1
        end
        return t
end
local startsWith = function(self, str)
    return self:find('^' .. str) ~= nil
end

lu.escape_html = function(post)
    return post:gsub("<", "&lt;"):gsub(">", "&gt;")
end

lu.ptext = function(post)
    local p_ = split(post)
    for i=1,#p_ do
        if (startsWith(p_[i], "&gt;")) then
            p_[i] = "<span style=\"color:#A229FF\">"..p_[i].."</span>"
        end
    end
    return table.concat(p_, "<br>\r\n")
end

return lu

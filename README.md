# Laine
The (buggy) textboard engine made with Lua

Most everything can be changed in the config file and/or editing the HTML/CSS files.

## HTTPS

Use Let's Encrypt. Just do it.

## Requires
[Luvit](https://luvit.io/)

[lua-xxhash](https://github.com/mah0x211/lua-xxhash)

[lua-cmsgpack](https://github.com/antirez/lua-cmsgpack)

[weblit](https://github.com/creationix/weblit)

[ansicolors](https://github.com/hoelzro/ansicolors)

[utf8.lua](https://github.com/alexander-yakushev/awesompd/blob/master/utf8.lua)

[crc32.lua](https://github.com/davidm/lua-digest-crc32lua/blob/master/lmod/digest/crc32lua.lua)

## Problems (There are lots!)

Well, first off, databases don't load. At all. No clue why.

And locked threads don't turn grey.

And unlocking doesn't work.

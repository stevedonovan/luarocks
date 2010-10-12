--~ local rep = require 'luarocks.rep' 
--~ local util = require 'luarocks.util' 
--~ local cfg = require "luarocks.cfg"

lrequire 'rep util cfg fetch deps'
local name = arg[1] or 'lpty'

local function dump(msg,t)
    local last
    print(msg)
    for k,v in pairs(t) do print(k,v); last = v end
    return last
end

local versions = rep.get_versions(name)
if versions == nil then  return print ('cannot find this package',name) end
local vs = dump('rep.getversions',versions)
t = rep.package_modules(name,vs)
if t == nil then  return "can't get modules" end
dump('rep.package_modules',t)


--~ require 'pl'

dump('platforms are',cfg.platforms)

local rockspec, err, errcode = fetch.load_rockspec 'ltcltk-0.9-1.rockspec'
if err then return print ('error reading rockspec '..err) end

res,err = deps.check_external_deps(rockspec) --'install')
if not res then print(err) end

t = {
 p1 = "$(LUA)",
 p2 = "$(CC) $(CFLAGS) $(LIBFLAG)",
 p3 = "$(BONZO)",  -- can put this on the command-line!
 p4 = "$(TCL_INCDIR)"
 }
util.variable_substitutions(t,rockspec.variables)
dump('variable subst',t)

t = {
    bonzo = 'dog',
    platforms={
        unix = { bonzo = 'cat' }
    }
}

util.platform_overrides(t)

print(t.bonzo, t.bonzo == 'cat')


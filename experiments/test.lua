local global_arg = arg
local util = require 'luarocks.util'

function lrequire(ls)
    ls = util.split_string(ls,' ')
    for _,name in ipairs(ls) do
        _G[name] = require('luarocks.'..name)
    end
end

module("test", package.seeall)

help_summary = "test LR scripts"

help_arguments = "script"

help = [[
Any script which is to be executed after proper LR setup
]]

function run(...)
    local flags,arg = util.parse_flags(...)
    table.remove(global_arg,1)
    table.remove(global_arg,1)
    local stat,err = pcall(require,arg)
    if not stat then print(err) end
    return true
end
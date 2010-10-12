#!/usr/bin/lual
--[[

 #A simple local Web interface to LuaRocks#

 Each rocks repository has already got an 'index.html' presenting the available
 rocks in a nice format. So the strategy is to grab this file, process it, and
 serve it up with a little webserver. This requires LuaSocket, so the first thing this
 script does is check whether LuaSocket is already installed, and attempts to
 install it otherwise.

 We first get a list of installed rocks using 'luarocks list', and then massage the index:

  - all local rock/spec references must be made absolute, using the server URL
  - the rock names are made into clickable links
  - the style of the side table is made either 'version' or 'installed', depending
	on whether the rock is currently installed
  - a new style called 'installed' is inserted, with a blue background.

  The clickable rock names are given a href="ROCKNAME", and the webserver sees any
  requests that don't have an extension to mean 'install this ROCKNAME', otherwise it
  returns the text of the requested file in the usual manner.

  We attempt to install the rock by capturing the output of 'luarocks install ROCKNAME'.
  This output is saved as ROCKNAME.log.txt. If the output contains 'Error:', we return
  the contents of the log file as the server response, otherwise we return a small
  document which redirects us back to the index, after re-processing the index. In
  this way, the installed status of the rocks is updated and presented appropriately.

  Limitations:
	- assumes that the luarocks script is on the path
	- only works with http repositories
    - currently only works with the first rock repository; not possible to span several
	- errors are not presented in a friendly way.

  Steve Donovan, 2009, MIT/X11

  Uses:
  Web server v0.1
  Copyright (c) 2008 Samuel Saint-Pettersen

--]]

local append = table.insert

local cfg = require 'luarocks.cfg'
local fs = require 'luarocks.fs'
local req = require 'luarocks.require'
local dir = require 'luarocks.dir'

-- we need LuaSocket to get the ball rolling here
local stat,socket = pcall(require,'socket')
if not stat then -- we need to grab luaSocket!
    if os.execute ('luarocks install luasocket') == 0 then
        -- restart this script
        os.execute (arg[-1]..' '..arg[0])
    end
    return
--[[ --unfortunately, this doesn't work for some reason!
	local install = require 'luarocks.install'
	local stat,err = install.run 'luasocket'
	if not stat then return print(err) end
	stat,socket = pcall(require,'socket')
--]]
end

local DIRSEP = package.config:sub(1,1)
--local root = cfg.variables.LUAROCKS_PREFIX..DIRSEP..'bin'..DIRSEP
local root = dir.path(cfg.home,'.luarocks')..'/'
local function readfile (f)
	local f,err = io.open(f)
	if not f then return nil,err end
	local s = f:read '*a'
	f:close()
	return s
end

local function writefile (f,s)
    local f,err = io.open(f,'w')
	if not f then return nil,err end
	f:write(s)
	f:close()
	return #s
end

local function get_installed_rocks ()
	local installed = {}
	local f = io.popen('luarocks list')
	for line in f:lines() do
		if line:find('^%S+$') and not line:find('^%-%-') then
			installed[line] = true
		end
	end
	f:close()
	return installed
end

local installed_style = [[
td.installed {
   background-color: #d0d0f0;
   vertical-align: top;
   text-align: left;
   padding: 5px;
   width: 100px;
}

td.version {
]]

local function href (title,url)
    return '<a href="'..url..'">'..title..'</a>'
end

local function get_index (force)
	local doc_index = root..'rocks_index.html'
	local server = cfg.rocks_servers[1]
	print(server,root,doc_index)
	if not fs.exists (doc_index) or force then
        fs.change_dir(root)
		assert(fs.download(server..'/index.html','rocks_index.html'))
        fs.pop_dir()
	end
	local index = readfile (doc_index)
	-- ensure that the relative links to rockspecs and rocks are absolute!
	index = index:gsub('href="([^"]+)"',function(ref)
		if not ref:find '^http://' then
			ref = server..'/'..ref
		end
		return 'href="'..ref..'"'
	end)

	-- patch the first line to give us a refresh option...
	index = index:gsub('Lua modules avaliable from this location',
		'Lua modules avaliable from '..server..' '..href('(refresh)','_refresh'),
		1)

	return index
end


local function process_index (contents,installed)
	local modules,module_set = {},{}
	local k = 1
	local font = '<font size="%-1">'

	-- add the 'installed' style
	contents = contents:gsub('td.version {',installed_style)

	-- make the rock names clickable
	contents = contents:gsub('<a name="([%w_%-]+)"></a><b>[%w_%-]+</b>',
		function(name)
			append(modules,name)
			module_set[name] = true
			return ('<a name="%s" href="%s"><b>%s</b></a>'):format(name,name,name)
		end
	)

	-- note the URL convention for removing a rock - trailing '_'
	contents = contents:gsub('<font size="%-1">',function()
		local name = modules[k]
		k = k + 1
		return '<font size="-1">'..href('install',name)..' | '..href('remove',name..'_')..' | '
	end)

	-- change the style for installed rocks
	k = 1
	contents = contents:gsub('class="version"',function()
	  local name = modules[k]
	  k = k + 1
	  local check = installed[name]
	  return 'class='..(check and '"installed"' or '"version"')
	end)
	return contents,modules,module_set
end

local function htmlify (s)
	local out = {}
	append(out,'<html><head><title>Lua Rocks Error</title></head><body>')
	for line in io.lines(s) do
		line = line .. '<br>'
		append(out,line)
	end
	append(out,'</body></html>')
	return table.concat(out,'\n')
end

local installed,contents,index_contents,modules,module_set

local function refresh_contents ()
	installed = get_installed_rocks()
	contents,modules,module_set = process_index(index_contents,installed)
	writefile(root..'index.html',contents)
end

local redirect = [[
	<html><head>
	<meta http-equiv="Refresh" content="0;url=http://localhost:8080/index.htmlMODULE">
	</head>
	<body></body>
	</html>
]]

local function force_refresh (mod)
	-- update index and force the browser to refresh, going back to the module.
	refresh_contents()
	if mod then mod = '#'..mod else mod = '' end
	return redirect:gsub('MODULE',mod)
end

local function run_rocks_command (cmd,mod)
	local f = io.popen('luarocks '..cmd..' '..mod..' 2>&1')
	local logfile = root..mod..'-'..cmd..'-log.txt'
	local log = io.open(logfile,'w')
	for line in f:lines() do
		print(line)
		log:write(line,'\n')
		if line:find '^Error:' then
			log:close()
			return htmlify(logfile)
		end
	end
	f:close()
	log:close()
	return force_refresh(mod)
end

local function process_url (file)
	if file == '_quit' then
		os.exit(0)
	elseif file == '_refresh' then
		get_index(true)
		return force_refresh()
	elseif module_set[file] then -- user wants to install a rock
		return run_rocks_command('install',file)
	else
		file = file:gsub('_$','')
		if module_set[file] then --user wants to remove a rock (name postfixed with '_')
			return run_rocks_command('remove',file)
		else
			return nil,"unrecognized request: '"..file.."'"
		end
	end
end


index_contents = get_index()
refresh_contents()


---- launch the browser ----

local Windows = DIRSEP == '\\'
local browsers = {
    "google-chrome", "firefox", "opera", "konqueror", "epiphany", "mozilla", "netscape"
};


function launch_browser (url)
    local exec = os.execute
    if Windows then
        exec('rundll32 url.dll,FileProtocolHandler '..url)
    else
        for _,p in ipairs(browsers) do
            if exec(p..' '..url..'&') == 0 then return end
        end
        -- OK, this should work if we're OS X...
		if exec('/Applications/Safari.app/Contents/macOS/Safari') ~= 0 then
			print 'could not automatically load browser.'
			print 'Please point your browser to http://localhost:8080'
		end
    end
end

if arg[1] ~= '-nolaunch' then
	launch_browser('http://localhost:8080')
end

----  A little web server, based on code by Samuel Saint-Pettersen ----

-- print message to show web server is running
print("LuaRocks Web Interface")
print("Running...(log files are at "..root..")")

local client

local function send_error (code)
	client:send("<h3>"..code.."</h3>")
	client:send("<hr/>")
	client:send("<small>Lua web server v0.1</small>")
end

local filepat = '[%l%d_%-]+'
local idpat = '/('..filepat..')'
local docpat = '/('..filepat..'%.%l+)'

-- create TCP socket on localhost:8080
local server = assert(socket.bind("localhost", 8080))
-- loop while waiting for a user agent request
while 1 do
	-- wait for a connection
	client = server:accept()
	-- send response to confirm this is a web server
	client:send("HTTP/1.1 200/OK\r\nContent-Type:text/html\r\n\r\n")
	-- set timeout - 1 minute
	client:settimeout(60)
	-- receive request from user agent
	local request, err = client:receive()
	-- if there's no error, return the requested page
	if not err then
		-- resolve requested file from user agent request
		print(request)
		local file,action
		if request:find ' / ' then
			file = 'index.html'
		else
			file = request:match(docpat)
			if not file then
				file = request:match(idpat)
				action = file
			end
		end
		-- if we're not requesting a file with extension, then it's a custom action
		if action then
			local body,err = process_url(action)
			if body then client:send(body)
			else send_error(err)
			end
		else
			-- display requested file in browser
			local content = readfile( root..file )
			if content ~= nil then
				client:send(content)
			else
			-- display 404 message and server information
				send_error('404 Not Found')
			end
		end
	end
	-- done with client, close request
	client:close()
end



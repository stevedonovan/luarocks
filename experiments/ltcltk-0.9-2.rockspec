package = "ltcltk"
version = "0.9-2"
source = {
	url = "http://www.tset.de/downloads/ltcltk-0.9-1.tar.gz"
}
description = {
	summary = "A binding for lua to the tcl interpreter and to the tk toolkit.",
	detailed = [[
		This is a binding of the tcl interpreter to lua. It allows
		for calls into tcl, setting and reading variables from tcl and
		registering of lua functions for use from tcl.
		Also, a binding to the tk toolit is included.
	]],
	homepage = "http://www.tset.de/ltcltk.html",
	license = "MIT/X11",
	maintainer = "Gunnar Zötl <gz@tset.de>"
}
supported_platforms = {
	"unix", "mac"
}
dependencies = {
	"lua >= 5.1"
}

-- a semi-colon separated list of possible locations for tcl.h;
-- the one that wins ends up setting TCL_INCDIR
external_dependencies = {
	TCL = {
		header = "tcl.h;tk/tcl.h;tcl/tcl.h",
	}
}

build = {
	type = "builtin",
	modules = {
		ltk = "ltk.lua",
		ltcl = {
			sources = { "ltcl.c" },
			-- change to tcl8.5 or tcl8.4, as needed
			libraries = { "tcl" },
			incdirs = {"$(TCL_INCDIR)"}
		},
	},
	copy_directories = { 'doc', 'samples' },
}


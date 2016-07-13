---
-- gcc.lua
-- Provides GCC-specific configuration strings.
-- Copyright (c) 2002-2015 Jason Perkins and the Premake project
---

	local p = premake

	p.tools.gcc = {}
	local gcc = p.tools.gcc

	local project = p.project
	local config = p.config


--
-- Returns list of C preprocessor flags for a configuration.
--

	gcc.cppflags = {
		system = {
			haiku = "-MMD",
			wii = { "-MMD", "-MP", "-I$(LIBOGC_INC)", "$(MACHDEP)" },
			_ = { "-MMD", "-MP" }
		}
	}

	function gcc.getcppflags(cfg)
		local flags = config.mapFlags(cfg, gcc.cppflags)
		return flags
	end


--
-- Returns list of C compiler flags for a configuration.
--

	gcc.cflags = {
		architecture = {
			x86 = "-m32",
			x86_64 = "-m64",
		},
		flags = {
			FatalCompileWarnings = "-Werror",
			LinkTimeOptimization = "-flto",
			NoFramePointer = "-fomit-frame-pointer",
			ShadowedVariables = "-Wshadow",
			Symbols = "-g",
			UndefinedIdentifiers = "-Wundef",
		},
		floatingpoint = {
			Fast = "-ffast-math",
			Strict = "-ffloat-store",
		},
		strictaliasing = {
			Off = "-fno-strict-aliasing",
			Level1 = { "-fstrict-aliasing", "-Wstrict-aliasing=1" },
			Level2 = { "-fstrict-aliasing", "-Wstrict-aliasing=2" },
			Level3 = { "-fstrict-aliasing", "-Wstrict-aliasing=3" },
		},
		optimize = {
			Off = "-O0",
			On = "-O2",
			Debug = "-Og",
			Full = "-O3",
			Size = "-Os",
			Speed = "-O3",
		},
		pic = {
			On = "-fPIC",
		},
		linkmode = {
		},
		vectorextensions = {
			AVX = "-mavx",
			AVX2 = "-mavx2",
			SSE = "-msse",
			SSE2 = "-msse2",
			SSE3 = "-msse3",
			SSSE3 = "-mssse3",
			["SSE4.1"] = "-msse4.1",
		},
		warnings = {
			Extra = "-Wall -Wextra",
			Off = "-w",
		}
	}

	function gcc.getcflags(cfg)
		local flags = config.mapFlags(cfg, gcc.cflags)
		flags = table.join(flags, gcc.getwarnings(cfg))
		return flags
	end

	function gcc.getwarnings(cfg)
		local result = {}
		for _, enable in ipairs(cfg.enablewarnings) do
			table.insert(result, '-W' .. enable)
		end
		for _, disable in ipairs(cfg.disablewarnings) do
			table.insert(result, '-Wno-' .. disable)
		end
		for _, fatal in ipairs(cfg.fatalwarnings) do
			table.insert(result, '-Werror=' .. fatal)
		end
		return result
	end


--
-- Returns list of C++ compiler flags for a configuration.
--

	gcc.cxxflags = {
		exceptionhandling = {
			Off = "-fno-exceptions"
		},
		flags = {
			NoBufferSecurityCheck = "-fno-stack-protector",
			["C++11"] = "-std=c++11",
			["C++14"] = "-std=c++14",
		},
		rtti = {
			Off = "-fno-rtti"
		}
	}

	function gcc.getcxxflags(cfg)
		local flags = config.mapFlags(cfg, gcc.cxxflags)
		return flags
	end


--
-- Decorate defines for the GCC command line.
--

	function gcc.getdefines(defines)
		local result = {}
		for _, define in ipairs(defines) do
			table.insert(result, '-D' .. p.esc(define))
		end
		return result
	end

	function gcc.getundefines(undefines)
		local result = {}
		for _, undefine in ipairs(undefines) do
			table.insert(result, '-U' .. p.esc(undefine))
		end
		return result
	end


--
-- Returns a list of forced include files, decorated for the compiler
-- command line.
--
-- @param cfg
--    The project configuration.
-- @return
--    An array of force include files with the appropriate flags.
--

	function gcc.getforceincludes(cfg)
		local result = {}

		table.foreachi(cfg.forceincludes, function(value)
			local fn = project.getrelative(cfg.project, value)
			table.insert(result, string.format('-include %s', premake.quoted(fn)))
		end)

		return result
	end


--
-- Decorate include file search paths for the GCC command line.
--

	function gcc.getincludedirs(cfg, dirs, sysdirs)
		local result = {}
		for _, dir in ipairs(dirs) do
			dir = project.getrelative(cfg.project, dir)
			table.insert(result, '-I' .. premake.quoted(dir))
		end
		for _, dir in ipairs(sysdirs or {}) do
			dir = project.getrelative(cfg.project, dir)
			table.insert(result, '-isystem ' .. premake.quoted(dir))
		end
		return result
	end

--
-- Return a list of decorated rpaths 
--

	function gcc.getrunpathdirs(cfg, dirs)
		local result = {}

		if not ((cfg.system == premake.MACOSX)
				or (cfg.system == premake.LINUX)) then
			return result
		end

		local rpaths = {}

		-- User defined runpath search paths
		for _, fullpath in ipairs(cfg.runpathdirs) do
			local rpath = path.getrelative(cfg.buildtarget.directory, fullpath)
			if not (table.contains(rpaths, rpath)) then
				table.insert(rpaths, rpath)
			end
		end

		-- Automatically add linked shared libraries path relative to target directory
		if cfg.linkmode == premake.DEFAULT then
			for _, sibling in ipairs(config.getlinks(cfg, "siblings", "object")) do
				if (sibling.kind == premake.SHAREDLIB) and (sibling.linkmode == premake.DEFAULT) then
					local fullpath = sibling.linktarget.directory
					local rpath = path.getrelative(cfg.buildtarget.directory, fullpath)
					if not (table.contains(rpaths, rpath)) then
						table.insert(rpaths, rpath)
					end
				end
			end
		end

		for _, rpath in ipairs(rpaths) do
			if (cfg.system == premake.MACOSX) then
				rpath = "@loader_path/" .. rpath
			elseif (cfg.system == premake.LINUX) then
				rpath = iif(rpath == ".", "", "/" .. rpath)
				rpath = "$$ORIGIN" .. rpath
			end

			table.insert(result, "-Wl,-rpath,'" .. rpath .. "'")
		end

		return result
	end

--
-- Return a list of LDFLAGS for a specific configuration.
--

	gcc.ldflags = {
		architecture = {
			x86 = "-m32",
			x86_64 = "-m64",
		},
		flags = {
			LinkTimeOptimization = "-flto",
			_Symbols = function(cfg)
				-- OS X has a bug, see http://lists.apple.com/archives/Darwin-dev/2006/Sep/msg00084.html
				return iif(cfg.system == premake.MACOSX, "-Wl,-x", "-s")
			end,
		},
		kind = {
			SharedLib = function(cfg)
				local r = { iif(cfg.system == premake.MACOSX, "-dynamiclib", "-shared") }
				if cfg.system == premake.WINDOWS and not cfg.flags.NoImportLib then
					table.insert(r, '-Wl,--out-implib="' .. cfg.linktarget.relpath .. '"')
				end
				if cfg.linkmode == premake.DEFAULT then
					if cfg.system == premake.LINUX then
						table.insert(r, '-Wl,-soname=' .. premake.quoted(cfg.linktarget.name))
					elseif cfg.system == premake.MACOSX then
						table.insert(r, '-Wl,-install_name,' .. premake.quoted('@rpath/' .. cfg.linktarget.name))
					end
				else
					-- Force installname to something that could work at run-time 
					if cfg.system == premake.MACOSX then
						table.insert(r, '-Wl,-install_name,' .. premake.quoted(cfg.linktarget.fullpath))
					end
				end
				return r
			end,
			WindowedApp = function(cfg)
				if cfg.system == premake.WINDOWS then return "-mwindows" end
			end,
		},
		system = {
			wii = "$(MACHDEP)",
		}
	}

	function gcc.getldflags(cfg)
		local flags = config.mapFlags(cfg, gcc.ldflags)
		return flags
	end



--
-- Return a list of decorated additional libraries directories.
--

	gcc.libraryDirectories = {
		architecture = {
			x86 = "-L/usr/lib32",
			x86_64 = "-L/usr/lib64",
		},
		system = {
			wii = "-L$(LIBOGC_LIB)",
		}
	}

	function gcc.getLibraryDirectories(cfg)
		local flags = config.mapFlags(cfg, gcc.libraryDirectories)

		-- Scan the list of linked libraries. If any are referenced with
		-- paths, add those to the list of library search paths. The call
		-- config.getlinks() all includes cfg.libdirs.
		for _, dir in ipairs(config.getlinks(cfg, "system", "directory")) do
			table.insert(flags, '-L' .. premake.quoted(dir))
		end

		if (cfg.linkmode == "System") then
			for _, dir in ipairs(config.getlinks(cfg, "siblings", "directory")) do
				local libFlag = "-L" .. premake.quoted(premake.project.getrelative(cfg.project, dir))
				if not table.contains(flags, libFlag) then
					table.insert(flags, libFlag)
				end
			end
		else
			-- Per sibling case
			for _, sibling in ipairs(config.getlinks(cfg, "siblings", "object")) do
				if sibling.linkmode == "System" then
					local libFlag = "-L" .. premake.quoted(premake.project.getrelative(cfg.project, sibling.linktarget.directory))
					if not table.contains(flags, libFlag) then
						table.insert(flags, libFlag)
					end
				end
			end
		end

		for _, dir in ipairs(cfg.syslibdirs) do
			table.insert(flags, '-L' .. premake.quoted(dir))
		end

		return flags
	end



--
-- Return the list of libraries to link, decorated with flags as needed.
--

	function gcc.getlinksonly(cfg, systemonly)
		local result = {}

		if not systemonly then
			local siblings = config.getlinks(cfg, "siblings", "object")
			if cfg.linkmode == "System" then
				-- Use relative links for all
				for _, sibling in ipairs(siblings) do
					table.insert(result, '-l' .. sibling.linktarget.basename)
				end
			elseif cfg.linkmode == "Absolute" then
				-- Use absolute path for all
				for _, sibling in ipairs(siblings) do
					table.insert(result, sibling.linktarget.fullpath)
				end
			else
				-- Per-sibling linkmode case
				for _, sibling in ipairs(siblings) do
					if sibling.linkmode == "System" then
						table.insert(result, '-l' .. sibling.linktarget.basename)
					elseif sibling.linkmode == "Absolute" then
						table.insert(result, sibling.linktarget.fullpath)
					else
						table.insert(result, project.getrelative(cfg.project, sibling.linktarget.fullpath)) 
					end
				end
			end
		end

		-- The "-l" flag is fine for system libraries

		local links = config.getlinks(cfg, "system", "fullpath")
		for _, link in ipairs(links) do
			if path.isframework(link) then
				table.insert(result, "-framework")
				table.insert(result, path.getbasename(link))
			elseif path.isobjectfile(link) then
				table.insert(result, link)
			else
				table.insert(result, "-l" .. path.getname(link))
			end
		end

		return result
	end


	function gcc.getlinks(cfg, systemonly)

		-- we don't want libraries to be order dependent.
		local result = gcc.getlinksonly(cfg, systemonly)
		if #result > 1 then
			local res = {}
			table.insert(res, '-Wl,--start-group')
			table.insertflat(res, result)
			table.insert(res, '-Wl,--end-group')
			return res
		end
		return result
	end


--
-- Returns makefile-specific configuration rules.
--

	gcc.makesettings = {
		system = {
			wii = [[
  ifeq ($(strip $(DEVKITPPC)),)
    $(error "DEVKITPPC environment variable is not set")'
  endif
  include $(DEVKITPPC)/wii_rules']]
		}
	}

	function gcc.getmakesettings(cfg)
		local settings = config.mapFlags(cfg, gcc.makesettings)
		return table.concat(settings)
	end


--
-- Retrieves the executable command name for a tool, based on the
-- provided configuration and the operating environment.
--
-- @param cfg
--    The configuration to query.
-- @param tool
--    The tool to fetch, one of "cc" for the C compiler, "cxx" for
--    the C++ compiler, or "ar" for the static linker.
-- @return
--    The executable command name for a tool, or nil if the system's
--    default value should be used.
--

	gcc.tools = {
		cc = "gcc",
		cxx = "g++",
		ar = "ar",
		rc = "windres"
	}

	function gcc.gettoolname(cfg, tool)
		if (cfg.gccprefix and gcc.tools[tool]) or tool == "rc" then
			return (cfg.gccprefix or "") .. gcc.tools[tool]
		end
		return nil
	end


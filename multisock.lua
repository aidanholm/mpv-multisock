-- Options {{{

opts = {
    src_socket = "/home/" .. os.getenv("USER") .. "/.mpv-socket",
    lock_file  = "/home/" .. os.getenv("USER") .. "/.mpv-socket-lock",
    poll_delay = 0.2,
}

-- }}}

-- ############################################################

require "mp.msg"
local utils = require "mp.utils"
local options = require "mp.options"

options.read_options(opts, "multisock")

-- {{{ cmd()

function cmd(...)
	local arg = {...}
	dbg("Running command `" .. table.concat(arg, " ") .. "`")

	local result = utils.subprocess({ args = arg, cancellable = false })
	if result["status"] < 0 then
		error(
			"  Command failed!",
			"    Status:" .. result["status"],
			"    Error:" .. result["error"]
		)
        die(arg)
	else
		dbg("  Status: " .. result["status"])
		dbg("  Stdout: " .. result["stdout"])
		return result["status"], result["stdout"]
	end
end

-- }}}
-- {{{ calculate_dst()

function calculate_dst(src)
	verbose("Calculating destination for socket...")

	local function getpid()
		verbose("Getting mpd PID...")
		local stat = io.open"/proc/self/stat":read'*l'
		local pid =  tonumber(string.sub(stat, 1, string.find(stat, " ")))
		verbose("  PID: ", pid)
		return pid
	end

	local dst = opts.src_socket .. "." .. getpid() 
	verbose("  Socket destination is", dst)
	return dst
end

--- }}}
-- {{{ File, socket, and directory existence tests

function test(t, name)
	return cmd("test", "-" .. t, name) == 0
end

function file_exists(name) return test("f", name) end
function dir_exists(name) return test("d", name) end
function socket_exists(name) return test("S", name) end

-- }}}
-- {{{ Locking and unlocking

locked = false
function lock()
	verbose("Locking with file " .. opts.lock_file .. "...")

	if locked then
		verbose("  Already locked, doing nothing...")
		return
	end

	local function sleep(n)
		verbose("  Sleeping for ".. n .. " seconds")
		cmd("sleep", tonumber(n))
	end

	local lock_time_limit = 5
	local time = 0
	while not cmd("mkdir", opts.lock_file) do 
		warn("  Another lock exists, waiting " .. opts.poll_delay .. " seconds...")
		verbose("  Waited " .. time .. " seconds so far...")
		time = time + opts.poll_delay 
		if time >= lock_time_limit then
			error("  Timed out waiting for lock!")
            die()
		end
		sleep(opts.poll_delay)
	end 
	locked = true
	verbose("  Locked!")
end

function unlock()
	verbose("Unlocking...")

	if not locked then
		verbose("  Already unlocked, doing nothing...")
		return
	end

	locked = false

	if dir_exists(opts.lock_file) then
		cmd("rmdir", opts.lock_file)
		verbose("  Unlocked!")
	else
		error("  lock_file removed by external process!")
	end
end

-- }}}
-- {{{ Logging wrappers

dbg = mp.msg.debug
warn = mp.msg.warn
info = mp.msg.info
error = mp.msg.error
verbose = mp.msg.verbose
function die(arg)
	mp.command("quit 1")
	shutdown()
	os.exit()
end 

-- }}}

do
	local time = 0

	function move_socket(src_socket, dst_socket)
		verbose("Trying to move " .. src_socket .. " to " .. dst_socket)

		assert(locked)

		if not socket_exists(src_socket) then
			verbose("  Doesn't exist yet, waiting ".. opts.poll_delay .. "s ... (".. time .. "s so far)")
			time = time + opts.poll_delay
			mp.add_timeout(opts.poll_delay, function() move_socket(src_socket, dst_socket) end)
		else
			verbose("  " .. src_socket .. " exists now!")
			info("Moving " .. src_socket .. " to " .. dst_socket)
			cmd("mv", src_socket, dst_socket)
			unlock()
			verbose("Done moving socket")
		end
	end
end

function remove_socket(socket)
	if socket_exists(socket) then
		info("Removing socket " .. socket)
		cmd("rm", socket)
	else
		verbose("Removing socket " .. socket)
		verbose("  No socket to remove, doing nothing...")
	end
end

-- function remove_existing_source_socket()
-- 	verbose("Checking if there's an existing source socket...")
-- 	assert(locked)
-- 	remove_socket(opts.src_socket)
-- end

function startup()
	verbose("Running startup hook...")
	verbose("src: " .. opts.src_socket)
	verbose("dst: " .. dst_socket)

	verbose("Registering shutdown handler...")
	mp.register_event("shutdown", shutdown)

	lock()
	-- remove_existing_source_socket()
	mp.add_timeout(0.00, function() move_socket(opts.src_socket, dst_socket) end)
end

function shutdown()
	verbose("Running shutdown hook...")
	remove_socket(dst_socket)
	unlock()
end

dst_socket = calculate_dst(opts.src_socket)

mp.add_timeout(0, startup)

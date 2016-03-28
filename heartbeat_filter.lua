require "string"
require "circular_buffer"
require "math"
require "os"

-- total = 0 -- globals preserved btwn restarts
-- local rows              = read_config("rows") or 1440

local timestamp_field   = "timestamp"

math.randomseed(os.time())

values_buf = circular_buffer.new(1440, 1, 15)
values_buf:set_header(1, "demo_val")

function process_message ()
    -- local ts = read_message("Fields["..timestamp_field.."]")
	local ts = read_message("Timestamp")
    local val = math.random(0, 100)
    if type(val) ~= "number" then return -1 end

	values_buf:add(ts, 1, val)

    return 0
end

function timer_event(ns)
	inject_payload("cbuf", "demo", values_buf)
end

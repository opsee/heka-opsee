require "string"
require "circular_buffer"

-- total = 0 -- globals preserved btwn restarts
-- local rows              = read_config("rows") or 1440

timestamp_field   = "timestamp"
process_field = "process_name"
metrics_field = "metrics"
cust_id_field = "customer_id"
bast_id_field = "bastion_id"
metrics_type_map_field = "metricTypes"

values_buf = circular_buffer.new(1440, 4, 15)
values_buf:set_header(1, "customer_id")
values_buf:set_header(2, "bastion_id")
values_buf:set_header(3, "process_name")
values_buf:set_header(4, "value")

function process_message ()
	local ts = read_message("Fields["..timestamp_field.."]")

    if type(ts) ~= "number" then
		inject_payload("txt", "opsee_log", string.format("error: bad timestamp received %s", ts))
		return -1
	end

	local proc_name = read_message("Fields["..process_field.."]")
	if proc_name == nil then
		inject_payload("txt", "opsee_log", string.format("error: empty process name"))
		return -1
	end

	local cust_id = read_message("Fields["..cust_id_field.."]")
	if cust_id == nil then
		inject_payload("txt", "opsee_log", string.format("error: empty cust id"))
		return -1
	end

	local bast_id = read_message("Fields["..bast_id_field.."]")
	if bast_id == nil then
		inject_payload("txt", "opsee_log", string.format("error: empty bast id for %s", cust_id))
		return -1
	end

	local metrics = read_message("Fields["..metrics_field.."]")
	if metrics == nil then
		inject_payload("txt", "opsee_log", string.format("error: empty metrics for %s", cust_id))
		return -1
	end

	local metrics_types = metrics[metrics_type_map_field]
	if type(metrics_types) ~= "table" then
		inject_payload("txt", "opsee_log", string.format("error: empty metrics types for %s", cust_id))
		return -1
	end

	local errors = 0
	for k,v in pairs(metrics) do
		if k == metrics_type_map_field then
            goto continue
        end

		if type(v) ~= "number" then
			errors = errors+1
			add_to_payload(string.format("error: non-numeric metric received, %s", v))
			goto continue
		end

		m_type = metrics_types[k]
		if m_type == nil then
			errors = errors+1
			add_to_payload(string.format("error: no type found for metric %s", k))
			goto continue
		end

		-- only support gauge types currently in librato encoder
		if m_type ~= "gauge" and m_type ~= "gaugeFloat64" then
            goto continue
        end

		values_buf:add(ts, 1, cust_id)
		values_buf:add(ts, 2, bast_id)
		values_buf:add(ts, 3, proc_name)
		values_buf:add(ts, 4, v)

		::continue::
	end

	if errors > 0 then
		inject_payload("txt", "opsee_log", string.format("errors processing metrics for %s", cust_id))
		return -1
	end

    inject_payload("txt", "opsee_log", "TEST")

    return 0
end

function timer_event(ns)
	inject_payload("cbuf", "heartbeat_metrics", values_buf)
end

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
		-- XXX logit
		return -1
	end

	local proc_name = read_message("Fields["..process_field.."]")
	if proc_name == nil then
		-- XXX logit
		return -1
	end

	local cust_id = read_message("Fields["..cust_id_field.."]")
	if cust_id == nil then
		-- XXX logit
		return -1
	end

	local bast_id = read_message("Fields["..bast_id_field.."]")
	if bast_id == nil then
		-- XXX logit
		return -1
	end

	local metrics = read_message("Fields["..metrics_field.."]")
	if metrics == nil then
		-- XXX logit
		return -1
	end

	local metrics_types = metrics[metrics_type_map_field]
	if type(metrics_types) ~= "table" then
		-- XXX logit
		return -1
	end

	for k,v in pairs(metrics) do
		if k == metrics_type_map_field then goto continue end

		if type(v) ~= "number" then
			-- XXX logit
			return -1
		end

		m_type = metrics_types[k]
		if m_type == nil then
			 -- XXX logit
			goto continue
		end

		-- only support gauge types currently in librato encoder
		if m_type ~= "gauge" and m_type ~= "gaugeFloat64" then
			-- XXX logit
			goto continue
		end

		values_buf:add(ts, 1, cust_id)
		values_buf:add(ts, 2, bast_id)
		values_buf:add(ts, 3, proc_name)
		values_buf:add(ts, 4, v)

		::continue::
	end

    return 0
end

function timer_event(ns)
	inject_payload("cbuf", "heartbeat_metrics", values_buf)
end

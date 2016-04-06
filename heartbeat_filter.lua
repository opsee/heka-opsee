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

max_num_metrics = 20

values_buf = circular_buffer.new(1440, max_num_metrics, 15)

function process_message ()
	local ts = read_message("Fields["..timestamp_field.."]")

    if type(ts) ~= "number" then
		return -1, string.format("error: bad timestamp received %s", ts)
	end

	local proc_name = read_message("Fields["..process_field.."]")
	if proc_name == nil then
		return -1, string.format("error: empty process name")
	end

	local cust_id = read_message("Fields["..cust_id_field.."]")
	if cust_id == nil then
		return -1, string.format("error: empty cust id")
	end

	local bast_id = read_message("Fields["..bast_id_field.."]")
	if bast_id == nil then
		return -1, string.format("error: empty bast id for %s", cust_id)
	end

	local metrics = read_message("Fields["..metrics_field.."]")
	if metrics == nil then
		return -1, string.format("error: empty metrics for %s", cust_id)
	end

	local metrics_types = metrics[metrics_type_map_field]
	if type(metrics_types) ~= "table" then
		return -1, string.format("error: empty metrics types for %s", cust_id)
	end

	local errors = 0
    local metric_col = 0
	for k,v in pairs(metrics) do
        local continue_loop = false

		if k == metrics_type_map_field then
            continue_loop = true
		elseif type(v) ~= "number" then
			errors = errors+1
            continue_loop = true
		elseif metrics_types[k] == nil then
			errors = errors+1
            continue_loop = true
		elseif metrics_types[k] ~= "gauge" and metrics_types[k] ~= "gaugeFloat64" then
            -- only support gauge types currently in librato encoder
            continue_loop = true
        end

        if not continue_loop then
            values_buf:set_header(metric_col, cust_id.."_"..proc_name.."_"..k)
            values_buf:add(ts, metric_col, v)

            if metric_col == max_num_metrics then
                break
            end
            metric_col = metric_col+1
        end
	end

	if errors > 0 then
		return -1, string.format("error: %d errors processing metrics for %s", errors, cust_id)
	end

    return 0
end

function timer_event(ns)
	inject_payload("cbuf", "heartbeat_metrics", values_buf)
end

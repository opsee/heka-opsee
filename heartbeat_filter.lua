require "string"
require "cjson"
require "table"

timestamp_field   = "timestamp"
process_field = "process_name"
cust_id_field = "customer_id"
bast_id_field = "bastion_id"
metrics_field = "metrics"
metrics_type_map_field = "metricTypes"

metric_names = {
    ["runtime.MemStats.TotalAlloc"]		= 1,
    ["runtime.MemStats.Alloc"]			= 2,
    ["runtime.MemStats.HeapAlloc"]		= 3,
    ["runtime.MemStats.HeapInuse"]		= 4,
	["runtime.MemStats.Mallocs"]		= 5,
    ["runtime.MemStats.NumGC"]			= 6,
    ["runtime.MemStats.StackSys"]		= 7,
    ["runtime.MemStats.Sys"] 			= 8,
    ["runtime.MemStats.NumThread"] 		= 9,
    ["runtime.MemStats.NumGoroutine"] 	= 10,
    ["runtime.MemStats.PauseTotalNs"] 	= 11,
    ["runtime.MemStats.BuckHashSys"] 	= 12,
    ["runtime.MemStats.DebugGC"] 		= 13,
    ["runtime.MemStats.EnableGC"] 		= 14,
    ["runtime.MemStats.Frees"] 			= 15,
    ["runtime.MemStats.GCCPUFraction"]  = 16,
    ["runtime.MemStats.HeapIdle"] 		= 17,
    ["runtime.MemStats.HeapObjects"] 	= 18,
    ["runtime.MemStats.HeapReleased"] 	= 19,
    ["runtime.MemStats.HeapSys"] 		= 20,
    ["runtime.MemStats.LastGC"] 		= 21,
    ["runtime.MemStats.Lookups"] 		= 22,
    ["runtime.MemStats.MCacheInuse"] 	= 23,
    ["runtime.MemStats.MCacheSys"] 		= 24,
    ["runtime.MemStats.MSpanSys"] 		= 25,
    ["runtime.MemStats.NextGC"] 		= 26,
    ["runtime.MemStats.StackInuse"] 	= 27,
    ["runtime.MemStats.Sys"] 			= 28,
    ["runtime.MemStats.NumCgoCall"] 	= 29,
}

local metric_sets_buffer = {}
local max_buffer_len = 10

function process_message ()
	local msg = read_message("Payload")
	if msg == nil then
		return -1, "empty msg received"
	end

    local ok, json = pcall(cjson.decode, msg)
    if not ok then return -1, string.format("Failed to decode JSON: %s", msg) end

	local ts = json[timestamp_field]
    if type(ts) ~= "number" then
		return -1, string.format("bad timestamp received %s", ts)
	end

	local proc_name = json[process_field]
	if proc_name == nil then
		return -1, string.format("empty process name")
	end

	local cust_id = json[cust_id_field]
	if cust_id == nil then
		return -1, string.format("empty cust id")
	end

	local bast_id = json[bast_id_field]
	if bast_id == nil then
		return -1, string.format("empty bast id for %s", cust_id)
	end

	local metrics = json[metrics_field]
	if metrics == nil or type(metrics) ~= "table" then
		return -1, string.format("invalid metrics field for %s", cust_id)
	end

	local metrics_types = metrics[metrics_type_map_field]
	if type(metrics_types) ~= "table" then
		return -1, string.format("empty metrics types for %s", cust_id)
	end

	local errors = 0
    payload = {}
	for k,v in pairs(metrics) do
        local continue_loop = false

		if k == metrics_type_map_field then
            continue_loop = true
		elseif type(v) ~= "table" then
			errors = errors+1
            continue_loop = true
		elseif metrics_types[k] == nil then
			errors = errors+1
            continue_loop = true
		elseif metrics_types[k] ~= "gauge" and metrics_types[k] ~= "gaugeFloat64" then
            -- only support gauge types currently in librato encoder
            continue_loop = true
        elseif metric_names[k] == nil then
            --- skip metrics not explicitly listed
            continue_loop = true
        end

        if not continue_loop then
            val = v["value"]
            if type(val) ~= "number" then
                errors = errors +1
                continue_loop = true
            end

            if not continue_loop then
                payload[k] = val
            end
        end
	end

	if errors > 0 then
		return -1, string.format("%d errors processing metrics for %s", errors, cust_id)
	end

    local metric_set = {
        Timestamp = ts,
        Customer = cust_id,
        Bastion = bast_id,
        Process = proc_name,
        Metrics = payload
    }

    table.insert(metric_sets_buffer, metric_set)

    if(table.getn(metric_sets_buffer) > max_buffer_len) then
		send_buffer({{name = "debug_msg_cnt", value=table.getn(metric_sets_buffer)},})
	end

    return 0
end

function send_buffer(addl_fields)
	local msg = {
		Type 	= 'heartbeat',
		Payload = cjson.encode(metric_sets_buffer),
		Fields 	= { }
	}

	if addl_fields ~= nil then
		for i, field in ipairs(addl_fields) do
			table.insert(msg.Fields, field)
		end
	end

	inject_message(msg)
	metric_sets_buffer = {}
end

function timer_event(ns)
	if(table.getn(metric_sets_buffer) > 0) then
        send_buffer()
    end
end

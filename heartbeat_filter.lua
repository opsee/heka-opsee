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
    ["runtime.MemStats.HeapInuse"]		= true,
    ["runtime.MemStats.HeapObjects"] 	= true,
    ["runtime.MemStats.NumGC"]			= true,
    ["runtime.MemStats.Alloc"]			= true,
    ["runtime.MemStats.TotalAlloc"]		= false,
    ["runtime.MemStats.HeapAlloc"]		= false,
	["runtime.MemStats.Mallocs"]		= false,
    ["runtime.MemStats.StackSys"]		= false,
    ["runtime.MemStats.Sys"] 			= false,
    ["runtime.MemStats.NumThread"] 		= false,
    ["runtime.MemStats.NumGoroutine"] 	= false,
    ["runtime.MemStats.PauseTotalNs"] 	= false,
    ["runtime.MemStats.BuckHashSys"] 	= false,
    ["runtime.MemStats.DebugGC"] 		= false,
    ["runtime.MemStats.EnableGC"] 		= false,
    ["runtime.MemStats.Frees"] 			= false,
    ["runtime.MemStats.GCCPUFraction"]  = false,
    ["runtime.MemStats.HeapIdle"] 		= false,
    ["runtime.MemStats.HeapReleased"] 	= false,
    ["runtime.MemStats.HeapSys"] 		= false,
    ["runtime.MemStats.LastGC"] 		= false,
    ["runtime.MemStats.Lookups"] 		= false,
    ["runtime.MemStats.MCacheInuse"] 	= false,
    ["runtime.MemStats.MCacheSys"] 		= false,
    ["runtime.MemStats.MSpanSys"] 		= false,
    ["runtime.MemStats.NextGC"] 		= false,
    ["runtime.MemStats.StackInuse"] 	= false,
    ["runtime.MemStats.Sys"] 			= false,
    ["runtime.MemStats.NumCgoCall"] 	= false,
}

proc_names = {
    ["runner"] = true,
    ["checker"] = true,
    ["test_runner"] = true,
    ["monitor"] = true,
    ["discovery"] = false,
    ["hacker"] = false,
    ["aws_command"] = false,
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
	elseif not proc_names[proc_name] then
        --- skip procs not explicitly listed or set to false
        return 0
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
        elseif not metric_names[k] then
            --- skip metrics not explicitly listed or set to false
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

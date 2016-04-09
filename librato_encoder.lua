require "cjson"
require "string"
require "math"

function process_message()
    local payload = read_message("Payload")
    if payload == nil then
        return -1, "invalid payload"
    end

    ok, metric_sets = pcall(cjson.decode, payload)
    if not ok then
        return -1, "error decoding payload json"
    end

    local gauges = {}
    for i, mset in ipairs(metric_sets) do
        local metrics_payload = mset.Metrics
        if type(metrics_payload) ~= "table" then
            return -1, "invalid metrics json"
        end

        local cust_id = mset.Customer
        if cust_id == nil then
            return -1, "empty customer id"
        end

        local bast_id = mset.Bastion
        if bast_id == nil then
            return -1, "empty bastion id"
        end

        local proc_name = mset.Process
        if proc_name == nil then
            return -1, "empty process name"
        end

        local ts = mset.Timestamp
        if type(ts) ~= "number" then
            return -1, "invalid timestamp"
        end

        local source = cust_id..":"..bast_id..":"..proc_name
        local record
        local time = math.floor(ts/1e9)
        for k,v in pairs(metrics_payload) do
            record = {name=k, source=source, value=v, measure_time=time}
            gauges[#gauges+1] = record
        end
    end

    if #gauges == 0 then
        return -2
    end

    inject_payload("json", "output", cjson.encode({gauges = gauges}))

    return 0
end

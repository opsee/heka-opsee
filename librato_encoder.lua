--[[
Example Output

    {"gauges":[{"value":12,"measure_time":1410824950,"name":"HTTP_200","source":"thor"},{"value":1,"measure_time":1410824950,"name":"HTTP_300","source":"thor"},{"value":1,"measure_time":1410824950,"name":"HTTP_400","source":"thor"}]}

--]]

require "cjson"
require "string"
require "math"

function process_message()
    local metrics_json = read_message("Payload")
    if metrics_json == nil then
        return -1, "invalid metrics payload"
    end

    local metrics_payload = cjson.decode(metrics_json)
    if type(metrics_payload) ~= "table" then
        return -1, "invalid metrics json"
    end

    local cust_id = read_message("Fields[customer]")
    if cust_id == nil then
        return -1, "empty customer id"
    end

    local proc_name = read_message("Fields[process]")
    if proc_name == nil then
        return -1, "empty process name"
    end

    local ts = read_message("Timestamp")
    if type(ts) ~= "number" then
        return -1, "invalid timestamp"
    end

    local source = cust_id..":"..proc_name
    local gauges = {}
    local record
    local time = math.floor(ts/1e9)
    for k,v in pairs(metrics_payload) do
        record = {name=k, source=source, value=v, measure_time=time}
        gauges[#gauges+1] = record
    end

    if #gauges == 0 then
        return -2
    end

    local output = {gauges = gauges}
    inject_payload("json", "output", cjson.encode(output))

    return 0
end

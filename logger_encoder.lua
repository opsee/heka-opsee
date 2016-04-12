require "os"
require "string"

function process_message ()
    local log_fields = read_config("msg_fields")
    local ts = os.date("%FT%TZ", read_message("Timestamp") / 1e9)
    local hn = read_message("Hostname")
    local pi = read_message("Logger")

    -- build payload from fields
    local pl = read_message("Payload")

    inject_payload("txt", "",
                   string.format("Timestamp: %s\nHostname: %s\nPlugin: %s\nAlert: %s\n", ts, hn, pi, pl))
    return 0
end

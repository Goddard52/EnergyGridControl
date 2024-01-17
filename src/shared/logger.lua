function Logger()
    local logBuffer = {}

    local function log(message)
        local logEntry = {
            message = message,
            timestamp = os.time()
        }

        table.insert(logBuffer, logEntry)

        -- Ensure the log buffer size does not exceed 20
        if #logBuffer > 20 then
            table.remove(logBuffer, 1)
        end
    end

    local function getLogMessages(count)
        count = count or 10  -- Default to returning the newest 10 messages

        local logMessages = {}
        local currentTime = os.time()
        local removalThreshold = currentTime - 300

        for i = #logBuffer, 1, -1 do
            if #logMessages < count and logBuffer[i].timestamp >= removalThreshold then
                table.insert(logMessages, logBuffer[i].message)
            else
                break
            end
        end

        return logMessages
    end

    return {
        log = log,
        getLogMessages = getLogMessages
    }
end

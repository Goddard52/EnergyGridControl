-- Logger.lua

local Logger = {}

function Logger.new()
    local self = {
        logBuffer = {},
    }

    setmetatable(self, { __index = Logger })
    return self
end

function Logger:log(message)
    local logEntry = {
        message = message,
        timestamp = os.time()
    }

    table.insert(self.logBuffer, logEntry)

    -- Ensure the log buffer size does not exceed 20
    if #self.logBuffer > 20 then
        table.remove(self.logBuffer, 1)
    end
end

function Logger:getLogMessages()
    local logMessages = {}

    local currentTime = os.time()
    local removalThreshold = currentTime - 300

    for i = #self.logBuffer, 1, -1 do
        if self.logBuffer[i].timestamp >= removalThreshold then
            table.insert(logMessages, self.logBuffer[i].message)
        else
            break  -- Stop adding logs once logs are older than the threshold
        end
    end

    return logMessages
end

return Logger

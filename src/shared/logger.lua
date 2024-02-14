-- Logger.lua

local Logger = {}

local levels = {
    INFO = 1,
    WARN = 2,
    ERROR = 3
}

function Logger.new()
    local self = {
        logBuffer = {},
        logLevel = levels.INFO
    }

    setmetatable(self, { __index = Logger })
    return self
end

function Logger:info(message)
    if self.logLevel == levels.INFO then
        self:addLog(message, levels.INFO)
    end
end

function Logger:warn(message)
    if self.logLevel == levels.WARN then
        self:addLog(message, levels.WARN)
    end
end

function Logger:error(message)
    self:addLog(message, levels.ERROR)
end

function Logger:addLog(message,level)
    local logEntry = {
        message = message,
        timestamp = os.time(),
        level = level
    }

    table.insert(self.logBuffer, logEntry)

    -- Ensure the log buffer size does not exceed 20
    if #self.logBuffer > 20 then
        table.remove(self.logBuffer, 1)
    end
end

function Logger:log(message)
    local logEntry = {
        message = message,
        timestamp = os.time(),
        level = levels.INFO
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
    local removalThreshold = currentTime - 500

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

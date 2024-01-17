-- CommonManager.lua

local event = require("event")

local messageHandler = require("messageHandler")

local CommonManager = {}

function CommonManager.create(managerType, managerPort)
    local validTypes = { "Battery Manager", "Turbine Manager" }

    if not managerType or not table.includes(validTypes, managerType) then
        error("Invalid manager type. Supported types are: " .. table.concat(validTypes, ", "))
    end

    local self = {
        modem = require("component").modem,
        gpu = require("component").gpu,

        messageHandler = messageHandler.new(),
        
        isConnected = false,
        orchestratorAddress = nil,
        orchestratorPort = 123,
        orchestratorTimeout = 1500,

        logBuffer = {},
        lastOrchestratorHeartbeat = 0,

        type = managerType,
    }

    self.screenWidth, self.screenHeight = self.gpu.getResolution()

    self.messageHandler:registerHandler(self.orchestratorPort, function(sender, message)
        if message == "Orchestrator Heartbeat" then
            -- Handle Orchestrator heartbeat
            self:handleOrchestratorHeartbeat(sender)
        elseif not self.isConnected then
            -- Only handle acknowledgment and confirmation when connected
            if message == "Acknowledgment" then
                -- Handle acknowledgment
                self:handleAcknowledgment(sender)
            end
        end
        -- Add more handlers if needed
    end)

    setmetatable(self, { __index = CommonManager })
    return self
end


function CommonManager:resetOrchestrator()
    self.orchestratorAddress = nil
    self.isConnected = false
    self:log("Resetting Orchestrator information.")
end

function CommonManager:handleOrchestratorHeartbeat()
    while true do
        local _, _, sender, port, _, message = event.pull("modem_message")

        if port == self.orchestratorHeartbeatPort and message == "Orchestrator Heartbeat" then
            -- Orchestrator heartbeat received
            if not self.isConnected then
                -- If not connected, establish a connection
                self.orchestratorAddress = sender
                self:log("Orchestrator found:  " .. self.orchestratorAddress)
                self:contactOrchestrator()
            end

            -- Update the timestamp for the last heartbeat
            self.lastOrchestratorHeartbeat = os.time()
        end

        -- Check for orchestrator unresponsiveness and initiate re-discovery if necessary
        if self.isConnected and os.time() - self.lastOrchestratorHeartbeat > self.orchestratorTimeout then
            self:log("Orchestrator is unresponsive. Waiting for a new Orchestrator...")
            self:resetOrchestrator()
        end
    end
end

function CommonManager:handleAcknowledgment()
    self.isConnected = true
    self:log("Connected to: " .. self.orchestratorAddress)
end

function CommonManager:contactOrchestrator()
    -- Contact Orchestrator
    self:log("Contacting Orchestrator")
    self.messageHandler:sendMessage(self.orchestratorAddress, self.orchestratorPort, self.type)
end


function CommonManager:drawLogBox(logBoxX, logBoxY, logBoxWidth, logBoxHeight)

    self.gpu.fill(logBoxX, logBoxY, logBoxWidth, logBoxHeight, " ")

    local logMessages = self:getLogMessages()

    for i, message in ipairs(logMessages) do
        if i <= logBoxHeight then
            self.gpu.set(logBoxX, logBoxY + i - 1, message)
        else
            break
        end
    end
end


function CommonManager:log(message)
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

function CommonManager:getLogMessages()
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



function table.includes(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end


return CommonManager

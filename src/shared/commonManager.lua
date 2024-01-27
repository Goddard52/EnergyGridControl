-- CommonManager.lua

local event = require("event")

local messageHandler = require("messageHandler")
local Logger = require("logger")

local CommonManager = {}

CommonManager.logger = Logger.new()

function CommonManager.create(managerType, managerPort)
    local validTypes = { "Battery Manager", "Turbine Manager" }

    if not managerType or not table.includes(validTypes, managerType) then
        error("Invalid manager type. Supported types are: " .. table.concat(validTypes, ", "))
    end

    local self = {
        modem = require("component").modem,
        gpu = require("component").gpu,

        logger = CommonManager.logger,
        messageHandler = messageHandler.new(CommonManager.logger),
        
        isConnected = false,
        orchestratorAddress = nil,
        orchestratorPort = 123,
        orchestratorTimeout = 1500,

        lastOrchestratorHeartbeat = 0,

        type = managerType,
    }

    self.screenWidth, self.screenHeight = self.gpu.getResolution()

    self.messageHandler:registerHandler(self.orchestratorPort, function(sender, message)
        if message == "Orchestrator Heartbeat" then
            -- Handle Orchestrator heartbeat
            self:handleOrchestratorHeartbeat(sender)
        elseif message == "Acknowledgment" then
                -- Handle acknowledgment
                self.logger:log("Handling the Ack...")

                self:handleAcknowledgment(sender)
        end
        -- Add more handlers if needed
    end)

    setmetatable(self, { __index = CommonManager })
    return self
end


function CommonManager:resetOrchestrator()
    self.orchestratorAddress = nil
    self.isConnected = false
    self.logger:log("Resetting Orchestrator information.")
end

function CommonManager:handleOrchestratorHeartbeat(sender)
    if not self.isConnected then
        -- If not connected, establish a connection
        self.orchestratorAddress = sender
        self.logger:log("Orchestrator found:  " .. self.orchestratorAddress)
        self:contactOrchestrator()
    end

    -- Update the timestamp for the last heartbeat
    self.lastOrchestratorHeartbeat = os.time()

        -- Check for orchestrator unresponsiveness and initiate re-discovery if necessary
    if self.isConnected and os.time() - self.lastOrchestratorHeartbeat > self.orchestratorTimeout then
        self.logger:log("Orchestrator is unresponsive. Waiting for a new Orchestrator...")
        self:resetOrchestrator()
    end
end

function CommonManager:handleAcknowledgment(sender)
    if sender == self.orchestratorAddress then
        self.isConnected = true
        self.logger:log("Connected to: " .. self.orchestratorAddress)
    end
end

function CommonManager:contactOrchestrator()
    -- Contact Orchestrator
    self.logger:log("Contacting Orchestrator")
    self.messageHandler:sendMessage(self.orchestratorAddress, self.orchestratorPort, self.type)
end


function CommonManager:drawLogBox(logBoxX, logBoxY, logBoxWidth, logBoxHeight)

    self.gpu.fill(logBoxX, logBoxY, logBoxWidth, logBoxHeight, " ")

    local logMessages = self.logger:getLogMessages()

    for i, message in ipairs(logMessages) do
        if i <= logBoxHeight then
            self.gpu.set(logBoxX, logBoxY + i - 1, message)
        else
            break
        end
    end
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
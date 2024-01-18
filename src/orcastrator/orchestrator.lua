local event = require("event")
local component = require("component")
local thread = require("thread")

local MessageHandler = require("messageHandler")

local Orchestrator = {}
Orchestrator.__index = Orchestrator

function Orchestrator.new()
    local self = setmetatable({}, Orchestrator)
    self.orchestratorPort = 123
    self.batteryManagerPort = 324
    self.addTurbineManagerPort = 325
    self.messageHandler = MessageHandler.new()
    self.modem = component.modem
    
    self.batteryManagers = {}
    self.turbineManagers = {}
    
    -- self.heartBeatThread = thread.create(function() self:broadcastOrchestratorHeartbeat() end)
    -- self.batteryStatusThread = thread.create(function() self:callForBatteryStatus() end)
    -- self.turbineStatusThread = thread.create(function() self:callForTurbineStatuses() end)
    
    self.messageHandler:registerHandler(self.orchestratorPort, function(sender, message)
        if message == "Turbine Manager" then
            self:addTurbineManager(sender)
        elseif message == "Battery Manager" then
            self:addBatteryManager(sender)
        end
    end)
    self.messageHandler:registerHandler(self.batteryManagerPort, function(sender, message)
        if message.code == "ChargeStatus" then
            self:updateChargeStatus(sender, message.content)
        end
    end)
    self.messageHandler:registerHandler(self.addTurbineManagerPort, function(sender, message)
        -- TODO: Replace with real code
        if message.code == "MaintenenceStatus" then
            self:updateTurbineStatus(sender,message.content)
        end
    end)
    
    -- Initializing GPU component
    self.gpu = component.gpu
    self.screenWidth, self.screenHeight = self.gpu.getResolution()
    self.drawScreenThread = thread.create(function() 
        while true do
            self:drawScreen()
        end
     end)
    
    return self
end

function Orchestrator:broadcastOrchestratorHeartbeat()
    while true do
        self.modem.broadcast(self.orchestratorPort, "Orchestrator Heartbeat")
        os.sleep(60)
    end
end

function Orchestrator:callForBatteryStatus()
    while true do
        if #self.batteryManagers > 0 then
            for _, batteryManager in ipairs(self.batteryManagers) do
                self.messageHandler:sendMessage(batteryManager.address, self.batteryManagerPort, "Status")
            end
        else
            print("No battery manager available!")
        end

        os.sleep(30)
    end
end

function Orchestrator:callForTurbineStatuses()
    while true do
        if #self.turbineManagers > 0 then
            print("No turbine manager available!")
        else
            print("No turbine manager available!")
        end
        os.sleep(30)
    end
end

function Orchestrator:callForPowerIfRequired(batteryStatus)
    if batteryStatus.charge < 30 then
        self:callForPower()
    end
    os.sleep(30)
end

-- TODO: Replace temp code
function Orchestrator:callForPower()
    -- Choose a turbine manager based on some criteria
    if #self.turbineManagers > 0 then
        local selectedTurbine = self.turbineManagers[1]
        self.communication:sendMessage(selectedTurbine, "Start Turbines")
    else
        print("No available turbine manager!")
    end
end

-- TODO: Is old, remove and send logs to another logging machine. Stats to be sent to a machine dedicated with drawing UI as updates come in.
function Orchestrator:drawScreen()
    self.gpu.fill(1, 1, self.screenWidth, self.screenHeight, " ") -- Clear screen

    self.gpu.set(1, 1, "Battery Charge: ")
    self.gpu.set(1, 2, "Calling for power: ")

    os.sleep(10)
end

-- -- TODO: Move to external UI program
-- function Orchestrator:drawLogBox(logBoxX, logBoxY, logBoxWidth, logBoxHeight)

--     self.gpu.fill(logBoxX, logBoxY, logBoxWidth, logBoxHeight, " ")

--     local logMessages = self:getLogMessages()

--     for i, message in ipairs(logMessages) do
--         if i <= logBoxHeight then
--             self.gpu.set(logBoxX, logBoxY + i - 1, message)
--         else
--             break
--         end
--     end
-- end

-- -- TODO: Move to shared logger
-- function Orchestrator:log(message)
--     local logEntry = {
--         message = message,
--         timestamp = os.time()
--     }

--     table.insert(self.logBuffer, logEntry)

--     -- Ensure the log buffer size does not exceed 20
--     if #self.logBuffer > 20 then
--         table.remove(self.logBuffer, 1)
--     end
-- end

-- -- TODO: Move to shared logger
-- function Orchestrator:getLogMessages()
--     local logMessages = {}

--     local currentTime = os.time()
--     local removalThreshold = currentTime - 300

--     for i = #self.logBuffer, 1, -1 do
--         if self.logBuffer[i].timestamp >= removalThreshold then
--             table.insert(logMessages, self.logBuffer[i].message)
--         else
--             break  -- Stop adding logs once logs are older than the threshold
--         end
--     end

--     return logMessages
-- end

return Orchestrator

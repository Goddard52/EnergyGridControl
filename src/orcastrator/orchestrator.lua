local event = require("event")
local component = require("component")
local thread = require("thread")

local messageHandler = require("messageHandler")

local Orchestrator = {}
Orchestrator.__index = Orchestrator

function Orchestrator.new()
    local self = setmetatable({}, Orchestrator)
    self.orchestratorPort = 123
    self.batteryManagerPort = 324
    self.addTurbineManagerPort = 325
    messageHandler = messageHandler.new()
    self.modem = component.modem
    
    self.batteryManagers = {}
    self.turbineManagers = {}
    
    self.heartBeatThread = thread.create(function() self:broadcastOrchestratorHeartbeat() end)
    self.batteryStatusThread = thread.create(function() self:callForBatteryStatus() end)
    self.turbineStatusThread = thread.create(function() self:callForTurbineStatuses() end)
    self.drawScreenThread = thread.create(function() self:drawScreen() end)

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
            self:log("No battery manager available!")
        end

        os.sleep(30)
    end
end

function Orchestrator:callForTurbineStatuses()
    while true do
        if #self.turbineManagers > 0 then
            self:log("No turbine manager available!")
        else
            self:log("No turbine manager available!")
        end
        os.sleep(30)
    end
end

function Orchestrator:callForPowerIfRequired(batteryStatus)
    if batteryStatus.charge < 30 then
        self:callForPower()
    else
        -- Logic for other scenarios
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
        self:log("No available turbine manager!")
    end
end

-- TODO: Is old, remove and send logs to another logging machine. Stats to be sent to a machine dedicated with drawing UI as updates come in.
function Orchestrator:drawScreen()
    self.gpu.fill(1, 1, self.screenWidth, self.screenHeight, " ") -- Clear screen

    self.gpu.set(1, 1, "Battery Charge: " .. (self.batteryCharge or "N/A"))
    self.gpu.set(1, 3, "Calling for power: " .. (self.callingForPower and "Yes" or "No"))

    self.gpu.set(1, 5, "Activity:")

    local currentTime = os.time()
    local entriesToRemove = {} -- Collect expired entries to remove after iteration

    for i, entry in ipairs(self.activity) do
        if entry.time + self.activityTimeout >= currentTime then
            self.gpu.set(1, 5 + i, entry.text)
        else
            table.insert(entriesToRemove, i) -- Collect expired entry index
        end
    end

    -- Remove expired entries in reverse to avoid index shifting
    for i = #entriesToRemove, 1, -1 do
        table.remove(self.activity, entriesToRemove[i])
    end
end

-- TODO: Move to external UI program
function Orchestrator:drawLogBox(logBoxX, logBoxY, logBoxWidth, logBoxHeight)

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

-- TODO: Move to shared logger
function Orchestrator:log(message)
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

-- TODO: Move to shared logger
function Orchestrator:getLogMessages()
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

return Orchestrator

local component = require("component")
local thread = require("thread")
local Logger = require("logger")
local MessageHandler = require("messageHandler")
local serialization = require("serialization")


-- Define the Manager class
local Manager = {}
Manager.__index = Manager


function Manager.new(managerType, address)
    local self = setmetatable({}, Manager)
    self.type = managerType
    self.address = address
    self.totalCharge = 0
    self.maintenanceStatus = 6
    return self
end

local Orchestrator = {}
Orchestrator.logger = Logger.new()
Orchestrator.__index = Orchestrator

function Orchestrator.new()
    local self = setmetatable({}, Orchestrator)
    self.orchestratorPort = 123
    self.batteryManagerPort = 324
    self.addTurbineManagerPort = 325
    self.messageHandler = MessageHandler.new(Orchestrator.logger)
    self.modem = component.modem
    self.logger = Orchestrator.logger

    self.managers = {}
    
    self.heartBeatThread = thread.create(function() 
        while true do
            self:broadcastOrchestratorHeartbeat()
            os.sleep(30)
        end
    end)
    
    self.batteryStatusThread = thread.create(function() 
        os.sleep(30)
        while true do
            self:callForBatteryStatus()
            os.sleep(15)
        end
    end)
    -- self.turbineStatusThread = thread.create(function() self:callForTurbineStatuses() end)
    
    self.messageHandler:registerHandler(self.orchestratorPort, function(sender, message)
        if message == "Turbine Manager" then
            self:addManager(message,sender)
        elseif message == "Battery Manager" then
            self:addManager(message,sender)
        end
    end)
    self.messageHandler:registerHandler(self.batteryManagerPort, function(sender, message)
        self.logger:log("Meesage:" .. message)
        
        if message.code == "ChargeStatus" then
            self:updateChargeStatus(sender, message.content)
        end
    end)
    self.messageHandler:registerHandler(self.addTurbineManagerPort, function(sender, message)
        if message.code == "MaintenenceStatus" then
            self:updateTurbineStatus(sender,message.content)
        end
    end)
    
    -- Initializing GPU component
    self.gpu = component.gpu
    self.screenWidth, self.screenHeight = self.gpu.getResolution()
    self.drawScreenThread = thread.create(function() 
        local count = 0
        while true do
            self:drawScreen(count)
            os.sleep(2.5)
            count = count + 1
        end
     end)
    
    return self
end

function Orchestrator:broadcastOrchestratorHeartbeat()
    self.modem.broadcast(self.orchestratorPort, "Orchestrator Heartbeat")
    self.logger:log("Broadcasting")
end

function Orchestrator:addManager(managerType, address)
    for _, manager in ipairs(self.managers) do
        if manager.address == address then
            self.logger:log(managerType .. " manager at " .. address .. " is already added.")
            return
        end
    end

    local newManager = Manager.new(managerType, address)
    table.insert(self.managers, newManager)
    
    self.logger:log(managerType .. " added: " .. address)
    
    -- Send acknowledgment to the manager
    self.messageHandler:sendMessage(address, self.orchestratorPort, "Acknowledgment")
    self.logger:log("Acknowledgment sent to " .. managerType .. ": " .. address)
end



function Orchestrator:callForBatteryStatus()
    for _, batteryManager in ipairs(self.managers) do
        if batteryManager.type == "Battery Manager" then
            self.messageHandler:sendMessage(batteryManager.address, self.batteryManagerPort, serialization.serialize({
                code = "Status"
            }))
        end
    end

    os.sleep(30)
end

function Orchestrator:updateChargeStatus(sender, totalCharge)
    self.logger:log("Updated charge status for battery manager at address " .. sender .. ": " .. totalCharge)
    local batteryManager = self:getManagerByAddress(sender)
    batteryManager.totalCharge = totalCharge
    self.logger:log("Updated charge status for battery manager at address " .. sender .. ": " .. totalCharge)
end

function Orchestrator:getManagerByAddress(address)
    for _, manager in ipairs(self.managers) do
        if manager.address == address then
            return manager
        end
    end
    return nil
end

function Orchestrator:updateTurbineStatus(sender, maintenanceStatus)
    local turbineManager = self:getManagerByAddress(sender)

    if turbineManager and turbineManager.type == "Turbine Manager" then
        turbineManager.maintenanceStatus = maintenanceStatus
        self.logger:log("Updated maintenance status for turbine manager at address " .. sender .. ": " .. maintenanceStatus)
    end
end


-- function Orchestrator:callForTurbineStatuses()
--     while true do
--         if #self.turbineManagers > 0 then
--             print("No turbine manager available!")
--         else
--             print("No turbine manager available!")
--         end
--         os.sleep(30)
--     end
-- end

-- function Orchestrator:callForPowerIfRequired(batteryStatus)
--     if batteryStatus.charge < 30 then
--         self:callForPower()
--     end
--     os.sleep(30)
-- end

-- -- TODO: Replace temp code
-- function Orchestrator:callForPower()
--     -- Choose a turbine manager based on some criteria
--     if #self.turbineManagers > 0 then
--         local selectedTurbine = self.turbineManagers[1]
--         self.communication:sendMessage(selectedTurbine, "Start Turbines")
--     else
--         print("No available turbine manager!")
--     end
-- end

-- TODO: Is old, remove and send logs to another logging machine. Stats to be sent to a machine dedicated with drawing UI as updates come in.
function Orchestrator:drawScreen(count)


    self.gpu.fill(1, 1, self.screenWidth, self.screenHeight, " ") -- Clear screen
    self.gpu.set(1, 1, "Battery Charge: " .. self:getBatteryCharge())
    self.gpu.set(1, 2, "Calling for power: " .. count)

    local logBoxWidth = self.screenWidth
    local logBoxHeight = self.screenHeight - 3
    local logBoxX, logBoxY = 1, 4    
    self:drawLogBox(logBoxX, logBoxY, logBoxWidth, logBoxHeight)
end

function Orchestrator:drawLogBox(logBoxX, logBoxY, logBoxWidth, logBoxHeight)

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

function Orchestrator:getBatteryCharge()
    local totalCharge = 0
    local numBuffers = 0

    for _, buffer in ipairs(self.managers) do
        if buffer.type == "Battery Manager" then
            totalCharge = totalCharge + buffer.totalCharge
            numBuffers = numBuffers + 1
        end
    end

    if numBuffers > 0 then
        return totalCharge
    else
        return 0  -- Default to 0 if there are no registered battery buffers
    end
end


return Orchestrator
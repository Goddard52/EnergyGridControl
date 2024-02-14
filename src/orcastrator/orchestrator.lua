local component = require("component")
local thread = require("thread")
local Logger = require("logger")
local Enums = require("enums")
local MessageHandler = require("messageHandler")
local serialization = require("serialization")


-- Define the Manager class
local Manager = {}
Manager.__index = Manager

function Manager.new(managerType, address)
    local self = setmetatable({}, Manager)
    self.address = address
    self.attempts = 0
    self.attemptTime = os.time()
    if managerType == Enums.ManagerType.BATTERY then
        self.totalCharge = 0
    end
    if managerType == Enums.ManagerType.TURBINE then
        self.maintenanceStatus = 100
        self.turbineType = 0
        self.powerState = 0
    end
    return self
end

local Orchestrator = {}
Orchestrator.logger = Logger.new()
Orchestrator.__index = Orchestrator

function Orchestrator.new()
    local self = setmetatable({}, Orchestrator)
    self.orchestratorPort = 123
    self.batteryManagerPort = 324
    self.turbineManagerPort = 325
    self.messageHandler = MessageHandler.new(Orchestrator.logger)
    self.modem = component.modem
    self.logger = Orchestrator.logger

    self.batteryManagers = {}
    self.turbineManagers = {}
    
    self.heartBeatThread = thread.create(function() 
        while true do
            self:broadcastOrchestratorHeartbeat()
            os.sleep(15)
        end
    end)
    
    self.batteryStatusThread = thread.create(function() 
        os.sleep(30)
        while true do
            self:callForBatteryStatus()
            os.sleep(10)
        end
    end)
    self.turbineStatusThread = thread.create(function()
        os.sleep(30)
        while true do
            self:callForTurbineStatuses()
            os.sleep(300)
        end 
    end)
    
    self.messageHandler:registerHandler(self.orchestratorPort, function(sender, message)
        if message == Enums.ManagerType.TURBINE.NAME then
            self:addManager(Enums.ManagerType.TURBINE,sender)
            self:getTurbineType(sender)
        elseif message == Enums.ManagerType.BATTERY.NAME then
            self:addManager(Enums.ManagerType.BATTERY,sender)
        end
    end)

    -- Battery Handlers
    self.messageHandler:registerHandler(self.batteryManagerPort, function(sender, message)
        if message.code == "ChargeStatus" then
            self:updateChargeStatus(sender, message.content)
        end
    end)

    -- Turbine Handlers
    self.messageHandler:registerHandler(self.turbineManagerPort, function(sender, message)
        if message.code == "MaintenenceStatus" then
            self:updateTurbineStatus(sender,message.content)
        elseif message.code == "TurbineType" then
            self:updateTurbineType(sender,message.content)
        end
    end)
    
    -- Initializing GPU component
    self.gpu = component.gpu
    self.screenWidth, self.screenHeight = self.gpu.getResolution()
    self.drawScreenThread = thread.create(function() 
        local count = 0
        while true do
            self:drawScreen(count)
            os.sleep(2)
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
    self.logger:log("Tring to Add")
    local managerMap
    if managerType == Enums.ManagerType.BATTERY then
        managerMap = self.batteryManagers
    elseif managerType == Enums.ManagerType.TURBINE then
        managerMap = self.turbineManagers
    else
        return
    end

    if managerMap[address] then
        self.logger:log(managerType.NAME .. " manager at " .. address .. " is already added.")
        self.messageHandler:sendMessage(address, self.orchestratorPort, "Acknowledgment")
        self.logger:log("Acknowledgment sent to " .. managerType.NAME .. ": " .. address)
        return
    end

    local newManager = Manager.new(managerType, address)
    if managerType == Enums.ManagerType.BATTERY then
        self.batteryManagers[address] = newManager
    elseif managerType == Enums.ManagerType.TURBINE then
        self.turbineManagers[address] = newManager
    else
        return nil
    end
    
    self.logger:log(managerType.NAME .. " added: " .. address)

    -- Send acknowledgment to the manager
    self.messageHandler:sendMessage(address, self.orchestratorPort, "Acknowledgment")
    self.logger:log("Acknowledgment sent to " .. managerType.NAME .. ": " .. address)
end

-- 
-- Battery Functions
-- 
function Orchestrator:callForBatteryStatus()
    for address, batteryManager in pairs(self.batteryManagers) do
        if batteryManager.attempts < 3 then
            self.messageHandler:sendMessage(address, self.batteryManagerPort, serialization.serialize({
                code = "Status"
            }))
            batteryManager.attempts = batteryManager.attempts + 1
            batteryManager.attemptTime = os.time()
        else
            -- Reset the manager if 3 attempts have been made
            self:resetManager(Enums.ManagerType.BATTERY.ID,address)
        end
    end
end

function Orchestrator:getBatteryChargePercentage()
    local totalCharge = self:getBatteryCharge()
    local maxCharge = Enums.BatteryMaxCharge -- Assuming you have a predefined maximum charge value in your Enums module

    if maxCharge > 0 then
        local percentage = (totalCharge / maxCharge) * 100
        return math.min(100, math.max(0, percentage)) -- Ensure the percentage is within the range [0, 100]
    else
        return 0 -- Default to 0 if maxCharge is not defined or 0
    end
end

function Orchestrator:updateChargeStatus(sender, totalCharge)
    self.batteryManagers[sender].totalCharge = totalCharge
    self.batteryManagers[sender].attempts = 0
    
    self.logger:log("Updated charge status for battery manager at address " .. sender .. ": " .. totalCharge)
end

function Orchestrator:getBatteryCharge()
    local totalCharge = 0
    local numBuffers = 0

    for _, buffer in pairs(self.batteryManagers) do
        totalCharge = totalCharge + buffer.totalCharge
        numBuffers = numBuffers + 1
    end

    if numBuffers > 0 then
        return totalCharge
    else
        return 0  -- Default to 0 if there are no registered battery buffers
    end
end

-- 
-- Turbine Functions
-- 

function Orchestrator:callForTurbineStatuses()
    for address, turbineManager in pairs(self.turbineManagers) do
        if turbineManager.attempts < 3 then
            self.messageHandler:sendMessage(address, self.turbineManagerPort, serialization.serialize({
                code = "MaintenenceStatus"
            }))
            turbineManager.attempts = turbineManager.attempts + 1
            turbineManager.attemptTime = os.time()
        else
            -- Reset the manager if 3 attempts have been made
            self:resetManager(Enums.ManagerType.TURBINE.ID, address)
        end
    end
end

function Orchestrator:updateTurbineStatus(sender, maintenanceStatus)
    self.turbineManagers[sender].maintenanceStatus = maintenanceStatus
    self.turbineManagers[sender].attempts = 0
    self.logger:log("Updated maintenance status for turbine manager at address " .. sender .. ": " .. maintenanceStatus)
end

function Orchestrator:updateTurbineType(sender, message)
    self.turbineManagers[sender].turbineType = message
    self.turbineManagers[sender].attempts = 0
    self.logger:log("Updated turbine type for turbine manager at address " .. sender .. ": " .. message.content)
end

function Orchestrator:getTurbineType(address)
    if self.turbineManagers[address].attempts < 3 then
        self.messageHandler:sendMessage(address, self.turbineManagerPort, serialization.serialize({
            code = "TurbineType"
        }))
    else
        -- Reset the manager if 3 attempts have been made
        self:resetManager(Enums.ManagerType.TURBINE, address)
    end

end

-- 
-- Power Functions
-- 
function Orchestrator:callForPower()
    local totalCharge = self:getBatteryChargePercentage()

    local steamPowerState = self:getTurbinePowerState(Enums.TurbineType.STEAM, totalCharge)
    local benzenePowerState = self:getTurbinePowerState(Enums.TurbineType.BENZENE, totalCharge)
    local highOctanePowerState = self:getTurbinePowerState(Enums.TurbineType.HIGH_OCTANE, totalCharge)

    -- Send messages to all turbine managers with their respective power states
    for address, turbineManager in pairs(self.turbineManagers) do
        local message = {
            code = "PowerState",
            powerState = Enums.PowerState.OFF
        }

        if turbineManager.turbineType == Enums.TurbineType.STEAM then
            message.powerState = steamPowerState
        elseif turbineManager.turbineType == Enums.TurbineType.BENZENE then
            message.powerState = benzenePowerState
        elseif turbineManager.turbineType == Enums.TurbineType.HIGH_OCTANE then
            message.powerState = highOctanePowerState
        end

        self.messageHandler:sendMessage(address, self.turbineManagerPort, serialization.serialize(message))
        self.logger:log("Sent PowerState message to turbine manager at address " .. address .. ": " .. message.powerState)
    end
end


function Orchestrator:getTurbinePowerState(turbineType, totalCharge)
    local powerStates = Enums.TurbineMatrix[turbineType]

    -- Find the appropriate power state based on the total charge
    if totalCharge <= powerStates[Enums.PowerState.HIGH] then
        return Enums.PowerState.HIGH
    elseif totalCharge <= powerStates[Enums.PowerState.MED] then
        return Enums.PowerState.MED
    elseif totalCharge <= powerStates[Enums.PowerState.LOW] then
        return Enums.PowerState.LOW
    else
        return Enums.PowerState.OFF
    end
end


-- 
-- Display Functions
-- 
function Orchestrator:drawScreen()
    self.gpu.fill(1, 1, self.screenWidth, self.screenHeight, " ") -- Clear screen

        -- Display Battery Managers Connected and EU Stored
    local batteryInfo = "Battery Managers: " .. tableLength(self.batteryManagers) .. "    EU Stored: " .. self:getBatteryCharge() .. " EU"
    self.gpu.set(1, 1, batteryInfo)

    local progressBarWidth = self.screenWidth -- Adjust the width of the progress bar
    local progressBarHeight = 3
    local progressBarX = 1
    local progressBarY = 2

    self:progressBar(progressBarX, progressBarY, progressBarWidth, progressBarHeight)
    
    -- Display Manager Details Heading
    self.gpu.set(1, 5, "Turbine Managers:")

    -- Display Manager Details
    local yOffset = 6
    for address, turbineManager in pairs(self.turbineManagers) do
        local managerInfo = string.format("Manager %d: Health: %d%% | Power: %s | Type: %s",
            yOffset - 4, turbineManager.maintenanceStatus, Enums.PowerState.ToString[turbineManager.powerState], Enums.TurbineType.ToString[turbineManager.turbineType])
        self.gpu.set(1, yOffset, managerInfo)
        yOffset = yOffset + 2 -- Adjust the vertical spacing based on your preference
    end

    -- Display Log Box
    local logBoxWidth = self.screenWidth
    local logBoxHeight = self.screenHeight - 10 - 1
    local logBoxX, logBoxY = 1, 10
    self:logBox(logBoxX, logBoxY, logBoxWidth, logBoxHeight)
end

function Orchestrator:logBox(logBoxX, logBoxY, logBoxWidth, logBoxHeight)

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

function Orchestrator:progressBar(x, y, width, height)
    local batteryChargePercentage = self:getBatteryChargePercentage()

    local filledColor = 0x00FF00  -- Green color for filled part
    local emptyColor = 0xCCCCCC    -- Light gray for empty part

    -- Draw the background of the progress bar
    self.gpu.setBackground(emptyColor)
    self.gpu.fill(x, y, width, height, " ")

    if batteryChargePercentage > 0 then
        local progressMessage = string.format("%.2f%%", batteryChargePercentage)
        local filledWidth = math.floor(width * batteryChargePercentage / 100)

        -- Draw the filled part of the progress bar
        self.gpu.setBackground(filledColor)
        self.gpu.fill(x, y, filledWidth, height, " ")

        -- -- Draw the percentage in the center
        self.gpu.setBackground(emptyColor)
        self.gpu.setForeground(0x000000)
        local textX = math.floor((width - string.len(progressMessage)) / 2) + x
        local textY = math.floor(height / 2) + y
        self.gpu.set(textX, textY, progressMessage)
    else
        -- Display a message when the battery charge is 0%
        local message = "No Charge"
        local textX = math.floor((width - string.len(message)) / 2) + x
        local textY = math.floor(height / 2) + y
        self.gpu.setForeground(0x000000)
        self.gpu.set(textX, textY, message)
    end

    -- Reset the background color
    self.gpu.setBackground(0x000000)
    self.gpu.setForeground(0xFFFFFF)

end



function tableLength(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

function Orchestrator:sendKillMessage(address)
    self.messageHandler:sendMessage(address, self.orchestratorPort, "Kill")
    self.logger:log("Sent Kill message to manager at address " .. address)
end

function Orchestrator:resetManager(type,address)
    if type == Enums.ManagerType.BATTERY.ID then
        self:sendKillMessage(address)
        self.batteryManagers[address] = nil
    elseif type == Enums.ManagerType.TURBINE.ID then
        self:sendKillMessage(address)
        self.turbineManagers[address] = nil
    else
        return nil
    end

    self.logger:log("Reset Manager at address " .. address)
end

return Orchestrator
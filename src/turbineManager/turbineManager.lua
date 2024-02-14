local component = require("component")
local event = require("event")
local thread = require("thread")
local serialization = require("serialization")
local Enums = require("enums")

local CommonManager = require("commonManager")
local Turbine = require("gt_machine")

local TurbineManager = setmetatable({}, { __index = CommonManager })

function TurbineManager.new(turbineType)
    local self = CommonManager.create("Turbine Manager", 325)
    setmetatable(self, { __index = TurbineManager })

    self.orchestratorManagerPort = 325
    self.turbineMap = {}
    self.totalTurbines = 0
    self.activeTurbines = 0
    self.powerRequirement = ''
    self.powerType = turbineType
    self.maintenanceBuckets = {}
    for i = 0, 6 do
        self.maintenanceBuckets[i] = {}
    end

    self:initTurbines()

    thread.create(function()
        while true do
            self:draw()
            self:checkOrchestratorConnection()
            os.sleep(1)
        end
    end)

    thread.create(function()
        while true do
            self:updateMaintenanceBuckets()

            os.sleep(300)
        end
    end)

    self.messageHandler:registerHandler(self.orchestratorManagerPort, function(sender, message)
        if message.code == "MaintenenceStatus" then
            self:updateTurbines(message.content)
        elseif message.code == "CallingForPower" then
            self:updateTurbines(message.content)
        elseif message.code == "TurbineType" then
            self.messageHandler:sendMessage(self.orchestratorAddress, self.orchestratorManagerPort, serialization.serialize({
                code = "TurbineType",
                content = self.powerType
            }))
        end
    end)

    return self
end

function TurbineManager:initTurbines()
    local turbines = {}
    
    -- Turn on all turbines
    for address, componentType in component.list("gt_machine") do
        local turbine = Turbine.new(component.proxy(address))
        if turbine == nil then
            return
        end
        turbine:setWorkAllowed(true)
        turbines[address] = turbine -- Change to use address as the key in turbineMap
    end

    os.sleep(2)  -- Allow time for the machines to start

    -- Check the status of all turbines and turn them off
    for _, turbine in pairs(turbines) do
        if turbine:isActive() then
            turbine:setWorkAllowed(false)
            os.sleep(2)  -- Allow time for the machine to stop

            -- Check if turbine is off
            if not turbine:isActive() then
                self.turbineMap[turbine.gtMachine.address] = turbine
                self.totalTurbines = self.totalTurbines + 1  -- Update total turbine count
            end
        end
    end
end

function TurbineManager:updateMaintenanceBuckets()
    -- Clear maintenance buckets
    for i = 0, 6 do
        self.maintenanceBuckets[i] = {}
    end

    -- Populate maintenance buckets based on the number of problems
    for _, turbine in pairs(self.turbineMap) do
        local numOfProblems = turbine:getMaintenance()
        table.insert(self.maintenanceBuckets[numOfProblems], turbine.gtMachine.address)
    end
end

function TurbineManager:updateTurbine(powerRequirement)
    local powerFactor

    if powerRequirement == Enums.PowerState.ToString[Enums.PowerState.LOW] then
        powerFactor = 0.33
    elseif powerRequirement == Enums.PowerState.ToString[Enums.PowerState.MED] then
        powerFactor = 0.66
    elseif powerRequirement == Enums.PowerState.ToString[Enums.PowerState.HIGH] then
        powerFactor = 1
    else
        powerFactor = 0
    end

    local requiredTurbines = math.ceil(#self.turbineMap * powerFactor)
    local turbinesStarted = 0

    for i = 0, 6 do
        local bucket = self.maintenanceBuckets[i]
        for _, turbineAddress in ipairs(bucket) do
            local turbine = self.turbineMap[turbineAddress]

            if turbine then
                if turbinesStarted <= requiredTurbines then
                    turbine:isEnabled(true)
                    turbinesStarted = turbinesStarted + 1
                else
                    turbine:isEnabled(false)
                end
            end
        end
    end

    self.activeTurbines = turbinesStarted
    self.powerRequirement = powerRequirement
end


function TurbineManager:getOverallMaintenanceStatus()
    local totalTurbines = 0
    local totalMaintenance = 0

    for _, turbine in pairs(self.turbineMap) do
        totalTurbines = totalTurbines + 1
        totalMaintenance = totalMaintenance + turbine.maintenance
    end

    local overallMaintenancePercentage = (totalMaintenance / (totalTurbines * 6)) * 100

    return overallMaintenancePercentage
end

function TurbineManager:requestMaintenanceStatus()

    local message = {
        code = "MaintenenceStatus",
        content = self:getOverallMaintenanceStatus()
    }

    self.messageHandler:sendMessage(self.orchestratorAddress, self.orchestratorManagerPort, serialization.serialize(message))
end


function TurbineManager:draw()
    local screenWidth, screenHeight = self.gpu.getResolution()
    
    -- Implement GPU-based UI updates
    self.gpu.fill(1, 1, screenWidth, screenHeight, " ")

    -- Display Battery Manager information
    local connectionStatus = self.isConnected and "Connected" or "Disconnected"
    self.gpu.set(1, 1, "Turbine Manager: " .. connectionStatus)
    self.gpu.set(1, 2, "Total Turbines: " .. self.totalTurbines)
    self.gpu.set(1, 3, "Active Turbines: " .. self.activeTurbines)
    self.gpu.set(1, 4, "Power Requirement: " .. self.powerRequirement)
        -- Display logs in a box
    local logBoxWidth = screenWidth
    local logBoxHeight = screenHeight - 3
    local logBoxX, logBoxY = 1, 6    
    self:drawLogBox(logBoxX, logBoxY, logBoxWidth, logBoxHeight)
end

return TurbineManager
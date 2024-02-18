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
    self.powerRequirement = Enums.PowerState.OFF
    self.powerType = turbineType
    self.maintenanceBuckets = {}
    for i = 0, 6 do
        self.maintenanceBuckets[i] = {}
    end

    thread.create(function()
        while true do
            self:draw()
            self:checkOrchestratorConnection()
            os.sleep(1)
        end
    end)

    self:initTurbines()

    thread.create(function()
        while true do
            self.logger:info("Checking Turbine maintenance...")
            if self.totalTurbines > 0 then
                self:updateMaintenanceBuckets()
                self.logger:info("Checked maintenance")
                os.sleep(30)
            else
                self.logger:info("No Turbines")
                os.sleep(15)
            end
        end
    end)

    self.messageHandler:registerHandler(self.orchestratorManagerPort, function(sender, message)
        if message.code == "MaintenenceStatus" then
            if self.totalTurbines > 0 then
                self:sendMaintenanceStatus(message.content)
            end
        elseif message.code == "PowerState" then
            self:updateTurbines(message.content.powerState)
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
        if turbine ~= nil then
            turbine:isEnabled(true)
            turbines[address] = turbine -- Change to use address as the key in turbineMap
        end
        
    end

    os.sleep(2)  -- Allow time for the machines to start

    -- Check the status of all turbines and turn them off
    for _, turbine in pairs(turbines) do
        if turbine:isMachineActive() then
            turbine:isEnabled(false)
            os.sleep(2)  -- Allow time for the machine to stop

            -- Check if turbine is off
            if not turbine:isMachineActive() then
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
        self.logger:info("Turbine: " .. numOfProblems)
        local bucketIndex = math.floor(numOfProblems)  -- Convert to integer
        table.insert(self.maintenanceBuckets[bucketIndex], turbine.gtMachine.address)
    end

    -- Print the number of addresses in each bucket
    for i = 0, 6 do
        self.logger:info("Bucket " .. i .. ": " .. #self.maintenanceBuckets[i] .. " turbines")
    end
end


function TurbineManager:updateTurbines(powerRequirement)
    self.logger:info("Updating Turbines with power requirement: " .. Enums.PowerState.ToString[powerRequirement])
    local powerFactor
    self.powerRequirement = powerRequirement

    if self.powerRequirement == Enums.PowerState.LOW then
        powerFactor = 0.33
    elseif self.powerRequirement == Enums.PowerState.MED then
        powerFactor = 0.66
    elseif self.powerRequirement == Enums.PowerState.HIGH then
        powerFactor = 1
    else
        powerFactor = 0
    end

    local requiredTurbines = math.ceil(self.totalTurbines * powerFactor)
    local turbinesStarted = 0

    self.logger:info("Required turbines: " .. requiredTurbines)

    for i = 0, 6 do
        local bucket = self.maintenanceBuckets[i]
        for _, turbineAddress in ipairs(bucket) do
            local turbine = self.turbineMap[turbineAddress]

            if turbine then
                if turbinesStarted < requiredTurbines then
                    turbine:isEnabled(true)
                    self.logger:info("Turbine " .. turbineAddress .. " enabled.")
                    turbinesStarted = turbinesStarted + 1
                else
                    turbine:isEnabled(false)
                    self.logger:info("Turbine " .. turbineAddress .. " disabled.")
                end
            end
        end
    end

    self.logger:info("Total turbines started: " .. turbinesStarted)
    self.activeTurbines = turbinesStarted
    self.powerRequirement = powerRequirement
end

function TurbineManager:getLowestRotorHealth()
    local lowestRotorHealth = 999

    for _, turbine in pairs(self.turbineMap) do
        if turbine and turbine.lowestRotorHealth then
            lowestRotorHealth = math.min(lowestRotorHealth, turbine.lowestRotorHealth)
        end
    end

    return lowestRotorHealth
end

function TurbineManager:getOverallMaintenanceStatus()
    local totalMaintenance = 0

    for _, turbine in pairs(self.turbineMap) do
        totalMaintenance = totalMaintenance + turbine.maintenance
    end

    local overallMaintenancePercentage = 100 - ((totalMaintenance / (self.totalTurbines * 6)) * 100)

    return overallMaintenancePercentage
end

function TurbineManager:sendMaintenanceStatus()
    local maintenanceStatus = self:getOverallMaintenanceStatus()
    local lowestRotorHealth = self:getLowestRotorHealth()
    
    local message = {
        code = "MaintenenceStatus",
        content = {
            maintenanceStatus = maintenanceStatus,
            lowestRotorHealth = lowestRotorHealth,
            powerState = self.powerRequirement
        }
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
    self.gpu.set(1, 4, "Power Requirement: " .. Enums.PowerState.ToString[self.powerRequirement])

    
    -- Display number, isActive, and health for all turbines in a table-like layout
    self.gpu.set(1, 6, "Turbine Status:")
    local lineCounter = 7 

    if self.totalTurbines > 0 then
        -- Calculate the width of each section for turbines
        local sectionWidth = math.floor(screenWidth / 8)

        -- Header line with column labels
        local turbineIndex = 1
        for address, _ in pairs(self.turbineMap) do
            self.gpu.set((turbineIndex - 1) * sectionWidth + 1, lineCounter, "" .. turbineIndex)
            turbineIndex = turbineIndex + 1
        end
        lineCounter = lineCounter + 1

        -- Display ON/OFF status for each turbine
        turbineIndex = 1
        for address, turbine in pairs(self.turbineMap) do
            local statusChar = (turbine.isActive and "ON" or "OFF") or ""
            self.gpu.set((turbineIndex - 1) * sectionWidth + 1, lineCounter, statusChar)
            turbineIndex = turbineIndex + 1
        end
        lineCounter = lineCounter + 1

        -- Display health percentage for each turbine
        turbineIndex = 1
        for address, turbine in pairs(self.turbineMap) do
            local healthPercentage = math.floor(100 - math.min(6, math.max(0, turbine.maintenance)) * 100 / 6) or 0
            local healthText = tostring(healthPercentage) .. "%"
            self.gpu.set((turbineIndex - 1) * sectionWidth + 1, lineCounter, healthText)
            turbineIndex = turbineIndex + 1
        end
        lineCounter = lineCounter + 1
    end

    --spacer
    lineCounter = lineCounter + 1

    self.gpu.set(1, lineCounter, "Logs:")
    --spacer
    lineCounter = lineCounter + 1

        -- Display logs in a box
    local logBoxWidth = screenWidth
    local logBoxHeight = screenHeight - 3
    local logBoxX, logBoxY = 1, lineCounter    
    self:drawLogBox(logBoxX, logBoxY, logBoxWidth, logBoxHeight)
end

return TurbineManager
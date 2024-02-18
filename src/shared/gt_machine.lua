local component = require("component")
local serialization = require("serialization")

-- GTMachine object definition
local GTMachine = {}
GTMachine.__index = GTMachine

function GTMachine.new(gtMachine)
    local self = setmetatable({}, GTMachine)
    self.gtMachine = gtMachine
    self.maintenance = 6
    self.sensorInfo = {}
    self.markedForTermination = false
    self.lastCheckTime = 0

    self.checkInterval = 60

    self:getMaintenance()
    self.isActive = self:isMachineActive()
    self.name = self:getName()

    self.turbineStatus = false
    self.maintenanceStatus = true
    self.currentSpeed = 0
    self.turbineDamage = 100

    return self
end

function GTMachine:retry(func)
    local maxAttempts = 3
    local attempts = 0
    local success, errorMessage

    repeat
        success, errorMessage = pcall(func)
        attempts = attempts + 1

        if not success and attempts >= maxAttempts then
            self:markForTermination()
        end
    until success or attempts >= maxAttempts

    return success
end

function GTMachine:markForTermination()
    self.markedForTermination = true
end

function GTMachine:withErrorHandling(func, defaultValue)
    local success, result

    self:retry(function()
        success = pcall(function()
            result = func()
        end)
    end)

    if not success then
        result = defaultValue
    end

    return result
end

function GTMachine:getSensorInformation()
    local currentTime = os.time()
    if currentTime - self.lastCheckTime >= self.checkInterval then
        self.sensorInfo = self:withErrorHandling(function()
            return self.gtMachine.getSensorInformation()
        end, {})

        -- Update internal values only if information retrieval was successful
        if self.sensorInfo and #self.sensorInfo >= 8 then

            for i, value in ipairs(self.sensorInfo) do
                self.sensorInfo[i] = value:gsub("§.", "")
            end

            local turbineStatusAndEUPerTick = self.sensorInfo[1]
            local turbineStatus, _ = turbineStatusAndEUPerTick:match("(%a+): (%d+) EU/tick")
            self.turbineStatus = (turbineStatus == "Running")
            self.maintenanceStatus = self.sensorInfo[2]
            local speedPercentage = tonumber(self.sensorInfo[3]:match("(%d+%.?%d*)%%"))
            self.currentSpeed = speedPercentage or 0
            self.turbineDamage = self.sensorInfo[7]
            return self.turbineStatus
        end
    end

    return false
end


function GTMachine:getMaintenance()
    self:getSensorInformation()
    -- Extract maintenance information only when the machine is running
    local numOfProblems = 6
    if self.isActive and self.maintenanceStatus == "Needs Maintenance" then
        if self.currentSpeed and self.currentSpeed > 0 and self.currentSpeed <= 100 then
            numOfProblems = math.max(0, 10 - math.floor(self.currentSpeed / 10))
        else
            return self.maintenance
        end
    elseif self.maintenanceStatus == "No Maintenance issues" then
        numOfProblems = 0
    end

    self.maintenance = numOfProblems
    return numOfProblems
end


function GTMachine:isEnabled(state)
    local result = self:withErrorHandling(function()
        self.gtMachine.setWorkAllowed(state)
    end, nil)
    
    self.isActive = state

    return state
end



function GTMachine:isMachineActive()
    local result = self:withErrorHandling(function()
        self.isActive = self.gtMachine.isMachineActive()
    end, false)

    if result == false then
        self.isActive = false
    end

    return self.isActive
end

function GTMachine:getName()
    return self:withErrorHandling(function()
        return self.gtMachine.getName()
    end, '')
end

return GTMachine

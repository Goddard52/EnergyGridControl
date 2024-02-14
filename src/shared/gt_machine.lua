-- GTMachine object definition
local GTMachine = {}
GTMachine.__index = GTMachine

function GTMachine.new(gtMachine)
    local self = setmetatable({}, GTMachine)
    self.gtMachine = gtMachine
    self.maintenance = 6
    self.sensorInfo = {}
    self.markedForTermination = false

    self.checkInterval = 60

    self.maintenance = self:getMaintenance()
    self.isActive = self:isActive()
    self.name = self:getName()

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

    return success, errorMessage
end

function GTMachine:markForTermination()
    self.markedForTermination = true
end

function GTMachine:withErrorHandling(func)
    local success, result, errorMessage

    self:retry(function()
        success, errorMessage = pcall(function()
            result = func()
        end)
    end)

    if not success then
        result = nil
    end

    return result
end

function GTMachine:getSensorInformation()
    local currentTime = os.time()
    if currentTime - self.lastCheckTime >= self.checkInterval then
        return self:withErrorHandling(function()
            self.sensorInfo = self.gtMachine.getSensorInformation()
        end)
    end
    
    return self.sensorInfo 
end

function GTMachine:getMaintenance()
    local sensorInfo = self:getSensorInformation()
    if not sensorInfo[5] then
        return nil
    end

    local fifthInfo = sensorInfo[5]
    local numOfProblems = fifthInfo:match("(%d+)")
    return numOfProblems
end

function GTMachine:isEnabled(state)
    return self:withErrorHandling(function()
        self.gtMachine.setWorkAllowed(state)
    end)
end

function GTMachine:isActive()
    return self:withErrorHandling(function()
        return self.gtMachine.isMachineActive()
    end)
end

function GTMachine:getName()
    return self:withErrorHandling(function()
        return self.gtMachine.getName()
    end)
end

return GTMachine

local component = require("component")

-- GTMachine object definition
local GTMachine = {}
GTMachine.__index = GTMachine

function GTMachine.new()
    local self = setmetatable({}, GTMachine)
    self.sensorInfo = {}
    return self
end

function GTMachine:getSensorInformation()
    self.sensorInfo = component.gt_machine.getSensorInformation()
    return self.sensorInfo
end

function GTMachine:getMaintenance()
    if not self.sensorInfo[5] then
        return nil
    end

    local fifthInfo = self.sensorInfo[5]
    local numOfProblems = fifthInfo:match("(%d+)")
    return numOfProblems
end

function GTMachine:isEnabled(state)
    component.gt_machine.setWorkAllowed(state)
end

function GTMachine:isActive()
    component.gt_machine.isMachineActive()
end

function GTMachine:getName()
    return component.gt_machine.getName()
end

return GTMachine

-- turbine_server.lua
local component = require("component")
local event = require("event")
local thread = require("thread")

local turbine = require("gt_machine")
local CommonManager = require("commonManager")

local TurbineManager = setmetatable({}, { __index = CommonManager })

function TurbineManager.new()
    local self = CommonManager.create("Turbine Manager", 324)
    setmetatable(self, { __index = TurbineManager })


    self.orchestratorTurbineManagerPort = 324

    return self
end

-- Do more stuff

return TurbineManager

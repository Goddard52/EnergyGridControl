local component = require("component")
local event = require("event")
local thread = require("thread")
local serialization = require("serialization")

local BatteryBuffer = require("battery")
local CommonManager = require("commonManager")

local BatteryManager = setmetatable({}, { __index = CommonManager })

function BatteryManager.new()
    local self = CommonManager.create("Battery Manager", 324)
    setmetatable(self, { __index = BatteryManager })

    self.orchestratorManagerPort = 324

    -- Battery Manager initialization
    self.batteryBuffers = {}
    self.lastCheckTime = 0
    self.totalCharge = 0

    thread.create(function()
        while true do
            self:draw()
            self:checkOrchestratorConnection()
            os.sleep(1)
        end
    end)
    
    self:initBatteryBuffers()
    
    for _, batteryBuffer in ipairs(self.batteryBuffers) do
        thread.create(function()
            while true do
                batteryBuffer:updateBatteryConfiguration()
                batteryBuffer:checkBatteriesCharge()
                os.sleep(5)
            end
        end)
        os.sleep(2)
    end
    
    thread.create(function()
        while true do
            self.totalCharge = self:getTotalBatteryCharge()
            os.sleep(1)
        end
    end)

    self.messageHandler:registerHandler(self.orchestratorManagerPort, function(sender, message)
        if message.code == "Status" then
            self.logger:log("Getting StatusUpdate")
            self:chargeStatusUpdate()
        end
    end)
    
    return self
end

function BatteryManager:initBatteryBuffers()
    local buffers = {}
    for address, componentType in component.list("gt_batterybuffer") do
        table.insert(buffers, component.proxy(address))
    end

    for _, buffer in ipairs(buffers) do
        local bat = BatteryBuffer.new(buffer)
        table.insert(self.batteryBuffers, bat)
    end
end

function BatteryManager:getTotalBatteryCharge()
    -- Print aggregated information
    local totalCharge = 0
    if #self.batteryBuffers > 0 then
        for _, buffer in ipairs(self.batteryBuffers) do
            totalCharge = totalCharge + buffer.charge
        end
    end
    
    return totalCharge
end

-- Modify the listenForChargeStatusUpdate function
function BatteryManager:chargeStatusUpdate()
        -- Respond with the total battery charge
        self.messageHandler:sendMessage(self.orchestratorAddress, self.orchestratorManagerPort, serialization.serialize({
            code = "ChargeStatus",
            content = self.totalCharge
        }))
end

function BatteryManager:draw()
    local screenWidth, screenHeight = self.gpu.getResolution()
    
    -- Implement GPU-based UI updates
    self.gpu.fill(1, 1, screenWidth, screenHeight, " ")

    -- Display Battery Manager information
    local connectionStatus = self.isConnected and "Connected" or "Disconnected"
    self.gpu.set(1, 1, "Battery Manager: " .. connectionStatus)
    self.gpu.set(1, 2, "Number of Battery Buffers: " .. #self.batteryBuffers)
    self.gpu.set(1, 3, "Total Charge: " .. self.totalCharge)

        -- Display logs in a box
    local logBoxWidth = screenWidth
    local logBoxHeight = screenHeight - 3
    local logBoxX, logBoxY = 1, 4    
    self:drawLogBox(logBoxX, logBoxY, logBoxWidth, logBoxHeight)
end

return BatteryManager

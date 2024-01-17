local component = require("component")

-- Battery object definition
local BatteryBuffer = {}
BatteryBuffer.__index = BatteryBuffer

function BatteryBuffer.new(buffer)
    local self = setmetatable({}, BatteryBuffer)
    self.buffer = buffer
    self.slots = {} -- Table to store discovered battery slots
    self.hasBatteries = false
    self.lastCheckTime = 0 -- Store the time of the last battery check
    self.checkInterval = 1200
    self.charge = 0
    return self
end

function BatteryBuffer:discoverBatteries()
    self.slots = {} -- Reset the slots table before discovery
    for i = 1, 16 do
        if self.buffer.getBatteryCharge(i) ~= nil then
            table.insert(self.slots, i) -- Store the battery slots that have batteries
        end
    end
    self.hasBatteries = #self.slots > 0
    self.lastCheckTime = os.time() -- Update the last check time
    return self.hasBatteries
end

function BatteryBuffer:updateBatteryConfiguration()
    local currentTime = os.time()
    if currentTime - self.lastCheckTime >= self.checkInterval then
        self:discoverBatteries()
    end
end

function BatteryBuffer:checkBatteriesCharge()
    if not self.hasBatteries then
        self.charge = 88
        return
    end

    local batteryCharge = 0
    for _, slot in ipairs(self.slots) do
        local charge = self.buffer.getBatteryCharge(slot)
        if charge ~= nil then
            batteryCharge = batteryCharge + charge
        end
    end
    self.charge = batteryCharge
end

return BatteryBuffer

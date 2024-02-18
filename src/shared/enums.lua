-- enums.lua

local Enums = {}

Enums.TurbineType = {
    STEAM = 1,
    BENZENE = 2,
    HIGH_OCTANE = 3
}

Enums.ManagerType = {
    BATTERY = {
        ID = 1,
        NAME = "Battery Manager"
    },
    TURBINE = {
        ID = 2,
        NAME = "Turbine Manager"
    }
}

Enums.PowerState = {
    OFF = 0,
    LOW = 1,
    MED = 2,
    HIGH = 3
}
Enums.PowerState.ToString = {
    [Enums.PowerState.OFF] = "OFF",
    [Enums.PowerState.LOW] = "LOW",
    [Enums.PowerState.MED] = "MED",
    [Enums.PowerState.HIGH] = "HIGH"
}

Enums.TurbineType.ToString = {
    [Enums.TurbineType.STEAM] = "Steam",
    [Enums.TurbineType.BENZENE] = "Benzene",
    [Enums.TurbineType.HIGH_OCTANE] = "High Octane"
}

Enums.BatteryMaxCharge = 2560000000

Enums.TurbineMatrix = {
    [Enums.TurbineType.STEAM] = {
        [Enums.PowerState.OFF] = 100,
        [Enums.PowerState.LOW] = 99,
        [Enums.PowerState.MED] = 97,
        [Enums.PowerState.HIGH] = 95
    },
    [Enums.TurbineType.BENZENE] = {
        [Enums.PowerState.OFF] = 90,
        [Enums.PowerState.LOW] = 60,
        [Enums.PowerState.MED] = 50,
        [Enums.PowerState.HIGH] = 40
    },
    [Enums.TurbineType.HIGH_OCTANE] = {
        [Enums.PowerState.OFF] = 70,
        [Enums.PowerState.LOW] = 40,
        [Enums.PowerState.MED] = 30,
        [Enums.PowerState.HIGH] = 25
    }
}

return Enums

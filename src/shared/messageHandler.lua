-- MessageHandler.lua

local event = require("event")
local thread = require("thread")

local MessageHandler = {}

function MessageHandler.new()
    local self = {
        handlers = {},
    }

    thread.create(function()
        self:listenForMessages()
    end)

    setmetatable(self, { __index = MessageHandler })
    return self
end

function MessageHandler:listenForMessages()
    while true do
        local _, _, sender, port, _, message = event.pull("modem_message")
        if port and message then
            -- Dispatch the message to the appropriate handler
            self:dispatchMessage(sender, port, message)
        end
    end
end

function MessageHandler:dispatchMessage(sender, port, message)
    local handler = self.handlers[port]
    if handler then
        handler(sender, message)
    end
end

function MessageHandler:registerHandler(port, handler)
    self.handlers[port] = handler
end

function MessageHandler:sendMessage(receiver, port, message)
    -- Assuming you are using modem communication
    local success, reason = pcall(function()
        require("component").modem.send(receiver, port, message)
    end)

    if not success then
        -- Handle the error, e.g., log it or raise an exception
        print("Failed to send message:", reason)
    end
end


return MessageHandler

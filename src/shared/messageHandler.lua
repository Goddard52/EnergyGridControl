-- MessageHandler.lua

local event = require("event")
local thread = require("thread")
local modem = require("component").modem
local serialization = require("serialization")

local MessageHandler = {}

function MessageHandler.new(logger)
    local self = {
        handlers = {},
        logger = logger,
        modem = modem
    }

    local function listenForMessages()
        while true do
            local success, result = pcall(function()
                local _, _, sender, port, _, message = event.pull("modem_message")
                if port then
                    -- Dispatch the message to the appropriate handler
                    self.logger:log("Received message: " .. message)
                    self:dispatchMessage(sender, port, message)
                end
            end)
    
            if not success then
                -- Handle the error, e.g., log it or take appropriate action
                self.logger:log("Error in thread:", result)
            end
        end
    end
    

    -- Start the event listening thread
    local listeningThread = thread.create(listenForMessages)

    setmetatable(self, { __index = MessageHandler })
    return self
end

function MessageHandler:dispatchMessage(sender, port, message)
    local handler = self.handlers[port]
    if handler then
        if port == 324 or port == 325 then
            self.logger:log("Received message on Port 324 or 325 : " .. message)
            local deserializedMessage = serialization.unserialize(message)
            self.logger:log("Deserialized message: " .. serialization.serialize(deserializedMessage))
            handler(sender, deserializedMessage)
        else
            handler(sender, message)
        end
    end
end


function MessageHandler:registerHandler(port, handler)
    if not self.modem.isOpen(port) then
        self.modem.open(port)
        self.logger:log("Opened port " .. port .. " for listening.")
    end

    self.handlers[port] = handler
    self.logger:log("Handler registered for port " .. port)
end

function MessageHandler:sendMessage(receiver, port, message)
    -- Assuming you are using modem communication
    local success, reason = pcall(function()
        self.modem.send(receiver, port, message)
        self.logger:log("Sent message to " .. receiver .. " on port " .. port .. ": " .. message)
    end)

    if not success then
        -- Handle the error, e.g., log it or raise an exception
        self.logger:log("Failed to send message:", reason)
    end
end

return MessageHandler

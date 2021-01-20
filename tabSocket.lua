--tabSocket is a simple tab interface for lua socket, the implementation
--demonstrates the correct use of tabProxy
--author cs
--email 04nycs@gmail.com
--https://github.com/ThinEureka/tabMachine
--created on Jan 11, 2021 

local socket = require "socket"

local cocosContext = require("app.common.tabMachine.cocosContext")
local tabSocket = class("tabSocket", cocosContext)

local STATUS_CLOSED = "closed"
local STATUS_NOT_CONNECTED = "Socket is not connected"
local STATUS_ALREADY_CONNECTED = "already connected"
local STATUS_ALREADY_IN_PROGRESS = "Operation already in progress"
local STATUS_TIMEOUT = "timeout"

tabSocket.STATE = {
    DISCONNECTED = 1, 
    CONNECTING = 2,
    CONNECTED = 3,
}

--------------------------------------------------------------------------------
-- main flow 
-- private:

function tabSocket:s1(isUsingIpV6)
    self._isUsingIpV6 = isUsingIpV6
    self._tcp = nil
    self._buffer = nil
    self:call(self:tabMain(), "main")
    self._main = self:getSub("main")
end

function tabSocket:tabMain()
    return {
        s1 = function(c)
            self._state = tabSocket.STATE.DISCONNECTED
            c:call(self:tabWaitConnectEvent(), "s2", {"ip", "port", "timeout"})
        end,

        s3 = function(c)
            self._state = tabSocket.STATE.CONNECTING
            c:call(self:tabConnectting(c.v.ip, c.v.port), "s4", {"isSuccess", "err"})
        end,

        s5 = function(c)
            if c.v.isSuccess then
                self._state = tabSocket.STATE.CONNECTED
                c:call(self:tabConnectted(), "s6")
            else
                c:start("s1")
            end
        end,

        s7 = function(c)
            c:start("s1")
        end,

        --public:
        tabState = function(c, scName)
            if scName == tabSocket.STATE.CONNECTING then
                return c:tabProxy("s4")
            elseif scName == tabSocket.STATE.CONNECTED then
                return c:tabProxy("s4")
            elseif scName == tabSocket.STATE.DISCONNECTED then
                return c:tabProxy("s4")
            end
        end,
    }
end

function tabSocket:tabWaitConnectEvent()
    return {
        s1 = function(c)
            if g_t.debug then
                c._nickName = "tabWaitConnectEvent"
            end
        end,
        s1_event = function(c, event)
            if type(event) == "table" and
                event.name == "tabSocket.connect" then
                c:output(event.ip, event.port, event.timeout)
                c:stop()
                return true
            end
        end,
    }
end

function tabSocket:tabConnectting(ip, port, timeout)
    if timeout == nil then
        timeout = 3
    end

    return {
        s1 = function(c)
            if g_t.debug then
                c._nickName = "tabConnectting"
            end
            self._buffer = {}

            local ipV6 = self:getIpV6Address(ip)
            if self._isUsingIpV6 and ipV6 ~= nil then
                c.v.ip = ipV6
                self._tcp = socket.tcp6() 
            else
                c.v.ip = ip
                self._tcp = socket.tcp()
            end
            self._tcp:settimeout(0)

            c.v.time = 0

            c.v.isConnected = c:_tryToConnect()
            if c.v.isConnected then
                c:output(true)
                c:stop()
            end
        end,

        s1_update = function(c, dt)
            c.v.isConnected = c:_tryToConnect()
            if c.v.isConnected then
                c:output(true)
                c:stop()
                return
            end

            c.v.time = c.v.time + dt
            if c.v.time >= timeout then
                c:output(false, "tabSocket.connectting.timeout")
                c:stop()
            end
        end,

        event = function(c, event)
            if type(event) == "table" and
                event.name == "tabSocket.disconnect" then
                c:output(false, event.name)
                c:stop()
            end
        end,

        final = function(c)
            if not c.v.isConnected then
                self._tcp:close()
                self._tcp = nil
            end
        end,

        --private:
        _tryToConnect = function(c)
            local isSuccess, status = self._tcp:connect(c.v.ip, port)
            if not isSuccess then
                if status == STATUS_ALREADY_CONNECTED then
                    isSuccess = true
                end
            end

            return isSuccess
        end,
    }
end

function tabSocket:tabConnectted()
    return {
        s1 = function(c)
            if g_t.debug then
                c._nickName = "tabConnectted"
            end
        end,

        s1_update = function(c)
            local body, status, partical = self._tcp:receive("*a")	-- read the package body
            if body and body:len() > 0 then
                table.insert(self._buffer, body)
            end

            if partical and partical:len() > 0 then
                table.insert(self._buffer, partical)
            end

    	    if status == STATUS_CLOSED or status == STATUS_NOT_CONNECTED then
                c:output(false, "closed")
                c:stop()
            end
        end,

        event = function(c, event)
            if type(event) == "table" and
                event.name == "tabSocket.disconnect" then
                c:output(false, event.name)
                c:stop()
            end
        end,

        final = function(c)
            self._tcp:shutdown()
            self._tcp:close()
            self._tcp = nil
        end,
    }
end


function tabSocket:final()
    if self._tcp then
        self._tcp:close()
    end
end

--------------------------------------------------------------------------------
--public:
function tabSocket:connect(ip, port)
    self._main:notify({name = "tabSocket.connect", ip = ip, port = port, timeout = timeout})
    return self._main:tabState(tabSocket.STATE.CONNECTING)
end

function tabSocket:disconnect()
    self._main:notify({name = "tabSocket.disconnect"})
end

function tabSocket:getState()
    return self._state
end

--the progress when socket is the specified state
function tabSocket:tabInState(state)
    return {
        s1 = function(c)
            c._nickName = "tabSocket#tabInState->".. state
            if self._state ~= state then
                c:stop()
            else
                c:call(self._main:tabState(state), "s2")
            end
        end,
    }
end

--read a segment of which the boundary is determined by funDecode 
function tabSocket:tabReadOneSegment(funDecode, updateInterval)
    return {
        s1 = function(c)
            if g_t.debug then
                c._nickName = "tabSocket#tabReadOneSegment"
            end

            c.v.lastBuffSize = 0
            local segment = c:_decode()
            if segment ~= nil then
                c:output(segment)
                c:stop()
            end
        end,

        s1_update = function(c, dt)
            local segment = c:_decode()
            if segment ~= nil then
                c:output(segment)
                c:stop()
            end
        end,

        s1_updateInterval = updateInterval,

        _decode = function(c)
            local newBuffLen = #self._buffer
            if newBuffLen ~= c.v.lastBuffLen and newBuffLen > 0 then
                local stream
                if newBuffLen > 1 then
                    stream = table.concat(self._buffer)
                else
                    stream = self._buffer[1]
                end

                local segment, remain = funDecode(stream)

                while (#self._buffer > 0) do
                    table.remove(self._buffer)
                end

                if remain and remain:len() > 0 then
                    table.insert(self._buffer, remain)
                    c.v.lastBuffLen = 1
                else
                    c.v.lastBuffLen = 0
                end

                return segment
            else
                return nil
            end
        end,
    }
end

--pull msgs repeatly 
function tabSocket:tabPullSegments(funDecode, segmentHandler, updateInterval)
    return {
        s1 = function(c)
            if g_t.debug then
                c._nickName = "tabSocket#tabPullSegments"
            end

            c.v.lastBuffSize = 0
            c:_pullSegment()
        end,

        s1_update = function(c, dt)
            c:_pullSegment()
        end,

        s1_updateInterval = updateInterval,

        --private:
        _pullSegment = function(c)
            while true do
                local segment = c:_decode()
                if segment ~= nil then
                    segmentHandler(segment)
                else
                    break
                end
            end
        end,

        _decode = function(c)
            local newBuffLen = #self._buffer
            if newBuffLen ~= c.v.lastBuffLen and newBuffLen > 0 then
                local stream
                if newBuffLen > 1 then
                    stream = table.concat(self._buffer)
                else
                    stream = self._buffer[1]
                end

                local segment, remain = funDecode(stream)

                while (#self._buffer > 0) do
                    table.remove(self._buffer)
                end

                if remain and remain:len() > 0 then
                    table.insert(self._buffer, remain)
                    c.v.lastBuffLen = 1
                else
                    c.v.lastBuffLen = 0
                end

                return segment
            else
                return nil
            end
        end,
    }
end

function tabSocket:send(data)
    assert(self._state == tabSocket.STATE.CONNECTED, "socket is not connected")
    if self._tcp then
        self._tcp:send(data)
    end
end

--------------------------------------------------------------------------------
--private:
function tabSocket:getIpV6Address(ip)
    local result = socket.dns.getaddrinfo(ip)
    local addr = nil
    if result then
        for k,v in pairs(result) do
            if v.family == "inet6" then
                addr = v.addr
                break
            end
        end
    end

    return addr
end

return tabSocket


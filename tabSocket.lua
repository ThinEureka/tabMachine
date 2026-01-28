--tabSocket is a simple tab interface for lua socket, the implementation
--demonstrates the correct use of tabProxy
--author cs
--email 04nycs@gmail.com
--https://github.com/ThinEureka/tabMachine
--created on Jan 11, 2021 

local socket = require "socket"

local tabSocket = nil

local STATUS_CLOSED = "closed"
local STATUS_NOT_CONNECTED = "Socket is not connected"
local STATUS_ALREADY_CONNECTED = "already connected"
local STATUS_ALREADY_IN_PROGRESS = "Operation already in progress"
local STATUS_TIMEOUT = "timeout"

--------------------------------------------------------------------------------
-- main flow 
-- private:
tabSocket = _{
    tabName = "tabSocket",

    STATE = {
        DISCONNECTED = 1, 
        CONNECTING = 2,
        CONNECTED = 3,
    },

    s1 = function(c, isUsingIpV6)
        c._isUsingIpV6 = isUsingIpV6
        c._closeDelay = 0.1
        c._tcp = nil
        c._buffer = nil

        c._state = tabSocket.STATE.DISCONNECTED
        c._nickName = "SOCKET->等待连接指令"
        c:suspend("s2")
    end,

    s2 = function(c, mode, ip, port, timeout, tcp)
        c._nickName = tostring(ip)..":"..tostring(port)

        if mode == 1 then
            c._state = tabSocket.STATE.CONNECTING
            c._nickName = "SOCKET->连接中"
            c._buffer = {}
            c._tcp = nil
            c:call(tabSocket.tabConnectting(ip, port, timeout) >> "isSuccess" >> "err", "s3")
        else
            --only for server mode
            c._nickName = "SOCKET->已连接"
            c._tcp = tcp
            c._tcp:settimeout(0.000000000001)
            c._buffer = {}
            c._state = tabSocket.STATE.CONNECTED
            c._connected = c:call(tabSocket.tabConnectted(), "s5")
        end
    end,

    s4 = function(c)
        if c.isSuccess then
            c._nickName = "SOCKET->已连接"
            c._state = tabSocket.STATE.CONNECTED
            c._connected = c:call(tabSocket.tabConnectted(), "s5")
        else
            c:start("s1")
        end
    end,

    s6 = function(c)
        c._connected = nil
        c:start("s1")
    end,

    final = function(c)
        if c._tcp then
            c._tcp:close()
        end
    end,

    -- inner 
    inner = {
        tabSocket = function(c)
            return c
        end,

        buffer = function(c)
            return c._buffer
        end,

        isUsingIpV6 = function(c)
            return c._isUsingIpV6
        end,

        tcp = function(c)
            return c._tcp
        end,

        setTcp = function(c, tcp)
            c._tcp = tcp
        end,

        closeDelay = function(c)
            return c._closeDelay
        end,
    },

    --public:
    connect = function(c, ip, port, timeout)
        c:resume("s2", 1, ip, port, timeout)
        return c:tabProxy("s3")
    end,

    disconnect = function(c)
        c:notify("tabSocket.disconnect")
    end,

    --for server
    acceptSocket = function(c, tcp)
        assert(tcp ~= nil)
        assert(c._state == tabSocket.STATE.DISCONNECTED)
        c:resume("s2", 2, nil, nil, nil, tcp)
    end,

    send = function(c, data)
        if c._connected == nil then
            return STATUS_NOT_CONNECTED
        end

        return c._connected:send(data)
    end,

    getState = function(c)
        return c._state
    end,

    --the progress when socket is the specified state
    tabInState = _{
        s1 = function(c, self, state)
            c._nickName = "tabSocket#tabInState->".. state
            if self._state ~= state then
                c:stop()
            else
                c:call(self:tabState(state), "s2")
            end
        end,
    },

    --private:
    tabState = function(c, scName)
        if scName == tabSocket.STATE.CONNECTING then
            return c:tabProxy("s2")
        elseif scName == tabSocket.STATE.CONNECTED then
            return c:tabProxy("s5")
        elseif scName == tabSocket.STATE.DISCONNECTED then
            return c:tabSuspend("s2")
        end
    end,
}

--private:
-- 2nd level flow
tabSocket.tabConnectting = _{
    tabName = "tabConnectting",

    s1 = function(c, ip, port, timeout)
        if timeout == nil then
            timeout = 3
        end

        c.timeout = timeout
        c.port = port

        local ipV6 = tabSocket.getIpV6Address(ip)
        if c:_("isUsingIpV6") and ipV6 ~= nil then
            c.ip = ipV6
            c.tcp = socket.tcp6() 
        else
            c.ip = ip
            c.tcp = socket.tcp()
        end

        c.tcp:settimeout(0.000000000001)
        c:_("setTcp", c.tcp)
        c.time = 0

        c.isConnected = c:_tryToConnect()
        if c.isConnected then
            c:output(true)
            c:stop("s1")
        end
    end,

    s1_update = function(c, dt)
        c.isConnected = c:_tryToConnect()
        if c.isConnected then
            c:output(true)
            c:stop()
            return
        end

        c.time = c.time + dt
        if c.time >= c.timeout then
            c:output(false, "tabSocket.connectting.timeout")
            c:stop()
        end
    end,

    s2 = function(c)
        c:call(g_t.skipFrames(1), "s3")
    end,

    s4 = function(c)
        c:stop()
    end,

    event = {
        ["tabSocket.disconnect"] = function(c)
            c:output(false, "tabSocket.disconnect")
            c:stop()
        end
    },

    final = function(c)
        if not c.isConnected then
            c.tcp:close()
            c.tcp = nil
        end
    end,

    --private:
    _tryToConnect = function(c)
        local isSuccess, status = c.tcp:connect(c.ip, c.port)
        if not isSuccess then
            if status == STATUS_ALREADY_CONNECTED then
                isSuccess = true
            end
        end

        return isSuccess
    end,
}

tabSocket.tabConnectted = _{
    tabName = "tabConnectted",

    s1 = function(c)
        c._sendQueue = {}
    end,

    s1_update = function(c)
        local body, status, partical = c:_("tcp"):receive("*a") -- read the package body
        if partical and partical:len() > 0 then
            local buffer = c:_("buffer")
            table.insert(buffer, partical)
        else
            if body and body:len() > 0 then
                local buffer = c:_("buffer")
                table.insert(buffer, body)
            end
        end

        if status == STATUS_CLOSED or status == STATUS_NOT_CONNECTED then
            c.status = status
            c:stop("s1")
            return
        end

        local queueSize = #c._sendQueue
        while queueSize > 0 do
            local data = table.remove(c._sendQueue, 1)
            c:send(data, true)
            if queueSize == #c._sendQueue then
                break
            end
            queueSize = #c._sendQueue
        end
    end,

    s2 = function(c)
        -- 在socket连接关闭后，给个默认的延迟是外部有一定的时间读取buffer里内容
        c:call(g_t.delay, "s3", nil, c:_("closeDelay"))
    end,

    s4 = function(c)
        c:output(false, c.status)
        c:stop()
    end,

    event = {
        ["tabSocket.disconnect"] = function(c)
            c:output(false, "tabSocket.disconnect")
            c:stop()
        end
    },

    final = function(c)
        local tcp = c:_("tcp")
        tcp:shutdown()
        tcp:close()
        c:_("setTcp", nil)
    end,

    -- public:
    send = function(c, data, isRent)
        if not isRent then
            if #c._sendQueue > 0 then
                table.insert(c._sendQueue, data)
                return nil, nil, #data
            end
        end

        local size, err, sent = c:_("tcp"):send(data)

        if err == nil then
            return size, nil, nil
        elseif err == "timeout" then
            table.insert(c._sendQueue, 1 , data:sub(sent+1))
            return nil, nil, sent
        else
            --assert(false)
            return nil, err, sent
        end
    end,
}

--------------------------------------------------------------------------------
--public:

--read a segment of which the boundary is determined by funDecode 
tabSocket.tabReadOneSegment = _{
    tabName =  "tabSocket#tabReadOneSegment",

    s1 = function(c, self, funDecode, updateInterval, timeout, disconnectWhenTimeout)
        c.buffer = self:_("buffer")
        c.tabSocket = self
        
        c.funDecode = funDecode
        c.disconnectWhenTimeout = disconnectWhenTimeout

        c.lastBuffLen = 0
        local segment = c:_decode(c.buffer, c.funDecode)
        if segment ~= nil then
            c:output(segment)
            c:stop()
        end

        if timeout then
            c:call(g_t.delay, "d1", nil, timeout)
        end

        c:setDynamics("s2", "updateInterval", updateInterval)
    end,

    s2 = g_t.empty_fun,

    s2_update = function(c, dt)
        local buffer = c.buffer
        local newBuffLen = #buffer
        local funDecode = c.funDecode
        if newBuffLen ~= c.lastBuffLen and newBuffLen > 0 then
            local segment = c:_decode(buffer, funDecode)
            if segment ~= nil then
                c:output(segment)
                c:stop()
                return
            end
            c.lastBuffLen = #buffer
        end
    end,

    --override by setDynamics
    s2_updateInterval = nil,

    d2 = function(c)
        if c.disconnectWhenTimeout then
            c:stop("s2")
            c.tabSocket:disconnect()
        else
            c:output(nil)
            c:stop()
        end
    end,

    event = g_t.empty_event,

    -- private:
    _decode = function(c, buffer, funDecode)
        local newBuffLen = #buffer
        if newBuffLen > 0 then
            local stream
            if newBuffLen > 1 then
                stream = table.concat(buffer)
            else
                stream = buffer[1]
            end

            local segment, remain = funDecode(stream)

            while (#buffer > 0) do
                table.remove(buffer)
            end

            if remain and remain:len() > 0 then
                table.insert(buffer, remain)
            end

            return segment
        else
            return nil
        end
    end,
}

--pull msgs repeatly 
tabSocket.tabPullSegments = _{
    tabName =  "tabSocket#tabPullSegments",

    s1 = function(c, self, funDecode, segmentHandler, updateInterval)
        c.funDecode = funDecode
        c.buffer = self:_("buffer")
        c.segmentHandler = segmentHandler
        c.lastBuffLen = 0
        c.lastBreak = false
        c:setDynamics("s2", "updateInterval", updateInterval)
    end,

    s2 = function(c)
        c:_pullSegment()
    end,

    s2_update = function(c, dt)
        c:_pullSegment()
    end,

    --override by setDynamics
    s2_updateInterval = nil,

    --private:
    _pullSegment = function(c, frameTime)
        local buffer = c.buffer
        local newBuffLen = #buffer
        local socket = require("socket")
        local startTime = socket:gettime()
        if not frameTime then
            frameTime = 0.001
        end
        if (newBuffLen ~= c.lastBuffLen and newBuffLen > 0) or c.lastBreak then
            c.lastBreak = false
            local funDecode = c.funDecode
            local segmentHandler = c.segmentHandler
            while true do
                local segment = c:_decode(buffer, funDecode)
                if segment ~= nil then
                    segmentHandler(segment)
                else
                    break
                end
                local endTime = socket:gettime()
                if (endTime - startTime > frameTime) then
                    c.lastBreak = true
                    break
                end
            end
            c.lastBuffLen = #buffer
        end
    end,

    _decode = function(c, buffer, funDecode)
        local newBuffLen = #buffer
        if newBuffLen > 0 then
            local stream
            if newBuffLen > 1 then
                stream = table.concat(buffer)
            else
                stream = buffer[1]
            end

            local segment, remain = funDecode(stream)

            while (#buffer > 0) do
                table.remove(buffer)
            end

            if remain and remain:len() > 0 then
                table.insert(buffer, remain)
                return segment
            end

            return segment
        else
            return nil
        end
    end,
}


--------------------------------------------------------------------------------
-- static private:
tabSocket.getIpV6Address = function(ip)
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


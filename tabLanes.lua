--author cs
--email 04nycs@gmail.com
--https://github.com/ThinEureka/tabMachine
--multi-theading support with luaLanes(https://lualanes.github.io/lanes)
--your project should integrate luaLanes to use following code
--to use asyncRequireWithShareData, you also need to interate conf(https://github.com/cloudwu/lua-conf)
--created on Aug 26, 2021 

-- With conf, you can share data between 2 lua states reducing the 
-- overhead of cloning data.
g_t.asyncRequireWithShareData = function (modules)
    return _{
    s1 = function(c)
        c._nickName = "asyncRequireWithShareData" .. #modules  
        local lanes = require("lanes")
        local linda = lanes.linda()
        c.linda = linda
        local function load()
            local index = 1
            local sendNum = 0
            local conf = require("conf")
            while true do
                local name = modules[index]
                if name == nil then
                    break
                end

                local m= require(name)
                local t = conf.host.new(m)
                linda:send(0, "m", t)
                index = index + 1
            end
        end

        c.a = lanes.gen( "package", "table", load)()
        c.index = 1
    end,

    s1_update = function(c)
        local key, t = c.linda:receive(0, "m")    -- timeout in seconds
        if t == nil then
            return
        end

        local box = conf.box(t)
        package.loaded[modules[c.index]] = box


        c.index = c.index + 1
        if c.index >= #modules then
            c:stop()
        end
    end,
    }
end

-- Without conf, you need to disassemble big tables in the working thread
-- and reasseble them in the main thread to avoid blocking the main thread.
-- However, the total time can't be saved and you also need to pay for the 
-- overhead of this mechanism.
local builderTable = class("builderTable")

function builderTable:ctor()
    self._value = {}
end

function builderTable:append(key, value)
    self._value[key] = value
end

function builderTable:complete()
    return self._value
end


local function isEndCmd(k)
    return k == "end"
end

local function isCmd(k)
    return k == "table" 
end

local builderMergeTable = class("builderMergeTable")

function builderMergeTable:ctor()
    self._value = {}
end

function builderMergeTable:append(key, value)
    for k, v in pairs(value) do
        self._value[k] = v
    end
end

function builderMergeTable:complete()
    return self._value
end

g_t.tabReceiveStreamedTable = function (linda, frameTimeout)
    frameTimeout = frameTimeout or 0
    return _{
    s1 = function(c)
        -- c:s1_update()
        c.receiveNum = 0
    end,

    s1_update = function(c)
        local t1 = socket.gettime()
        while true do
            local p1 = socket.gettime()
            local k, v = linda:receive(0, "m")
            local p2 = socket.gettime()

            if v == nil then 
                return
            end

            c.receiveNum = (c.receiveNum  + 1) % 10


            if c.lastBuilder ~= nil then
                if not v.isEnd then
                    if v.cmd == nil then
                        c.lastBuilder:append(v.key, v.value)
                    else
                        local builder = c:_createBuilder(v.cmd)
                        builder.parentBuilder = c.lastBuilder
                        builder.parentKey = v.key
                        c.lastBuilder = builder
                    end
                else
                    local value = c.lastBuilder:complete()
                    local key = c.lastBuilder.parentKey
                    c.lastBuilder = c.lastBuilder.parentBuilder

                    if c.lastBuilder ~= nil then
                        c.lastBuilder:append(key, value)
                    else
                        c:output(value)
                        c:stop()
                        return
                    end
                end
            else
                if v.cmd == nil then
                    c:output(v.value)
                    c:stop()
                    return
                end
                c.lastBuilder = c:_createBuilder(v.cmd)
                c.rootBuilder = c.lastBuilder
            end


            local t2 = socket.gettime()
            if t2 - t1 > frameTimeout then
                return
            end
        end
    end,

    --private:
    _createBuilder = function(c, cmd)
        if cmd == "table" then
            return builderTable.new()
        elseif cmd == "mergeTable" then
            return builderMergeTable.new()
        end
    end,
    }
end

g_t.asyncRequireByStep = function (modules, depth, frameTimeout)
    return _{
    s1 = function(c)
        local lanes = require("lanes")
        local linda = lanes.linda()
        c.linda = linda


        local function load()
            local index = 1
            local sendNum = 0
            local m = {}
            while true do
                local name = modules[index]
                if name == nil then
                    break
                end
                m[name] = require(name)
                index = index + 1
            end

            local function sendTable(t, key, depth)
                if depth ~= nil and depth <= 0 then
                    linda:send(0, "m", {key = key, value = t})
                    sendNum = (sendNum + 1) % 10
                    return
                end

                if depth ~= nil then
                    depth = depth - 1
                end

                linda:send(0, "m", {cmd = "table", key = key})
                sendNum = (sendNum + 1) % 10
                for k, v in pairs(t) do
                    if type(v) == "table" and (depth == nil or depth > 0) then
                        local newDepth = nil
                        if depth ~= nil then
                            newDepth = depth - 1
                        end
                        sendTable(v, k, newDepth)
                    else
                        linda:send(0, "m", {key=k, value = v})
                        sendNum = (sendNum + 1) % 10
                    end
                end
                linda:send(0, "m", {isEnd = true})
                sendNum = (sendNum + 1) % 10
            end
            sendTable(m, nil, depth)
        end

        c.a = lanes.gen( "package", "table", load)()

        c:call(g_t.tabReceiveStreamedTable(linda, frameTimeout), "s2", {"result"})
    end,
    }
end

g_t.asyncRequireFileOneByOne = function (modules, frameTimeout)
    return g_t.asyncRequireByStep(modules, 2, frameTimeout)
end

g_t.asyncRequireBigFiles = function (modules, depth, maxLines)
    return _{
    s1 = function(c)
        local lanes = require("lanes")
        local linda = lanes.linda()
        c.linda = linda

        depth = 1
        maxLines = maxLines or 100

        c.t1 = socket.gettime()
        local function load()
            local index = 1
            local sendNum = 0
            local m = {}
            while true do
                local name = modules[index]
                if name == nil then
                    break
                end
                m[name] = require(name)
                index = index + 1
            end

            local sendTable
            local sendMergeTable


            sendMergeTable = function (t, key)
                linda:send(nil, "m", {cmd = "mergeTable", key = key})
                sendNum = (sendNum + 1) % 10

                local unit = {}

                local line = 0
                for k, v in pairs(t) do
                    unit[k] = v
                    line = line + 1

                    if line >= maxLines then
                        linda:send(nil, "m", {value = unit})
                        sendNum = (sendNum + 1) % 10
                        line = 0
                        unit = {}
                    end
                end

                if line ~= 0 then
                    linda:send(nil, "m", {value = unit})
                    sendNum = (sendNum + 1) % 10
                end

                linda:send(nil, "m", {isEnd = true})
                sendNum = (sendNum + 1) % 10
            end

            sendTable = function(t, key, curDepth)
                linda:send(nil, "m", {cmd = "table", key = key})
                sendNum = (sendNum + 1) % 10
                for k, v in pairs(t) do
                    if type(v) == "table" then
                        if curDepth + 1 >= depth then 
                            sendMergeTable(v, k)
                        else
                            sendTable(v, k, curDepth + 1)
                        end
                    else
                        linda:send(nil, "m", {key=k, value = v})
                        sendNum = (sendNum + 1) % 10
                    end
                end
                linda:send(nil, "m", {isEnd = true})
                sendNum = (sendNum + 1) % 10
            end
            sendTable(m, nil, 0)
        end

        c.a = lanes.gen( "package", "table", load)()
        c:call(g_t.tabReceiveStreamedTable(linda, 0), "s2", {"result"})
    end,
    }
end


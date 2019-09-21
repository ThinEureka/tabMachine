--author cs
--email 04nycs@gmail.com
--https://github.com/ThinEureka/tabMachine
--created on July 11, 2019 

g_t = {}
g_t.anyOutputVars = {"a1", "a2", "a3", "a4", "a5", "a6", "a7", "a8", "a9", "a10"}

local tabMachine = require("app.common.tabMachine.tabMachine")
local cocosContext = class("cocosContext", tabMachine.context)
cocosContext.isTabClass = true


function cocosContext:ctor()
    tabMachine.context.ctor(self)
    self._hasMsg = false
end

function cocosContext:registerMsg(msg, fun)
     self._hasMsg = true
     local pc = self._pc

     if pc == nil then
         pc = self
     end

     local pcName = self._pcName
     local pcAction = self._action

     SoraDAddMessage(self, msg, function(...)
         pc:_setPc(pc, pcName, pcAction)
         self.tm:_pcall(fun, ...)
     end)
end

function cocosContext:dispose()
    if self._hasMsg then
        SoraDRemoveMessageByTarget(self)
    end

    print("context disposed ", self:_getPath())
end

function cocosContext:getObject(path)
    if path == "" then
        return self
    end

    local object = self
    local beginIndex = 1

    local len = path:len()
    while object ~= nil and beginIndex <= len do
        local key = nil

        local endIndex = path:find(".", beginIndex, true)
        if endIndex == nil then
            endIndex = len + 1
        end

        key = path:sub(beginIndex, endIndex - 1)

        if key == "^" then
            object = self.p
        else
            object = object:getSub(key)
        end

        beginIndex = endIndex + 1
    end

    return object
end

-------------------------- gt --------------------------
g_t.empty_event = function(target, e) end
g_t.empty_touch = function(target, type) end
g_t.empty_frame = function(...) end

g_t.delay = {
    s1 = function(c, totalTime)
        c.v.totalTime = totalTime
        c.v.time = 0
    end,

    s1_update = function(c, dt)
        c.v.time = c.v.time + dt
        if c.v.time >= c.v.totalTime then
            c:stop()
        end
    end,
}

g_t.skipFrames = {
    s1 = function (c, totalFrames)
        c.v.totalFrames = totalFrames
        c.v.numFrames = 0
    end,

    s1_update = function(c, dt)
        c.v.numFrames = c.v.numFrames + 1
        if c.v.numFrames >= c.v.totalFrames then
            c:stop()
        end
    end,
}

g_t.waitMessage = {
    s1 = function(c, msg)
        c:registerMsg(msg, function()
            c:output(true, msg)
            c:stop()
        end)
    end,

    event = g_t.empty_event,
}

g_t.click = {
    s1 = function(c, target, soundId)
        c.v.target = target
        c.v.target:addTouchEventListener(function(btn, event_type)
            if event_type == ccui.TouchEventType.ended then
                c:output(true)
                if soundId ~= -1 then
                    SoraDPlaySound(soundId)
                end
                c:stop()
            end
        end)
    end,

    event = g_t.empty_event,

    final = function(c)
        local target = c.v.target
        if not tolua.isnull(target) then
            target:addTouchEventListener(g_t.empty_touch)
        end
    end,
}

--------------------wrapped tabs -------------

function g_t.bind(tab, ...)
    local a1, a2, a3, a4, a5, a6, a7, a8, a9, a10 = ...
    return {
        s1 = function(c)
            c:call(tab, "tab1", g_t.anyOutputVars, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
        end,

        tab2 = function(c)
            c:output(c.v.a1, c.v.a2, c.v.a3, c.v.a4, c.v.a5, c.v.a6, c.v.a7,
                c.v.a8, c.v.a9, c.v.a10)
        end,
    }
end

function g_t.seq(...)
    local tabs = {...}
    return {
        s1 = function (c)
            c.v.tabs = tabs
            for key, tab in ipairs(c.v.tabs) do
                if type(tab) == "number" then
                    c.v.tabs[key] = g_t.bind(g_t.delay, tab)
                end
            end
            c.v.index = 1
            c:start("s3")
        end,

        s3 = function (c)
            if c.v.index > #c.v.tabs then
                return
            end

            local scName = "ss"..c.v.index
            c:join({scName}, "s2")
            c:call(c.v.tabs[c.v.index], scName)
            c.v.index = c.v.index + 1
        end,
    }
end

function g_t.join(...)
    local tabs = {...}
    return {
        s1 = function(c)
            for index, tab in ipairs(tabs) do
                c:call(tab, "ss_"..index.. "ss")
            end
        end,
    }
end

function g_t.select(...)
    local tabs = {...}
    return {
        s1 = function (c)
            c.v.prefix = "__select_sub"
            c.v.prefixLen = string.len(c.v.prefix)
            c.v.tabs = tabs
            for k,tab in ipairs(c.v.tabs) do 
                c:call(tab, c.v.prefix..k, g_t.anyOutputVars)
            end 
        end,

        event = function (c, msg)
            if type(msg) == "table" 
                and msg.eventType == tabMachine.event_context_stop then
                if msg.name:find("__select_sub") then
                    local index = msg.name:sub(c.v.prefixLen+1)
                    c:output(tonumber(index),c.v.a1, c.v.a2, c.v.a3, c.v.a4, c.v.a5, c.v.a6, c.v.a7,
                        c.v.a8, c.v.a9, c.v.a10)
                    c:stop()
                end
            end
        end 
    }

end

require("app.common.tabMachine.tabAction")
-- function g_t.tabIfElse(conCallback, tabIf, tabElse)
--     return {
--         s1 = function (c)
--             if conCallback() then
--                 c:call(tabIf, "if")
--             else
--                 c:call(tabElse, "else")
--             end
--         end,
--     }
-- end

-- function g_t.tabWhile(conditionCallback, tab)
--     return {
--         s1 = function (c)
--         if conditionCallback() then
--             c:call(tab, "s0")
--         end,

--         event = g_t.empty_event
--     }
-- end
--


return cocosContext

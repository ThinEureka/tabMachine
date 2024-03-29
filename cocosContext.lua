--author cs
--email 04nycs@gmail.com
--https://github.com/ThinEureka/tabMachine
--created on July 11, 2019 

g_t = {}
g_t.anyOutputVars = {"a1", "a2", "a3", "a4", "a5", "a6", "a7", "a8", "a9", "a10"}

local tabMachine = require("app.common.tabMachine.tabMachine")
local cocosContext = tabMachine.context
cocosContext.isTabClass = true
cocosContext.reuse = true

cocosContext.p_ctor = cocosContext.ctor

function cocosContext:ctor()
    cocosContext.p_ctor(self) 
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
        self.tm:_pcall(self, fun, ...)
    end)
end

function cocosContext:registerMsgs(msgs, fun)
    self._hasMsg = true
    local pc = self._pc

    if pc == nil then
        pc = self
    end

    local pcName = self._pcName
    local pcAction = self._action

    for _, msg in ipairs(msgs) do
        SoraDAddMessage(self, msg, function(...)
            pc:_setPc(pc, pcName, pcAction)
            self.tm:_pcall(self, fun, ...)
        end)
    end

end

function cocosContext:dispose()
    if self._hasMsg then
        SoraDRemoveMessageByTarget(self)
    end

    --print("context disposed ", self:_getPath())
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

function cocosContext:getTreeMsg()
    local msg = self:getMsg(self)
    return msg
end

function cocosContext:getMsg(context, prefix, msg)
    local xx = prefix or ""
    local name = xx..context._name
    if context.__cname and context.__cname ~= "cocosContext" then
        name = name .. "(" .. context.__cname .. ")"
    end

    if context._nickName then
        name = name .. "[" .. context._nickName .. "]"
    end

    msg = msg or ""
    msg = msg .. "\n" .. name
    print(name)

    local subContext = context._headSubContext
    while subContext ~= nil do
        msg = self:getMsg(subContext, xx .. " ", msg)
        subContext = subContext._nextContext
    end
    return msg
end

-------------------------- gt --------------------------
g_t.empty_event = function(target, e) end
g_t.empty_touch = function(target, type) end
g_t.empty_frame = function(...) end
g_t.empty_fun = function(...) end

g_t.tabError = {
    s1 = g_t.empty_fun,
    event = g_t.empty_event,
    reuse = true,
}

g_t.schedulerCtrl = {
    s1 = function(c, target)
        c.v.cocosScheduler = cc.Scheduler:new()
        c.v.cocosScheduler:retain()

        c.v.actionManager = cc.ActionManager:new()
        c.v.actionManager:retain()

        c.v.timer = cc.Director:getInstance():getScheduler():scheduleScriptFunc(function(dt)
            if not c.v.isPaused then
                if c.v.timeScale then
                    dt = dt * c.v.timeScale
                end
                if c.v.cocosScheduler then
                    c.v.cocosScheduler:update(dt)
                end
                if c.v.actionManager then
                    c.v.actionManager:update(dt)
                end
            end
        end, 0, false)

        c.v.target = target
        target:setScheduler(c.tm:createScheduler(c.v.cocosScheduler, c.v.actionManager, c))
    end,

    event = g_t.empty_event,
    reuse = true,

    final = function(c)
        if c.v.timer then
            cc.Director:getInstance():getScheduler():unscheduleScriptEntry(c.v.timer)
            c.v.timer = nil
        end

        if not c.v.target._isFinalized then
            c.v.target:setScheduler(c.tm:createSystemScheduler())
        end 

        if not tolua.isnull(c.v.cocosScheduler) then
            c.v.toBeDeletedCocosScheduler = c.v.cocosScheduler
            c.v.cocosScheduler = nil
        end

        if not tolua.isnull(c.v.actionManager) then
            c.v.toBeDeletedActionManager = c.v.actionManager
            c.v.actionManager = nil
        end

        if c.v.toBeDeletedActionManager or c.v.toBeDeletedActionManager then
            --we delete the scheduler at the next frame to avoid the problem that  
            --context are stopped within the callback of the target scheduler
            c.v.deleteTimer = cc.Director:getInstance():getScheduler():scheduleScriptFunc(function(dt)
                if c.v.toBeDeletedCocosScheduler then
                    c.v.toBeDeletedCocosScheduler:release()
                    c.v.toBeDeletedCocosScheduler = nil
                end
                if c.v.toBeDeletedActionManager then
                    c.v.toBeDeletedActionManager:release()
                    c.v.toBeDeletedActionManager = nil
                end
                cc.Director:getInstance():getScheduler():unscheduleScriptEntry(c.v.deleteTimer)
                c.v.deleteTimer = nil
            end, 0, false)
        end
    end,

    isPaused = function(c)
        return c.v.isPaused
    end,

    pause = function(c)
        c.v.isPaused = true
    end,

    resume = function(c)
        c.v.isPaused = false
    end,

    setTimeScale = function (c, timeScale)
        c.v.timeScale = timeScale
    end,

    getTimeScale = function(c, timeScale)
        return c.v.timeScale
    end,
}

g_t.delay = {
    s1 = function(c, totalTime)
        if g_t.debug then
            c._nickName = "delay"
        end

        if totalTime == nil then
            c:stop()
        else
            local scheduler = c:getScheduler()
            c.v.totalTime = totalTime
            c.v.timer = scheduler:createTimer(function(dt) 
                c:stop() 
            end, totalTime)
        end
    end,

    final = function (c)
        if c.v.timer ~= nil then
            local scheduler = c:getScheduler()
            scheduler:destroyTimer(c.v.timer)
            c.v.timer = nil
        end
    end,

    s1_event = g_t.empty_event,

    reuse = true,

    --override 
    --This is a hack, don't do this in custom code and
    --don't change scheduler when there are g_t.delays 
    --running. Usually, we set a scheduler only when 
    --a part of system is initialized, we don't want to
    --pay for the price needed to make sure g_t.delay 
    --work precisely even when the scheduler is changed.
    --Resarting the timer with original total time is an 
    --acceptable solution as a compromise between 
    --efficiency and correctness.
    setScheduler = function (c, scheduler)
        local oldScheduler = c:getScheduler()
        if c.v.timer ~= nil then
            local oldScheduler = c:getScheduler()
            oldScheduler:destroyTimer(c.v.timer)
        end
        cocosContext.setScheduler(c, scheduler)
        if c.v.timer ~= nil then
            local newScheduler = c:getScheduler()
            c.v.timer = newScheduler:createTimer(function(dt) 
                c.v.timer = nil
                c:stop() 
            end, c.v.totalTime)
        end
    end,
}

g_t.skipFrames = {
    s1 = function (c, totalFrames)
        if g_t.debug then
            c._nickName = "skipFrames"
        end

        c.v.totalFrames = totalFrames
        c.v.numFrames = 0
    end,

    s1_update = function(c, dt)
        c.v.numFrames = c.v.numFrames + 1
        if c.v.numFrames >= c.v.totalFrames then
            c:stop()
        end
    end,

    reuse = true,
}

g_t.waitMessage = {
    s1 = function(c, msg)
        if g_t.debug then
            c._nickName = "waitMessage"
        end

        c:registerMsg(msg, function(target, data)
            c:output(data)
            c:stop()
        end)
    end,

    event = g_t.empty_event,

    reuse = true,
}

g_t.waitMessageWithFilter = {
    s1 = function(c, msg, filter)
        if g_t.debug then
            c._nickName = "waitMessageWithFilter"
        end

        c:registerMsg(msg, function(target, data)
            local ok = true
            ok = filter(data)
            if ok then
                c:output(data)
                c:stop()
            end
        end)
    end,

    event = g_t.empty_event,

    reuse = true,
}

g_t.click = {
    s1 = function(c, target, soundId)
        if g_t.debug then
            c._nickName = "click"
        end

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

    reuse = true,
}

--------------------wrapped tabs -------------

function g_t.bind(tab, ...)
    local a1, a2, a3, a4, a5, a6, a7, a8, a9, a10 = ...
    return {
        s1 = function(c)
            if g_t.debug then
                c._nickName = "bind"
            end
            c:call(tab, "tab1", g_t.anyOutputVars, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10)
        end,

        tab2 = function(c)
            c:output(c.v.a1, c.v.a2, c.v.a3, c.v.a4, c.v.a5, c.v.a6, c.v.a7,
                c.v.a8, c.v.a9, c.v.a10)
        end,
    }
end

function g_t.seqWithArray(tabs)
    return {
        s1 = function (c)
            if g_t.debug then
                c._nickName = "seq"
            end
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

            if c.v.index == 2 then
                --为concurrentSteps特殊写的，其他地方不需要
                c:upwardNotify({name = "concurrentSteps_step_start", target = c}, 1)
            end

            local scName = "ss"..c.v.index
            c:join({scName}, "s2")
            local index = c.v.index
            c.v.index = c.v.index + 1
            c:call(c.v.tabs[index], scName)
        end,
    }
end

function g_t.seq(...)
    local tabs = {...}
    return g_t.seqWithArray(tabs)
end

function g_t.join(...)
    local tabs = {...}
    return g_t.joinWithArray(tabs)
end

function g_t.joinWithArray(tabs)
    return {
        s1 = function(c)
            if g_t.debug then
                c._nickName = "join"
            end
            for index, tab in ipairs(tabs) do
                c:call(tab, "ss_"..index.. "ss")
            end
        end,
    }
end

function g_t.select(...)
    local tabs = {...}
    return g_t.selectWithArray(tabs)
end

function g_t.selectWithArray(tabs)
    return {
        s1 = function (c)
            if g_t.debug then
                c._nickName = "select"
            end
            c.v.prefix = "__select_sub"
            c.v.prefixLen = string.len(c.v.prefix)
            c.v.tabs = tabs
            local s1Sub = c:getSub("s1")
            for k,tab in ipairs(c.v.tabs) do 
                local name = c.v.prefix..k
                c:registerLifeTimeListener(name, c)
                c:call(tab, name, g_t.anyOutputVars)
            end 
        end,

        event = function (c, msg)
            if type(msg) == "table" 
                and msg.eventType == tabMachine.event_context_stop then
                if msg.name:find(c.v.prefix) then
                    local index = msg.name:sub(c.v.prefixLen+1)
                    c:output(tonumber(index),c.v.a1, c.v.a2, c.v.a3, c.v.a4, c.v.a5, c.v.a6, c.v.a7,
                        c.v.a8, c.v.a9, c.v.a10)
                    c:stop()
                end
            end
        end 
    }
end

function g_t.tabWhile(conditionCallback, tabLoop)
    return {
        s1 = function (c)
            if g_t.debug then
                c._nickName = "while"
            end

            if conditionCallback() then
                c.v.flowCode = nil
                c:call(tabLoop, "s2", {"flowCode"})
            end
        end,

        s3 = function(c)
            if c.v.flowCode == g_t.flowCodeBreak then
                return
            else
                c:start("s1")
            end
        end,
    }
end

function g_t.tabDoWhile(tabLoop, conditionCallback)
    return {
        s1 = function (c)
            if g_t.debug then
                c._nickName = "doWhile"
            end
            c.v.flowCode = nil
            c:call(tabLoop, "s2", {"flowCode"})
        end,

        s3 = function (c)
            if c.v.flowCode == g_t.flowCodeBreak then 
                return
            end
            if conditionCallback() then
                c:start("s1")
            end
        end
    }
end

function g_t.tabForIndex(beginIndex, endIndex, tabLoop)
    return {
        s1 = function (c)
            if g_t.debug then
                c._nickName = "forNum"
            end
            c.v.index = beginIndex
        end,

        s2 = function (c)
            if (c.v.index <= endIndex) then
                c.v.flowCode = nil
                c:call(tabLoop, "s3", {"flowCode"}, c.v.index)
            end
        end,

        s4 = function (c)
            if c.v.flowCode == g_t.flowCodeBreak then 
                return
            end

            c.v.index = c.v.index + 1
            c:start("s2")
        end,
    }
end

function g_t.tabForIpairs(array, tabLoop)
    return {
        s1 = function (c)
            if g_t.debug then
                c._nickName = "forIpairs"
            end
            c.v.index = 1
        end,

        s2 = function (c)
            if (c.v.index <= #array) then
                c.v.flowCode = nil
                c:call(tabLoop, "s3", {"flowCode"}, c.v.index, array[c.v.index])
            end
        end,

        s4 = function (c)
            if c.v.flowCode == g_t.flowCodeBreak then 
                return
            end
            c.v.index = c.v.index + 1
            c:start("s2")
        end,
    }
end

function g_t.tabForPairs(map, tabLoop)
    return {
        s1 = function (c)
            if g_t.debug then
                c._nickName = "forPairs"
            end
            c.v.num = 0
            c.v.funNext = pairs(map)
            c.v.key = nil
        end,

        s2 = function(c)
            c.v.key, c.v.value = c.v.funNext(map, c.v.key)
        end,

        s3 = function (c)
            if (c.v.key ~= nil) then
                c:call(tabLoop, "s4", nil, c.v.key, c.v.value)
            end
        end,

        s5 = function(c)
            if c.v.flowCode == g_t.flowCodeBreak then 
                return
            end
            c:start("s2")
        end,

    }
end

function cocosContext:break_()
    self:output(g_t.flowCodeBreak)
    self:stop()
end

g_t.flowCodeBreak = "break"

g_t.httpGetJson = function (url, timeout)
    return {
        s1 = function(c)
            c.v.url = url
            c.v.timeout = timeout or 15
            c.v.xhr = cc.XMLHttpRequest:new()
            c.v.xhr.responseType = cc.XMLHTTPREQUEST_RESPONSE_JSON
            c.v.xhr:setRequestHeader("Content-Type","application/json")
            c.v.xhr:open("GET", c.v.url)
            c.v.xhr.timeout = c.v.timeout 

            c.v.xhr:registerScriptHandler(handler(c, c._onRespond))
            c.v.xhr:send()
        end,

        _onRespond = function(c)
            local retCode = c.v.xhr.status
            if retCode == 200 then
                local response = json.decode(c.v.xhr.response)
                c:output(response)
                c:stop()
            else
                c:output(nil, retCode)
                c:stop()
            end
        end,

        event = g_t.empty_event,
    }
end

g_t.httpDownload = function (url, path, timeout)
    return {
        s1 = function(c)
            c.v.url = url
            c.v.timeout = timeout or 15
            c.v.xhr = cc.XMLHttpRequest:new()
            c.v.xhr.responseType = cc.XMLHTTPREQUEST_RESPONSE_STRING
            c.v.xhr:setRequestHeader("Content-Type","application/json")
            c.v.xhr:open("GET", c.v.url)
            c.v.xhr.timeout = c.v.timeout

            c.v.xhr:registerScriptHandler(handler(c, c._onRespond))
            c.v.xhr:send()
        end,

        _onRespond = function(c)
            local writablePath = cc.FileUtils:getInstance():getWritablePath()
            local retCode = c.v.xhr.status
            if retCode == 200 then
                local response = c.v.xhr.response
                local fullFileName = writablePath .. path
                local file = io.open(fullFileName, "wb")
                file:write(response)
                file:close()
                c:output(fullFileName)
                c:stop()
            else
                c:output(nil, retCode)
                c:stop()
            end
        end,

        event = g_t.empty_event,
    }
end

require("app.common.tabMachine.tabAction")
require("app.common.tabMachine.tabLanes")

return cocosContext

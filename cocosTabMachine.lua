
--author cs
--email 04nycs@gmail.com
--created on July 13, 2019 
--

local tabMachine = require("app.common.tabMachine.tabMachine")

local cocosTabMachine = class("cocosTabMachine", function(target)
    return tabMachine.new(target)
end)

local commonTabs = {}

-------------------------- cocosTabMachine ----------------------

function cocosTabMachine:ctor()
    tabMachine.ctor(self)
    self._timer = nil
    for name, tab in pairs(commonTabs) do
        self:registerGlobalTab(name, tab)
    end
end

function cocosTabMachine:startUpdate(perFrame)
    assert(self:isRunning())
    assert(self._timer == nil)

    self._timer = SoradCreateTimer(g_tabMachine, function(dt)
            g_tabMachine:update(dt)
        end, perFrame)
end

function cocosTabMachine:_onStopped()
    print("machine stopped")
    if self._timer then
        SoraDManagerRemoveTimerByTarget(self)
        self._timer = nil
    end

    tabMachine._onStopped(self)
end

function cocosTabMachine:_createContext()
    local context = tabMachine._createContext()
    context.registerMsg = function (c, msg, fun)
        context._hasMsg = true
        SoraDAddMessage(c, msg, function(...)
            fun(...)
        end)
    end

    return context
end

function cocosTabMachine:_disposeContext(context)
    if self._hasMsg then
        SoraDRemoveMessageByTarget(context)
    end
    print("context disposed ", context._name)
end

-------------------------- commonTabs --------------------------

commonTabs["::delay"] = {
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

commonTabs["::skipFrames"] = {
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

return cocosTabMachine


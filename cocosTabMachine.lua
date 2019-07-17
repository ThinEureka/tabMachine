
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
    self._updateTimer = nil
    self._tickTimer = nil
    for name, tab in pairs(commonTabs) do
        self:registerGlobalTab(name, tab)
    end
end

function cocosTabMachine:_addUpdate()
    print("machine add update")
    if self._updateTimer == nil then
        self._updateTimer = SoradCreateTimer(self, function(dt)
                g_tabMachine:update(dt)
            end, true)
    end
end

function cocosTabMachine:_decUpdate()
    print("machine dec update")
    if self._updateTimer then
        SoraDManagerRemoveTimerByTarget(self)
        self._updateTimer = nil
    end
end

function cocosTabMachine:_addTick()
    print("machine add tick")
    if self._tickTimer == nil then
        self._tickTimer = SoradCreateTimer(self, function(dt)
                self._tickIndex = self._tickIndex + 1
                g_tabMachine:tick(self._tickIndex)
            end, false)
    end
end

function cocosTabMachine:_decTick()
    print("machine dec tick")
    if self._tickTimer then
        SoraDManagerRemoveTimerByTarget(self)
        self._tickTimer = nil
    end
end

function tabMachine:_addNotify()
    print("machine add notify")
end

function tabMachine:_decNotify()
    print("machine dec notify")
end

function cocosTabMachine:_onStopped()
    print("machine stopped")
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


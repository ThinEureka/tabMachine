--author cs
--email 04nycs@gmail.com
--https://github.com/ThinEureka/tabMachine
--created on July 18, 2020

local tabQueue = nil

-- tabQueue currently does not support bind tab
tabQueue = _({
    tabName = "tabQueue",

    DUPLICATE_ACTION = {
        NONE = 0,
        REPLACE = 1,
        IGNORE = 2,
        MERGE = 3,
    },


    s1 = function(c, firstRunInFrame)
        c._queue = {}
        c._uid = 0
        c.isOpen = false
        c.firstRunInFrame = firstRunInFrame
        c._curAliveMap = c:call(g_t.tabAliveMap, "curTabMap")
        c._curTabConfigMap = {}
    end,

    s2 = function(c)
        if c.isOpen then
            local index = #c._queue
            while index > 0 do
                local cfg = c._queue[index]
                if c:checkCanRun(cfg) then
                    table.remove(c._queue, index)
                    local context = c:call(c._tabRunning(cfg), "s3")
                    c:notify("runningTab", cfg.uid, context:getTarget())
                    if not context:isStopped() then
                        c:start("s2")
                    end
                    return
                end
                index = index - 1
            end
        end
    end,

    s4 = function(c)
        c:start("s2")
    end,

    event = g_t.empty_event,

    inner = {
        tabQueue = function(c)
            return c
        end,

        getTabUid = function(c)
            c._uid = c._uid + 1
            return c._uid
        end,

        removeByUid = function(c, uid)
            -- 移除队列里面的对象
            local index = 1
            while index <= #c._queue do
                local data = c._queue[index]
                if data.uid == uid then
                    table.remove(c._queue, index)
                    c:notify("removeTab", data.uid)
                    return
                else
                    index = index + 1
                end
            end
        end,

        insertCurTab = function(c, config, tab)
            local uid = config.uid
            c._curAliveMap:set(uid, tab)
            c._curTabConfigMap[uid] = config
        end,

        removeCurTab = function(c, uid)
            c._curAliveMap:remove(uid)
            c._curTabConfigMap[uid] = nil
        end,
    },

    --private:
    startNextTask = function(c)
        c:start("s2")
    end,

    getCurTasks = function(c)
        local tabs = {}
        c._curAliveMap:forEach(function (t)
            table.insert(tabs, t)
        end)
        return tabs
    end,

    checkCanRun = function(c, checkCfg)
        c._curAliveMap:validate()
        for uid, curRunningCfg in pairs(c._curTabConfigMap) do
            local tab = c._curAliveMap:get(uid)
            if tab == nil then
                c._curTabConfigMap[uid] = nil
            else
                local pass = c:_verifyPass(checkCfg, curRunningCfg)
                if not pass then
                    return false
                end
            end
        end
        return true
    end,

    _verifyPass = function(c, verifyCfg, curRunningCfg)
        if verifyCfg.unblockType == nil then
            return false
        end
        if curRunningCfg.unblockList == nil then
            return false
        end
        for _, v in ipairs(curRunningCfg.unblockList) do
            if verifyCfg.unblockType == v then
                return true
            end
        end
        return false
    end,

    _tabRunning = _({
        s1 = function(c, config)
            c.cfg = config
            c._nickName = "running_"..c.cfg.uid
            c.targetTab = c:call(c.cfg.tab(c.cfg.tabParams), "s2")
            if c.targetTab:isStopped() then
                c.noRemove = true
                c:stop()
                return
            end
            c:_("insertCurTab",  c.cfg, c.targetTab)
        end,

        final = function(c)
            if c.noRemove or c:_("tabQueue"):isQuitting() then
                return
            end
            c:_("removeCurTab", c.cfg.uid)
        end,

        getTarget = function(c)
            return c.targetTab
        end,
    })
})


tabQueue.tabStartTaskNextFrame =_({
    s1 = function(c)
        c:call(g_t.skipFrames(1), "s2")
    end,

    s3 = function(c)
        local queue = c:_("tabQueue")
        if #queue:getCurTasks() <= 0 then
            queue:startNextTask()
        end
    end
})

--public:
function tabQueue:add(tab, tabParams, isWait, queueParams)

    local queueData = {
        uid = self:_("getTabUid"),
        tab = #tab,
        -- tab的参数
        tabParams = tabParams,
        -- 优先级，如果没有传递优先级，统统默认-1
        priority = (queueParams and queueParams.priority or tab.priority) or -1,
        -- 被放行类型
        unblockType = queueParams and queueParams.unblockType or tab.unblockType,
        -- 放行列表
        unblockList = queueParams and queueParams.unblockList or tab.unblockList,
        duplicateTag = queueParams and queueParams.duplicateTag or tab.duplicateTag,
        duplicateAction = queueParams and queueParams.duplicateAction or tab.duplicateAction,
        dontStopHostWhenStop = queueParams and queueParams.dontStopHostWhenStop
    }

    local replaceFlag = false
    if queueData.duplicateAction ~= nil and
        queueData.duplicateAction ~= tabQueue.DUPLICATE_ACTION.NONE then
        for index, old in ipairs(self._queue) do
            if old.duplicateTag == queueData.duplicateTag then
                if queueData.duplicateAction == tabQueue.DUPLICATE_ACTION.IGNORE then
                    return nil, 0
                elseif queueData.duplicateAction == tabQueue.DUPLICATE_ACTION.MERGE
                    or queueData.duplicateAction == tabQueue.DUPLICATE_ACTION.REPLACE then

                    if tab.duplicateAction == tabQueue.DUPLICATE_ACTION.MERGE then
                        queueData.tab = #tab.merge(tab, old.tab)
                    end

                    if queueData.priority == old.priority then
                        replaceFlag = true
                        self._queue[index] = queueData
                        break
                    end

                    table.remove(self._queue, index)
                    self:notify("removeTab", old.uid)
                    break
                end
            end
        end
    end

    if not replaceFlag then
        self:_addToQueueByPriority(queueData)
    end

    local waitTab = nil
    if isWait then
        waitTab = self:waitTabCompleted(queueData.uid, queueData.dontStopHostWhenStop)
    end

    if self.firstRunInFrame or self:checkCanRun(queueData) then
        self:startNextTask()
    elseif not self:getSub("tabStartTaskNextFrame") then
        self:call(tabQueue.tabStartTaskNextFrame(), "tabStartTaskNextFrame")
    end
    return waitTab, queueData.uid
end

function tabQueue:addNow(tab, tabParams, queueParams)
    local queueData = {
        tab = #tab,
        -- tab的参数
        tabParams = tabParams,
        -- 优先级，如果没有传递优先级，统统默认-1
        priority = (queueParams and queueParams.priority or tab.priority) or -1,
        -- 被放行类型
        unblockType = queueParams and queueParams.unblockType or tab.unblockType,
        -- 放行列表
        unblockList = queueParams and queueParams.unblockList or tab.unblockList,
        duplicateTag = queueParams and queueParams.duplicateTag or tab.duplicateTag,
        duplicateAction = queueParams and queueParams.duplicateAction or tab.duplicateAction,
        dontStopHostWhenStop = queueParams and queueParams.dontStopHostWhenStop,
        uid = self:_("getTabUid")
    }
    self:call(self._tabRunning(queueData), "s3")
    return queueData.uid
end

function tabQueue:removeAllByTag(tag)
    local index = 1
    while index <= #self._queue do
        local data = self._queue[index]
        if data.duplicateTag == tag then
            table.remove(self._queue, index)
            self:notify("removeTab", data.uid)
        else
            index = index + 1
        end
    end
end

function tabQueue:removeByFilter(filter)
    local index = 1
    while index <= #self._queue do
        local data = self._queue[index]
        if filter(data.tab) then
            table.remove(self._queue, index)
            self:notify("removeTab", data.uid)
        else
            index = index + 1
        end
    end
end

function tabQueue:remove(tab)
    local index = 1
    while index <= #self._queue do
        local data = self._queue[index]
        if data.tab == tab then
            table.remove(self._queue, index)
            self:notify("removeTab", data.uid)
            break
        else
            index = index + 1
        end
    end
end

function tabQueue:hasTaskByFilter(filter)
    for index in ipairs(self._queue) do
        local tab = self._queue[index].tab
        if filter(tab) then
            return true
        end
    end
    return false
end

function tabQueue:openQueue()
    if self.isOpen then
        return
    end
    self.isOpen = true
    if #self:getCurTasks() <= 0 then
        self:startNextTask()
    end
end

function tabQueue:closeQueue()
    self.isOpen = false
end

function tabQueue:_addToQueueByPriority(data)
    local index = 1
    while index <= #self._queue do
        local old = self._queue[index]
        if data.priority > old.priority then
            index = index + 1
        else
            break
        end
    end

    table.insert(self._queue, index, data)
end

function tabQueue:hasTypeInTop(type)
    local hasType = false
    self:forEachSub(function(sub)
        if sub.tabType == type then
            hasType = true
            return true
        end
    end)
    return hasType
end

function tabQueue:getAllTaskCount()
    -- 队列数
    local queueCount = table.nums(self._queue)
    -- 当前运行数
    queueCount = queueCount + #self:getCurTasks()
    return queueCount
end

function tabQueue:getTaskCount(tabType)
    local count = 0
    for k, data in pairs(self._queue) do 
        if data.tab.tabType == tabType then 
            count = count + 1
        end
    end
    return count
end

function tabQueue:isTaskRuning()
    if #self:getCurTasks() <= 0 then
        return false
    end
    return true
end

function tabQueue:existUid(uid)
    if uid == 0 then
        return false
    end
    for _, data in pairs(self._queue) do
        if data.uid == uid then
            return true
        end
    end
    if self._curTabConfigMap[uid] then
        return true
    end
    return false
end

function tabQueue:removeByUid(uid)
    -- 如果当前运行的就是目标对象，则直接停止当前对象
    if self._curTabConfigMap[uid] then
        local tab = self._curAliveMap:get(uid)
        if tab then
            tab:stop()
        end
        return
    end
    -- 移除队列里面的对象
    self:_("removeByUid", uid)
end

function tabQueue:waitTabCompleted(uid, dontStopHostWhenStop)
    -- 如果要等待的是当前的tab，那么直接返回当前的proxy
    if self._curTabConfigMap[uid] then
        local tab = self._curAliveMap:get(uid)
        if tab then
            return tab:tabProxy(nil, not dontStopHostWhenStop)
        else
            return nil
        end
    end
    if not self:existUid(uid) then
        return nil
    end

    local waitTabMgr = self:getSub("waitTabCompletedMgr")
    if not waitTabMgr then
        waitTabMgr = self:call(tabQueue._tabWaitTabCompletedMgr(uid), "waitTabCompletedMgr")
    else
        waitTabMgr:addTab(uid)
    end
    return waitTabMgr:getWatiTabProxy(uid, not dontStopHostWhenStop)
end

tabQueue._tabWaitTabCompletedMgr = _({
    s1 = function(c, uid)
        c.aliveMap = c:call(g_t.tabAliveMap, "aliveMap")
        c.refCount = c:call(g_t.tabRefCount, "refCount")
        c:addTab(uid)
    end,

    refCount_event = {
        zero = function(c)
            c:stop()
        end,
    },

    event = {
        runningTab = function(c, uid, context)
            local waitTab = c.aliveMap:get(uid)
            if waitTab then
                waitTab:notify("running", context)
            end
            c.aliveMap:validate()
        end,

        removeTab = function(c, uid)
            c:removeTab(uid)
        end,
    },

    -- public:

    addTab = function(c, uid)
        -- 重复添加直接返回
        local waitTab = c.aliveMap:get(uid)
        if waitTab then
            return
        end
        local tab = c:call(tabQueue._tabMonitor(uid), uid)
        c.aliveMap:set(uid, tab)
        c.refCount:acquire(tab, "monitor")
    end,

    removeTab = function(c, uid)
        local waitTab = c.aliveMap:get(uid)
        if waitTab then
            waitTab:sendRemoveMsg()
            waitTab:stop()
        end
        c.aliveMap:validate()
    end,

    getWatiTabProxy = function(c, uid, stopHostWhenStop)
        local waitTab = c.aliveMap:get(uid)
        if waitTab then
            return waitTab:tabProxy(nil, stopHostWhenStop)
        end
        c.aliveMap:validate()
        return nil
    end,
})

tabQueue._tabMonitor = _({
    s1 = function(c, uid)
        c._uid = uid
        c._nickName = "monitor_".. c._uid
        c.running = false
    end,

    s1_event = {
        running = function(c, tab)
            c.running = true
            c.tab = tab
            c:stop("s1")
        end,
    },

    s2 = function(c)
        c._nickName = "running_".. c._uid
        c:call(c.tab:tabProxy(nil, true),"s3")
    end,

    s4 = function(c)
        local outputs = c.tab:getOutputs()
        if outputs ~= nil then
            c:output(table.unpack(outputs))
        end
    end,

    final = function(c)
        if c.running then return end
        -- 从列表中删除排队对象
        c:_("removeByUid", c._uid)
    end,

    sendRemoveMsg = function(c)
        c:upwardNotify("tabQueue_remove")
    end,

    --public:

    uid = function(c)
        return c._uid
    end,

})

return tabQueue

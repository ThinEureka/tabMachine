--author cs
--email 04nycs@gmail.com
--https://github.com/ThinEureka/tabMachine
--created on July 18, 2020 

local cocosContext = require("app.common.tabMachine.cocosContext")
local tabQueue = class("tabQueue", cocosContext)

tabQueue.DUPLICATE_ACTION = {
   NONE = 0,
   REPLACE = 1,
   IGNORE = 2,
   MERGE = 3,
}

function tabQueue:s1()
    self._queue = {}
    self.isOpen = false
end

function tabQueue:add(tab)
    local newTab = tab
    if tab.duplicateAction ~= nil and
         tab.duplicateAction ~= tabQueue.DUPLICATE_ACTION.NONE then
        for index, oldTab in ipairs(self._queue) do
            if oldTab.duplicateTag == tab.duplicateTag then
                if tab.duplicateAction == tabQueue.DUPLICATE_ACTION.IGNORE then
                    return
                elseif tab.duplicateAction == tabQueue.DUPLICATE_ACTION.MERGE 
                    or tab.duplicateAction == tabQueue.DUPLICATE_ACTION.REPLACE then

                    if tab.duplicateAction == tabQueue.DUPLICATE_ACTION.MERGE then
                        newTab = tab.merge(tab, oldTab)
                    end

                    if newTab.priority == oldTab.priority then
                        self._queue[index] = newTab
                        newTab = nil
                        break
                    end

                    table.remove(self._queue, index)
                    break
                end
            end
        end
    end

    if newTab then
        self:_addToQueueByPriority(newTab)
    end

    if self:getCurTasks() == nil then
        self:_startNextTask()
    end
end

function tabQueue:addNow(tab)
    self.v.delayTaskTime = nil
    self:call(tab, "t1", {"delayTaskTime"})
end

function tabQueue:removeAllByTag(tag)
    local index = 1
    while index <= #self._queue do 
        local tab = self._queue[index]
        if tab.duplicateTag == tag then
            table.remove(self._queue, index)
        else
            index = index + 1
        end
    end
end

function tabQueue:removeByFilter(filter)
    local index = 1
    while index <= #self._queue do 
        local tab = self._queue[index]
        if filter(tab) then
            table.remove(self._queue, index)
        else
            index = index + 1
        end
    end
end

function tabQueue:_startNextTask()
    if not self.isOpen then 
        return
    end
    local len = #self._queue
    if len > 0 then
        local tab = self._queue[len]
        table.remove(self._queue)
        self.v.delayTaskTime = nil
        self:call(tab, "t1", {"delayTaskTime"})
    end
end

function tabQueue:t2()
    if not self:getSub("t1") then  
        if self.v.delayTaskTime and self.v.delayTaskTime > 0 then 
            self:call(g_t.delay, "t3", nil, self.v.delayTaskTime)
        else 
            self:_startNextTask()
        end
    end
end

function tabQueue:t4()
    if not self:getSub("t1") then
        self:_startNextTask()
    end
end

function tabQueue:getCurTasks()
    return self:getSub("t1")
end

function tabQueue:openQueue()
    if self.isOpen then 
        return
    end
    self.isOpen = true
    if self:getCurTasks() == nil then
        self:_startNextTask()
    end
end

function tabQueue:closeQueue()
    self.isOpen = false
end

function tabQueue:_addToQueueByPriority(tab)
    local index = 1
    while index <= #self._queue do
        local oldTab = self._queue[index]
        if tab.priority > oldTab.priority then
            index = index + 1
        else
            break
        end
    end

    table.insert(self._queue, index, tab)
end

tabQueue.event = g_t.empty_event

return tabQueue


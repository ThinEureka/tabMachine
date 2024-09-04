local tabProfiler = class("tabProfiler")
local socket = require("socket")

function tabProfiler:start() 
    self.isRun = true
    self.recordList = {}
    self.curRecordStack = {}
    self.recordUpdateList = {}
end

function tabProfiler:stop()
    self.isRun = false

    print("----------tab start 消耗--------")
    table.sort(self.recordList, function (a, b)
        return a.costTime > b.costTime
    end)
    for k,v in ipairs(self.recordList) do 
        print(v.key, "消耗时间为：", v.costTime * 1000, "ms")
    end

    local updateResult = {}
    for k,v in pairs(self.recordUpdateList) do 
        table.insert(updateResult, v)
    end

    table.sort(updateResult, function(a, b)
        return a.maxTime > b.maxTime
    end)

    print("----------tab update 消耗--------")
    for k,v in ipairs(updateResult) do 
        print(v.key..".update最大耗时时间为:", v.maxTime * 1000, "ms")
    end

    self.recordList = {}
    self.recordUpdateList = {}
end

function tabProfiler:beginSampleTime(key)
    if not self.isRun then 
        return
    end
    local curTime = socket:gettime()
    local record = {key = key, startTime = curTime, costTime = 0}
    table.insert(self.recordList, record)
    local curIndex = #self.recordList
    table.insert(self.curRecordStack, curIndex)
end

function tabProfiler:endSampleTime()
    if not self.isRun then 
        return
    end
    local curTime = socket:gettime()
    local curIndex = table.remove(self.curRecordStack)
    if not curIndex then 
        return
    end
    local tempCostTime = 0
    for i = curIndex+1, #self.recordList do 
        tempCostTime = tempCostTime + self.recordList[i].costTime
    end
    self.recordList[curIndex].costTime = curTime - self.recordList[curIndex].startTime - tempCostTime
end

function tabProfiler:beginSampleUpdateTime(key)
    if not self.isRun then 
        return
    end
    self.startIndex = #self.recordList
    local curTime = socket:gettime()
    if not self.recordUpdateList[key] then
        self.recordUpdateList[key] = {key = key, startTime = curTime, maxTime = -1}
    else 
        self.recordUpdateList[key].startTime = curTime
    end
end

function tabProfiler:endSampleUpdateTime(key)
    if not self.isRun then 
        return
    end
    local curTime = socket:gettime()
    local data = self.recordUpdateList[key]
    if data then
        local costStartTime = 0
        for i = self.startIndex +1, #self.recordList do 
            costStartTime = costStartTime + self.recordList[i].costTime
        end
        local costTime = curTime - data.startTime - costStartTime
        if data.maxTime < costTime then 
            data.maxTime = costTime
        end
    end
end

return tabProfiler
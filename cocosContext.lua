

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

    print("context disposed ", self:_getAbsName())
end

function cocosContext:getObject(path)
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

function cocosContext:emptyTouchListener(target, type)
end

return cocosContext

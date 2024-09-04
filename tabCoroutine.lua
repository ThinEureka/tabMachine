-- Author: linbaoqiang
-- Date: 7/27/2022 9:56:05 AM
--
local tabCoroutine = class("tabCoroutine")
local tabMachine = require("tabMachine.tabMachine")
local socket = require("socket")

local coroutine_yield = coroutine.yield
local coroutine_create = coroutine.create
local coroutine_resume = coroutine.resume
local coroutine_status = coroutine.status
local _xpcall = xpcall
-- local errorHandler = tabMachine.getPCallErrorHandler()
local _quitSignal = {"quit signal"}

local _coroutine_err = function(errMsg)
    if errMsg == _quitSignal then
        print("_coroutine almost dead")
    else
        -- errorHandler.on_error(errMsg)
    end
end

g_t.tabCoroutine = _({
    s1 = function(c, func)
        c.co = tabCoroutine.co_create(func, c)
        c:s1_update(0)
    end,
    s1_update = function(c, dt)
        local state, signal, data = coroutine_resume(c.co, c)
        if not state or signal == "SUSPEND" then
            c.isCoroutineFinal = true
            c:stop()
        end
    end,
    --public
    yield = function(c)
        coroutine_yield()
        assert(not c:isStopped(), _quitSignal)
    end,

    final = function(c)
        if not c.isCoroutineFinal then
            coroutine_resume(c.co)
        end
    end,
})

-- coroutine reuse
local coroutine_pool = setmetatable({}, { __mode = "kv" })
function tabCoroutine.co_create(f, ...)
	local co = table.remove(coroutine_pool)
	if co == nil then
		co = coroutine_create(function(...)
            _xpcall(f, _coroutine_err, ...)
			while true do
				-- recycle co into pool
				f = nil
				coroutine_pool[#coroutine_pool+1] = co
				-- recv new main function f
				f = coroutine_yield "SUSPEND"
                _xpcall(f, _coroutine_err, coroutine_yield())
			end
		end)
	else
		coroutine_resume(co, f, ...)
	end
	return co
end

return tabCoroutine


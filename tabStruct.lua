--author cs
--email 04nycs@gmail.com
--
--https://github.com/ThinEureka/tabMachine
--created on Feb 3, 2026

local table = table
local table_insert = table.insert

local __traceback
local on_error = function(err)
    __traceback = debug.traceback("", 2)
    return err
end

tabStruct = {}
__structs = {}
local __structs = __structs

__structsMap = {}
local __structsMap = __structsMap

tabStruct.keywords = {
    __struct = true,
    __ref = true,
}

tabStruct.register = function(sName, ctor, dtor)
    assert(__structsMap[sName] == nil)
    local struct = { sName = sName,
        ctor = ctor, dtor = dtor,
        repool = {}, repoolSize = 0,
        pool = {}, poolSize = 0,}

    __structsMap[sName] = struct
    table_insert(__structs, struct)
end

__autoReleasePool = {}
local __autoReleasePool = __autoReleasePool
__autoReleasePoolSize = 0

tabStruct.checkout = function(sName, ...)
    local t
    local struct = __structsMap[sName]
    local pool = struct.pool
    local poolSize = struct.poolSize
    if poolSize > 0 then
        t = pool[poolSize]
        struct.poolSize = poolSize - 1
    else
        t = {}
        t.__ref = 0
        t.__struct = struct
    end

    local ctor = struct.ctor
    if ctor then
        local stat, err = xpcall(ctor, on_error, t, ...)
        if not stat then
            pool[poolSize] = false -- clear corrupted table ref
            local e = {}
            e.luaStackTrace = __traceback
            e.errorMsg = err
            if g_tm then
                g_tm:onUnCaughtException(e)
            end
            return nil
        end
    end

    local autoReleasePoolSize = __autoReleasePoolSize + 1
    if autoReleasePoolSize <= #__autoReleasePool then
        __autoReleasePool[autoReleasePoolSize] = t
    else
        table_insert(__autoReleasePool, t)
    end
    __autoReleasePoolSize = autoReleasePoolSize

    return t
end

tabStruct.checkin = function(t)
    local struct = t.__struct
    local pool = struct.repool
    local size = struct.repoolSize
    size = size + 1
    if size <= #pool then
        pool[size] = t
    else
        table_insert(pool, t)
    end
    struct.repoolSize = size
end

tabStruct.gc = function(structProtectedSize)
    local autoReleasePool = __autoReleasePool
    for i = 1, __autoReleasePoolSize do
        local t = autoReleasePool[i]
        local ref = t.__ref
        if ref == 0 then
           tabStruct.checkin(t)
        end
    end
    __autoReleasePoolSize = 0

    for _, struct in ipairs(__structs) do
        local sName = struct.sName
        local pool = struct.pool
        local repool = struct.repool

        local poolSize = struct.poolSize
        local protectedRepoolSize = structProtectedSize and structProtectedSize[sName] or 0
        local repoolSize = struct.repoolSize - protectedRepoolSize

        for i = 1, poolSize + repoolSize - #pool do
            table_insert(pool, false) --placeHolder
        end

        for i =  1, repoolSize do
            local t = repool[protectedRepoolSize +  i]
            local dtor = struct.dtor
            if dtor then
                local stat, err = xpcall(dtor, on_error, t)
                if stat then
                    poolSize = poolSize + 1
                    pool[poolSize] = t
                else
                    repool[protectedRepoolSize +  i] = false -- clear ref to corrupted table
                    local e = {}
                    e.luaStackTrace = __traceback
                    e.errorMsg = err .. "\n in dtor of struct " .. sName
                    if g_tm then
                        g_tm.onUnCaughtException(e)
                    end
                end
            else
                poolSize = poolSize + 1
                pool[poolSize] = t
            end
        end

        struct.poolSize = poolSize
        struct.repoolSize = protectedRepoolSize
    end
end

__rtPool = {}
local __rtPool = __rtPool
local __rtPoolSize = 0

local rTable = {}
local meta_rTable = {
    __index = function(rt, k)
        return rt.__container[k]
    end,

    __newindex = function(rt, k, v)
        local container = rt.__container
        local v0 = container[k]
        if v0 == v then
            return
        end

        if v ~= nil then
            assert(v.__struct, "rTable can only be used to store struct now!")
        end

        if v0 ~= nil then
            local ref0 = v0.__ref
            ref0 = ref0 - 1
            if ref0 == 0 then
                tabStruct.checkin(v0)
            else
                v0.__ref = ref0
            end
        end

        if v == nil then
            container[k] = nil
            return
        end

        local ref = v.__ref
        v.__ref = ref + 1
        container[k] = v
    end,
}

rTable.checkout = function()
    local rt
    local rtPoolSize = __rtPoolSize
    if rtPoolSize > 0 then
        rt = __rtPool[rtPoolSize]
        __rtPoolSize = rtPoolSize - 1
    else
        rt = {}
        rt.__container = {}
        setmetatable(rt, meta_rTable)
    end

    return rt
end

rTable.checkin = function(rt)
    local container = rt.__container
    for k, v in pairs(rt.__container) do
        local ref = v.__ref
        ref = ref - 1
        v.__ref = ref
        if ref == 0 then
            tabStruct.checkin(v)
        end
        container[k] = nil
    end

    local size = __rtPoolSize + 1
    if size <= #__rtPool  then
        __rtPool[size] = rt
    else
        table_insert(__rtPool, rt)
    end

    __rtPoolSize = size
end

tabStruct.rTable = rTable

return tabStruct

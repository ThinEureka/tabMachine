--author cs
--04nycs@gmail.com
--
--https://github.com/ThinEureka/tabMachine
--created on Oct 21, 2023 
--

local tabHotReload = {}

tabHotReload.enableLog = false

tabHotReload.logs = {
    -- reload_packages = {},
    reload_tabs = {},
    non_reload_tabs = {}
}

tabHotReload.baseExcludes = {
    "_G",
    "package",
    "string",
    "coroutine",
    "os",
    "io",
    "debug",
    "math",
    "table",
    "utf8",

    "socket",
    "crypt",
    "lpeg",

    "framework.*",
    "tabMachine.*",

    "luaconfig",
}

function tabHotReload.hotReload(rootContext, extraExcludes, includes)
    local packages = tabHotReload.getReloadPackages(extraExcludes, includes)

    if tabHotReload.enableLog then
        tabHotReload.logs.reload_packages = packages
    end

    local tabMap, rTabMap = tabHotReload.buildTabMap(packages)
    local contextMap = tabHotReload.buildContextMap(rTabMap, rootContext)
    tabHotReload.reloadPackage(packages)
    tabMap, rTabMap = tabHotReload.buildTabMap(packages)
    tabHotReload.reloadTabForContexts(contextMap, tabMap)
end

function tabHotReload.isPackageInList(packPath, list)
    for _, path in ipairs(list) do
        local plain = path:find("*", 1, true) == nil
        if plain then
            if packPath == path then
                return true
            end
        else
            local index, endIndex = packPath:find(path, 1)  
            if index == 1 and endIndex == #packPath then
                return true
            end
        end
    end
end

function tabHotReload.getReloadPackages(extraExcludes, includes)
    local baseExcludes = tabHotReload.baseExcludes
    local packages = {}
    for packPath, pack in pairs(package.loaded) do
        if type(pack) == "table" then
            local isIncluded = true
            if includes ~= nil then
                isIncluded = tabHotReload.isPackageInList(packPath, includes)
            end

            if isIncluded then
                isIncluded = not tabHotReload.isPackageInList(packPath, baseExcludes)
            end

            if isIncluded and extraExcludes ~= nil then
                isIncluded = not tabHotReload.isPackageInList(packPath, extraExcludes)
            end

            if isIncluded then
                packages[packPath] = pack
            end
        end
    end

    return packages
end

function tabHotReload.buildTabMap(packages)
    local tabMap = {}
    local uniqueMap = {}
    local addTable = nil
    addTable = function(path, table)
        if uniqueMap[table] == nil then
            uniqueMap[table] = table

            if rawget(table, "__hooked") then
                tabMap[path] = table
            end

            for k, v in pairs(table) do
                local tk = type(k)
                local tv = type(v)
                if tv == "table" and  (tk == "number" or tk == "string") and k ~= "super" and k~= "__index" then
                    local newPath = path .. ".@" .. k
                    addTable(newPath, v)
                end
            end
        end
    end

    for packPath, pack in pairs(packages) do
        addTable(packPath, pack)
    end

    local rTabMap = {}
    for path, tab in pairs(tabMap) do
        rTabMap[tab] = path
    end

    return tabMap, rTabMap
end

function tabHotReload.reloadPackage(packages)
    for path, _ in pairs(packages) do
        package.loaded[path] = nil
    end

    for path, _ in pairs(packages) do
        pcall(function()
            packages[path] = require(path)
        end)
    end
end

function tabHotReload.buildContextMap(rTabMap, rootContext)
    local contextMap = {}
    local function addContext(c)
        local tab = c.__tab
        if tab ~= nil then
            local tabPath = rTabMap[tab] 
            if tabPath ~= nil then
                contextMap[c] = tabPath
            else
                if tabHotReload.enableLog then
                    local log = {
                        context_path = c:getDetailedPath(),
                        reason = "dynamic tab can not be reloaded",
                    }
                    table.insert(tabHotReload.logs.non_reload_tabs, log)
                end
            end
        else
            if tabHotReload.enableLog then
                local log = {
                    context_path = c:getDetailedPath(),
                    reason = "no tab",
                }
                table.insert(tabHotReload.logs.non_reload_tabs, log)
            end
        end

        if c.__subContexts ~= nil then
            for _, subContext in ipairs(c.__subContexts) do
                addContext(subContext)
            end
        end
    end

    addContext(rootContext)
    return contextMap
end

function tabHotReload.reloadTabForContexts(contextMap, tabMap)
    for context, tabPath in pairs(contextMap) do
        local newTab = tabMap[tabPath]
        if newTab ~= nil then
            tabHotReload.reloadTabForContext(context, newTab)
            if tabHotReload.enableLog then
                local log = {
                    context_path = context:getDetailedPath(),
                    tab_path = tabPath 
                }
                table.insert(tabHotReload.logs.reload_tabs, log)
            end
        else
            if tabHotReload.enableLog then
                local log = {
                    context_path = context:getDetailedPath(),
                    tab_path = tabPath,
                    reason = "can not find tab path",
                }
                table.insert(tabHotReload.logs.non_reload_tabs, log)
            end
        end
    end
end

function tabHotReload.reloadTabForContext(context, newTab)
    local tm = g_tm
    tm.compileTab(newTab)

    local oldMetatable = getmetatable(context)
    if oldMetatable == context.__tab then
        setmetatable(context, newTab)
    end

    context.__tab = newTab

    context.__finalFun = newTab.final
    context.__event = newTab.event
    context.__catchFun = newTab.catch
    -- local oldUpdateFun = context.__updateFun
    context.__updateFun = newTab.update
    context.__updateInterval = newTab.updateInterval
    context.__updateTimerMgr = newTab.updateTimerMgr


    -- if oldUpdateFun ~= nil then
        -- tabHotReload.reloadUpdateFun(context, oldUpdateFun, context.__updateFun)
    -- end

    local selfTab = newTab
    if context.__subContexts ~= nil then
        for _, subContext in ipairs(context.__subContexts) do
            if subContext.__tab == nil then
                local subUpdateFunEx 
                local subUpdateIntevalEx
                local subUpdateTimerMgrEx
                local eventEx
                local subFinalFunEx
                local subCatchFunEx

                local commonLabels = tm.__commonLabelCache[subContext.__name]
                if commonLabels then
                    subUpdateFunEx = selfTab[commonLabels.update]
                    local dynamics = context.__dynamics 
                    if dynamics ~= nil then
                        local dynamicLabels = dynamics[scName]
                        if dynamicLabels ~= nil then
                            subUpdateIntevalEx = dynamicLabels.updateInterval
                        end
                    end

                    if subUpdateIntevalEx == nil then
                        subUpdateIntevalEx = selfTab[commonLabels.updateInterval]
                    end
                    subUpdateTimerMgrEx = selfTab[commonLabels.updateTimerMgr]
                    eventEx = selfTab[commonLabels.event]
                    subFinalFunEx = selfTab[commonLabels.final]
                    subCatchFunEx = selfTab[commonLabels.catch]


                end

                -- local oldUpdate = subContext.__updateFunEx
                subContext.__updateFunEx = subUpdateFunEx
                subContext.__updateIntervalEx = subUpdateIntevalEx
                subContext.__updateTimerMgrEx = subUpdateTimerMgrEx
                subContext.__eventEx = eventEx
                subContext.__finalFunEx = subFinalFunEx
                subContext.__catchFunEx = subCatchFunEx

                -- if oldUpdate ~= nil then
                -- tabHotReload.reloadUpdateFun(subContext, oldUpdate, newUpdate)
                -- end
            end
        end
    end
end

--reload updateFun
-- function tabHotReload.reloadUpdateFun(context, oldUpdate, newUpdate)
    -- local timerMgr = g_timerMgr
--
	-- for k, v in ipairs(timerMgr.timerList) do
        -- if v.target == context and v.callBack == oldUpdate then
            -- v.callBack = newUpdate
        -- end
	-- end
-- end


return tabHotReload

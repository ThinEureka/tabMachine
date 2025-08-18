
--author cs
--email 04nycs@gmail.com
--
--https://github.com/ThinEureka/tabMachine
--created on Oct 26, 2023
--
--
local tabSerialization = {}

local baseExcludeKeys = {
    __tab = true,
    __type = true,
    __address = true,
}

local raw_pairs = function(x)
    return next, x, nil
end

local rawget = rawget

function tabSerialization.createSnapshot(rootContext, detailControl)
    local addPath = false
    local addStat = nil
    local addTableAddress = false

    local excludeKeys  = baseExcludeKeys

    if detailControl ~= nil then
        addPath = detailControl.addPath
        addTableAddress = detailControl.addTableAddress
        local extraExcludeKeys = detailControl.extraExcludeKeys
        if extraExcludeKeys ~= nil then
            excludeKeys = {}
            for k, v in pairs(baseExcludeKeys) do
                excludeKeys[k] = v
            end

            for k, v in pairs(extraExcludeKeys) do
                excludeKeys[k] = v
            end
        end

        addStat = detailControl.addStat
    end

    local addressToTable = {}
    local tableToAddress = {}

    local addressToImage = {}
    local addressToPath = {}

    local nextAddress = 1
    local visitArray = {}
    local visitMap = {}

    local function createImage(t, type, path)
        local address = tableToAddress[t]
        if address ~= nil then
            local image = addressToImage[address]
            return address, image
        end

        local address = nextAddress
        nextAddress = nextAddress + 1
        tableToAddress[t] = address
        addressToTable[address] = t
        addressToPath[address] = path

        local image = {}
        if type == "table" then
            if addTableAddress then
                image.__type = type
                image.__address = address
            end
        else
            image.__type = type
            image.__address = address
        end

        if addPath then
            image.__path = path
        end
        addressToImage[address] = image

        return address, image 
    end

    --create image of contexts first
    local contextArray = {}
    table.insert(contextArray, rootContext)
    local contextIndex = 1
    while contextIndex <= #contextArray do
        local c = contextArray[contextIndex]
        local address, image = createImage(c, "table", c:_getPath())
        local subContexts = c.__subContexts
        if subContexts ~= nil then
            for _, sc in ipairs(subContexts) do
                if not sc.__excludeInSnapshot then
                    table.insert(contextArray, sc)
                end
            end
        end
        contextIndex = contextIndex + 1
    end

    local function visitTable(t, image, address, path)
        for k, v in raw_pairs(t) do
            local k_type = type(k)
            if k_type == "string" or k_type == "number" then
                if excludeKeys[k] == nil then
                    local v_type = type(v)
                    if v_type == "number" or v_type == "string" or v_type == "boolean" then
                        image[k] = v
                    elseif v_type == "table" then
                        local v_path = nil
                        if addPath then
                            v_path = path .. "@" .. k
                        end
                        local v_address, v_image = createImage(v, v_type, v_path)
                        image[k] = v_image
                        if not rawget(v, "__excludeInSnapshot") then
                            if not visitMap[v_address] then
                                visitMap[v_address] = true
                                table.insert(visitArray, v_address)
                            end
                        else
                            v_image.__name = rawget(v, "__name")
                        end
                    else
                        if addPath then
                            v_path = path .. "@" .. k
                        end
                        local v_address, v_image = createImage(v, v_type, v_path)
                        image[k] = v_image
                    end
                end
            end
        end
    end

    local rootAddress = tableToAddress[rootContext]
    visitMap[rootAddress] = true
    table.insert(visitArray, rootAddress)
    local visitIndex = 1

    while visitIndex <= #visitArray do
        local nextA = visitArray[visitIndex]
        local nextImage = addressToImage[nextA]
        local nextT = addressToTable[nextA]
        local nextPath = addressToPath[nextA]
        visitTable(nextT, nextImage, nextA, nextPath)
        visitIndex = visitIndex + 1
    end

    local rootImage = addressToImage[rootAddress]

    if addStat then
        if addStat.statTreeSize then
            tabSerialization.statTreeSize(rootImage)
        end
    end

    local snapshot = rootImage 
    return snapshot
end

function tabSerialization.statTreeSize(context)
    local treeSize = 1
    local subContexts = context.__subContexts

    if subContexts ~= nil then
        for _, sc in ipairs(subContexts) do
            if not sc.__excludeInSnapshot then
                treeSize = treeSize + tabSerialization.statTreeSize(sc)
            end
        end
    end

    context.__treeSize = treeSize
    return treeSize

end

function tabSerialization.createTabTreeFromSnapshot(snapshot)
    do 
        return snapshot
    end
    -- local addressToTable = {}
    -- local addressToImage = snapshot.addressToImage
--
    -- local visitArray = {}
    -- local visitMap = {}
--
    -- local function createTable(address, type)
        -- local t = addressToTable[address]
        -- if t ~= nil then
            -- return t
        -- end
--
        -- t = {}
        -- addressToTable[address] = t
--
        -- if type ~= nil then
            -- t["#type"] = type
            -- t["#address"] = address
        -- end
--
        -- return t
    -- end
--
    -- local function visit(t, image, address)
        -- for k, v in pairs(image) do
            -- if excludeKeys[k] == nil then
                -- local v_type = type(v)
                -- if v_type == "number" or v_type == "string" or v_type == "boolean" then
                    -- t[k] = v
                -- elseif v_type == "table" then
                    -- if v.__type == "table" then
                        -- local v_address = v.__address
                        -- t[k] = createTable(v_address)
                        -- if not visitMap[v_address] then
                            -- visitMap[v_address] = true
                            -- table.insert(visitArray, v_address)
                        -- end
                    -- else
                        -- t[k] = createTable(v.__address, v.__type)
                    -- end
                -- end
            -- end
        -- end
    -- end
--
    -- local rootAddress = snapshot.rootAddress
    -- local rootContext = createTable(rootAddress)
    -- local rootImage = addressToImage[rootAddress]
--
    -- local nextT = rootContext
    -- local nextImage = rootImage
    -- local nextA = rootAddress
--
    -- visitMap[rootAddress] = true
--
    -- local visitIndex = 1
    -- while true do
        -- visit(nextT, nextImage, nextA)
        -- nextA = visitArray[visitIndex]
        -- visitIndex = visitIndex + 1
--
        -- if nextA then
            -- nextT = addressToTable[nextA]
            -- nextImage = addressToImage[nextA]
        -- else
            -- break
        -- end
    -- end
--
    -- return rootContext
end

local function exportstring( s )
    return string.format("%q", s)
end

function tabSerialization.saveSnapshotToFile(snapshot, filename)
    local charS,charE = "   ","\n"
    local file,err = io.open( filename, "wb" )
    if err then return err end

    -- initiate variables for save procedure
    local tables,lookup = { snapshot },{ [snapshot] = 1 }
    file:write( "return {"..charE )

    for idx,t in ipairs( tables ) do
        file:write( "-- Table: {"..idx.."}"..charE )
        file:write( "{"..charE )
        local thandled = {}

        for i,v in ipairs( t ) do
            thandled[i] = true
            local stype = type( v )
            -- only handle value
            if stype == "table" then
                if not lookup[v] then
                    table.insert( tables, v )
                    lookup[v] = #tables
                end
                file:write( charS.."{"..lookup[v].."},"..charE )
            elseif stype == "string" then
                file:write(  charS..exportstring( v )..","..charE )
            elseif stype == "number" then
                file:write(  charS..tostring( v )..","..charE )
            end
        end

        for i,v in pairs( t ) do
            -- escape handled values
            if (not thandled[i]) then

                local str = ""
                local stype = type( i )
                -- handle index
                if stype == "table" then
                    if not lookup[i] then
                        table.insert( tables,i )
                        lookup[i] = #tables
                    end
                    str = charS.."[{"..lookup[i].."}]="
                elseif stype == "string" then
                    str = charS.."["..exportstring( i ).."]="
                elseif stype == "number" then
                    str = charS.."["..tostring( i ).."]="
                end

                if str ~= "" then
                    stype = type( v )
                    -- handle value
                    if stype == "table" then
                        if not lookup[v] then
                            table.insert( tables,v )
                            lookup[v] = #tables
                        end
                        file:write( str.."{"..lookup[v].."},"..charE )
                    elseif stype == "string" then
                        file:write( str..exportstring( v )..","..charE )
                    elseif stype == "number" then
                        file:write( str..tostring( v )..","..charE )
                    end
                end
            end
        end
        file:write( "},"..charE )
    end
    file:write( "}" )
    local fileSize = file:seek()
    file:close()
    return fileSize
end

function tabSerialization.loadSnapshotFromFile(sfile)
    local ftables,err = loadfile( sfile )
    if err then return _,err end
    local tables = ftables()
    for idx = 1,#tables do
        local tolinki = {}
        for i,v in pairs( tables[idx] ) do
            if type( v ) == "table" then
                tables[idx][i] = tables[v[1]]
            end
            if type( i ) == "table" and tables[i[1]] then
                table.insert( tolinki,{ i,tables[i[1]] } )
            end
        end
        -- link indices
        for _,v in ipairs( tolinki ) do
            tables[idx][v[2]],tables[idx][v[1]] =  tables[idx][v[1]],nil
        end
    end
    return tables[1]
end

function tabSerialization.addSnapshotTabTree(parentContext, tabTree, name)
    local container = nil
    if not parentContext:hasSub("__snapshots") then
        container = parentContext:call(g_t.tabContainer, "__snapshots")
        container.__excludeInSnapshot = true
        container.__subContexts = {}
    else
        container = parentContext:getSub("__snapshots")
    end

    tabTree.__name = name
    table.insert(container.__subContexts, tabTree)
end


tabSerialization.tabRecordTabClip = _{
    tabName = "recordSnapshots",

    s1 = function (c, rootContext, totalFrame, frameInterval)
        -- c.__excludeInSnapshot = true

        c.rootContext = rootContext
        c.totalFrame = totalFrame
        c.frameInterval = frameInterval or 1

        local clip = {}
        clip.snapshots = {}
        c.clip = clip
        -- c.clip.__excludeInSnapshot = true
        c.beginFrame = g_frameIndex

        c:s1_update()
    end,

    s1_update = function(c)
        local frameIndex = g_frameIndex
        local frameOffset = frameIndex - c.beginFrame
        local clip = c.clip
        local snapshots = clip.snapshots

        if frameOffset % c.frameInterval == 0 then
            local snapshot = tabSerialization.createSnapshot(c.rootContext)
            snapshot.__excludeInSnapshot = true
            snapshot.frameIndex = frameIndex
            table.insert(snapshots, snapshot)
        end

        if c.totalFrame ~= nil then
            if #snapshots >= c.totalFrame then
                c:stop()
            end
        end
    end,

    final = function(c) 
        c:output(c.clip)
    end,

}

return tabSerialization

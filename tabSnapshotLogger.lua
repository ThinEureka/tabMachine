


_tabSnapshotLoggerInstance = nil
tabSnapshotLogger = class("tabSnapshotLogger")


local function saveErrorInfoToFile(filename, errorMsg)
    local file,err = io.open( filename, "wb" )
    if err then return err end


    file:write(errorMsg)
    
    local fileSize = file:seek()
    file:close()
    return fileSize
end

function tabSnapshotLogger:getInstance()
    if _tabSnapshotLoggerInstance == nil then
        _tabSnapshotLoggerInstance = tabSnapshotLogger.new()
    end
    return _tabSnapshotLoggerInstance
end

function tabSnapshotLogger:ctor()
    self.reportPool = {}
end


function tabSnapshotLogger:dumpTabSnapshot( errorMsg, errorStack, tabStack )
    local md5Key = CS.Utils.GetMD5(errorMsg .. errorStack)
    local info = self.reportPool[md5Key]
    if info then
        local count = info.count
        local frameIndex = info.frameIndex
        info.count = count + 1
        info.frameIndex = g_frameIndex
        if count > 20 or frameIndex >= g_frameIndex - 1 then
            print("tabSnapshotLogger:dumpTabSnapshot 频繁触发,暂时忽略")
            return
        end
    else
        info = {
            count = 1,
            frameIndex = g_frameIndex
        }
        self.reportPool[md5Key] = info
    end


    local tabSerialization = require("tabMachine.tabSerialization")
    local rootContext = g_root
    
    local snapshotName = md5Key .. os.date('_%Y-%m-%d-%H-%M-%S_') .. g_frameIndex
    local filename = CS.UnityEngine.Application.persistentDataPath .. "/err_snapshots/" .. snapshotName 
    print("creating snapshot ", filename)

    local pathDir = CS.System.IO.Path.GetDirectoryName(filename)
    if not CS.System.IO.Directory.Exists(pathDir) then
        CS.System.IO.Directory.CreateDirectory(pathDir)
    end
    
    local socket = require("socket")
    local t0 = socket.gettime()
    local detailControl = {
        addPath = false,
        -- addStat = {
            -- statTreeSize = true,
        -- },
        addTableAddress = false,
        extraExcludeKeys = {
            class = true,
            sprotos = true,
        },
    }
    local snapshot = tabSerialization.createSnapshot(rootContext, detailControl)
    snapshot.errorMsgs = string.split(errorStack, "\n")

    local t1 = socket.gettime()
    print("tabSnapshotLogger create snapshot using time: ", t1 - t0)

    local fileSize = tabSerialization.saveSnapshotToFile(snapshot, filename)
    local t2 = socket.gettime()
    print("tabSnapshotLogger save snapshot to file using time: ", t2 - t1, "/", t2 - t0)
    print("tabSnapshotLogger fileSize ", fileSize / (1024*1024), "M")

end

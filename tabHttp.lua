
g_t.httpGetJson = _({
    s1 = function(c, uri, timeout)
        c.uri = uri
        c.requestId = CS.Utils.HttpRequestGet(uri, timeout or 10, function(status, downloadText)
            c:_onRespond(status, downloadText)
        end)
        c.json = require("cjson")
    end,

    _onRespond = function(c, status, downloadText)
        c.requestEnd = true
        if status == 1 then
            local isOk, ret = pcall(function() return c.json.decode(downloadText) end)
            if isOk then
                c:output(true, ret)
            else
                c:output(false)
            end
        else
            c:output(false)
        end
        c:stop()
    end,

    final = function(c)
        if not c.requestEnd then
            CS.Utils.StopRequest(c.requestId)  
        end
    end,

    s1_event = g_t.empty_event,

    __addNickName = function(c)
        c._nickName = "httpGetJson<" .. (c.uri)  .. ">"
    end,
})

g_t.httpGetJsonWithCompete = _({
    s1 = function(c, urls, timeout)
        local tabs = {}
        for _, url in ipairs(urls) do
            local tab = g_t.httpGetJson(url, timeout)
            table.insert(tabs, tab)
        end
        c:call(g_t.compete(tabs), "s2", {"index", "json"})
    end,

    s3 = function(c)
        c:output(c.index~=nil, c.json)
    end,

    __addNickName = function(c)
        c._nickName = "httpGetJsonWithCompete"
    end,
})

g_t.httpGetData = _({
    s1 = function(c, uri, timeout)
        c.requestId = CS.Utils.HttpRequestGet(uri, timeout or 10, function(status, downloadText, data)
            c:_onRespond(status, downloadText, data)
        end)
    end,

    _onRespond = function(c, status, downloadText, data)
        c.requestEnd = true
        if status == 1 then
            c:output(true, data)
        else
            c:output(false)
        end
        c:stop()
    end,

    final = function(c)
        if not c.requestEnd then
            CS.Utils.StopRequest(c.requestId)
        end
    end,

    s1_event = g_t.empty_event,

    __addNickName = function(c)
        c._nickName = "httpGetData"
    end,
})


g_t.httpPost = _({
    s1 = function(c, uri, postData, contentType, timeout)
        c.uri = uri
        c.requestId = CS.Utils.HttpRequestPost(uri, postData, contentType or "application/json", timeout or 10,function(status, downloadText)
            c:_onRespond(status, downloadText)
        end)
    end,

    _onRespond = function(c, status, downloadText)
        c.requestEnd = true
        if status == 1 then
            c:output(true, downloadText)
        else
            c:output(false)
        end
        c:stop()
    end,

    final = function(c)
        if  not c.requestEnd then
            CS.Utils.StopRequest(c.requestId)
        end
    end,

    s1_event = g_t.empty_event,
})

g_t.httpPostFormData = _({
    s1 = function(c, uri, fromData, timeout)
        c.uri = uri
        c.requestId = CS.Utils.HttpRequestPostFormData(uri, fromData, timeout or 10, function(status, downloadText)
            c:_onRespond(status, downloadText)
        end)
    end,

    _onRespond = function(c, status, downloadText)
        c.requestEnd = true
        if status == 1 then
            c:output(true, downloadText)
        else
            c:output(false)
        end
        c:stop()
    end,

    final = function(c)
        if  not c.requestEnd then
            CS.Utils.StopRequest(c.requestId)
        end
    end,

    s1_event = g_t.empty_event,
})


g_t.httpError = {
    webRequestError = 1,
    fileSizeNotMatch = 2,
    md5NotMatch = 3,
}

-- if fileSize is not nil, check the tmp file size first then continue from where last time aborted
-- if you do not need this behavior, delete the tmp file by yourself.
g_t.httpSafeDownload = _({
    s1 = function(c, url, savePath, enableProgressEvent, fileSize, md5, tmpPath, progressInterval)
        c.startTime = require("socket").gettime()
        local downloadedSize = 0
        c.savePath = savePath
        tmpPath = tmpPath or (c.savePath .. ".tmp")
        c.tmpPath = tmpPath
        c.md5 = md5
        c.fileSize = fileSize
        c.url = url
        if g_t.debug then
            c:__addNickName()
        end
        c.report = {url = url, savePath = savePath, existSize = downloadedSize, totalSize = fileSize, md5 = md5}

        if c:fileExists(tmpPath) then
            if fileSize ~= nil  then
                local tmpFileSize = c:getFileSize(tmpPath)
                if tmpFileSize == fileSize then
                    c.ret = {result = true}
                    c:start("s3")
                    return
                elseif tmpFileSize > fileSize then
                    c:deleteFile(tmpPath)
                else
                    downloadedSize = tmpFileSize
                end
            else
                c:deleteFile(tmpPath)
            end
        end

        local csTab = CS.TabHttp.TabDownloadFile(url, tmpPath, function(downloaded)
            if enableProgressEvent then
                c:upwardNotify("downloadProgress", downloaded)
            end
        end, downloadedSize, progressInterval or 500)
        c.report.existSize = downloadedSize
        c:call(g_t.tabCS(csTab) >> "ret", "s2")
    end,

    s3 = function(c)
        c.report.result = c.ret and c.ret.result
        c.report.time = require("socket").gettime() - c.startTime

        if c.ret.result == true then
            if c.fileSize ~= nil then
                local downloadedSize = c:getFileSize(c.tmpPath)
                if downloadedSize ~= c.fileSize then
                    c:deleteFile(c.tmpPath)
                    c.report.error = g_t.httpError.fileSizeNotMatch
                    c:output(false, g_t.httpError.fileSizeNotMatch, c.report)
                    return
                end
            end

            if c.md5 ~= nil then 
                local md5 = c:getFileMd5(c.tmpPath)
                if md5 ~= c.md5 then
                    c:deleteFile(c.tmpPath)
                    c.report.error = g_t.httpError.md5NotMatch
                    c:output(false, g_t.httpError.md5NotMatch, c.report)
                    return
                end
            end

            if c:fileExists(c.savePath) then
                c:deleteFile(c.savePath)
            end

            c:moveFile(c.tmpPath, c.savePath)
            local downloadedSize = c:getFileSize(c.savePath)
            c:upwardNotify("downloadProgress", downloadedSize)
            c.report.fileSize = downloadedSize
            c:output(true, nil, c.report)
        else
            c.report.error = g_t.httpError.webRequestError
            c:output(false, g_t.httpError.webRequestError, c.report)
            return
        end
    end,

    __addNickName = function(c)
        c._nickName = "safeDownload:" .. c.url
    end,

    --private:
    fileExists = function(c, path)
        return CS.Framework.FileUtils.IsFileExists(path)
    end,

    deleteFile = function(c, path)
        CS.System.IO.File.Delete(path)
    end,

    getFileSize = function(c, path)
        return CS.Utils.GetFileSize(path)
    end,

    getFileMd5 = function(c, path)
        return CS.Framework.MD5Utils.GetFileMD5(path)
    end,

    moveFile = function(c, oldPath, newPath)
        CS.System.IO.File.Move(oldPath, newPath)
    end,
})

g_t.tabGetFileSize = _({
    s1 = function(c, url)
        local csTab = CS.TabHttp.TabGetFileSize(url)
        c:call(g_t.tabCS(csTab) >> "result", "s2")
    end,

    s3 = function(c)
        if c.result.isSuccess then
            c:output(c.result.size)
        else
            c:output(-1, c.result)
        end
    end,
})

--author cs
--email 04nycs@gmail.com
--https://github.com/ThinEureka/tabMachine
--created on August 23, 2019 

g_t.mouse_click_event = _({
    s1 = function(c, target, callBack)
        if g_t.debug then
            c._nickName = "click<" .. (target.name or "")  .. ">"
        end
        if type(target) == "table" then 
            c.target = target:com(ct.custom_MouseEvent)
        else
            c.target = target
        end
        c.callBack = callBack
        c.target:AddMouseClickedListener(c.callBack)
    end,

    __addNickName = function(c)
        c._nickName = "mouse_click_event<" .. (c.target.name or "")  .. ">"
    end,

    event = g_t.empty_event,
    final = function(c)
        c.target:RemoveMouseClickedListener(c.callBack)
    end,
})

g_t.click = _({
    s1 = function(c, target, soundId, monitor) 
        if monitor ~= nil then
            c.monitorRef = g_t.aliveRef(monitor)
        end

        if g_t.debug then
            c._nickName = "click<" .. (target.name or "")  .. ">"
        end

        if type(target) == "table" then 
            c.target = target:com(ct.button)
        else
            c.target = target
        end

        c.clickHandler = function()
            local monitor = nil
            if c.monitorRef then
                monitor = c.monitorRef:getTarget()
            end

            if monitor == nil or monitor:isIdle() then
                c:_onClick()
            end
        end

        c.action = CS.Utils.AddButtonListener(c.target,c.clickHandler)
    end,

    __addNickName = function(c)
        c._nickName = "click<" .. (c.target.name or "")  .. ">"
    end,

    event = g_t.empty_event,

    final = function(c)
        c.target.onClick:RemoveListener(c.action)
        c.target = nil
        c.action = nil
    end,

    _onClick = function ( c )
        -- body
        c:output(true)
        c:stop()
    end,
})

g_t.clickTextLink = _({
    s1 = function(c, target, monitor) 
        if g_t.debug then
            c._nickName = "click<" .. tostring(target.name) .. ">"
        end

        if monitor ~= nil then
            c.monitorRef = g_t.aliveRef(monitor)
        end

        c.target = target
        c.action = target:addTextlinkClickHandler(function(linkId, linkStr, index)
            local monitor = nil
            if c.monitorRef then
                monitor = c.monitorRef:getTarget()
            end

            if monitor == nil or monitor:isIdle() then
                c:clickLink(linkId, linkStr, index)
            end
        end)
    end,

    event = g_t.empty_event,

    final = function(c)
        c.target:removeTextlinkClickHandler(c.action)
        c.target = nil
        c.action = nil
    end,

    clickLink = function (c, linkId, linkStr, index)
        c:output(linkId, linkStr, index)
        c:stop()
    end,

    __addNickName = function(c)
        c._nickName = "clickTextLink<" .. (c.target.name or "")  .. ">"
    end,
})

g_t.toggle = _({
    s1 = function(c, target, soundId, monitor) 
        if g_t.debug then
            c._nickName = "toggle<" .. (target.name or "")  .. ">"
        end

        if monitor ~= nil then
            c.monitorRef = g_t.aliveRef(monitor)
        end

        if type(target) == "table" then 
            c.target = target:com(ct.toggle)
        else
            c.target = target
        end

        c.toggleHandler = function(isOn)
            local monitor = nil
            if c.monitorRef then
                monitor = c.monitorRef:getTarget()
            end

            if monitor == nil or monitor:isIdle() then
                c:_onToggle(isOn)
            end
        end
        c.action = CS.Utils.AddToggleListener(c.target, c.toggleHandler)
    end,

    event = g_t.empty_event,

    final = function(c)
        c.target.onValueChanged:RemoveListener(c.action)
        c.target = nil
        c.action = nil
    end,

    _onToggle = function ( c , isOn)
        -- body
        c:output(isOn)
        if not isOn then
            c:call(g_t.skipFrames, "t1", nil ,1)
        else
            c:stop()
        end
    end,
    t2 = function(c)
        c:stop()
    end,

    __addNickName = function(c)
        c._nickName = "toggle<" .. (c.target.name or "")  .. ">"
    end,
})

g_t.bookmarkPageClick = _({
    s1 = function(c, target, monitor) 
        c.target = target
        if monitor ~= nil then
            c.monitorRef = g_t.aliveRef(monitor)
        end

        c.clickHandler = function(index)
            local monitor = nil
            if c.monitorRef then
                monitor = c.monitorRef:getTarget()
            end

            if monitor == nil or monitor:isIdle() then
                c:_onClick(index)
            end
        end
        c.target:AddBookMarkListener(c.clickHandler)
    end,
    event = g_t.empty_event,

    final = function(c)
        c.target:RemoveBookMarkListener()
        c.target = nil
    end,

    _onClick = function (c, index)
        c:output(index)
        c:stop()
    end,
})

g_t.UISwitchClick = _({
    s1 = function(c, uiSwitchGoTable, monitor)
        c.target = uiSwitchGoTable:com(ct.uiSwitch)
        if monitor ~= nil then
            c.monitorRef = g_t.aliveRef(monitor)
        end
        c.clickHandler = function(on)
            local monitor = nil
            if c.monitorRef then
                monitor = c.monitorRef:getTarget()
            end

            if monitor == nil or monitor:isIdle() then
                c:_onClick(on)
            end
        end
        c.target:AddValueChangeListener(c.clickHandler)
    end,

    final = function(c)
        c.target:RemoveValueChangeListener()
        c.target = nil
    end,

    _onClick = function(c, on)
        c:output(on)
        c:stop()
    end,

    event = g_t.empty_event,
})

g_t.toggleGroup = _({
    s1 = function(c, target, soundId, monitor) 
        if type(target) == "table" then 
            c.target = target:com(ct.custom_toggles)
        else
            c.target = target
        end

        if g_t.debug then
            c._nickName = "toggleGroup<" .. c.target.name .. ">"
        end

        if monitor ~= nil then
            c.monitorRef = g_t.aliveRef(monitor)
        end

        c.toggleHandler = function(index)
            local monitor = nil
            if c.monitorRef then
                monitor = c.monitorRef:getTarget()
            end

            if monitor == nil or monitor:isIdle() then
                c:_onToggle(index)
            end
        end
        c.action = CS.Utils.AddToggleGroupListener(c.target, c.toggleHandler)
    end,

    event = g_t.empty_event,

    final = function(c)
        c.target.onValueChanged:RemoveListener(c.action)
        c.target = nil
        c.action = nil
    end,

    _onToggle = function ( c , index)
        c:output(index)
        c:stop()
    end,

    __addNickName = function(c)
        c._nickName = "toggleGroup<" .. (c.target.name or "")  .. ">"
    end,
})

g_t.urlClick = _({
    s1 = function(c, target, monitor)
        if type(target) == "table" then 
            c.target = target:com(ct.text)
        else
            c.target = target
        end

        if monitor ~= nil then
            c.monitorRef = g_t.aliveRef(monitor)
        end
        -- if g_t.debug then
            c._nickName = "urlClick<" .. c.target.name .. ">"
        -- end
        c.urlHandler = CS.TMPro.TMP_TextClickEventHandler.GetObject(c.target)
        c.action = c.urlHandler:AddURLClickListener(function(linkID, linkText, linkIndex)
            local monitor = nil
            if c.monitorRef then
                monitor = c.monitorRef:getTarget()
            end

            if monitor == nil or monitor:isIdle() then
                c:output(linkID, linkText, linkIndex)
                c:stop()
            end
        end)
    end,
    event = g_t.empty_event,
    final = function(c)
        if isNil(c.urlHandler) then
            return
        end
        c.urlHandler:RemoveURLClickListener(c.action)
    end,

    __addNickName = function(c)
        c._nickName = "urlClick<" .. (c.target.name or "")  .. ">"
    end,
})



--author lch

-------------------------------actions -------------------
g_t.waitAnimatorStatusChange = _{
    s1 = function(c, animator, statusName)
        c._nickName = "waitAnimatorStatusChange"
        c.animator = animator
        c.statusName = statusName
        c.normalizedTimeList = {}
    end,
    s1_update = function(c)
        local nextAnimatorStatusInfo = c.animator:GetNextAnimatorStateInfo(0)
        if not nextAnimatorStatusInfo:IsName(c.statusName) then
            c:stop("s1")
        end
    end,
    s2 = g_t.empty_fun,
    s2_update = function(c)
        local animatorStatusInfo = c.animator:GetCurrentAnimatorStateInfo(0)
        if not animatorStatusInfo:IsName(c.statusName) then
            c:stop()
        end
        if animatorStatusInfo.normalizedTime >= 1 then
            c:stop()
        end
        for _,normalizedTime in ipairs(c.normalizedTimeList) do
            if animatorStatusInfo.normalizedTime > normalizedTime then
                c:stop(normalizedTime + "normalizedTime")
            end
        end
    end,

    tabProxyForNormalizedTime = function(c, normalizedTime)
        if not c:getSub(normalizedTime + "normalizedTime") then
            table.insert(c.normalizedTimeList, normalizedTime)
            c:call(_{
                s1 = g_t.empty_fun,
                event = g_t.empty_event,
            }, normalizedTime + "normalizedTime")
        end
        return c:tabProxy(normalizedTime + "normalizedTime")
    end,

    --public
    tabProxyKeyFrame = function (c, keyFrame)
        if not c.frameEvent then
            c.frameEvent = true
        end
        if not c:getSub(keyFrame) then
            c:call(c:tabKeyFrame(keyFrame), keyFrame)
        end
        return c:tabProxy(keyFrame)
    end,
    -- private:
    tabKeyFrame = function(c)
        return _{
            s1 = g_t.empty_fun,
            event = g_t.empty_event,
        }
    end,

    keyFrameEventCall = function(c, keyFrame)
        c:stop(keyFrame)
    end,
}

g_t.waitAniChangeByFrame  = _{
    s1 = function(c, animator, clipName)
        c._nickName = "waitAnimatorStatusChange"
        c.animator = animator
        c.clipName = clipName
        c.normalizedTimeList = {}
        c.animator:AddLastFrameEvent(c.clipName)
    end,

    event = g_t.empty_event,

    --public
    tabProxyKeyFrame = function (c, keyFrame, frameTime)
        if not c:getSub(keyFrame) then
            if frameTime then
                c.animator.AddFrameEvent(c.clipName, keyFrame, frameTime)
            end
            c:call(c:tabKeyFrame(keyFrame), keyFrame)
        end
        return c:tabProxy(keyFrame)
    end,

    -- private:
    tabKeyFrame = function(c)
        return _{
            s1 = g_t.empty_fun,
            event = g_t.empty_event,
        }
    end,

    keyFrameEventCall = function(c, keyFrame)
        if keyFrame == "lastFrame" then
            c:stop()
        else
            c:stop(keyFrame)
        end
    end,
}
g_t.waitForNormalizedTime = _{
    s1 = function(c, animator, statusName, normalizedTime)
        c.normalizedTime = normalizedTime
        c.animator = animator
        c.statusName = statusName
    end,
    s1_update = function(c)
        local animatorStatusInfo = c.animator:GetCurrentAnimatorStateInfo(0)
        if animatorStatusInfo:IsName(c.statusName) then 
            c:stop("s1")
        end
    end,
    s2 = g_t.empty_fun,
    s2_update = function(c)
        local animatorStatusInfo = c.animator:GetCurrentAnimatorStateInfo(0)
        if not animatorStatusInfo:IsName(c.statusName) or animatorStatusInfo.normalizedTime >= c.normalizedTime then
            c:stop("s2")
        end
    end,
}

g_t.waitForLastFrame = _{
    s1 = function(c, animation)
        c._nickName = "waitForLastFrame"
        c.animation = animation
    end,

    s1_update = function(c)
        if not c.animation.isPlaying then 
            c:stop()
        end
    end,

    --public
    tabProxyKeyFrame = function (c, keyFrame)
        local sub = c:getSub(keyFrame)
        if not sub then
            c:call(c:tabKeyFrame(keyFrame), keyFrame)
            sub = c:getSub(keyFrame)
        end
        return sub:tabProxy()
    end,
    -- private:
    tabKeyFrame = function(c, keyFrame)
        return _{
            s1 = g_t.empty_fun,
            event = {
                keyFrame = function(c, frame)
                    if keyFrame == frame then
                        c:stop()
                    end
                end
            },
        }
    end,

    keyFrameEventCall = function(c, keyFrame)
        c:notify("keyFrame", keyFrame)
    end,

    event = g_t.empty_event,
}

g_t.waitForAct = _{
    s1 = function (c, node, act)
        if g_t.debug then
            c._nickName = "waitForAct"
        end
        transition.execute(node, act, {onComplete = function()
            c:stop()
        end})
        if act.getDuration then
            c:call(g_t.delay, "s2", nil, act:getDuration())
        end
    end,
    s3 = function(c)
        c:stop()
    end,
    event = g_t.empty_event,
}

g_t.playSpineAnimation = _{
    s1 = function(c, spine, animationName)
        c.spine = spine
        spine:registerSpineEventHandler(function (data)
            if data.type == spEventTypeString.SP_ANIMATION_COMPLETE 
                and animationName == data.animation then
                c:stop()
            end
        end,spEventType.SP_ANIMATION_COMPLETE)
        spine:setAnimation(0, animationName, false)
    end,

    final = function(c)
        local spine = c.spine
        if not tolua.isnull(spine) then
            spine:unregisterSpineEventHandler(sp.EventType.ANIMATION_COMPLETE)
        end
    end,
    event = g_t.empty_event,
}
local math_pow = math.pow or function(x, y) return x^y end

g_t.curve = {}
g_t.curve.circleEaseOut = function(k)
    local value = k - 1
    return math.sqrt(1 - value * value)
end

g_t.curve.circleEaseIn = function(k)
    local value = k
    return -1 * (math.sqrt(1 - value * value) - 1)
end

g_t.curve.circleEaseInOut = function(k)
    local value = k*2
    if value < 1 then 
        return -0.5*(math.sqrt(1 - value * value) - 1)
    end
    value = value - 2
    return 0.5 * (math.sqrt(1 - value * value) + 1)
end

g_t.curve.quadEaseOut = function(k)
    local value = k
    return -1 * value * (value - 2)
end

g_t.curve.quadEaseIn = function(k)
    local value = k
    return value * value
end

g_t.curve.quadEaseInOut = function(k)
    local value = k * 2
    if value < 1 then 
        return 0.5 * value * value
    end 
    value = value - 1
    return -0.5*(value*(value-2)-1)
end

g_t.curve.cubicEaseIn = function(k)
    local value = k
    return k * value * value
end

g_t.curve.cubicEaseOut = function (k)
    local value = k - 1
    return value*value*value+1
end

g_t.curve.cubicEaseInOut = function(k)
    local value = k * 2
    if value < 1 then 
        return 0.5 * value * value * value
    end
    value = value - 2
    return 0.5 * (value * value * value + 2)
end

g_t.curve.sineEaseIn = function (k)
    return -1*math.cos(k*math.pi/2) + 1
end

g_t.curve.sineEaseOut = function (k)
    return math.sin(k*math.pi/2)
end

g_t.curve.sineEaseInOut = function (k)
    return -0.5*(math.cos(math.pi*k)-1)
end

g_t.curve.expoEaseIn = function (k)
    return math_pow(2, 10*(k-1))
end

g_t.curve.expoEaseOut = function (k)
    return math.sin(k*math.pi/2)
end

g_t.curve.expoEaseInOut = function (k)
    return -0.5*(math.cos(math.pi*k)-1)
end

g_t.curve.quintEaseIn = function (k)
    return k * k * k * k * k
end

g_t.curve.quintEaseOut = function (k)
    k = k - 1
    return k * k * k * k * k + 1
end

g_t.curve.quintEaseInOut = function (k)
    k = k * 2
    if k < 1 then 
        return 0.5 * k * k * k * k * k
    end
    k= k - 2
    return 0.5 * (k * k * k * k * k + 2)
end

g_t.curve.easeInQuart = function(k)
    return k * k * k * k 
end

g_t.curve.easeOutQuart = function(k)
    return 1 - math_pow(1 - k, 4)
end

g_t.curve.easeInOutQuart = function(k)
    if k < 0.5 then 
        return 8 * k * k * k * k 
    end
    return 1 - (-2 * k + 2)^ 4 / 2
end

g_t.curve.easeInBack = function(k)
    local k1 = 1.70158
    local k2 = k1 + 1
    return k2 * k * k * k - k1 * k * k
end

g_t.curve.easeOutBack = function(k)
    local k1 = 1.70158
    local k2 = k1 + 1
    return 1 + k2 * math_pow(k - 1, 3) + k1 * math_pow(k - 1, 2)
end

g_t.curve.easeInOutBack = function(k)
    local k1 = 1.70158
    local k2 = k1 * 1.525;

    k = k * 2
    if k < 1 then 
        return 0.5 * (k * k  * ((k2 + 1) * k - k2)) 
    end
    k = k - 2
    return 0.5 * (k * k  * ((k2 + 1) * k + k2) + 2)
end

g_t.curve.easeInElastic = function(k)
    local k1 = 2 / 3 * math.pi

    if k == 0  then 
        return 0 
    elseif k == 1 then 
        return 1
    end
    return -1 * math_pow(2, 10 * k - 10) * math.sin((k * 10 - 10.75) * k1)
end

g_t.curve.easeOutElastic = function(k)
    local k1 =  2 / 3 * math.pi
    if k == 0 then
        return 0 
    elseif k == 1 then
        return 1
    end
    return math_pow(2, -10 * k) * math.sin((k * 10 - 0.75) * k1) + 1
end

g_t.curve.easeInOutElastic = function(k)
    local k1 = 4 / 9 * math.pi 
    if k == 0 then 
        return 0 
    elseif k == 1 then 
        return 1
    end
    k = k * 20
    if k < 10 then 
        return - 0.5 * (math_pow(2, k - 10) * math.sin((k - 11.125) * k1)) 
    end
    return 0.5 * math_pow(2, -k + 10) * math.sin((k - 11.125) * k1)+ 1
end

g_t.curve.easeOutBounce = function(k)
    local k1 = 7.5625;
    local k2 = 2.75;
    if (k < 1 / k2) then
        return k1 * k * k;
    elseif (k < 2 / k2) then
        local k = k - 1.5/k2
        return k1 * k * k + 0.75
    elseif (k < 2.5 / k2) then
        local k2 = k - 2.25/k2
        return k1 * k2 * k2 + 0.9375
    else 
        local k3 = k - 2.625/k2
        return k1 * k3 * k3 + 0.984375
    end
end

g_t.curve.easeInBounce = function(k)
    return 1 - g_t.curve.easeOutBounce(1-k)
end

g_t.curve.easeInOutBounce = function(k)
    k = k * 2
    if k < 1 then 
        return 0.5 - 0.5 * g_t.curve.easeOutBounce(1 -  k)
    else
        return 0.5 + 0.5 * g_t.curve.easeOutBounce(k - 1)
    end
end

g_t.curve.defaultLine = function (k)
    return k
end

g_t.tween = _{
    s1 = function(c, fun, v1, v2, duration, curve)
        if g_t.debug then
            c._nickName =  "tween"
        end
        fun(v1)
        c.time = 0
        c.duration = duration
        c.v1 = v1
        c.v2 = v2
        c.fun = fun
        c.curve = curve
    end,

    s1_update = function(c, dt)
        c.time = c.time + dt
        if c.time > c.duration then
            c:stop("s1")
            return
        end

        local rate = c.time / c.duration
        local v
        if c.curve and type(c.curve) == "function" then
            local tempRate = c.curve(rate)
            v = (c.v2 - c.v1)*tempRate + c.v1
        else
            v = c.v1 * (1.0 - rate) + c.v2 * rate
        end
        c.fun(v)
    end,

    s2 = function(c)
        c.fun(c.v2)
    end,

    _preCal = function(v1, v2, curDuration, duration, curve)
        local rate = curDuration / duration
        local v
        if curve and type(curve) == "function" then
            local tempRate = curve(rate)
            v = (v2 - v1)*tempRate + v1
        else
            v = v1 * (1.0 - rate) + v2 * rate
        end
        return v
    end
}

--二阶
g_t.curve.bezierOnePoint = function(t, p0, p1, p2)
    local p0p1 = mathLib.lerpVec3(p0, p1, t)
    local p1p2 = mathLib.lerpVec3(p1, p2, t)
    local result = mathLib.lerpVec3(p0p1, p1p2, t)
    return result
end

--三阶
g_t.curve.bezierTwoPoint = function(t, p0, p1, p2, p3)
    local p0_1 = mathLib.lerpVec3(p0,p1,t)
    local p1_2 = mathLib.lerpVec3(p1,p2,t)
    local p2_3 = mathLib.lerpVec3(p2,p3,t)
    local p0_1_1_2 = mathLib.lerpVec3(p0_1,p1_2,t)
    local p1_2_2_3 = mathLib.lerpVec3(p1_2,p2_3,t)
    local p0_1_1_2_1_2_2_3 = mathLib.lerpVec3(p0_1_1_2,p1_2_2_3,t)
    return p0_1_1_2_1_2_2_3
end

g_t.bezier = _{
    s1 = function(c, fun, v1, v2, duration, bezierCurve, points, curve)
        if not bezierCurve or type(bezierCurve) ~= "function" then
            printError("bezierCurve is error")
            return
        end
        if g_t.debug then
            c._nickName =  "bezier"
        end
        fun(v1)

        c.v2 = v2
        c.fun = fun
        local ratePos = {}
        if not curve then
            curve = g_t.curve.defaultLine
        end
        local function moveTo(rate)
            ratePos.x = rate
            ratePos.y = rate
            ratePos.z = rate
            local v
            if (#points == 1) then
                v = bezierCurve(ratePos, v1, points[1], v2)
            elseif (#points == 2) then
                v = bezierCurve(ratePos, v1, points[1], points[2], v2)
            end
            fun(v)
        end
        c:call(g_t.tween, "s2", nil, moveTo, 0, 1, duration, curve)
    end,
    s3 = function(c)
        c.fun(c.v2)
    end,
}

g_t.printText = _{
    s1 = function(c, labNode, word, interval)
        print("tabPrintText==========", word, interval)
        c.word = word or ""
        c.index = 0
        c.t = 0
        c.interval = interval or 0.1
        c.wordCount = str_util.subStringGetTotalIndex(word)
        c.labelNode = labNode
        if c.wordCount > 1 then
            local subWord = str_util.subStringUTF8(c.word, 1, 1)
              c.labelNode:setString(subWord)
        end
    end,
    s1_update = function(c, dt)
        c.index = c.index + 1
        if c.index <= c.wordCount then
            local subWord = str_util.subStringUTF8(c.word, 1, c.index)
            if not tolua.isnull(c.labelNode) then
                c.labelNode:setString(subWord)
            end
        else
            c:stop()
        end
    end,
    s1_updateInterval = interval,
    final = function(c)
       -- labNode = nil
    end
}

g_t.printTextEx = _{
    s1 = function(c, labNode, word, interval, needUpwardNotify)
        labNode:setData(word)
        c.labCom = labNode:com(ct.text)
        c.curCount = 0
        c.labCom.maxVisibleCharacters = c.curCount
        c.needUpwardNotify = needUpwardNotify
        c:setDynamics("s3", "updateInterval", interval or 0.1)
        c:call(g_t.skipFrames, "s2", nil, 1)
    end,
    s3 = function(c)
        c.maxCount = c.labCom.textInfo.characterCount
        if (c.needUpwardNotify) then
            c:upwardNotify("onLabSizeFix")
        end
    end,
    s3_update = function(c)
        if c.curCount > c.maxCount then
            c:stop("s3")
            return
        end
        c.curCount = c.curCount + 1
        c.labCom.maxVisibleCharacters = c.curCount
    end,
    --overwrite in s1 setDynamics(s3)
    s3_updateInterval = nil,
    final = function(c)
        if (c.maxCount) then
            c.labCom.maxVisibleCharacters = c.maxCount
        end
    end
}

g_t.timeline_anim = _{
    s1 = function(c, nodeList, timeLineConfig, anim)
        require("gameFlow.timeline.timeline_util")
        if g_t.debug then
            c._nickName = "timeline_anim"
        end
        local fps = timeLineConfig.fps
        local animConfigs = timeLineConfig[anim]
        for _, v in pairs(nodeList) do
            local name = v.name
            local go = v.go
            local animConfig = animConfigs[name]
            local loop = animConfigs.loop
            for key, attrCfg in pairs(animConfig) do
                c:call(c.playNode(key, attrCfg, go, loop, fps), "playNode" .. name .. key)
            end
        end
    end,

    playNode = _{
        s1 = function(c, key, attrCfg, go, loop, fps)
            c.key = key
            c.object = go
            c.loop = loop
            c.frameDatas = timeline_util.parseFrameNodeConfig(attrCfg)
            c.totalCount = #c.frameDatas
            c.index = 1
            c.nextIndex = c.index + 1
            c.time = 0
        end,
        s2 = function(c)
            c.curFrame = c.frameDatas[c.index]
            c.nextFrame = c.frameDatas[c.nextIndex]
            c.beginTime = c.curFrame.time
            c.beginValue = c.curFrame.value
            c.endTime = c.nextFrame.time
            c.endValue = c.nextFrame.value
            c.curveType = c.curFrame.curve and g_t.curve[c.curFrame.curve] or g_t.curve.defaultLine
        end,
        s2_update = function(c, deltaTime)
            c.time = c.time + deltaTime
            local progress = math.min(1, (c.time - c.beginTime)/(c.endTime - c.beginTime))
            progress = c.curveType(progress)
            local value = (c.endValue - c.beginValue) * progress + c.beginValue
            timeline_util.setObjectClipFrame(c.key, c.object, value)
            if c.time >= c.endTime then
                c:stop("s2")
            end
        end,
        s3 = function(c)
            c.index = c.index + 1
            c.nextIndex = c.index + 1
            if c.nextIndex <= c.totalCount then
                c:start("s2")
            elseif c.loop and c.loop == 1 then
                c.index = 1
                c.nextIndex = c.index + 1
                c.time = 0
                c:start("s2")
            else
                c:stop()
            end
        end,
    }
}

local getNodeAttribute
local parseTimeLineData
local setNodeAttribute
------------示例
--eParams = {e1=function() ,e2 = function()}
--g_t.timeline(node, "t=0|t=4,x=200,y=200,sx=0,a=1,r=90,e=e1|t=8,+x=300,+y=300,sx=1,a=255,r=0,e=e2", eParams)
--timeStr参数说明t为时间节点，x,y,+x,+y为位置参数，s,sx,sy,+s,+sx,+sy为缩放参数，r,+r为角度旋转参数，d,+d为弧度旋转参数
--a,+a为透明参数，e为回调函数或者tab 

-- {x y +x +y lx, ly +lx, +ly 未位置参数， s,sx,sy,+s,+sx,+sy}
g_t.timeline = _{
    s1 = function(c, gameObject, operateTable)
        if g_t.debug then
            c._nickName = "timeline"
        end
        c.time = 0
        c.gameObject = gameObject
        c.operateTable = operateTable
        c.lineData = parseTimeLineData(operateTable)
    end,
    s2 = function(c)
        c.curData = table.remove(c.lineData, 1)
        if c.curData then 
            c:start("s4")
        end
    end,
    s4 = function(c)
        c.nodeAttribute = getNodeAttribute(c.gameObject, c.curData.animation)
    end,
    s4_update = function(c, dt)
        c.time = c.time + dt
        setNodeAttribute(c.gameObject, c.nodeAttribute, c.curData, c.operateTable, c.time)
        if c.time >= c.curData.animation.t then 
            if c.curData.animation.f then 
                if type(c.curData.animation.f) == "function" then 
                    c.curData.animation.f(c, c.gameObject)
                elseif type(c.curData.animation.f) == "table" then 
                    c:call(c.curData.animation.f(c.gameObject), "f")
                end 
            end 
            c:stop("s4")
        end
    end,
    s5 = function(c)
        c:start("s2")
    end,
}

parseTimeLineData = function(operateTable)
    local count = 1
    local list = {}
    local custom = {}
    local preValue = 0 
    for index, v in ipairs(operateTable) do
        if not v.curve then 
            list[count] = {
                animation = v,
            }
            custom = {}
            for type, value in pairs(v) do
                if operateTable[type] then 
                    preValue = 0
                    for i = math.max(index - 1, 1), 1, -1 do 
                        if operateTable[i][type] then 
                            preValue = operateTable[i][type]
                            break
                        end
                    end
                    custom[type] = {preValue = preValue, value = value }
                end
            end
            list[count].custom = custom
            if operateTable[index + 1] and operateTable[index + 1].curve then 
                list[count].curve = operateTable[index + 1].curve 
            end
            count = count + 1
        end
    end
    for i, v in ipairs(list) do
        v.timeInterval = list[i - 1] and v.animation.t - list[i - 1].animation.t or v.animation.t
    end
    return list
end

getNodeAttribute = function (gameObject, curData, operateTable, custom)
    local data = {}
    if curData.x or curData["+x"] then 
        data.x = CS.GameObjUtil.GetLocalPositionX(gameObject)
    end 
    if curData.y or curData["+y"] then 
        data.y = CS.GameObjUtil.GetLocalPositionY(gameObject)
    end
    if curData.s or curData["+s"] then 
        data.s = CS.GameObjUtil.GetScale(gameObject)
    end
    if curData.a or curData["+a"] then 
        local canvasGroup = gameObject:GetComponentInChildren("CanvasGroup")
        local alpha = 1
        if not isNil(canvasGroup) then
            alpha = canvasGroup.alpha
        end
        data.a = alpha
    end 
    if curData.sx or curData["+sx"] then 
        data.sx = CS.GameObjUtil.GetScaleX(gameObject)
    end
    if curData.sy or curData["+sy"] then 
        data.sy = CS.GameObjUtil.GetScaleY(gameObject)
    end
    if curData.w then
        data.w, data.h = CS.GameObjUtil.GetSizeDelta(gameObject.rectTransform)
    end
    -- if curData.cr then
    --     local color = node:getColor()
    --     data.cr = color.r
    -- end
    -- if curData.cg then
    --     local color = node:getColor()
    --     data.cg = color.g
    -- end
    -- if curData.cb then
    --     local color = node:getColor()
    --     data.cb = color.b
    -- end
    return data
end


setNodeAttribute = function(gameObject, oldAttribute, operateData, operateTable, curTime)
    local rate = 1
    local finalAttribute = operateData.animation
    if finalAttribute.t > 0 then 
        rate = (operateData.timeInterval - math.max(finalAttribute.t - curTime,0)) / operateData.timeInterval
        if operateData and operateData.curve then
            rate = operateData.curve(rate)
        end
    end
    if finalAttribute.x or finalAttribute["+x"] then 
        local addX = finalAttribute.x and (finalAttribute.x - oldAttribute.x) or finalAttribute["+x"]
        local x = oldAttribute.x + addX * rate
        CS.GameObjUtil.SetLocalPositionX(gameObject, x)
    end
    if finalAttribute.y or finalAttribute["+y"] then 
        local addY = finalAttribute.y and (finalAttribute.y - oldAttribute.y ) or finalAttribute["+y"]
        local y = oldAttribute.y + addY * rate
        CS.GameObjUtil.SetLocalPositionY(gameObject, y)
    end 
    if finalAttribute.s or finalAttribute["+s"] then 
        local addS = finalAttribute.s and (finalAttribute.s - oldAttribute.s ) or finalAttribute["+s"]
        local s = oldAttribute.s + addS * rate 
        CS.GameObjUtil.SetScale(gameObject, s)
    end 
    if finalAttribute.a or finalAttribute["+a"] then
        local addA = finalAttribute.a and (finalAttribute.a - oldAttribute.a ) or finalAttribute["+a"]
        local a = oldAttribute.a + addA * rate
        local canvasGroup = gameObject:GetComponentInChildren("CanvasGroup")
        if not isNil(canvasGroup) then
            canvasGroup.alpha = a
        end
    end 
    if finalAttribute.sx or finalAttribute["+sx"] then 
        local addSx = finalAttribute.sx and (finalAttribute.sx - oldAttribute.sx ) or finalAttribute["+sx"]
        local sx = oldAttribute.sx + addSx * rate
        CS.GameObjUtil.SetScaleX(gameObject, sx)
    end 
    if finalAttribute.sy or finalAttribute["+sy"] then 
        local addSy = finalAttribute.sy and (finalAttribute.sy - oldAttribute.sy ) or finalAttribute["+sy"]
        local sy = oldAttribute.sy + addSy * rate
        CS.GameObjUtil.SetScaleY(gameObject, sy)
    end 
    if finalAttribute.w then
        local addW = finalAttribute.w and (finalAttribute.w - oldAttribute.w )
        local sw = oldAttribute.w + addW * rate
        CS.GameObjUtil.SetSizeDelta(gameObject.rectTransform, sw, oldAttribute.h)
    end
    for type, customValue in pairs(operateData.custom) do
        local addCustom = customValue.value - customValue.preValue
        local addValue = customValue.preValue + addCustom * rate
        operateTable[type](addValue)
    end
end

local function splitStr(inputstr, sep)
    local t={} ; i=1
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        t[i] = str
        i = i + 1
    end
    return t
end

-- 由于数组起始索引lua和c++有所不同，代码有做适当改动
-- node：
--     1.为node时自动改变节点位置
--     2.为nil时仅作为纯计算用途
function g_t.catmullRom(node, duration, points, needAutoRotation)
    assert(type(points) == "table", "points must be array")
    assert(#points > 1, "point num must greater than 1")
    assert(duration > 0, "duration must greater than zero!")
    return _{
        s1 = function(c)
            if g_t.debug then
                c._nickName = "catmullRom"
            end
            c.deltaT = 1 / (#points - 1)
            c.elapsed = 0
            c.dir = cc.p(0, 0)
            if node and type(node) == "userdata" then
                local x, y = node:getPosition()
                c.pos = cc.p(x, y)
            else
                c.pos = points[1]
            end
        end,

        update = function(c, deltaTime)
            local p;
            local lt;
            c.elapsed = c.elapsed + deltaTime
            local time = c.elapsed / (duration > 0 and duration or 1.4e-45)
            local reached = false
            if time >= 1 then
                reached = true
                time = 1
            end
            if (time == 1) then
                p = #points
                lt = 1
            else 
                p = math.floor(time / c.deltaT)
                lt = (time - c.deltaT * p) / c.deltaT
                p = p + 1
            end
    
            -- Interpolate    
            local pp0 = c:_getControlPointAtIndex(p - 1)
            local pp1 = c:_getControlPointAtIndex(p + 0)
            local pp2 = c:_getControlPointAtIndex(p + 1)
            local pp3 = c:_getControlPointAtIndex(p + 2)
            local newPos = c:_cardinalSplineAt(pp0, pp1, pp2, pp3, lt)
            c.pos = newPos
            if node and not tolua.isnull(node) then
                node:setPosition(newPos)
            end
            if time ~= 1 then
                -- 获取方向
                if needAutoRotation then
                    local dir = c:_dirAt(pp0, pp1, pp2, pp3, lt)
                    c.dir = dir
                    if node and not tolua.isnull(node) then
                        local angle = math.radian2angle(math.atan2(dir.y, dir.x))
                        node:setRotation(-angle)
                    end
                end
            end
            if reached then
                c:stop()
            end
        end,

        getCurPos = function(c)
            return c.pos
        end,

        getDir = function (c)
            return c.dir
        end,

        _cardinalSplineAt = function (c, p0, p1, p2, p3, t)
            local t2 = t * t
            local t3 = t2 * t
            --
            -- Formula: s(-ttt + 2tt - t)P1 + s(-ttt + tt)P2 + (2ttt - 3tt + 1)P2 + s(ttt - 2tt + t)P3 + (-2ttt + 3tt)P3 + s(ttt - tt)P4
            --
            local s = (1 - 0.5) / 2
            
            local b1 = s * ((-t3 + (2 * t2)) - t)                      -- s(-t3 + 2 t2 - t)P1
            local b2 = s * (-t3 + t2) + (2 * t3 - 3 * t2 + 1)          -- s(-t3 + t2)P2 + (2 t3 - 3 t2 + 1)P2
            local b3 = s * (t3 - 2 * t2 + t) + (-2 * t3 + 3 * t2)      -- s(t3 - 2 t2 + t)P3 + (-2 t3 + 3 t2)P3
            local b4 = s * (t3 - t2)                                   -- s(t3 - t2)P4
            
            local x = (p0.x * b1 + p1.x * b2 + p2.x * b3 + p3.x * b4)
            local y = (p0.y * b1 + p1.y * b2 + p2.y * b3 + p3.y * b4)
            return cc.p(x,y)
        end,

        _dirAt = function (c, p0, p1, p2, p3, t)
            local t2 = t * t
            local s = (1 - 0.5) / 2
            local b1 = s * (-3 * t2 + 4 * t - 1)
            local b2 = s * (-3 * t2 + 2 * t) + (6 * t2 - 6 * t)
            local b3 = s * (3 * t2 - 4 * t + 1) + (-6 * t2 + 6 * t)
            local b4 = s * (3 * t2 - 2 * t)
            local x = (p0.x * b1 + p1.x * b2 + p2.x * b3 + p3.x * b4)
            local y = (p0.y * b1 + p1.y * b2 + p2.y * b3 + p3.y * b4)
            return cc.p(x, y)
        end,

        _getControlPointAtIndex = function (c, index)
            return points[util.clampf(index, 1, #points)]
        end,

    }
end

return cocosContext

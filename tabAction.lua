--author lch

-------------------------------actions -------------------

g_t.waitForLastFrame = {
    s1 = function(c, act)
        if g_t.debug then
            c._nickName = "waitForLastFrame"
        end

        c.v.act = act
        act:setLastFrameCallFunc(function()
            c:stop()
        end)
    end,

    final = function(c)
        local act = c.v.act
        if not tolua.isnull(act) then
            act:setLastFrameCallFunc(g_t.empty_frame)
        end
    end,

    event = g_t.empty_event,
}

g_t.waitForAct = {
    s1 = function (c, node, act)
        if g_t.debug then
            c._nickName = "waitForAct"
        end
        transition.execute(node, act, {onComplete = function()
            c:stop()
        end})
    end,
    event = g_t.empty_event,
}

g_t.playSpineAnimation = {
    s1 = function(c, spine, animationName)
        c.v.spine = spine
        spine:registerSpineEventHandler(function (data)
            if data.type == spEventTypeString.SP_ANIMATION_COMPLETE 
                and animationName == data.animation then
                c:stop()
            end
        end,spEventType.SP_ANIMATION_COMPLETE)
        spine:setAnimation(0, animationName, false)
    end,

    final = function(c)
        local spine = c.v.spine
        if not tolua.isnull(spine) then
            spine:unregisterSpineEventHandler(sp.EventType.ANIMATION_COMPLETE)
        end
    end,
    event = g_t.empty_event,
}

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
    return math.pow(2, 10*(k-1))
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

g_t.curve.defaultLine = function (k)
    return k
end

g_t.tween =  {
    s1 = function(c, fun, v1, v2, duration, curve)
        if g_t.debug then
            c._nickName =  "tween"
        end
        fun(v1)
        c.v.time = 0
        c.v.duration = duration
        c.v.v1 = v1
        c.v.v2 = v2
        c.v.fun = fun
        c.v.curve = curve
    end,

    s1_update = function(c, dt)
        c.v.time = c.v.time + dt
        if c.v.time > c.v.duration then
            c:stop()
            return
        end

        local rate = c.v.time / c.v.duration
        local v
        if c.v.curve and type(c.v.curve) == "function" then
            local tempRate = c.v.curve(rate)
            v = (c.v.v2 - c.v.v1)*tempRate + c.v.v1
        else
            v = c.v.v1 * (1.0 - rate) + c.v.v2 * rate
        end
        c.v.fun(v)
    end,

    s2 = function(c)
        c.v.fun(c.v.v2)
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

local getNodeAttribute
local parseTimeLineData
local setNodeAttribute
------------示例
--eParams = {e1=function() ,e2 = function()}
--g_t.timeLine(node, "t=0|t=4,x=200,y=200,sx=0,a=1,r=90,e=e1|t=8,+x=300,+y=300,sx=1,a=255,r=0,e=e2", eParams)
--timeStr参数说明t为时间节点，x,y,+x,+y为位置参数，s,sx,sy,+s,+sx,+sy为缩放参数，r,+r为角度旋转参数，d,+d为弧度旋转参数
--a,+a为透明参数，e为回调函数或者tab 
function g_t.timeLine(node, timeStr, eParam)
    return {
        s1 = function (c)
            if g_t.debug then
                c._nickName = "timeLine"
            end
            if not c.v.lineData then 
                c.v.lineData = parseTimeLineData(timeStr, node, eParam)
            end 
            if not c.v.time then 
                c.v.time = 0
            end
            c.v.curData = table.remove(c.v.lineData, 1)
            if not c.v.curData then 
                c:stop()
            end
        end,

        s2 = function (c)
            c.v.nodeAttribute = getNodeAttribute(node, c.v.curData)
        end,

        s2_update = function (c, dt)
            c.v.time = c.v.time + dt
            setNodeAttribute(node, c.v.nodeAttribute, c.v.curData, c.v.time)
            if c.v.time >= c.v.curData.t then 
                if c.v.curData.e then 
                    if type(c.v.curData.e) == "function" then 
                        c.v.curData.e()
                    elseif type(c.v.curData.e) == "table" then 
                        c:call(c.v.curData.e, "e")
                    end 
                end 
                c:stop("s2")
            end 
        end,

        s3 = function (c)
            c:start("s1")
        end,
    }
end

setNodeAttribute = function (node, oldAttribute, finalAttribute, curTime)
    local rate = 1
    if finalAttribute.time > 0 then 
        rate = (finalAttribute.time - math.max(finalAttribute.t - curTime,0)) / finalAttribute.time
        if finalAttribute.curve then
            if g_t.curve[finalAttribute.curve] then 
                rate = g_t.curve[finalAttribute.curve](rate)
            end
        end
    end
    if finalAttribute.x or finalAttribute["+x"] then 
        local addX = finalAttribute.x and (finalAttribute.x - oldAttribute.x) or finalAttribute["+x"]
        local x = oldAttribute.x + addX * rate
        node:setPositionX(x)
    end
    if finalAttribute.y or finalAttribute["+y"] then 
        local addY = finalAttribute.y and (finalAttribute.y - oldAttribute.y ) or finalAttribute["+y"]
        local y = oldAttribute.y + addY * rate
        node:setPositionY(y)
    end 
    if finalAttribute.s or finalAttribute["+s"] then 
        local addS = finalAttribute.s and (finalAttribute.s - oldAttribute.s ) or finalAttribute["+s"]
        local s = oldAttribute.s + addS * rate 
        node:setScale(s)
    end 
    if finalAttribute.r or finalAttribute["+r"] then 
        local addR = finalAttribute.r and (finalAttribute.r - oldAttribute.r ) or finalAttribute["+r"]
        local r = oldAttribute.r + addR * rate
        node:setRotation(r)
    end 
    if finalAttribute.a or finalAttribute["+a"] then
        local addA = finalAttribute.a and (finalAttribute.a - oldAttribute.a ) or finalAttribute["+a"]
        local a = oldAttribute.a + addA * rate
        node:setOpacity(a)
    end 
    if finalAttribute.d or finalAttribute["+d"] then 
        local addD = finalAttribute.d and (finalAttribute.d - oldAttribute.d ) or finalAttribute["+d"]
        local d = oldAttribute.d + addD * rate
        node:setRotation(d*180/3.1415)
    end
    if finalAttribute.sx or finalAttribute["+sx"] then 
        local addSx = finalAttribute.sx and (finalAttribute.sx - oldAttribute.sx ) or finalAttribute["+sx"]
        local sx = oldAttribute.sx + addSx * rate
        node:setScaleX(sx)
    end 
    if finalAttribute.sy or finalAttribute["+sy"] then 
        local addSy = finalAttribute.sy and (finalAttribute.sy - oldAttribute.sy ) or finalAttribute["+sy"]
        local sy = oldAttribute.sy + addSy * rate
        node:setScaleY(sy)
    end 
    if finalAttribute.cr and finalAttribute.cg and finalAttribute.cb then
        local addR = finalAttribute.cr and (finalAttribute.cr - oldAttribute.cr )
        local addG = finalAttribute.cg and (finalAttribute.cg - oldAttribute.cg )
        local addB = finalAttribute.cb and (finalAttribute.cb - oldAttribute.cb )
        local cr = oldAttribute.cr + addR * rate
        local cg = oldAttribute.cg + addG * rate
        local cb = oldAttribute.cb + addB * rate
        node:setColor(cc.c3b(cr, cg, cb))
    end
end

getNodeAttribute = function (node, curData)
    local data = {}
    if curData.x or curData["+x"] then 
        data.x = node:getPositionX()
    end 
    if curData.y or curData["+y"] then 
        data.y = node:getPositionY()
    end
    if curData.s or curData["+s"] then 
        data.s = node:getScale()
    end
    if curData.r or curData["+r"] then 
        data.r = node:getRotation()
    end 
    if curData.a or curData["+a"] then 
        data.a = node:getOpacity()
    end 
    if curData.d or curData["+d"] then 
        data.d = node:getRotation()*3.1415/180
    end
    if curData.sx or curData["+sx"] then 
        data.sx = node:getScaleX()
    end
    if curData.sy or curData["+sy"] then 
        data.sy = node:getScaleY()
    end
    if curData.cr then
        local color = node:getColor()
        data.cr = color.r
    end
    if curData.cg then
        local color = node:getColor()
        data.cg = color.g
    end
    if curData.cb then
        local color = node:getColor()
        data.cb = color.b
    end
    return data
end

parseTimeLineData = function ( str, node, eParam)
    local tempData = SoraDSplitString(str, "|")
    local lineData = {}
    for k,v in ipairs(tempData) do
        local result = {}
        local data = SoraDSplitString(v, ",")
        for _,str in ipairs(data) do 
            local pos = string.find(str, "=")
            local key = string.sub(str, 1, pos - 1)
            local value = string.sub(str, pos+1, string.len(str))
            if key == "curve" then
                value = value
            elseif key ~= "e" then 
                value = tonumber(value)
            else 
                value = eParam[value]
            end  
            result[key] = value
        end 
        table.insert(lineData,result)
    end 

    for k,v in ipairs(lineData) do 
        local key = k - 1
        if lineData[key] then
            v.time = v.t - lineData[key].t 
        else 
            v.time = v.t
        end
    end
    -- dump(lineData,"g_t.parseTimeLineData") 
    return lineData
end

return cocosContext

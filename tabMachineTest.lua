--author cs
--email 04nycs@gmail.com
--https://github.com/ThinEureka/tabMachine
--created on July 13, 2019 
--
local cocosTabMachine = require("app.common.tabMachine.cocosTabMachine")
local tabDebugger = require("app.common.tabMachine.tabDebugger")

local test = {}

function test.testTab(tabName)
    if g_tabMachine and g_tabMachine:isRunning() then
        g_tabMachine:stop()
        g_tabMachine = nil
    end

    g_tabMachine = cocosTabMachine.new()
    g_tabMachine:setDebugger(tabDebugger.new())
    g_tabMachine:installTab(test[tabName])
    g_tabMachine:start()
end

----------------------- tabs  -------------------------
test.empty = {
}

test.helloWorld = {
    s1 = function(c)
        print("hello world")
    end,
}

test.helloWorldEx = {
    s1 = function(c)
        c:call(test.tickPrint, "s1", nil, "Hello World Ex")
    end,
}

test.except1 = {
    s1 = function(c)
    end,

    s1_catch = function(c)
        print("catch s1")
        return true
    end,

    s2 = function(c)
        local a = 5
        -- throw a lua exception
        a = a + nil
    end,

    s2_catch = function(c, e)
        print("catch s2")
        return false
    end,

    s3 = function(c)
        c.v.m = 0
    end,

    s3_tick = function(c, dt)
        c.v.m = c.v.m + 1
        print("s3 ", 10 - c.v.m)
        if c.v.m >= 10 then
            --throw custom error
            c:throw("error s3")
        end
    end,

    s3_catch = function(c, e)
        if e.isCustom then
            --
            return false
        end
    end,

    catch = function(c, e)
        print("catch")
        if e.isCustom then
            c:stop("s3")
        end
        return true
    end
}

test.except2 = {
    s1 = function(c)
        c:call(c.t1, "t1")
        c:call(c.u1, "u1")
    end,

    s1_catch = function(c, e)
        print("final catch")
        --dump(e)
        c:stop("s1")
        return true
    end,

    t1 ={
        s1 = function(c)
            c:start("m1")
        end
    },

    --m1_update = function(c, dt)
    --end,

    u1 = {
        s1 = function(c)
            print("u1 start1")
            local a = nil
            -- throw a lua error
            local b = a + 1
            c.v.t = 0
        end,

        s1_update = function(c, dt)
            print("kkk")
        end,

        s1_catch = function(c, e)
            c:stop("s1")
            return true
        end,

        s2 = function(c)
            c.v.t = 0
        end,

        s2_tick = function(c, dt)
            print("s2 ", 5 - c.v.t)
            c.v.t = c.v.t + dt
            if c.v.t > 5 then
                local k = nil
                -- throw a lua error
                local x = k + 5
            end
        end,

        s2_catch = function(c, e)
            print("s2 catched but not receive")
            return false
        end,

        s3 = function(c)
            c.v.index = 0
        end,

        s3_tick = function(c, index)
            print("s3 ", 10 - c.v.index)
            c.v.index = c.v.index + 1
            if c.v.index > 10 then
                -- throw a custom error
                c:throw("error e3")
            end
        end,

        s3_catch = function(c)
            print("s3 catched")
            return false
        end,

        catch = function(c, e)
            print("u1 catched")
            c:stop("s2")
            return false
        end,
    },

    catch = function(c, e)
        if e.isCustom then
            c:stop()
        end
        return true
    end
}

test.updateOpt = {
    s1 = function(c)
        c:call(test.tickPrint, "t1", nil, "s1s1s1s1s1s1s1s1s1s1s1s1s1s1s1s1")
    end,

    u1 = {
        s1 = function(c)
            c:call(test.tickPrint, "t1", nil, "u1u1u1u1u1u1u1u1u1u1u1u1u1u1")
        end
    },

    m1 = {
        s1 = function(c)
            c:call(c.t1, "t1")
        end,

        t1 = {
            s1 = function(c)
                c:call(c.t1, "t1")
            end,

            t1 = {
                s1 = function(c)
                    c:call(c.t1, "t1")
                end,

                t1 = {
                    s1 = function(c)
                        c:call(test.tickPrint, "t1", nil, "m1m1m1m1m1m1m1m1m1m1m1m1m1m1")
                    end,
                },
            },
        },
    },

    event = function(c, msg)
        if msg == "s1" then
            c:start("s1")
        elseif msg == "u1" then
            c:call(c.u1, "u1")
        elseif msg == "m1" then
            c:call(c.m1, "m1")
        end
    end
}

test.notifyOpt = {
    s1 = function(c)
        c.v.t = 0
    end,

    s1_update = function (c, dt)
        c.v.t = c.v.t + dt
        if c.v.t > 5 then
            c:start("t1")
            c:stop("s1")
        end
    end,

    t1_event = function(c, msg)
        if msg == "s1" then
            c:start("s1")
            c:stop("t1")
        end
    end,
}

test.notify = {
    s1 = function(c)
        c:start("s3")
    end,

    s1_event = function(c, msg)
        print("s1 event ", msg)
        if msg == "end_s1" then
            return  false
        elseif msg == "end_s2" then
            c:stop("s2")
            return true
        elseif msg == "start_s2" then
            c:call(test.tickPrint, "s2", nil, "Hello world")
        end
        return false
    end,

    s3_event = function(c, msg)
        print("s3 event ", msg)
    end,

    event = function(c, msg)
        print("total event ", msg)
        if msg == "end" then
            c:stop()
            return true
        elseif msg == "end_s2" then
            print("receive end s2 not captured")
            return false
        end
        return false
    end,
}

test.join = {
    s1 = function(c)
        local isSameOrder = math.random(2) == 2
        
        if isSameOrder then
            c:call(test.tickPrint, "t1", nil, "Hello World")
            c:call(test.tickPrint, "m1", nil, "HaHaHaHaHa HaHaHa")
        else
            c:call(test.tickPrint, "t1", nil, "Hello World long long long long long long")
            c:call(test.tickPrint, "m1", nil, "HaHaHaHaHa HaHaHa")
        end
        c:join({"t1", "m1"}, "k1")
    end,

    k2 = function(c)
        print("t1 m1 joined")
    end,
}

test.lifetime = {
    s1 = function(c)
        c._nickName = "lifetime"
        c:call(g_t.delay, "s2", nil, 1)
    end,

    s3 = function(c)
        local tabs = {{}, g_t.bind(test.tickPrint, "hello"), g_t.bind(test.tickPrint, "world")}
        for index, tab in ipairs(tabs) do
            c:call(tab, "kk"..index)
        end
    end,
}

test.final = {
    s1 = function(c)
        c:start("t1")
        c:start("u1")
        c:call(c.m1, "m1")
    end,

    t1_update = function(c, dt)
        if c.v.a == nil then
            c.v.a = 0
        end

        c.v.a = c.v.a + dt
        if c.v.a > 1 then
            c.v.a = c.v.a - 1
            print("tick")
        end
    end,

    t1_final = function(c)
        print("t1 final")
    end,

    u1 = function(c)
        print("u1")
    end,

    u1_final = function(c)
        print("u1 final")
    end,

    m1 = {
        s1 = function(c)
            print("mmmm")
            c:call(g_t.delay, "d1", nil, 3)
        end,

        s1_final = function(c)
            print("m1.s1 final")
        end,

        final = function(c)
            print("m1 final")
        end,
    },

    final = function(c)
        print("final")
    end,
}

test.inputs = {
    s1 = function(c)
        c:call(test.tickPrint, "s1", nil, "Hello World again")
    end,
}

test.outputs = {
    s1 = function(c)
        c:call(test.tickPrint, "s2", {"o1", "o2", "o3"}, "Hello World again")
    end,

    s3 = function(c)
        print("o1 ", c.v.o1)
        print("o2 ", c.v.o2)
        print("o3 ", c.v.o3)
    end,
}

test.tick = {
    s1 = function(c)
        c:call(test.countDown, "t1", nil, 15, "tick")
    end,
}

test.tickPrint = {
    s1 = function(c, word)
        c.v.word = word
        c.v.index = 0
    end,

    -- s1_update = function(c, dt)
    --     c.v.t = c.v.t + dt
    --     if c.v.t >= 1 then
    --         c.v.t = c.v.t - 1
    --         c.v.index = c.v.index + 1

    --         if c.v.index <= c.v.word:len() then
    --             local subWord = c.v.word:sub(1, c.v.index)
    --             print(subWord)
    --         else
    --             c:output("o1-value", "o2-value")
    --             c:stop()
    --         end
    --     end

    -- end,

    s1_tick = function(c, index)
        c.v.index = c.v.index + 1
        if c.v.index <= c.v.word:len() then
            local subWord = c.v.word:sub(1, c.v.index)
            print(subWord)
        else
            c:output("o1-value", "o2-value")
            c:stop()
        end
    end,
}

test.tabWhile = {
    s1 = function(c)
        c.v.N = 0
        local function condition() 
            return c.v.N < 10
        end
        local loop = {
            s1 = function(c1)
                local word = "["
                for i = 1, c.v.N do
                    word = word .. tostring(c.v.N)
                end
                word = word .. "]"
                c1:call(test.tickPrint, "s2", nil, word)
            end,
            s3 = function(c1)
                -- note that we modify the local value of c indead of c1
                c.v.N = c.v.N + 1
            end,
        }
        c:call(g_t.tabWhile(condition, loop), "s2")
    end,
}

test.tabDoWhile = {
     s1 = function(c)
        c.v.N = 0
        local function condition() 
            return c.v.N < 10
        end
        local loop = {
            s1 = function(c1)
                local word = "["
                for i = 1, c.v.N do
                    word = word .. tostring(c.v.N)
                end
                word = word .. "]"
                c1:call(test.tickPrint, "s2", nil, word)
            end,
            s3 = function(c1)
                -- note that we modify the local value of c indead of c1
                c.v.N = c.v.N + 1
            end,
        }
        c:call(g_t.tabDoWhile(loop, condition), "s2")
    end,
}

test.tabForIndex = {
    s1 = function(c)
        local loop = {
            s1 = function(c1, index)
                local word = "["
                for i = 1, index do
                    word = word .. tostring(index)
                end
                word = word .. "]"
                c1:call(test.tickPrint, "s2", nil, word)
            end,
        }
        c:call(g_t.tabForIndex(1, 9, loop, "s2"))
    end,
}

test.tabForIpairs = {
    s1 = function(c)
        local array = {}
        for i = 1, 9 do
            table.insert(array, i)
        end

        local loop = {
            s1 = function(c1, index, v)
                local word = "["
                for i = 1, index do
                    word = word .. tostring(v)
                end
                word = word .. "]"
                c1:call(test.tickPrint, "s2", nil, word)
            end,
        }
        c:call(g_t.tabForIpairs(array, loop , "s2"))
    end,
}

test.tabForPairs = {
    s1 = function(c)
        local map = {abc = "99", [2] = "mmmmm"}
        map.kk = 9
        map.gg = "This is innevetable"
        local loop = {
            s1 = function(c1, k, v)
                local word = "[" .. k .. "-" .. v .. "]"
                c1:call(test.tickPrint, "s2", nil, word)
            end,
        }
        c:call(g_t.tabForPairs(map, loop, "s2"))
    end,
}

test.tabBreak = {
    s1 = function(c)
        c.v.N = 0
        local function condition() 
            return c.v.N < 10
        end
        local loop = {
            s1 = function(c1)
                local word = "["
                for i = 1, c.v.N do
                    word = word .. tostring(c.v.N)
                end
                word = word .. "]"
                if c.v.N == 4 then
                    print("break")
                    c1:break_()
                    return
                end
                c1:call(test.tickPrint, "s2", nil, word)
            end,
            s3 = function(c1)
                -- note that we modify the local value of c indead of c1
                c.v.N = c.v.N + 1
            end,
        }
        c:call(g_t.tabWhile(condition, loop), "s2")
    end,

     s3 = function(c)
        c.v.N = 0
        local function condition() 
            return c.v.N < 10
        end
        local loop = {
            s1 = function(c1)
                local word = "["
                for i = 1, c.v.N do
                    word = word .. tostring(c.v.N)
                end
                word = word .. "]"
                if c.v.N == 5 then
                    print("break")
                    c1:break_()
                    return
                end
                c1:call(test.tickPrint, "s2", nil, word)
            end,
            s3 = function(c1)
                -- note that we modify the local value of c indead of c1
                c.v.N = c.v.N + 1
            end,
        }
        c:call(g_t.tabDoWhile(loop, condition), "s4")
    end,

    s5 = function(c)
        local loop = {
            s1 = function(c1, index)
                local word = "["
                for i = 1, index do
                    word = word .. tostring(index)
                end
                word = word .. "]"
                if index == 4 then
                    print("break")
                    c1:break_()
                    return
                end
                c1:call(test.tickPrint, "s2", nil, word)
            end,
        }
        c:call(g_t.tabForIndex(1, 9, loop), "s6")
    end,

    s7 = function(c)
        local array = {}
        for i = 1, 9 do
            table.insert(array, i)
        end

        local loop = {
            s1 = function(c1, index, v)
                local word = "["
                for i = 1, index do
                    word = word .. tostring(v)
                end
                word = word .. "]"
                if index == 4 then
                    print("break")
                    c1:break_()
                    return
                end
                c1:call(test.tickPrint, "s2", nil, word)
            end,
        }
        c:call(g_t.tabForIpairs(array, loop), "s8")
    end,

    s9 = function(c)
        local map = {abc = "99", [2] = "mmmmm"}
        map.kk = 9
        map.gg = "This is innevetable"
        local loop = {
            s1 = function(c1, k, v)
                local word = "[" .. k .. "-" .. v .. "]"
                if k == "kk" then
                    print("break")
                    c1:break_()
                    return
                end
                c1:call(test.tickPrint, "s2", nil, word)
            end,
        }
        c:call(g_t.tabForPairs(map, loop), "s10")
    end,
}


test.countDown = {
    s1 = function(c, num, tag)
        c.v.num = num
        c.v.tag = tag and tag or "countDown"
    end,
    
    s1_tick = function(c, index)
        print(c.v.tag .. ":" .. c.v.num, " ", index)
        c.v.num = c.v.num - 1
        if c.v.num <= 0 then
            c:stop()
        end
    end,
}


test.all = {
    s1 = function(c)
        c:call(g_t.delay, "t0", nil, 10)
    end,

    t1 = function(c)
        print("hello world")
    end,

    t2 = function (c)  
        c.v.a = 0
        c.v.t = 0
        print("test next call")
    end,

    t2_update = function(c, dt)
        c.v.a = c.v.a + dt
        if c.v.a > 1 then
            c.v.t = c.v.t + 1
            c.v.a = c.v.a - 1
            print("tick ", c.v.t)
        end

        if c.v.t >= 5 and not c:hasSub("m1") then
            if c.v.m == nil then
                c.v.m = 0
            end
            c.v.m = c.v.m + 1
            c:call(c.m1, "m1")
        end

        if c.v.t >= 100 then
            c:stop("t2")
        end
    end,

    t3 = function(c)
        print("t3")
    end,

    m1 = {
        s1 = function(c)
            c.v.word = "Hello World"
            c.v.index = 0
            c.v.t = 0
        end,

        s1_update = function(c, dt)
            c.v.t = c.v.t + dt
            if c.v.t > 1 then
                c.v.t = c.v.t - 1
                c.v.index = c.v.index + 1
                if c.v.index <= c.v.word:len() then
                    print(c.v.word:sub(1, c.v.index))
                else
                    c:stop()
                end
            end
        end
    },

    m2 = function(c)
        if c.v.m >= 5 then
            c:stop()
        end
    end,
}

test.call_all = {
    s1 = function(c)
        print("hello")
        c:call(test.all, "s2")
        c:call(test.all, "s4")
    end,

    s3 = function(c)
        print("s3 call all return")
    end,

    s5 = function(c) 
        print("s5 call all return")
    end
}

test.extTrigger = {
    s1 = function(c)
        c:call(c.t1, "t1")
    end,

    t1 = {
        s1 = function(c)
            c:call(c.m1, "m1")
        end,

        m1 = {
            s1 = function(c)
                print("inner s1")
                g_head = c
            end,

            s1_event = function(c)
            end,
        },
    },

    t2 = function(c)
        c:start("s1")
    end
}

return test

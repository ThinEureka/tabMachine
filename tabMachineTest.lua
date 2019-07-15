
--author cs
--email 04nycs@gmail.com
--created on July 13, 2019 
--

local test = {}

function test.testTab(tabName)
    if g_tabMachine and g_tabMachine:isRunning() then
        g_tabMachine:stop()
        g_tabMachine = nil
    end

    g_tabMachine = require("app.common.tabMachine.cocosTabMachine").new()
    g_tabMachine:installTab(test[tabName])
    g_tabMachine:start()
    g_tabMachine:startUpdate(true)
end

----------------------- tabs  -------------------------

test.hello = {
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

test.final = {
    s1 = function(c)
        c:start("t1")
        c:start("u1")
        c:call("m1", "m1")
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
            c:call("::delay", "d1", nil, 3)
        end,

        s1_final = function(c)
            print("m1.s1 final")
        end,

        final = function(c)
            print("m1 final")
        end,
    },

    m1_final = function(c)
        print("m1 ex final")
    end,
}

test.inputs = {
    s1 = function(c)
        c:call(test.tickPrint, "s1", nil, "Hello World again")
    end,
}

test.outputs = {
    s1 = function(c)
        c:call(test.tickPrint, "s1", {"o1", "o2"}, "Hello World again")
    end,

    s2 = function(c)
        print("o1 ", c.v.o1)
        print("o2 ", c.v.o2)
    end,
}

test.tick = {
    s1_update = function(c, dt)
        if c.v.a == nil then
            c.v.a = 0
        end

        c.v.a = c.v.a + dt
        if c.v.a > 1 then
            c.v.a = c.v.a - 1
            print("tick")
        end
    end,
}

test.tickPrint = {
    s1 = function(c, word)
        c.v.word = word
        c.v.t = 0
        c.v.index = 0
    end,

    s1_update = function(c, dt)
        c.v.t = c.v.t + dt
        if c.v.t >= 1 then
            c.v.t = c.v.t - 1
            c.v.index = c.v.index + 1

            if c.v.index <= c.v.word:len() then
                local subWord = c.v.word:sub(1, c.v.index)
                print(subWord)
            else
                c:output("o1-value", "o2-value")
                c:stop()
            end
        end

    end,
}

test.all = {
    s1 = function(c)
        c:call("::delay", "t0", nil, 10)
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
            c:call("m1", "m1")
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

return test

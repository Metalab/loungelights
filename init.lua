wifi.setmode(wifi.STATION)
gpio.mode(1,gpio.OUTPUT)
gpio.mode(2,gpio.OUTPUT)
gpio.mode(0,gpio.OUTPUT)
gpio.mode(8,gpio.OUTPUT)
spi.setup(1, spi.MASTER, spi.CPOL_LOW, spi.CPHA_LOW, spi.DATABITS_8, 0)

wifi.sta.config("metalab", "")
wifi.sta.connect()
tmr.alarm(0, 1000, 1, function()
    if wifi.sta.status() == 5 then
        startMqttClient()
        tmr.stop(0)
    else
        print("Connect AP, Waiting...")
    end
end)

function startMqttClient()
    currentLights = {100,200,50,100,255}
    m = mqtt.Client("lights", 120, "lichter", "password")
    m:on("connect", function(con) print ("connected") end)
    m:on("offline", function(con) print ("offline") end)
    m:on("message", function(conn, topic, data)
        print(topic .. ":" )
            if data ~= nil then print(data)
                currentLights = parseData(data,currentLights)

                if currentLights[1] == 0 then
                    gpio.write(2,gpio.HIGH)
                end
                if currentLights[2] == 0 then
                    gpio.write(8,gpio.HIGH)
                end
                if currentLights[1] > 0 then
                    gpio.write(1,gpio.HIGH)
                end
                
                if currentLights[2] > 0 then
                    gpio.write(0,gpio.HIGH)
                end

                pwm.setup(4,1000,currentLights[1]*4+3)
                pwm.setup(6,1000,currentLights[2]*4+3)
                pwm.start(4)
                pwm.start(6)
                spi.send(1,{currentLights[3],currentLights[4],currentLights[5]})
            end 
    end)

    -- IP-Adress of Mqtt Server (probably the IP-Adress of Slackomatic)
    -- You must send a message to /lights (or whatever other name you chose for the channel) to control the lights.
    -- The default port is 1883. 
    -- The expected format is explained below.
    m:connect("10.20.30.186", 1883, 0, function(conn) 
        print("connected")
        m:subscribe("/lights",0, function(conn) print("subscribe success") end)
        m:publish("/lights","Lights ready. Read the comments in the Lua-Code if you don't know what to do.",0,0, function(conn) print("sent") end)
    end)
end


-- The expected string format is: w,a,r,g,b where w = white, a = amber, r = red, g = green, b = blue.
-- If left out variable remains at current value.
-- Example: 123,,,255, means: white = 123, a,r and b are left unchanged and g = 255 = max.
-- Which exact characters are used for separation doesn't matter. 123,,,255, is to interpreted the same as as 123:::255: for instance.
-- Values are to in [0,255]. Larger Values will be assumed to be 255 = max. 
-- A way to send "delta" values that define a new color by adding an offset to the current color should be implemented BY YOU,
-- because frankly, I don't give a damn. It might be a practical way to implement the red alert or some other annoying shit.
-- "Deltas" (i.e. "offsets") are recognized by the sign (+ or -) at their beginning. 
-- Example: 100,+3,,-4,0     means: w = 100, a = a+3, r unchanged, g = g-4, b = 0.

function parseData(data,current)
    leng = string.len(data)
    color = 1
    num = ""
    vals = {}
    for i = 1, leng, 1 do
        if color > 5 then
            break
        end
        ch = string.sub(data,i,i)
        if tonumber(ch) ~= nil then
            num = num..ch
        else
            if num == "" then
                vals[color] = current[color]
                color = color + 1
            else
                number = tonumber(num)
                if number > 255 then
                    number = 255
                end
                vals[color] = number 
                num = ""
                color = color + 1
            end 
        end
    end
    if num ~= "" then
      number = tonumber(num)
      if number > 255 then
        number = 255
      end
    else
      number = nil
    end
    vals[5] = number 
    return vals
end

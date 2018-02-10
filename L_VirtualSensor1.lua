-- -----------------------------------------------------------------------------
-- L_VirtualSensor.lua
-- Copyright 2017,2018 Patrick H. Rigney, All Rights Reserved
-- http://www.toggledbits.com/projects
-- This file is available under GPL 3.0. See LICENSE in documentation for info.
-- -----------------------------------------------------------------------------

if luup == nil then luup = {} end -- for lint/check

module("L_VirtualSensor1", package.seeall)

local _PLUGIN_NAME = "VirtualSensor"
local _PLUGIN_VERSION = "1.0"
local _PLUGIN_URL = "http://www.toggledbits.com/projects"
local _CONFIGVERSION = 010000

local debugMode = true
local traceMode = false

local MYSID = "urn:toggledbits-com:serviceId:VirtualSensor1"
local MYTYPE = "urn:schemas-toggledbits-com:device:VirtualSensor:1"

local runStamp = 0
local isALTUI = false
local isOpenLuup = false

--[[ const ]] local tau = 6.28318531

--[[   D E B U G   F U N C T I O N S   ]]

local function dump(t)
    if t == nil then return "nil" end
    local k,v,str,val
    local sep = ""
    local str = "{ "
    for k,v in pairs(t) do
        if type(v) == "table" then
            val = dump(v)
        elseif type(v) == "function" then
            val = "(function)"
        elseif type(v) == "string" then
            val = string.format("%q", v)
        elseif type(v) == "number" then
            local d = v - os.time()
            if d < 0 then d = -d end
            if d <= 86400 then
                val = string.format("%d (%s)", v, os.date("%X", v))
            else
                val = tostring(v)
            end
        else
            val = tostring(v)
        end
        str = str .. sep .. k .. "=" .. val
        sep = ", "
    end
    str = str .. " }"
    return str
end

local function L(msg, ...)
    local str
    if type(msg) == "table" then
        str = msg["prefix"] .. msg["msg"]
    else
        str = _PLUGIN_NAME .. ": " .. msg
    end
    str = string.gsub(str, "%%(%d+)", function( n )
            n = tonumber(n, 10)
            if n < 1 or n > #arg then return "nil" end
            local val = arg[n]
            if type(val) == "table" then
                return dump(val)
            elseif type(val) == "string" then
                return string.format("%q", val)
            elseif type(val) == "number" then
                local d = val - os.time()
                if d < 0 then d = -d end
                if d <= 86400 then
                    val = string.format("%d (time %s)", val, os.date("%X", val))
                end
            end
            return tostring(val)
        end
    )
    luup.log(str)
    -- if traceMode then trace('log',str) end
end

local function D(msg, ...)
    if debugMode then
        L({msg=msg,prefix=_PLUGIN_NAME.."(debug)::"}, ... )
    end
end

--[[   U T I L I T Y   F U N C T I O N S   ]]

-- Get numeric variable, or return default value if not set or blank
local function getVarNumeric( name, dflt, dev, serviceId )
    assert((name or "") ~= "") -- cannot be blank or nil
    assert(dev ~= nil) -- alternately we could supply luup.device, but that doesn't work consistently in openLuup
    if serviceId == nil then serviceId = MYSID end
    local s = luup.variable_get(serviceId, name, dev) or ""
    if s == "" then return dflt end
    s = tonumber(s, 10)
    if (s == nil) then return dflt end
    return s
end

-- Take a string and split it around sep, returning table (indexed) of substrings
-- For example abc,def,ghi becomes t[1]=abc, t[2]=def, t[3]=ghi
-- Returns: table of values, count of values (integer ge 0)
local function split(s, sep)
    local t = {}
    local n = 0
    if s == nil or s == "" then return t,n end -- empty string returns nothing
    local i,j
    local k = 1
    repeat
        i, j = string.find(s, sep or "%s*,%s*", k)
        if (i == nil) then
            table.insert(t, string.sub(s, k, -1))
            n = n + 1
            break
        else
            table.insert(t, string.sub(s, k, i-1))
            n = n + 1
            k = j + 1
        end
    until k > string.len(s)
    return t, n
end

-- Constraint the argument to the specified min/max
local function constrain( n, nMin, nMax )
    if nMin ~= nil and n < nMin then return nMin end
    if nMax ~= nil and n > nMax then return nMax end
    return n
end

-- Lua has no ternary op, so fake one
local function iif( b, t, f )
    if b then return t end
    return f
end

--[[   A C T I O N   H A N D L E R S   ]]

function actionSetArmed( dev, newArmed )
    D("actionSetArmed(%1,%2)", dev, newArmed)
    newArmed = tonumber(newArmed,10) or 0
    if newArmed ~= 0 then newArmed = 1 end
    luup.variable_set( "urn:micasaverde-com:serviceId:SecuritySensor1", "Armed", newArmed, dev )
end

--[[   P L U G I N   C O R E   F U N C T I O N S   ]]

-- Check current firmware for compatibility (called at startup by plugin_init)
local function plugin_checkVersion(dev)
    assert(dev ~= nil)
    D("checkVersion() branch %1 major %2 minor %3, string %4, openLuup %5", luup.version_branch, luup.version_major, luup.version_minor, luup.version, isOpenLuup)
    if isOpenLuup or ( luup.version_branch == 1 and luup.version_major >= 7 ) then
        local v = luup.variable_get( MYSID, "UI7Check", dev )
        if v == nil then luup.variable_set( MYSID, "UI7Check", "true", dev ) end
        return true
    end
    return false
end

--[[ Check for and do one-time initializations. Called at startup by plugin_init.
     Uses the Version state variable to determine if the plugin has run before.
     If not, sets up default state values, store configuration version, and returns.
     If configuration version is lower than current value of _CONFIGVERSION, then
     can attempt to upgrade config. ]]
local function plugin_runOnce(dev)
    assert(dev ~= nil)
    local rev = getVarNumeric( "Version", 0, dev, MYSID )
    if (rev == 0) then
        -- Initialize for entirely new instance
        D("runOnce() Performing first-time initialization!")
        luup.variable_set( MYSID, "Interval", 5, dev )
        luup.variable_set( MYSID, "Period", 120, dev )
        luup.variable_set( MYSID, "Amplitude", 1, dev )
        luup.variable_set( MYSID, "Midline", 0, dev )
        luup.variable_set( MYSID, "DutyCycle", 50, dev )
        luup.variable_set( MYSID, "Precision", 2, dev )
        luup.variable_set( MYSID, "NextX", 0, dev )
        
        luup.variable_set( "urn:upnp-org:serviceId:TemperatureSensor1", "CurrentTemperature", "", dev )
        luup.variable_set( "urn:micasaverde-com:serviceId:SecuritySensor1", "Armed", 0, dev )
        luup.variable_set( "urn:micasaverde-com:serviceId:SecuritySensor1", "Tripped", 0, dev )
        luup.variable_set( "urn:micasaverde-com:serviceId:SecuritySensor1", "ArmedTripped", 0, dev )
        luup.variable_set( "urn:micasaverde-com:serviceId:GenericSensor1", "CurrentLevel", "", dev )
        luup.variable_set( "urn:micasaverde-com:serviceId:HumiditySensor1", "CurrentLevel", "", dev )
        luup.variable_set( "urn:micasaverde-com:serviceId:LightSensor1", "CurrentLevel", "", dev )

        luup.variable_set( "urn:micasaverde-com:serviceId:HaDevice1", "ModeSetting", "1:;2:;3:;4:", dev )
        
        luup.variable_set( MYSID, "Version", _CONFIGVERSION, dev )
        return -- this branch must return
    end

--[[ Future config revisions should compare the current revision number and apply
     changes incrementally. The code below is an example of how to handle. As versions
     change, do not remove the prior version updates, just add incremental updates from
     version to version. This assures that any version will be upgradeable in future
     (because old backups get restored, etc.)

    if rev < 010100 then
        D("runOnce() updating config for rev 010100")
        -- Future. This code fragment is provided to demonstrate method.
        -- Insert statements necessary to upgrade configuration for version number indicated in conditional.
        -- Go one version at a time (that is, one condition block for each version number change).
    end
--]]

    -- No matter what happens above, if our versions don't match, force that here/now.
    if (rev ~= _CONFIGVERSION) then
        luup.variable_set(MYSID, "Version", _CONFIGVERSION, dev)
    end
end

--[[ Helper function to schedule next timer tick. Can be called by any function
     as needed. If timing is changed and a tick needs to happen at a different time
     from a currently scheduled call_delay, simply change (e.g. increment) the runStamp
     global and pass it to this function. The previously-set delay function will still fire,
     but will see that the stamp has changed and exit without do any work. The new callback
     will happen as scheduled. Any data that needs to be passed to your delay callback
     can be passed in the "passthru" string. ]]
local function plugin_scheduleTick( dly, newStamp, dev, passthru )
    dly = tonumber( dly, 10 )
    assert(dly ~= nil)
    assert(dev ~= nil)
    assert(passthru == nil or type(passthru) == "string")
    dly = constrain( dly, 1, 7200 )
    luup.call_delay( "virtualSensorTick", dly, table.concat( { newStamp, dev, passthru or "" }, ":" ) )
end

--[[ Timer tick function. This function is intended to be the callback for luup.call_delay.
     It should be schedule (only) using plugin_scheduleTick() above. Luup passes a single
     argument through call_delay, so these two functions work together to make sure that
     enough context plus whatever additional data you want is passed through. ]]
function plugin_tick(targ)
    local pdev, stepStamp, passthru
    stepStamp,pdev,passthru = string.match( targ, "(%d+):(%d+):(.*)" )
    D("plugin_tick(%1) stepStamp %2, pdev %3, passthru %4", targ, stepStamp, pdev, passthru)
    pdev = tonumber( pdev, 10 )
    assert( pdev ~= nil and luup.devices[pdev] )
    stepStamp = tonumber( stepStamp, 10 )
    if stepStamp ~= runStamp then
        D("plugin_tick() got stepStamp %1, expected %2, another thread running, so exiting...", stepStamp, runStamp)
        return
    end

    -- Do the plugin work
    local nextX = getVarNumeric( "NextX", 0, pdev, MYSID )
    local per = getVarNumeric( "Period", 300, pdev, MYSID )
    local freq = getVarNumeric( "Interval", 5, pdev, MYSID )
    local mid = getVarNumeric( "Midline", 0, pdev, MYSID )
    local amp = getVarNumeric( "Amplitude", 1, pdev, MYSID )
    
    -- Make sure X is in range (can be out if period changes in settings), and 
    -- compute new sensor value.
    nextX = nextX % per
    local currVal = math.sin( nextX / per * tau ) * amp + mid

    -- Now that we have our value, format it to requested precision
    local prec = getVarNumeric( "Precision", 2, pdev, MYSID )
    local sprec
    if prec == 0 then
        sprec = math.floor( currVal + 0.5 )
    else
        sprec = string.format("%." .. prec .. "f", currVal)
    end
    
    -- For binary sensor, consider the duty cycle
    local duty = getVarNumeric( "DutyCycle", 50, pdev, MYSID )
    local flag = iif( nextX < ( per * duty / 100), 1, 0 )

    -- Set this in a variety of ways
    luup.variable_set( "urn:upnp-org:serviceId:TemperatureSensor1", "CurrentTemperature", sprec, pdev )
    luup.variable_set( "urn:micasaverde-com:serviceId:GenericSensor1", "CurrentLevel", sprec, pdev )
    luup.variable_set( "urn:micasaverde-com:serviceId:HumiditySensor1", "CurrentLevel", sprec, pdev )
    luup.variable_set( "urn:micasaverde-com:serviceId:LightSensor1", "CurrentLevel", sprec, pdev )
    luup.variable_set( "urn:micasaverde-com:serviceId:SecuritySensor1", "Tripped", flag, pdev )
    if getVarNumeric( "Armed", 0, pdev, "urn:micasaverde-com:serviceId:SecuritySensor1" ) ~= 0 then
        -- Armed, ArmedTripped follows Tripped
        luup.variable_set( "urn:micasaverde-com:serviceId:SecuritySensor1", "ArmedTripped", flag, pdev )
    else
        -- Not armed, ArmedTripped always 0
        luup.variable_set( "urn:micasaverde-com:serviceId:SecuritySensor1", "ArmedTripped", 0, pdev )
    end
    
    -- Figure out the next step
    nextX = nextX + freq
    if nextX >= per then nextX = nextX - per end -- limit range to 0..per
    luup.variable_set( MYSID, "NextX", nextX, pdev )

    -- Schedule out next tick. Notice we pass through what we got.    
    plugin_scheduleTick( freq, stepStamp, pdev, passthru )
end

--[[ Start-up initialization for plug-in. This is called by the startup function
     in the implementation file. The bulk of the work should be done here, because,
     well, writing Lua inside an XML file is insanity, or a path to it. ]]
function plugin_init(dev)
    D("plugin_init(%1)", dev)
    L("starting version %1 for device %2", _PLUGIN_VERSION, dev )

    -- Check for ALTUI and OpenLuup. ??? need quicker, cleaner check
    local k,v
    for k,v in pairs(luup.devices) do
        if v.device_type == "urn:schemas-upnp-org:device:altui:1" then
            local rc,rs,jj,ra
            D("init() detected ALTUI at %1", k)
            isALTUI = true
--[[
            rc,rs,jj,ra = luup.call_action("urn:upnp-org:serviceId:altui1", "RegisterPlugin",
                { newDeviceType=MYTYPE, newScriptFile="J_VirtualSensor1_ALTUI.js", newDeviceDrawFunc="VirtualSensor_ALTUI.DeviceDraw" },
                k )
            D("init() ALTUI's RegisterPlugin action returned resultCode=%1, resultString=%2, job=%3, returnArguments=%4", rc,rs,jj,ra)
]]
        elseif v.device_type == "openLuup" then
            D("init() detected openLuup")
            isOpenLuup = true
        end
    end

    -- Make sure we're in the right environment
    if not plugin_checkVersion(dev) then
        L("This plugin does not run on this firmware!")
        luup.set_failure( 1, dev )
        return false, "Unsupported system firmware", _PLUGIN_NAME
    end

    -- See if we need any one-time inits
    plugin_runOnce(dev)

    -- Other inits here
    runStamp = os.time() -- any value we set is fine, really.
    
    -- Schedule our first tick.
    plugin_scheduleTick( 1, runStamp, dev )

    -- Mark success.
    L("Running!")
    luup.set_failure( 0, dev )
    return true, "OK", _PLUGIN_NAME
end

function plugin_getVersion()
    return _PLUGIN_VERSION, _PLUGIN_NAME, _CONFIGVERSION
end

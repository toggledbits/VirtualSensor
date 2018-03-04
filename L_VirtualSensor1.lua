-- -----------------------------------------------------------------------------
-- L_VirtualSensor.lua
-- Copyright 2017,2018 Patrick H. Rigney, All Rights Reserved
-- http://www.toggledbits.com/projects
-- This file is available under GPL 3.0. See LICENSE in documentation for info.
-- -----------------------------------------------------------------------------

module("L_VirtualSensor1", package.seeall)

local _PLUGIN_NAME = "VirtualSensor"
local _PLUGIN_VERSION = "1.2"
local _PLUGIN_URL = "http://www.toggledbits.com/projects"
local _CONFIGVERSION = 010100

local debugMode = false

local MYSID = "urn:toggledbits-com:serviceId:VirtualSensor1"
local MYTYPE = "urn:schemas-toggledbits-com:device:VirtualSensor:1"

local SECURITYSID = "urn:micasaverde-com:serviceId:SecuritySensor1"
local HADEVICESID = "urn:micasaverde-com:serviceId:HaDevice1"

local runStamp = 0
local isALTUI = false
local isOpenLuup = false

--[[ const ]] local tau = 6.28318531 -- tau > pi

--[[   D E B U G   F U N C T I O N S   ]]

local function dump(t)
    if t == nil then return "nil" end
    local sep = ""
    local str = "{ "
    for k,v in pairs(t) do
        local val
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
    local level = 50
    if type(msg) == "table" then
        str = tostring(msg.prefix or _PLUGIN_NAME) .. ": " .. tostring(msg.msg)
        level = msg.level or level
    else
        str = _PLUGIN_NAME .. ": " .. tostring(msg)
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
    luup.log(str, level)
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

-- Set or reset the current tripped state
local function trip( flag, pdev )
    D("trip(%1,%2)", flag, pdev)
    local val = iif( flag, 1, 0 )
    local currTrip = getVarNumeric( "Tripped", 0, pdev, SECURITYSID )
    if currTrip ~= val then
        luup.variable_set( SECURITYSID, "Tripped", val, pdev )
        -- We don't need to worry about LastTrip or ArmedTripped, as Luup manages them
    end
    --[[ TripInhibit is our copy of Tripped, because Luup will change Tripped
         behind our back when AutoUntrip > 0--it will reset Tripped after
         that many seconds, but then we would turn around and set it again.
         We don't want to do that until Tripped resets because WE want
         it reset, so we use TripInhibit to lock ourselves out until then. --]]
    luup.variable_set( MYSID, "TripInhibit", val, pdev )
end

--[[   A C T I O N   H A N D L E R S   ]]

function actionSetArmed( dev, newArmed )
    D("actionSetArmed(%1,%2)", dev, newArmed)
    newArmed = tonumber(newArmed,10) or 0
    if newArmed ~= 0 then newArmed = 1 end
    luup.variable_set( SECURITYSID, "Armed", newArmed, dev )
end

function actionTrip( dev )
    D("actionTrip(%1)", dev)
    trip( true, dev );
end

function actionReset( dev )
    D("actionReset(%1)", dev)
    trip( false, dev );
end

function actionResetBattery( dev )
    D("actionResetBattery(%1)", dev)
    if getVarNumeric( "BatteryEmulation", 0, dev, MYSID ) > 0 then
        luup.variable_set( MYSID, "BatteryBase", os.time(), dev )
        luup.variable_set( HADEVICESID, "BatteryLevel", 100, dev )
        luup.variable_set( HADEVICESID, "BatteryDate", os.time(), dev )
    end
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
        luup.variable_set( MYSID, "BaseTime", os.time(), dev )
        luup.variable_set( MYSID, "NextX", 0, dev )
        luup.variable_set( MYSID, "Continuity", 1, dev )
        luup.variable_set( MYSID, "BatteryEmulation", 0, dev )
        luup.variable_set( MYSID, "BatteryReset", 0, dev )
        
        luup.variable_set( "urn:upnp-org:serviceId:TemperatureSensor1", "CurrentTemperature", "", dev )
        luup.variable_set( SECURITYSID, "Armed", 0, dev )
        luup.variable_set( SECURITYSID, "Tripped", 0, dev )
        luup.variable_set( SECURITYSID, "ArmedTripped", 0, dev )
        luup.variable_set( SECURITYSID, "LastTrip", os.time(), dev )
        luup.variable_set( SECURITYSID, "AutoUntrip", 0, dev )
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
--]]
    if rev < 010100 then
        D("runOnce() updating config for rev 010100")
        luup.variable_set( MYSID, "Enabled", 1, dev )
        luup.variable_set( MYSID, "BaseTime", os.time(), dev )
        luup.variable_set( MYSID, "Continuity", 1, dev )
        luup.variable_set( MYSID, "BatteryEmulation", 0, dev )
        luup.variable_set( MYSID, "BatteryReset", 0, dev )
        luup.variable_set( SECURITYSID, "LastTrip", 0, dev )
        luup.variable_set( SECURITYSID, "AutoUntrip", 0, dev )
    end

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
    dly = constrain( dly, 1, nil )
    luup.call_delay( "virtualSensorTick", dly, table.concat( { newStamp, dev, passthru or "" }, ":" ) )
end

--[[ Timer tick function. This function is intended to be the callback for luup.call_delay.
     It should be schedule (only) using plugin_scheduleTick() above. Luup passes a single
     argument through call_delay, so these two functions work together to make sure that
     enough context plus whatever additional data you want is passed through. ]]
function plugin_tick( targ )
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
    if getVarNumeric( "Enabled", 1, pdev, MYSID ) == 0 then
        D("plugin_tick() disabled, stopping")
        return
    end
    
    local now = os.time()
    local baseX = getVarNumeric( "BaseTime", 0, pdev, MYSID )
    if baseX == 0 then
        baseX = now
        luup.variable_set( MYSID, "BaseTime", baseX, pdev )
    end
    local per = constrain( getVarNumeric( "Period", 300, pdev, MYSID ), 1, nil ) -- no upper bound
    local freq = constrain( getVarNumeric( "Interval", 5, pdev, MYSID ), 1, per )
    local nextDelay = freq -- a reasonable default that we may shorten

    -- Make sure X is in range (can be out if period changes in settings), and 
    -- compute new sensor value.
    local nextX = ( now - baseX ) % per
    luup.variable_set( MYSID, "NextX", nextX, pdev )

    local mid = getVarNumeric( "Midline", 0, pdev, MYSID )
    local amp = getVarNumeric( "Amplitude", 1, pdev, MYSID )
    local currVal = math.sin( nextX / per * tau ) * amp + mid    
    
    -- Now that we have our value, format it to requested precision
    local prec = getVarNumeric( "Precision", 2, pdev, MYSID )
    local sprec
    if prec == 0 then
        sprec = math.floor( currVal + 0.5 )
    else
        sprec = string.format("%." .. prec .. "f", currVal)
    end
    
    -- Set this in a variety of ways
    luup.variable_set( "urn:upnp-org:serviceId:TemperatureSensor1", "CurrentTemperature", sprec, pdev )
    luup.variable_set( "urn:micasaverde-com:serviceId:GenericSensor1", "CurrentLevel", sprec, pdev )
    luup.variable_set( "urn:micasaverde-com:serviceId:HumiditySensor1", "CurrentLevel", sprec, pdev )
    luup.variable_set( "urn:micasaverde-com:serviceId:LightSensor1", "CurrentLevel", sprec, pdev )
    
    --[[ For binary sensor, consider the duty cycle against time (func value is irrelevant).
         Handling the trip state is made a little more complex by AutoUntrip. When AutoUntrip
         is non-zero, the sensor untrips after that many seconds, even if the base condition
         indicates continued trip. We use TripInhibit when AutoUntrip resets the tripped state, 
         to prevent re-tripping until the base condition goes back to false/untripped.
    --]]
    local duty = getVarNumeric( "DutyCycle", 50, pdev, MYSID )
    local dutyTime = math.floor( per * duty / 100 + 0.5 )
    local flag = nextX < dutyTime
    local inhibit = getVarNumeric( "TripInhibit", 0, pdev, MYSID ) ~= 0
    local currTrip = getVarNumeric( "Tripped", 0, pdev, SECURITYSID ) ~= 0
    local untrip = getVarNumeric( "AutoUntrip", 0, pdev, SECURITYSID )
    D("target trip state %1, current %2, inhibit %3, AutoUntrip %4", flag, currTrip, inhibit, untrip)
    if not flag then
        if currTrip or inhibit then
            -- Change to untripped (trailing edge): reset and clear inhibit.
            D("VVVVV TRIP RESET")
            trip( false, pdev )
        end
    else
        if not inhibit then -- see comment in trip() for semantics
            -- Changed, set tripped, LastTrip, and inhibit more trips until reset
            D("^^^^^ TRIP SET")
            trip( true, pdev )
            -- luup.variable_set( SECURITYSID, "LastTrip", now, pdev ) -- luup sets automatically
        end
    end
    if untrip > 0 and currTrip then
        local lastTrip = getVarNumeric( "LastTrip", 0, pdev, SECURITYSID )
        D("plugin_tick() Luup will AutoUntrip in %1 seconds", (lastTrip + untrip) - now)
    end

    -- Approaching duty cycle point?
    if nextX < dutyTime then
        nextDelay = math.min( dutyTime - nextX, nextDelay )
    end
    
    -- If we're approaching the max or min, come as close as we can.
    local nn = math.ceil( ( per / 4 ) - nextX )
    -- D("time to max is %1", nn)
    if nn < 0 then -- already passed max, try min
        nn = math.ceil( ( 3 * per / 4 ) - nextX )
        -- D("time to min is %1", nn)
    end
    if nn > 0 then
        nextDelay = math.min( nn, nextDelay )
    end
    
    -- Battery emulation?
    local batteryTime = getVarNumeric( "BatteryEmulation", 0, pdev, MYSID )
    if batteryTime > 0 then
        -- Battery updates at most once per minute
        local batteryDate = getVarNumeric( "BatteryDate", 0, pdev, HADEVICESID )
        if ( now - batteryDate ) >= getVarNumeric( "BatteryInterval", math.min( 1, math.floor( batteryTime / 30 ) ), pdev, MYSID ) then
            local oldLevel = getVarNumeric( "BatteryLevel", 0, pdev, HADEVICESID )
            if oldLevel == 0 then
                if getVarNumeric( "BatteryReset", 0, pdev, MYSID ) ~= 0 then
                    -- Reset time base for next update, which resets battery to 100% on next pass
                    actionResetBattery( pdev )
                end
            else
                local bBase = getVarNumeric( "BatteryBase", 0, pdev, MYSID )
                if bBase == 0 then
                    luup.variable_set( MYSID, "BatteryBase", now, pdev )
                    bBase = now
                end
                local bDelta = now - bBase
                local bLevel = 0
                if bDelta <= batteryTime then
                    bLevel = constrain( math.floor( 100 - math.exp( ( bDelta / batteryTime ) * 10.1 - 5.5 ) + 0.5 ), 0, 100 )
                    -- bLevel = constrain( 100 - math.floor( bDelta * 100 / batteryTime + 0.5 ) , 0, 100 )
                end
                -- Vera semantics? Battery level set only when changes, but BatteryDate is always updated.
                if bLevel ~= oldLevel then
                    luup.variable_set( HADEVICESID, "BatteryLevel", bLevel, pdev )
                end
                luup.variable_set( HADEVICESID, "BatteryDate", now, pdev )
            end
        end
    end
    
    -- Schedule our next tick. Notice we pass through what we got.    
    plugin_scheduleTick( nextDelay, stepStamp, pdev, passthru )
end

-- Watch callback
function plugin_watchCallback( dev, service, variable, oldValue, newValue )
    D("plugin_watchCallback(%1,%2,%3,%4,%5)", dev, service, variable, oldValue, newValue)
    -- assert(luup.device ~= nil) -- fails on openLuup, but only ~= dev when child dev w/handleChildren parent
    if service == MYSID then
        if variable == "Period" then
            D("plugin_watchCallback() Period changed, resetting BaseTime")
            luup.variable_set( MYSID, "BaseTime", os.time(), dev )  
        elseif variable == "Interval" then
            D("plugin_watchCallback() Interval changed, starting new timer thread")
            runStamp = os.time()
            plugin_scheduleTick( tonumber(newValue) or 1, runStamp, dev, "" )
        elseif variable == "Enabled" then
            newValue = tonumber(newValue, 10) or 0
            if newValue == 0 then
                -- Stopping
                D("plugin_watchCallback() stopping timer loop")
                runStamp = 0
            else
                -- If Continuity is set, reset the base time to match the progress of the
                -- function when it stopped, so the next tick provides the next continuous
                -- value of the function.
                if getVarNumeric( "Continuity", 1, dev, MYSID ) ~= 0 then
                    local nextX = getVarNumeric( "NextX", 0, dev, MYSID )
                    luup.variable_set( MYSID, "BaseTime", os.time()-nextX, dev )
                end
                runStamp = os.time()
                D("plugin_watchCallback() Enabled set, starting timing with new stamp %1", runStamp)
                plugin_scheduleTick( 1, runStamp, dev, "" )
            end
        end
    end
end

--[[ Start-up initialization for plug-in. This is called by the startup function
     in the implementation file. The bulk of the work should be done here, because,
     well, writing Lua inside an XML file is insanity, or a path to it. ]]
function plugin_init(dev)
    D("plugin_init(%1)", dev)
    L("starting version %1 for device %2", _PLUGIN_VERSION, dev )

    -- Check for ALTUI and OpenLuup. ??? need quicker, cleaner check
    for k,v in pairs(luup.devices) do
        if v.device_type == "urn:schemas-upnp-org:device:altui:1" then
            local rc,rs,jj,ra
            D("plugin_init() detected ALTUI at %1", k)
            isALTUI = true
            rc,rs,jj,ra = luup.call_action("urn:upnp-org:serviceId:altui1", "RegisterPlugin",
                { newDeviceType=MYTYPE, newScriptFile="J_VirtualSensor1_ALTUI.js", newDeviceDrawFunc="VirtualSensor_ALTUI.DeviceDraw" },
                k )
            D("init() ALTUI's RegisterPlugin action returned resultCode=%1, resultString=%2, job=%3, returnArguments=%4", rc,rs,jj,ra)
        elseif v.device_type == "openLuup" then
            D("plugin_init() detected openLuup")
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
    luup.variable_watch( "virtualSensorWatchCallback", MYSID, nil, dev )
    luup.variable_watch( "virtualSensorWatchCallback", SECURITYSID, nil, dev )
    
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

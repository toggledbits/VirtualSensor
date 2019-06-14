-- -----------------------------------------------------------------------------
-- L_VirtualSensor.lua
-- Copyright 2017,2018,2019 Patrick H. Rigney, All Rights Reserved
-- http://www.toggledbits.com/sitesensor
-- This file is available under GPL 3.0. See LICENSE in documentation for info.
-- -----------------------------------------------------------------------------

module("L_VirtualSensor1", package.seeall)

local _PLUGIN_ID = 9031 -- luacheck: ignore 211
local _PLUGIN_NAME = "VirtualSensor"
local _PLUGIN_VERSION = "1.9"
local _PLUGIN_URL = "http://www.toggledbits.com/virtualsensor"
local _CONFIGVERSION = 19148

local debugMode = false

local MYSID = "urn:toggledbits-com:serviceId:VirtualSensor1"
local MYTYPE = "urn:schemas-toggledbits-com:device:VirtualSensor:1"

local SECURITYSID = "urn:micasaverde-com:serviceId:SecuritySensor1"
local HADEVICESID = "urn:micasaverde-com:serviceId:HaDevice1"

local pluginDevice
local runStamp = 0
local isALTUI = false
local isOpenLuup = false

local watchMap = {}

local dfMap = {
	  ["urn:schemas-micasaverde-com:device:DoorSensor:1"] =
			{ device_file="D_DoorSensor1.xml", category=4, subcategory=1, service="urn:micasaverde-com:serviceId:SecuritySensor1", variable="Tripped", name="Door/Security (binary)" }
	, ["urn:schemas-micasaverde-com:device:TemperatureSensor:1"] =
			{ device_file="D_TemperatureSensor1.xml", category=17, service="urn:upnp-org:serviceId:TemperatureSensor1", variable="CurrentTemperature", name="Temperature" }
	, ["urn:schemas-micasaverde-com:device:HumiditySensor:1"] =
			{ device_file="D_HumiditySensor1.xml", category=16, service="urn:micasaverde-com:serviceId:HumiditySensor1", variable="CurrentLevel", name="Humidity" }
	, ["urn:schemas-micasaverde-com:device:LightSensor:1"] =
			{ device_file="D_LightSensor1.xml", category=18, service="urn:micasaverde-com:serviceId:LightSensor1", variable="CurrentLevel", name="Light" }
	, ["urn:schemas-micasaverde-com:device:GenericSensor:1"] =
			{ device_file="D_GenericSensor1.xml", category=12, service="urn:micasaverde-com:serviceId:GenericSensor1", variable="CurrentLevel", name="Generic" }
}

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

local function L(msg, ...) -- luacheck: ignore 212
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

-- Split string to array of strip on separator
local function split( str, sep )
	if sep == nil then sep = "," end
	local arr = {}
	if #str == 0 then return arr, 0 end
	local rest = string.gsub( str or "", "([^" .. sep .. "]*)" .. sep, function( m ) table.insert( arr, m ) return "" end )
	table.insert( arr, rest )
	return arr, #arr
end

local function coalesce( a, b )
	return ("" ~= (a or "")) and a or b
end

-- Add watch if not already present (keeps watchMap)
local function addWatch( dev, svc, var, pdev )
	D("addWatch(%1,%2,%3,%4)", dev, svc, var, pdev)
	local key = (dev .. "/" .. svc .. "/" .. var):lower()
	if watchMap[key] == nil then
		watchMap[key] = {}
		luup.variable_watch( "virtualSensorWatchCallback", svc, var, dev )
		D("addWatch() registered system watch for %1", key)
	end
	if not watchMap[key][tostring(pdev)] then
		D("addWatch() %1 (self) subscribing to %2", pdev, key)
		watchMap[key][tostring(pdev)] = pdev
	end
end

local function removeWatch( dev, svc, var, pdev )
	D("addWatch(%1,%2,%3,%4)", dev, svc, var, pdev)
	local key = (dev .. "/" .. svc .. "/" .. var):lower()
	if watchMap[key] then
		watchMap[key][tostring(pdev)] = nil
	end
end

-- Set or reset the current tripped state
local function trip( flag, pdev )
	D("trip(%1,%2)", flag, pdev)
	local val = flag and 1 or 0
	local currTrip = getVarNumeric( "Tripped", 0, pdev, SECURITYSID )
	if currTrip ~= val then
		luup.variable_set( SECURITYSID, "Tripped", val, pdev )
		-- We don't need to worry about LastTrip or ArmedTripped, as Luup manages them.
		-- Note, the semantics of ArmedTripped are such that it changes only when Armed=1
		-- AND there's an edge (change) to Tripped. If Armed is changed from 0 to 1,
		-- ArmedTripped is not changed, even if Tripped=1 at that moment; it will change
		-- only when Tripped is explicitly set.
	end
	--[[ TripInhibit is our copy of Tripped, because Luup will change Tripped
		 behind our back when AutoUntrip > 0--it will reset Tripped after
		 that many seconds, but then we would turn around and set it again.
		 We don't want to do that until Tripped resets because WE want
		 it reset, so we use TripInhibit to lock ourselves out until then. --]]
	luup.variable_set( MYSID, "TripInhibit", val, pdev )
end

local function getChildDevices( typ, parent, filter )
	assert(parent ~= nil)
	local res = {}
	for k,v in pairs(luup.devices) do
		if v.device_num_parent == parent and ( typ == nil or v.device_type == typ ) and ( filter==nil or filter(k, v) ) then
			table.insert( res, k )
		end
	end
	return res
end

local function prepForNewChildren( existingChildren, dev )
	D("prepForNewChildren(%1)", existingChildren)
	if existingChildren == nil then
		existingChildren = {}
		for k,v in pairs( luup.devices ) do
			if v.device_num_parent == dev then
				if dfMap[v.device_type] ~= nil then
					table.insert( existingChildren, k )
				else
					L({level=2,msg="Skipping child id %1 dev %2 (%3), type %4 not supported"},
						v.id, k, v.description, v.device_type)
				end
			end
		end
	end
	local ptr = luup.chdev.start( dev )
	for _,k in ipairs( existingChildren ) do
		local v = luup.devices[k]
		assert(v)
		assert(v.device_num_parent == dev)
		D("prepForNewChildren() appending existing child %1 (%2/%3)", v.description, k, v.id)
		luup.chdev.append( dev, ptr, v.id, v.description, "",
			dfMap[v.device_type].device_file,
			"", "", false )
	end
	return ptr, existingChildren
end

--[[   A C T I O N   H A N D L E R S   ]]

function actionAddChild( dev, childType )
	local df = dfMap[ childType ]
	assert( df )

	-- Find max ID in use.
	local mx = 0
	local c = getChildDevices( nil, dev )
	for _,d in ipairs( c or {} ) do
		local v = tonumber(luup.devices[d].id)
		if v and v > mx then mx = v end
	end

	-- Generate default description
	local desc = "Virtual " .. df.service:gsub( "[^:]+:", "" ):gsub( "%d+$", "" )

	L("Add new child type %1 id %2 desc %3", childType, mx+1, desc)

	local ptr = prepForNewChildren( nil, dev )
	luup.chdev.append( dev, ptr, tostring(mx+1), desc, "", dfMap[childType].device_file, "", "", false )
	luup.chdev.sync( dev, ptr )
	return 4,0
end

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

function actionSetValue( dev, val )
	D("actionSetValue(%1,%2)", dev, val)
	val = tonumber(val)
	if val ~= nil then
		luup.variable_set( "urn:upnp-org:serviceId:TemperatureSensor1", "CurrentTemperature", val, dev )
		luup.variable_set( "urn:micasaverde-com:serviceId:GenericSensor1", "CurrentLevel", val, dev )
		luup.variable_set( "urn:micasaverde-com:serviceId:HumiditySensor1", "CurrentLevel", val, dev )
		luup.variable_set( "urn:micasaverde-com:serviceId:LightSensor1", "CurrentLevel", val, dev )
		trip( val ~= 0, dev );
	end
end

function actionResetBattery( dev )
	D("actionResetBattery(%1)", dev)
	if getVarNumeric( "BatteryEmulation", 0, dev, MYSID ) > 0 then
		luup.variable_set( MYSID, "BatteryBase", os.time(), dev )
		luup.variable_set( HADEVICESID, "BatteryLevel", 100, dev )
		luup.variable_set( HADEVICESID, "BatteryDate", os.time(), dev )
	end
end

--[[   C H I L D   C O P Y   I M P L E M E N T A T I O N --]]

local function initChild( dev )
	local s = getVarNumeric( "Version", 0, dev, MYSID )
	if s == 0 then
		luup.variable_set( MYSID, "SourceDevice", "", dev )
		luup.variable_set( MYSID, "SourceServiceId", "", dev )
		luup.variable_set( MYSID, "SourceVariable", "", dev )

		luup.attr_set( 'invisible', 0, dev );

		local df = dfMap[ luup.devices[dev].device_type ]
		if df then
			if df.category ~= nil then
				luup.attr_set( "category_num", df.category, dev )
				if df.subcategory ~= nil then
					luup.attr_set( "subcategory_num", df.subcategory, dev )
				end
			end
		end

		luup.variable_set( MYSID, "Version", _CONFIGVERSION, dev )
		return
	end

	if s < _CONFIGVERSION then
		luup.variable_set( MYSID, "Version", _CONFIGVERSION, dev )
	end
end

-- Update child virtual sensor.
local function forceChildUpdate( child )
	D("forceChildUpdate(%1)", child)
	assert( luup.devices[child] )
	local df = dfMap[ luup.devices[child].device_type ]
	assert(df, "Device map entry not found for "..tostring(luup.devices[child].device_type))
	local dev = getVarNumeric( "SourceDevice", -1, child, MYSID )
	if luup.devices[dev] then
		local svc = luup.variable_get( MYSID, "SourceServiceId", child ) or "X"
		local var = luup.variable_get( MYSID, "SourceVariable", child ) or "X"
		local val = luup.variable_get( svc, var, dev ) or ""
		local ts = coalesce( (luup.variable_get( MYSID, "TargetServiceId", child )), (df or {}).service ) or ""
		local tv = coalesce( (luup.variable_get( MYSID, "TargetVariable", child )), (df or {}).variable ) or ""
		local oldval = luup.variable_get( ts, tv, child ) or ""
		if val ~= oldval then
			luup.variable_set( ts, tv, val, child )
			luup.variable_set( MYSID, "PreviousValue", oldval, child )
			luup.variable_set( MYSID, "LastUpdate", os.time(), child )
		end
	else
		L({level=2,msg="Can't update child virtual sensor %1 (#%2): source device %3 no longer exists!"},
			luup.devices[child].description, child, dev)
	end
end

-- Start virtual sensor
local function startChild( dev )
	D("startChild(%1)", dev)
	local df = dfMap[ luup.devices[dev].device_type ]
	assert( df ~= nil, "Unsupported device type for child" )

	initChild( dev )

	local device = luup.variable_get( MYSID, "SourceDevice", dev ) or ""
	if device == "" then
		-- No copy. Just clear error state and return.
		luup.set_failure( 0, dev )
		return
	end

	-- Find device
	local dn = tonumber(device)
	if dn == nil then
		device = device:lower()
		for k,d in pairs( luup.devices ) do
			if d.description:lower() == device then
				dn = k
				break
			end
		end
		if dn == nil then
			L({level=1,msg="%1 (%2) can't find your configured source device %3"},
				luup.devices[dev].description, dev, device)
			luup.set_failure( 1, dev )
		end
	end

	-- Get source variable.
	local service = luup.variable_get( MYSID, "SourceServiceId", dev ) or ""
	local variable = luup.variable_get( MYSID, "SourceVariable", dev ) or ""
	if service == "" or variable == "" then
		L({level=1,msg="%1 (#%2) not configured; stopping."}, luup.devices[dev].description, dev)
		luup.set_failure( 1, dev )
		return
	end
	D("startChild() child %1 pull from %2.%3/%4", dev, dn, service, variable)

	if getVarNumeric( "Enabled", 0, pluginDevice, MYSID ) == 0 then
		L({level=2,"%1 (#%2) not started, parent %1 (#%2) is disabled."},
			luup.devices[dev].description, dev, luup.devices[pluginDevice].description, pluginDevice)
		luup.set_failure( 1, dev )
	else
		-- Add source state variable to watch map.
		addWatch( dn, service, variable, dev )

		-- Get value right now and set if changed.
		forceChildUpdate( dev )

		-- Soup is on, baby!
		luup.set_failure( 0, dev )
	end
end

-- Watched variable for child has changed. Set new value on child.
local function childWatchCallback( dev, svc, var, oldVal, newVal, child )
	D("childWatchCallback(%1,%2,%3,%4,%5,%6)", dev, svc, var, oldVal, newVal, child)
	assert( luup.devices[child] )
	if svc == MYSID and var == "SourceVariable" then
		-- Source change; restart child.
		L("Restarting %1 (#%2) -- source changed", (luup.devices[dev] or {}).description, dev)
		startChild( dev )
	else
		-- Copy source variable value
		local sd = tonumber( luup.variable_get( MYSID, "SourceDevice", child ) or -1 ) or -1
		local ss = luup.variable_get( MYSID, "SourceServiceId", child ) or ""
		local sv = luup.variable_get( MYSID, "SourceVariable", child ) or ""
		D("childWatchCallback() update source? %1.%2/%3 changed, current source is %4.%5/%6",
			dev, svc, var, sd, ss, sv)
		if dev == sd and svc == ss and var == sv then
			-- Only copy if it's the current configured source.
			local df = dfMap[ luup.devices[child].device_type ]
			local ts = coalesce( (luup.variable_get( MYSID, "TargetServiceId", child )), (df or {}).service ) or ""
			local tv = coalesce( (luup.variable_get( MYSID, "TargetVariable", child )), (df or {}).variable ) or ""
			if ts ~= "" and tv ~= "" then
				D("childWatchCallback() setting %1.%2/%3 to %4", child, ts, tv, newVal)
				luup.variable_set( ts, tv, newVal, child )
				luup.variable_set( MYSID, "PreviousValue", oldVal, child )
				luup.variable_set( MYSID, "LastUpdate", os.time(), child )
			else
				L({level=1,msg="Failed to store value on %1 (#%2), target invalid"},
					luup.devices[child].description, child, ts, tv)
				luup.set_failure( 1, child )
				removeWatch( dev, svc, var, child )
			end
		end
		-- Note we silently ignore watch calls for old (non-current) source
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
		luup.variable_set( MYSID, "Enabled", 1, dev )
		luup.variable_set( MYSID, "DebugMode", 0, dev )
		luup.variable_set( MYSID, "Interval", 60, dev )
		luup.variable_set( MYSID, "Period", 0, dev )
		luup.variable_set( MYSID, "Amplitude", 1, dev )
		luup.variable_set( MYSID, "Midline", 0, dev )
		luup.variable_set( MYSID, "DutyCycle", 50, dev )
		luup.variable_set( MYSID, "Precision", 2, dev )
		luup.variable_set( MYSID, "BaseTime", os.time(), dev )
		luup.variable_set( MYSID, "NextX", 0, dev )
		luup.variable_set( MYSID, "Continuity", 1, dev )
		luup.variable_set( MYSID, "BatteryEmulation", 0, dev )
		luup.variable_set( MYSID, "BatteryReset", 0, dev )
		luup.variable_set( MYSID, "ExtraVariables", 2, dev )

		luup.variable_set( "urn:upnp-org:serviceId:TemperatureSensor1", "CurrentTemperature", "", dev )
		luup.variable_set( SECURITYSID, "Armed", 0, dev )
		luup.variable_set( SECURITYSID, "Tripped", 0, dev )
		luup.variable_set( SECURITYSID, "AutoUntrip", 0, dev )
		luup.variable_set( "urn:micasaverde-com:serviceId:GenericSensor1", "CurrentLevel", "", dev )
		luup.variable_set( "urn:micasaverde-com:serviceId:HumiditySensor1", "CurrentLevel", "", dev )
		luup.variable_set( "urn:micasaverde-com:serviceId:LightSensor1", "CurrentLevel", "", dev )

		luup.variable_set( "urn:micasaverde-com:serviceId:HaDevice1", "ModeSetting", "1:;2:;3:;4:", dev )

		luup.attr_set( "category_num", 4, dev )
		luup.attr_set( "subcategory_num", 1, dev )

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
		luup.variable_set( SECURITYSID, "AutoUntrip", 0, dev )
	end
	if rev < 010101 then
		D("runOnce() updating config for rev 010101")
		luup.variable_set( MYSID, "Alias", "", dev )
	end
	if rev < 010200 then
		D("runOnce() updating config for rev 010200")
		luup.attr_set( "category_num", 4, dev )
		luup.attr_set( "subcategory_num", 1, dev )
	end
	if rev < 010201 then
		D("runOnce() updating config for rev 010201")
		luup.variable_set( MYSID, "ExtraVariables", "", dev )
	end
	if rev < 010202 then
		luup.variable_set( MYSID, "DebugMode", 0, dev )
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
	stepStamp = tonumber( stepStamp )
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

	local per = constrain( getVarNumeric( "Period", 300, pdev, MYSID ), 0, nil ) -- no upper bound
	if per == 0 then
		-- Period is 0, do not run simulator.
		luup.variable_set( "urn:upnp-org:serviceId:TemperatureSensor1", "CurrentTemperature", "", pdev )
		luup.variable_set( "urn:micasaverde-com:serviceId:GenericSensor1", "CurrentLevel", "", pdev )
		luup.variable_set( "urn:micasaverde-com:serviceId:HumiditySensor1", "CurrentLevel", "", pdev )
		luup.variable_set( "urn:micasaverde-com:serviceId:LightSensor1", "CurrentLevel", "", pdev )
		return
	end

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

	local s = split( luup.variable_get( MYSID, "ExtraVariables", pdev ) or "" )
	for _,v in pairs( s ) do
		if v ~= "" then
			local svc = split( v, "/" )
			if #svc == 1 then
				table.insert( svc, 1, MYSID )
			end
			luup.variable_set( svc[1], svc[2], sprec, pdev )
		end
	end

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
	-- Ignore all non-changes
	if oldValue == newValue then return end

	-- Child update?
	local key = (dev .. "/" .. service .. "/" .. variable):lower()
	if watchMap[key] then
		-- No child updates when disabled.
		if getVarNumeric( "Enabled", 0, pluginDevice, MYSID ) == 0 then
			return
		end
		for _,d in pairs( watchMap[key] ) do
			pcall( childWatchCallback, dev, service, variable, oldValue, newValue, d )
		end
	end

	-- Also check and do these, in case someone makes a child that looks at us.
	-- We still have work to do, you know.
	if service == MYSID then
		if variable == "Period" then
			D("plugin_watchCallback() Period changed, resetting BaseTime")
			luup.variable_set( MYSID, "BaseTime", os.time(), dev )
		elseif variable == "Interval" then
			D("plugin_watchCallback() Interval changed, starting new timer thread")
			runStamp = os.time()
			plugin_scheduleTick( tonumber(newValue) or 1, runStamp, dev, "" )
		elseif variable == "Enabled" then
			newValue = tonumber(newValue or 0) or 0
			if newValue == 0 then
				-- Stopping
				D("plugin_watchCallback() stopping timer loop")
				runStamp = 0
				-- Update child sensors
				for _,child in ipairs( getChildDevices( nil, dev ) or {} ) do
					luup.set_failure( 1, child )
				end
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

				-- Restart child sensors
				for _,child in ipairs( getChildDevices( nil, dev ) or {} ) do
					pcall( startChild, child )
				end
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

	pluginDevice = dev

	if getVarNumeric("DebugMode",0,dev,MYSID) ~= 0 then
		debugMode = true
		D("plugin_init(): Debug enabled by DebugMode state variable")
	end

	-- Check for ALTUI and OpenLuup. ??? need quicker, cleaner check
	for k,v in pairs(luup.devices) do
		if v.device_type == "urn:schemas-upnp-org:device:altui:1" and v.device_num_parent == 0 then
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
	-- luup.variable_watch( "virtualSensorWatchCallback", SECURITYSID, nil, dev )

	for _,n in ipairs( getChildDevices( nil, dev ) or {} ) do
		addWatch( n, MYSID, "SourceVariable", dev )
		local success, err = pcall( startChild, n )
		if not success then
			L({level=1,msg="Failed to start child %1 (#%2): %3"}, luup.devices[n].description, n, err)
			luup.set_failure( 1, n )
		end
	end

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

local function getDevice( dev, pdev, v ) -- luacheck: ignore 212
	if v == nil then v = luup.devices[dev] end
	local json = require("json")
	if json == nil then json = require("dkjson") end
	local devinfo = {
		  devNum=dev
		, ['type']=v.device_type
		, description=v.description or ""
		, room=v.room_num or 0
		, udn=v.udn or ""
		, id=v.id
		, ['device_json'] = luup.attr_get( "device_json", dev )
		, ['impl_file'] = luup.attr_get( "impl_file", dev )
		, ['device_file'] = luup.attr_get( "device_file", dev )
		, manufacturer = luup.attr_get( "manufacturer", dev ) or ""
		, model = luup.attr_get( "model", dev ) or ""
	}
	local rc,t,httpStatus,uri
	if isOpenLuup then
		uri = "http://localhost:3480/data_request?id=status&DeviceNum=" .. dev .. "&output_format=json"
	else
		uri = "http://localhost/port_3480/data_request?id=status&DeviceNum=" .. dev .. "&output_format=json"
	end
	rc,t,httpStatus = luup.inet.wget(uri, 15)
	if httpStatus ~= 200 or rc ~= 0 then
		devinfo['_comment'] = string.format( 'State info could not be retrieved, rc=%s, http=%s', tostring(rc), tostring(httpStatus) )
		return devinfo
	end
	local d = json.decode(t)
	local key = "Device_Num_" .. dev
	if d ~= nil and d[key] ~= nil and d[key].states ~= nil then d = d[key].states else d = nil end
	devinfo.states = d or {}
	return devinfo
end

function requestHandler( lul_request, lul_parameters, lul_outputformat )
	D("request(%1,%2,%3) luup.device=%4", lul_request, lul_parameters, lul_outputformat, luup.device)
	local action = lul_parameters['action'] or lul_parameters['command'] or ""
	local deviceNum = tonumber( lul_parameters['device'], 10 ) or luup.device
	if action == "debug" then
		local err,msg,job,args = luup.call_action( MYSID, "SetDebug", { debug=1 }, deviceNum )
		return string.format("Device #%s result: %s, %s, %s, %s", tostring(deviceNum), tostring(err), tostring(msg), tostring(job), dump(args)), "text/plain"
	end

	if action == "status" then
		local json = require("dkjson")
		if json == nil then json = require("dkjson") end
		local st = {
			name=_PLUGIN_NAME,
			version=_PLUGIN_VERSION,
			configversion=_CONFIGVERSION,
			author="Patrick H. Rigney (rigpapa)",
			url=_PLUGIN_URL,
			['type']=MYTYPE,
			responder=luup.device,
			timestamp=os.time(),
			system = {
				version=luup.version,
				isOpenLuup=isOpenLuup,
				isALTUI=isALTUI,
				units=luup.attr_get( "TemperatureFormat", 0 ),
			},
			devices={}
		}
		for k,v in pairs( luup.devices ) do
			if v.device_type == MYTYPE then
				local devinfo = getDevice( k, luup.device, v ) or {}
				table.insert( st.devices, devinfo )
			end
		end
		return json.encode( st ), "application/json"
	elseif string.find("trip reset arm disarm setvalue", action) then
		local alias = lul_parameters['alias'] or ""
		local parm = {}
		local devAction
		local sid = MYSID
		if action == "trip" then
			devAction = "Trip"
		elseif action == "arm" then
			devAction = "SetArmed"
			parm.newArmedValue = 1
			sid = SECURITYSID
		elseif action == "disarm" then
			devAction = "SetArmed"
			parm.newArmedValue = 0
			sid = SECURITYSID
		elseif action == "setvalue" then
			devAction = "SetValue"
			parm.newValue = lul_parameters['value']
		else
			devAction = "Reset"
		end
		local nDev = 0
		for k,v in pairs( luup.devices ) do
			if v.device_type == MYTYPE then
				local da = luup.variable_get(MYSID, "Alias", k) or ""
				if da ~= "" and ( alias == "*" or alias == da ) then
					luup.call_action( sid, devAction, parm, k)
					nDev = nDev + 1
				end
			end
		end
		return string.format("Done with %q for %d devices matching alias %q", action, nDev, alias), "text/plain"

	elseif action == "getvtypes" then
		local json = require("dkjson")
		local r = {}
		if isOpenLuup then
			-- For openLuup, only show device types for resources that are installed
			local loader = require "openLuup.loader"
			if loader.find_file ~= nil then
				for k,v in pairs( dfMap ) do
					if loader.find_file( v.device_file ) then
						r[k] = v
					end
				end
			else
				L{level=1,msg="PLEASE UPGRADE YOUR OPENLUUP TO 181122 OR HIGHER FOR FULL SUPPORT OF SITESENSOR VIRTUAL DEVICES"}
			end
		else
			r = dfMap
		end
		return json.encode( r ), "application/json"

	else
		return string.format("Action %q not implemented", action), "text/plain"
	end
end

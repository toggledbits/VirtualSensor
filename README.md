# VirtualSensor #
Virtual Sensor is a plugin for Vera home automation controllers that generates
data and events for testing other plugins, scenes, scripts and program logic.

## Why? ##

I have written and maintain several plugins for Vera controllers. Many of them use sensor
input for various purposes, and sometimes testing with live data is too slow and tedious.
So I cobbled together a plugin that can act as any kind of sensor native to Vera: temperature,
motion/door (aka security), humidity, light, and generic (it does them all at once).

VirtualSensor can also operate entirely in "manual" mode, meaning that the trip/reset state
of its SecuritySensor1 service can be managed exclusively through the UI or scene/Lua/PLEG
actions. It can also be managed by external web requests to the Vera, so an outside service
could set the tripped/reset state of the device based on conditions entirely unknown to Vera.
For example, BlueIris is popular NVR software for managing and recording IP security cameras,
and it offers excellent motion detection, sound triggers, etc. Simple configuration within
BlueIris would allow to set and reset the tripped state of a VirtualSensor, allowing it
to operate as a motion sensor controlled by BlueIris reaction to what it sees in a camera.

Virtual Sensor runs on Vera UI7, ALTUI, and openLuup.

## Configuration ##

In my original version, there was no UI--configuration happened through direct manipulation of
state variables. This released version offers a simple GUI for configuration. Here are the
knobs you get to turn:

### Period ###

The period (in seconds) is the amount of time taken for a full cycle of the function. The shorter
the period, the higher the frequency of the wave and the faster the data changes. The smallest 
period is one second, but this probably has no practical use. There is no upper limit other than
what's practical.

### Amplitude ###

The amplitude, or more specifically peak amplitude, is how far above and below the midline the
function will go. The maximum amplitude will be reached at 1/4 of the period, and the minimum
at 3/4 of the period.

### Midline ###

The midline offsets the "zero" of the function. In combination with the amplitude, this allows
any range of values to be produced. For example, with a midline of 68 and an amplitude of 2,
Virtual Sensor will generate values in the range of 66 (68 - 2) to 70 (68 + 2).

### Duty Cycle ###

In proving the binary sensor state "tripped," Virtual Sensor uses the duty cycle to determine
what percentage of the period will be report in tripped state. For example, settings the Period
to 300 seconds and the duty cycle to 5% will result in a sensor that is tripped 15 seconds
out of every five minutes. The tripped period is always contiguous and at the beginning of the period.

### Update Interval ###

The update interval determines how often sensor values will be computed. This can be as little as
1 second. Intervals that are a high percentage of the period value can result in "choppy" sensor
reports.

Because of the resolution of the timer, it is possible, even likely, that a given set of parameters
will produce a run of sensor values for which the mathematical maximum and minimum of the function
are never reported--the timing may "miss" these peaks. This is normal and expected, so triggers
or scripts should not expect to encounter the peak values explicitly.

### Precision ###

The precision simply sets how many decimals Virtual Sensor will provide in its numeric sensor values.
The default is 2.

## Operation ##

Virtual Sensor is free-running. It survives Luup restarts and continues the function from its last
known point. It should be understood, however, that when compared to real time, restarts
cause a "stretch" of time between two values (on a graph against real time, this would appear
as a flat spot). I suppose I could some day offer the option to
tie the computation to a point in real time, but so far I haven't had the need (if you do, let me know!).

Settings changes, particularly changes to the Period, may cause a sudden sharp change in Virtual
Sensor's output. Consider changing a function period from 300 seconds to 30 seconds--if the running
function is already beyond the 30 second mark when the change is made, the formula must reset.

For the security sensor function (motion/door/etc.), Virtual Sensor supports Armed and Disarmed
states, controllable both in the UI and as usual through scenes and Lua. The value of ArmedTripped
is implemented as it would be for any "hard" sensor.

The generated values are the same for all sensor types. That is, if the plugin is configured to produce
temperature values in the range of 10-30C, then reading the virtual sensor as a light sensor will
yield lux values in that range, as will reading the humidity. One might think that the humidity could
simply be mapped so that the 10-30 value range produces 0-100 humidity percentages, but in practice,
this makes the sensor less useful--what if you really want to just test humidity in that small range?
I recommend not "overloading" one sensor with too many functions. Create one to be the temperature
sensor, and another to be the humidity sensor, etc. They're pretty lightweight and easy on resources.

## Scenes, Scripting, and Actions ##

Virtual Sensor provides the values, events, and actions typical to the sensors it attempts to
mimic.

### Service urn:upnp-org:serviceId:TemperatureSensor1 ###

VirtualSensor stores generated values in the `CurrentTemperature` state variable, which sends events.

No actions are implemented for this service. Scene and notification triggers on the value being
above or below a specified test value are supported.

### Service urn:micasaverde-com:serviceId:HumiditySensor1 ###

Generated values are stored in the `CurrentLevel` state variable, which sends events.

No actions are implemented for this service. Scene and notification triggers on the value being
above or below a specified test value are supported.

### Service urn:micasaverde-com:serviceId:LightSensor1 ###

Generated values are stored in the `CurrentLevel` state variable, which sends events.

No actions are implemented for this service. Scene and notification triggers on the value being
above or below a specified test value are supported.

### Service urn:micasaverde-com:serviceId:GenericSensor1 ###

Generated values are stored in the `CurrentLevel` state variable, which sends events.

No actions are implemented for this service. Scene and notification triggers on the value being
above or below a specified test value are supported.

### Service urn:micasaverde-com:serviceId:SecuritySensor1 ###

The `Tripped` state variable is set according to the period and duty cycle configured, and
sends events. In addition, the `ArmedTripped` state variable will track the state of `Tripped`
(with events) if the sensor is in "Armed" state (state variable `Armed`).

The `SetArmed` service action is implemented, and takes a single `newArmedValue` parameter.
Scene notification and triggers are provided for tripped or untripped when armed, and tripped
or untripped regardless of armed state.

The actions `Trip` and `Reset` are also available, to set and reset the *Tripped*
state of the sensor, respectively. To prevent the function from automatically
tripped and resetting the sensor and use these actions to exclusively control
the state of the VirtualSensor, make sure the device stays in *Disabled* state.

### Service urn:toggledbits-com:serviceId:VirtualSensor1 ###

The `Alias` state variable sets an alias for the VirtualSensor. It is used
in conjunction with the alternate web API described below, to identify one
or more sensors (rather than using the Vera device ID).

The `SetEnabled` service action can be invoked to enable or disable the
VirtualSensor's formulaic operation and manipulation of its values. 
To enable it, set the `newEnabledValue` parameter to 1; to disable it, 
set it 0. When disabled, a VirtualSensor can still be tripped using the `Trip` 
and `Reset` actions described above, have its value assigned via the `SetValue` 
action described below, and controlled via the alternate web API, below.

The `SetValue` service action sets a new value for the sensor. The value must
be passed in the `newValue` parameter, and must be a number or a string that
can be parsed to a number. When used, the sensor's value will be set to any
valid value that is passed, regardless of the parameters of the function
configured. The value will _not_ cause the *Tripped* state of the sensor to
change based on the value and function configuration. This action is intended
to be used only when the sensor is *Disabled*.

## Alternate Web API for Control ##

VirtualSensor (>=1.3) supports an alternate method of setting/resetting tripped state. By
using the request URL below, one can set the trip or reset one or more VirtualSensors 
that match the "alias" passed in the request. The alias must match the contents of the
Alias state variable on one or more VirtualSensor devices.

```http://your-vera-ip/port_3480/data_request?id=lr_VirtualSensor&action=trip&alias=string

http://your-vera-ip/port_3480/data_request?id=lr_VirtualSensor&action=reset&alias=string
```

If the alias is given as "\*" (asterisk/star), all VirtualSensors with non-empty 
aliases (on the Vera side) are acted upon.

The advantages of using this method rather than the typical Vera action request are:
1. The same alias can be used on multiple sensors, so they can be tripped or reset as a group
rather than having to make multiple calls for each sensor.
2. The aliases are names you assign, so that you do not have to bury Vera device numbers
in your requests in external systems--were those to change later, your requests would 
no longer work. If for
some reason you need to rebuild your Vera, delete and recreate or reassign a sensor,
all you need to do is make sure the new sensor has the right alias on the Vera side, 
and your remote requests will continue to work without additional configuration changes.

In addition to the `trip` and `reset` commands shown, there are also `arm`, `disarm`
and `setvalue` actions that may be used with this method. The `setvalue` action
takes an additional parameter (`value`) to be the new value assigned to the
matching sensor(s). For example:

```http://your-vera-ip/port_3480/data_request?id=lr_VirtualSensor&action=setvalue&alias=test&value=1234```

# VirtualSensor
Virtual Sensor is a plugin for Vera home automation controllers that generates data and events for testing other plugins, scenes, scripts and program logic.

## Why? ##

I have written and maintain several plugins for Vera controllers. Many of them use sensor
input for various purposes, and sometimes testing with live data is too slow and tedious.
So I cobbled together a plugin that can act as any kind of sensor native to Vera: temperature,
motion/door (aka security), humidity, light, and generic (it does them all at once).

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
known point. It should be understood, however, that when compared to actual timing, the restart
would cause a "stretch" of time between two values. I suppose I could some day offer the option to
tie the time computation to real time, but so far I haven't had the need (if you do, let me know!).

Settings changes, particularly changes to the Period, may cause a sudden sharp change in Virtual
Sensor's output. Consider changing a function period from 300 seconds to 30 seconds--if the running
function is already beyond the 30 second mark when the change is made, the formula resets.

For the security sensor function (motion/door/etc.), Virtual Sensor supports Armed and Disarmed
states, controllable both in the UI and as usual through scenes and Lua. The value of ArmedTripped
is implemented as it would be for any "hard" sensor.

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

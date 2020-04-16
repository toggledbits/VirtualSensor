# VirtualSensor #
VirtualSensor is a plugin for Vera home automation controllers that generates
data and events for testing other plugins, scenes, scripts and program logic.
It also creates standalone sensors of the available types (temperature, humidity,
light, generic, and security) and can set the sensor value to that of any variable
on any other device (and keep it up-to-date).

## Questions and Support

Support for this plugin is offered through the (Vera Community)[https://community.getvera.com/t/plugin-virtual-sensor/198699/1].

## Virtual Sensors ##

Virtual Sensor's control panel allows you to create any number of virtual sensors,
which can then be configured to clone their values from another device. This is
handy to use in conjunction with other plugins that more store information in 
a variable, but not create a child device for that variable to use as a trigger
in scenes, Reactor, etc.

Source data for each virtual sensor created is set on the "Virtual Sensors" tab
of the Virtual Sensor parent device. New virtual sensors can also be created
directly here. This view also provides a display of the current and prior values
copied from the source device, and the timestamp at which the last change occurred.

**openLuup:** openLuup users will need to install device and service files for the various 
sensor types for them to be available in Virtual Sensor. This is because openLuup
does not include Vera's full suite of default, known device type definitions. 
It is a simple matter to copy the device file and service file(s) from your
Vera's `/etc/cmh-lu` directory to your openLuup installation directory. If you are using
the VeraBridge, you can invoke the `GetVeraFiles` action on the bridge device.

Binary virtual sensors can either copy the value of the source device directly 
(the default behavior), or match the value to a specified string. When matching,
the binary sensor will have its `Tripped` state variable set to "1" if the string
matches, or `false` otherwise. The match string provided is a simple string, and
the match is not case sensitive by default. Advanced users may set the `MatchPattern`
state variable to "1" to have the match string used as a Lua pattern. The state
variable `MatchCase` can be set to "1" to make a match case-sensitive.

## Simulator ##

The Simulator function of Virtual Sensor generates values using a sinusoidal formula,
the parameters of which you can control.

In *disabled* state, VirtualSensor is static and will change only when acted
upon by the UI buttons, scenes, Reactor, Lua, API requests, etc.

In its *enabled* state, VirtualSensor automatically changes its values
according to the configuration of its free-running function generator.
It survives Luup restarts and continues the function from a fixed starting
point in time, meaning, if the function is configured to make a full cycle
every twenty minutes, it will stay on time even if Luup restarts in
the middle of the period. Configuration of the function generator is described
in detail in the next section.

Settings changes, particularly changes to the Period, may cause a sudden sharp change in Virtual
Sensor's output. Consider changing a function period from 300 seconds to 30 seconds--if the running
function is already beyond the 30 second mark when the change is made, the formula must reset.

For the security sensor function (motion/door/etc.), VirtualSensor supports Armed and Disarmed
states, controllable both in the UI and as usual through scenes and Lua. The value of *ArmedTripped*
is implemented as it would be for any "hard" sensor. VirtualSensor also supports *AutoUntrip*;
if non-zero, the sensor will automatically untrip that many seconds after tripping.

The generated values are the same for all sensor types. That is, if the plugin is configured to produce
temperature values in the range of 10-30C, then reading the VirtualSensor as a light sensor will
yield lux values in that range, as will reading the humidity. One might think that the humidity could
simply be mapped so that the 10-30 value range produces 0-100 humidity percentages, but in practice,
this makes the sensor less useful--what if you really want to just test humidity in that small range?
I recommend not "overloading" one sensor with too many functions. Create one to be the temperature
sensor, and another to be the humidity sensor, etc. They're pretty lightweight and easy on resources.

## Function Generator Configuration ##

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
VirtualSensor will generate values in the range of 66 (68 - 2) to 70 (68 + 2).

### Duty Cycle ###

In proving the binary sensor state "tripped," VirtualSensor uses the duty cycle to determine
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

The precision simply sets how many decimals VirtualSensor will provide in its numeric sensor values.
The default is 2.

## Scenes, Scripting, and Actions ##

VirtualSensor provides the values, events, and actions typical to the sensors it attempts to
mimic.

**NOTE THAT ALL OF THE BELOW APPLIES TO THE VIRTUALSENSOR MASTER DEVICE ONLY. THIS SECTION DOES NOT APPLY TO CHILD DEVICES.**

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
tripping and resetting the sensor and use these actions exclusively to control
its state, make sure the device stays in *Disabled* state.

### Service urn:toggledbits-com:serviceId:VirtualSensor1 ###

The `SetEnabled` service action can be invoked to enable or disable the
VirtualSensor's function generator and automatic manipulation of values.
To enable it, set the `newEnabledValue` parameter to 1; to disable it,
set it 0. When disabled, a VirtualSensor can still be controlled by the
Luup actions available (`Trip`, `Reset`, `SetValue`) and
the alternate web API, below.

The `SetValue` service action sets a new value for the sensor's function generator. The value must
be passed in the `newValue` parameter, and must be a number or a string that
can be parsed to a number. When used, the sensor's value will be set to any
valid value that is passed, regardless of the configuration of the function
generator. That is, if the value set is outside the range of the generator's
configured range, so be it--no attempt is made to limit the value passed.
The value will also _not_ cause the *Tripped* state of the sensor to
change, as values generated by the function generator do.
This action is intended to be used only when the sensor is *Disabled*
(i.e. the function generator is not running/used).

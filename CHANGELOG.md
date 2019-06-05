# Change Log

## Version 1.9 (development)

* Do a (much) better job of making a virtual sensor react to configuration changes. No Luup reloads should be necessary at this point.

## Version 1.8 (released)

* Clear values when simulator is not running.

## Version 1.7 (released)

* Fix issue that could cause excess system watches places on a variable (only need one each). This would be rare for this plugin, and benign, but improves efficiency.

## Version 1.6 (released)

* This version fixes some UI issues with respect to creating virtual sensors. It also fixes the community URLs to the new forums.

## Version 1.5 (released)

* Free-running function generator can now be disabled by setting the "Period" to 0.
* Disabling the plugin instances stops the updating of child virtual sensors (and flags them with the Luup device error indicator).

## Version 1.4 (released)

* Create child virtual sensors that just copy data from another device. Create by using the buttons on the "Control" tab. Assign source device and variable using the "Virtual Sensors" tab.

## Version 1.3 (released)

* Follow Vera semantics for `ArmedTripped` and `LastTrip` more closely. Basically, don't touch them. Vera and openLuup handle them automatically.

## Version 1.2 (released)

* Ability to trip and reset the set through actions and manually via the UI. Issue #1.

## Version 1.1 (released)

* Code cleanup.
* Battery emulation.
* Enable/disable UI.
* Tie function to absolute time (deterministic value for time).

## Version 1.0 (released)

* Initial release.
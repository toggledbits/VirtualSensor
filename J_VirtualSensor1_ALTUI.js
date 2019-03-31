//# sourceURL=J_VirtualSensor1_ALTUI.js
/* globals window,MultiBox,ALTUI_PluginDisplays,_T */

"use strict";

var VirtualSensor_ALTUI = ( function( window, undefined ) {

    function _draw( device ) {
        var html ="";
        var message = MultiBox.getStatus( device, "urn:micasaverde-com:serviceId:GenericSensor1", "CurrentLevel");
        var st = MultiBox.getStatus( device, "urn:micasaverde-com:serviceId:SecuritySensor1", "Armed");
        var en = MultiBox.getStatus( device, "urn:toggledbits-com:serviceId:VirtualSensor1", "Enabled");
        html += '<div class="pull-left">';
        html += message;
        html += "</div>";
        html += ALTUI_PluginDisplays.createOnOffButton( en, "virtualsensor-enabled-" + device.altuiid, _T("Disabled,Enabled"), "pull-right");
        html += ALTUI_PluginDisplays.createOnOffButton( st, "virtualsensor-armed-" + device.altuiid, _T("Disarmed,Armed"), "pull-right");
        html += "<script type='text/javascript'>";
        html += "$('div#virtualsensor-armed-{0}').on('click', function() { VirtualSensor_ALTUI.toggleArmed('{0}','div#virtualsensor-armed-{0}'); } );".format(device.altuiid);
        html += "$('div#virtualsensor-enabled-{0}').on('click', function() { VirtualSensor_ALTUI.toggleEnabled('{0}','div#virtualsensor-enabled-{0}'); } );".format(device.altuiid);
        html += "</script>";
        return html;
    }
    return {
        DeviceDraw: _draw,
        toggleArmed: function (altuiid, htmlid) {
            ALTUI_PluginDisplays.toggleButton(altuiid, htmlid, 'urn:micasaverde-com:serviceId:SecuritySensor1', 'Armed', function(id, newval) {
                    MultiBox.runActionByAltuiID( altuiid, 'urn:micasaverde-com:serviceId:SecuritySensor1', 'SetArmed', {newArmedValue:newval} );
            });
        },
        toggleEnabled: function (altuiid, htmlid) {
            ALTUI_PluginDisplays.toggleButton(altuiid, htmlid, 'urn:toggledbits-com:serviceId:VirtualSensor1', 'Enabled', function(id, newval) {
                    MultiBox.runActionByAltuiID( altuiid, 'urn:toggledbits-com:serviceId:VirtualSensor1', 'SetEnabled', {newEnabledValue:newval} );
            });
        }
    };
})( window );

//# sourceURL=J_VirtualSensor1_UI7.js
var VirtualSensor = (function(api) {

    // unique identifier for this plugin...
    var uuid = '7ed70018-0e76-11e8-a584-74d4351650de';

    var serviceId = "urn:toggledbits-com:serviceId:VirtualSensor1";

    var myModule = {};
    
    function updateMessage( dev ) {
        var amplitude = parseFloat( jQuery( "input#amplitude" ).val() );
        var midline = parseFloat( jQuery( "input#midline" ).val() );
        var interval = parseInt( jQuery( "input#interval" ).val() );
        var period = parseInt( jQuery( "input#period" ).val() );
        var duty = parseFloat( jQuery( "input#duty" ).val() );
        
        var msg;
        var el = jQuery("div#message");
        if ( isNaN( amplitude ) ) {
            el.addClass("tb-red");
            msg = "Please correct the amplitude (non-numeric value)";
        } else if ( isNaN( midline ) ) {
            el.addClass("tb-red");
            msg = "Please correct the midline (non-numeric value)";
        } else if ( isNaN( interval ) || interval < 1 ) {
            el.addClass("tb-red");
            msg = "Invalid interval, must be integer > 0";
        } else if ( isNaN( period ) || period < 1 ) {
            el.addClass("tb-red");
            msg = "Invalid period value, must be integer > 0";
        } else if ( isNaN( duty ) || duty < 0 || duty > 100 ) {
            el.addClass("tb-red");
            msg = "Invalid duty cycle, must be 0-100";
        } else {
            el.removeClass("tb-red");
            var q = 3.14159265 / 2.0;
            msg = "With these settings, the minimum value is " + ( Math.sin( q * 3 ) * amplitude + midline )
            + " and the maximum is " + ( Math.sin( q ) * amplitude + midline ) + ".";
            var t = Math.round( period * duty / 100.0 );
            msg += " The sensor will be tripped for about " + t + " seconds of every period.";
        }
        if ( interval > ( period / 8.0 ) ) {
            msg += " Your interval may be a bit long (or your period too short) to produce a good range of values.";
        }
        el.text(msg);
        jQuery("span#intervalreq").text( isNaN(period) ? "5" : Math.min( 5, Math.max( 1, Math.floor( period / 40 ) ) ) );
    }
    
    function onBeforeCpanelClose(args) {
        // console.log('handler for before cpanel close');
    }

    function initPlugin() {
    }

    function configurePlugin()
    {
        try {
            initPlugin();

            var myDevice = api.getCpanelDeviceId();
            
            var html = "";

            html += "<style>";
            html += ".tb-cgroup { padding: 0px 16px 0px 0px; width: 25%; }";
            html += ".tb-large { font-size: 1.5em; }";
            html += ".tb-medium { font-size: 1.2em; }";
            html += ".tb-red { color: red; }";
            html += "</style>";

            html += '<div class="tb-large">';
            html += '<img src="https://www.toggledbits.com/assets/virtualsensor/sine.png" align="right" width="329" height="240">VirtualSensor generates sensor values as a sine wave. You can specify the period (1), peak amplitude (2), and midline (3) of the wave.';
            html += '</div>';

            // Period
            html += "<div class=\"tb-cgroup pull-left\">";
            html += "<h2>Period</h2><label for=\"period\">This is the number of seconds the function will take to make a full cycle (that is, from 0 to <i>t</i> on the graph at right).</label><br/>";
            html += "<input type=\"text\" size=\"5\" maxlength=\"5\" class=\"numfield\" id=\"period\" />";
            html += "</div>";

            // Amplitude
            html += "<div class=\"tb-cgroup pull-left\">";
            html += "<h2>Amplitude</h2><label for=\"amplitude\">Enter the peak amplitude (how far beyond the midline the values will go in each direction):</label><br/>";
            html += "<input type=\"text\" size=\"8\" class=\"numfield\" id=\"amplitude\" />";
            html += "</div>";

            // Midline
            html += "<div class=\"tb-cgroup pull-left\">";
            html += "<h2>Midline</h2><label for=\"midline\">Enter the midline value:</label><br/>";
            html += "<input type=\"text\" size=\"8\" class=\"numfield\" id=\"midline\" />";
            html += "</div>";

            // Duty Cycle
            html += "<div class=\"tb-cgroup pull-left\">";
            html += "<h2>Duty Cycle (Binary Output)</h2><label for=\"duty\">The duty cycle is for binary sensor output, and is the percentage of the period that the sensor will be \"tripped.\" Enter a value in the range 0 to 100, inclusive:</label><br/>";
            html += "<input type=\"text\" size=\"3\" class=\"numfield\" id=\"duty\" />&nbsp;%";
            html += "</div>";

            // Sample Interval
            html += "<div class=\"tb-cgroup pull-left\">";
            html += "<h2>Update Interval</h2><label for=\"interval\">Enter the number of seconds between updates. Recommended: <span id='intervalreq'>5</span>.</label><br/>";
            html += "<input type=\"text\" size=\"5\" maxlength=\"5\" class=\"numfield\" id=\"interval\" />";
            html += "</div>";

            // Precision
            html += "<div class=\"tb-cgroup pull-left\">";
            html += "<h2>Precision</h2><label for=\"interval\">Select the decimal precision of the sample values:</label><br/>";
            html += "<select id='prec'><option value='5'>0.00000</option>";
            html += '<option value="4">0.0000</option>';
            html += '<option value="3">0.000</option>';
            html += '<option value="2">0.00 (default)</option>';
            html += '<option value="1">0.0</option>';
            html += '<option value="0">0</option>';
            html += '</select>';
            html += "</div>";

            html += "<div class=\"clearfix\"></div>";

            html += '<div class="tb-large" id="message">&nbsp;</div>';
            
            html += '<div class="tb-medium">';
            html += 'To create a range of 0 to 100% (humidity, for example), set midline=50, amplitude=50.';
            html += ' For a temperature range of 65&deg;F to 85&deg;F, set midline=75, amplitude=10.';
            html += ' Note that due to the resolution of the timer, the full range of values may not be seen, including the mathematical min/max.';
            html += '</div>';
            
			html += '<hr><p>&copy; 2017, 2018 Patrick H. Rigney, All Rights Reserved. <a href="https://toggledbits.com/projects">https://toggledbits.com/projects</a></p><p><b>Find VirtualSensor useful?</b> Please consider supporting the project with <a href="https://www.makersupport.com/toggledbits">a one-time &ldquo;tip&rdquo;, or a monthly $1 donation</a>. I am grateful for any support you choose to give!</p>';

            // Push generated HTML to page
            api.setCpanelContent(html);

            // Restore values
            var s;
            s = parseInt(api.getDeviceState(myDevice, serviceId, "Interval"));
            if (isNaN(s))
                s = 5;
            jQuery("input#interval").val(s).change( function( obj ) {
                var newInterval = jQuery(this).val();
                if (newInterval.match(/^[0-9]+$/) && newInterval > 0) {
                    api.setDeviceStatePersistent(myDevice, serviceId, "Interval", newInterval, 0);
                }
                updateMessage( myDevice );
            });

            s = parseInt(api.getDeviceState(myDevice, serviceId, "Period"));
            if (isNaN(s))
                s = 120;
            jQuery("input#period").val(s).change( function( obj ) {
                var newVal = jQuery(this).val();
                if (newVal.match(/^[0-9]+$/) && newVal > 0) {
                    api.setDeviceStatePersistent(myDevice, serviceId, "Period", newVal, 0);
                }
                updateMessage( myDevice );
            });
            
            s = parseFloat(api.getDeviceState(myDevice, serviceId, "Amplitude"));
            if (isNaN(s))
                s = 1.0;
            jQuery("input#amplitude").val(s).change( function( obj ) {
                var newVal = parseFloat( jQuery(this).val() );
                if ( ! isNaN( newVal ) ) {
                    api.setDeviceStatePersistent(myDevice, serviceId, "Amplitude", newVal, 0);
                }
                updateMessage( myDevice );
            });
            
            s = parseFloat(api.getDeviceState(myDevice, serviceId, "Midline"));
            if (isNaN(s))
                s = 0.0;
            jQuery("input#midline").val(s).change( function( obj ) {
                var newVal = parseFloat( jQuery(this).val() );
                if ( ! isNaN( newVal ) ) {
                    api.setDeviceStatePersistent(myDevice, serviceId, "Midline", newVal, 0);
                }
                updateMessage( myDevice );
            });

            s = parseFloat(api.getDeviceState(myDevice, serviceId, "DutyCycle"));
            if (isNaN(s))
                s = 50.0;
            jQuery("input#duty").val(s).change( function( obj ) {
                var newVal = parseFloat( jQuery(this).val() );
                if ( ! isNaN( newVal ) && newVal >= 0 && newVal <= 100 ) {
                    api.setDeviceStatePersistent(myDevice, serviceId, "DutyCycle", newVal, 0);
                }
                updateMessage( myDevice );
            });

            s = api.getDeviceState(myDevice, serviceId, "Precision");
            if (s) {
                // If the currently selected option isn't on the list, add it, so we don't lose it.
                var el = jQuery('select#prec option[value="' + s + '"]');
                if ( el.length == 0 ) {
                    jQuery('select#prec').append($('<option>', { value: s }).text(s + ' digits (custom)').prop('selected', true));
                } else {
                    el.prop('selected', true);
                }
            }
            jQuery("select#prec").change( function( obj ) {
                var newVal = jQuery(this).val();
                api.setDeviceStatePersistent(myDevice, serviceId, "Precision", newVal, 0);
                updateMessage( myDevice );
            });

            
            
            updateMessage( myDevice );
        }
        catch (e)
        {
            Utils.logError('Error in VirtualSensor.configurePlugin(): ' + e);
        }
    }
    
    function stub() { }
    
    myModule = {
        uuid: uuid,
        initPlugin: initPlugin,
        onBeforeCpanelClose: onBeforeCpanelClose,
        configurePlugin: configurePlugin
    };
    return myModule;
})(api);

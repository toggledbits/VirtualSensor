//# sourceURL=J_VirtualSensor1_UI7.js
/**
 * J_VirtualSensor1_UI7.js
 * Configuration interface for ReactorSensor
 *
 * Copyright 2017,2018,2019 Patrick H. Rigney, All Rights Reserved.
 * This file is part of Reactor. For license information, see LICENSE at https://github.com/toggledbits/Reactor
 */
/* globals api,jQuery,Utils */

var VirtualSensor = (function(api) {

	// unique identifier for this plugin...
	var uuid = '7ed70018-0e76-11e8-a584-74d4351650de';

	var serviceId = "urn:toggledbits-com:serviceId:VirtualSensor1";

	var myModule = {};

	function footer() {
		return '<hr><p>&copy; 2017,2018,2019 Patrick H. Rigney, All Rights Reserved. <a href="https://toggledbits.com/projects" target="_blank">https://toggledbits.com/projects</a></p><p><b>Find VirtualSensor useful?</b> Please consider supporting the project with <a href="https://www.toggledbits.com/donate" target="_blank">a small donation</a>. I am grateful for any support you choose to give!</p>';
	}

	function updateMessage( dev ) {
		var amplitude = parseFloat( jQuery( "input#amplitude" ).val() );
		var midline = parseFloat( jQuery( "input#midline" ).val() );
		var interval = parseInt( jQuery( "input#interval" ).val() );
		var period = parseInt( jQuery( "input#period" ).val() );
		var duty = parseFloat( jQuery( "input#duty" ).val() );
		var autountrip = api.getDeviceState( dev, "urn:micasaverde-com:serviceId:SecuritySensor1", "AutoUntrip" ) || 0;

		var msg;
		var el = jQuery("div#message");
		if ( 0 === period ) {
			msg = "The simulator is disabled. Set period>0 to enable.";
		} else if ( isNaN( amplitude ) ) {
			el.addClass("tb-red");
			msg = "Please correct the amplitude (non-numeric value)";
		} else if ( isNaN( midline ) ) {
			el.addClass("tb-red");
			msg = "Please correct the midline (non-numeric value)";
		} else if ( isNaN( interval ) || interval < 1 ) {
			el.addClass("tb-red");
			msg = "Invalid interval, must be integer > 0";
		} else if ( isNaN( period ) || period < 0 ) {
			el.addClass("tb-red");
			msg = "Invalid period value, must be integer >= 0";
		} else if ( isNaN( duty ) || duty < 0 || duty > 100 ) {
			el.addClass("tb-red");
			msg = "Invalid duty cycle, must be 0-100";
		} else {
			el.removeClass("tb-red");
			var q = 3.14159265 / 2.0;
			msg = "With these settings, the minimum value is " + ( Math.sin( q * 3 ) * amplitude + midline ) +
				" and the maximum is " + ( Math.sin( q ) * amplitude + midline ) + ".";
			/* Duty cycle. May be overridden by AutoUntrip. */
			var t = Math.round( period * duty / 100.0 );
			if ( autountrip > 0 && autountrip < t ) {
				msg += " AutoUntrip is set to " + autountrip + " and will fire before the duty cycle specified.";
			} else {
				msg += " The sensor will be tripped for about " + t + " seconds of every period.";
			}
		}
		if ( period > 0 && interval > ( period / 8.0 ) ) {
			msg += " Your update interval may be a bit long (or your period too short) to produce a good range of values.";
			jQuery("span#intervalreq").text( isNaN(period) ? "5" : Math.min( 5, Math.max( 1, Math.floor( period / 40 ) ) ) );
		}
		el.text(msg);
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
			html += ".tb-cgroup { padding: 0px 16px 0px 0px; }";
			html += ".tb-large { font-size: 1.5em; }";
			html += ".tb-medium { font-size: 1.2em; }";
			html += ".tb-red { color: red !important; font-weight: bold; }";
			html += "div#message { color: #00a652; }";
			html += "</style>";

			html += '<div class="tb-large">';
			html += '<img src="https://www.toggledbits.com/assets/virtualsensor/sine.png" align="right" width="329" height="240">VirtualSensor generates sensor values as a sine wave. You can specify the period (1), peak amplitude (2), and midline (3) of the wave.';
			html += '</div>';

			html += '<div class="row">';

			// Period
			html += "<div class=\"tb-cgroup pull-left\">";
			html += "<h2>Period</h2><label for=\"period\">This is the number of seconds the function will take to make a full cycle (that is, from 0 to <i>t</i> on the graph at right). If 0, the simulator is disabled and will not generate values.</label><br/>";
			html += "<input type=\"text\" size=\"5\" maxlength=\"5\" class=\"numfield\" id=\"period\" />";
			html += "</div>";

			// Amplitude
			html += "<div class=\"tb-cgroup pull-left\">";
			html += "<h2>Amplitude</h2><label for=\"amplitude\">Enter the peak amplitude (how far above/below the midline values may go):</label><br/>";
			html += "<input type=\"text\" size=\"8\" class=\"numfield\" id=\"amplitude\" />";
			html += "</div>";

			// Midline
			html += "<div class=\"tb-cgroup pull-left\">";
			html += "<h2>Midline</h2><label for=\"midline\">Enter the midline value:</label><br/>";
			html += "<input type=\"text\" size=\"8\" class=\"numfield\" id=\"midline\" />";
			html += "</div>";

			html += '</div><div class="row">';

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
			html += "<h2>Precision</h2><label for=\"prec\">Select the decimal precision of the sample values:</label><br/>";
			html += "<select id='prec'><option value='5'>0.00000</option>";
			html += '<option value="4">0.0000</option>';
			html += '<option value="3">0.000</option>';
			html += '<option value="2">0.00 (default)</option>';
			html += '<option value="1">0.0</option>';
			html += '<option value="0">0</option>';
			html += '</select>';
			html += "</div>";

			html += '</div><div class="row">';

			/* html += "<div class=\"clearfix\"></div>"; */

			html += '<div class="tb-large" id="message">&nbsp;</div>';

			html += '<div class="tb-medium">';
			html += 'To create a range of 0 to 100% (humidity, for example), set midline=50, amplitude=50.';
			html += ' For a temperature range of 65&deg;F to 85&deg;F, set midline=75, amplitude=10.';
			html += ' Note that due to the resolution of the timer, the full range of values may not be seen, including the mathematical min/max.';
			html += '</div>';

			html += footer();

			// Push generated HTML to page
			api.setCpanelContent(html);

			// Restore values
			var s;
			s = parseInt(api.getDeviceState(myDevice, serviceId, "Interval"));
			if (isNaN(s))
				s = "120";
			jQuery("input#interval").val(s).change( function( obj ) {
				var newInterval = jQuery(this).val();
				if (newInterval.match(/^[0-9]+$/) && newInterval > 0) {
					api.setDeviceStatePersistent(myDevice, serviceId, "Interval", newInterval, 0);
				}
				updateMessage( myDevice );
			});

			s = parseInt(api.getDeviceState(myDevice, serviceId, "Period"));
			if (isNaN(s))
				s = "0";
			jQuery("input#period").val(s).change( function( obj ) {
				var newVal = jQuery(this).val();
				if (newVal.match(/^[0-9]+$/) && newVal >= 0) {
					api.setDeviceStatePersistent(myDevice, serviceId, "Period", newVal, 0);
				}
				updateMessage( myDevice );
			});

			s = parseFloat(api.getDeviceState(myDevice, serviceId, "Amplitude"));
			if (isNaN(s))
				s = "1.0";
			jQuery("input#amplitude").val(s).change( function( obj ) {
				var newVal = parseFloat( jQuery(this).val() );
				if ( ! isNaN( newVal ) ) {
					api.setDeviceStatePersistent(myDevice, serviceId, "Amplitude", newVal, 0);
				}
				updateMessage( myDevice );
			});

			s = parseFloat(api.getDeviceState(myDevice, serviceId, "Midline"));
			if (isNaN(s))
				s = "0.0";
			jQuery("input#midline").val(s).change( function( obj ) {
				var newVal = parseFloat( jQuery(this).val() );
				if ( ! isNaN( newVal ) ) {
					api.setDeviceStatePersistent(myDevice, serviceId, "Midline", newVal, 0);
				}
				updateMessage( myDevice );
			});

			s = parseFloat(api.getDeviceState(myDevice, serviceId, "DutyCycle"));
			if (isNaN(s))
				s = "50.0";
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
					jQuery('select#prec').append( jQuery( '<option>/' ).val( s ).text(s + ' digits (custom)') );
				}
				el.val( s );
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

	/**
	 * Make a service/variable menu of all state defined for the device. Be
	 * brief, using only the variable name in the menu, unless that name is
	 * used by multiple services, in which case the last component of the
	 * serviceId is added parenthetically to draw the distinction.
	 */
	function makeVariableMenu( device, key ) {
		var el = jQuery('<select class="varmenu form-control form-control-sm"></select>');
		var myid = api.getCpanelDeviceId();
		var devobj = api.getDeviceObject( device );
		if ( devobj ) {
			var mm = {}, ms = [];
			for ( var k=0; k<( devobj.states || []).length; ++k ) {
				var st = devobj.states[k];
				if ( undefined === st.variable || undefined === st.service ) continue;
				/* For self-reference, only allow variables created from configured expressions */
				if ( device == myid && st.service != "urn:toggledbits-com:serviceId:ReactorValues" ) continue;
				var vnm = st.variable.toLowerCase();
				if ( undefined === mm[vnm] ) {
					/* Just use variable name as menu text, unless multiple with same name (collision) */
					mm[vnm] = ms.length;
					ms.push( { text: st.variable, service: st.service,
						variable: st.variable } );
				} else {
					/* Collision. Modify existing element to include service name. */
					var n = mm[vnm];
					ms[n].text = ms[n].variable + ' (' + ms[n].service.replace(/^([^:]+:)+/, "") + ')';
					/* Append new entry (text includes service name) */
					ms.push( { text: st.variable + ' (' +
						st.service.replace(/^([^:]+:)+/, "") + ')',
						service: st.service,
						variable: st.variable
					} );
				}
			}
			var r = ms.sort( function( a, b ) {
				/* ??? <=> */
				if ( a.text.toLowerCase() === b.text.toLowerCase() ) return 0;
				return a.text.toLowerCase() < b.text.toLowerCase() ? -1 : 1;
			});
			r.forEach( function( sv ) {
				el.append( '<option value="' + sv.service + '/' + sv.variable + '">' + sv.text + '</option>' );
			});
			if ( 0 === r.length ) {
				el.append( '<option value="" disabled>(no eligible variables)</option>' );
			}
		}

		if ( ( key || "" ) !== "" ) {
			var opt = jQuery( 'option[value="' + key + '"]', el );
			if ( opt.length === 0 ) {
				el.append( jQuery('<option/>').val( key ).text( key + "???" ).prop( 'selected', true ) );
			} else {
				el.val( key );
			}
		}
		return el;
	}

	function handleVariableChange( ev ) {
		var el = jQuery( ev.currentTarget );
		var row = el.closest( 'div.row' );
		var vsdevice = parseInt( row.attr( 'id' ) );
		var device = parseInt( jQuery( 'select.devicemenu', row ).val() );
		var vs = el.val();
		var variable = vs.replace( /^[^\/]+\//, "" );
		var service = vs.replace( /\/.*$/, "" );
		/* First the device */
		api.setDeviceStateVariablePersistent( vsdevice, serviceId, "SourceDevice", isNaN( device ) ? "" : device,
		{
			'onSuccess' : function() {
				/* ...then service ID */
				api.setDeviceStateVariablePersistent( vsdevice, serviceId, "SourceServiceId", service || "",
				{
					'onSuccess' : function() {
						/* Variable MUST be last. */
						api.setDeviceStateVariablePersistent( vsdevice, serviceId, "SourceVariable", variable || "",
						{
							'onSuccess' : function() {
							}
						});
					}
				});
			},
			'onFailure' : function() {
				alert('There was a problem saving the configuration. Vera/Luup may have been restarting. Please try again in 5-10 seconds.');
			}
		});
	}

	function handleDeviceChange( ev ) {
		var el = jQuery( ev.currentTarget );
		var row = el.closest( 'div.row' );
		var device = parseInt( el.val() );
		var vm = jQuery( 'select.varmenu', row );
		vm.empty();
		if ( ! isNaN(device) ) {
			var m = makeVariableMenu( device );
			jQuery( 'select.varmenu', row ).append( m.children() );
		}
		vm.change();
	}

	function waitForReload() {
		jQuery.ajax({
			url: api.getDataRequestURL(),
			data: {
				id: "status",
				DeviceNum: api.getCpanelDeviceId(),
				output_format: "json"
			},
			dataType: "json",
			timeout: 5000
		}).done( function( data, statusText, jqXHR ) {
			var key = "Device_Num_" + api.getCpanelDeviceId();
			if ( data[key] && -1 === parseInt( data[key].status ) ) {
				setTimeout( redrawChildren, 2000 );
			} else {
				jQuery( 'div#vs-content div#notice' ).append( "&ndash;" );
				setTimeout( waitForReload, 1000 );
			}
		}).fail( function( jqXHR, textStatus, errorThrown ) {
			jQuery( 'div#vs-content div#notice' ).append( "&bull;" );
			setTimeout( waitForReload, 2000 );
		});
	}

	function handleAddChildClick( ev ) {
		var el = jQuery( ev.currentTarget );
		var row = el.closest( 'div.row' );
		var childType = jQuery( 'select#childtype', row ).val() || "";
		if ( "" !== childType ) {
			api.performActionOnDevice( api.getCpanelDeviceId(), serviceId, "AddChild", {
				actionArguments: { NewChildDeviceType: childType },
				onSuccess: function( xhr ) {
					el.prop( 'disabled', true );
					jQuery( 'div#notice', row ).text("Creating child... please wait while Luup reloads...");
					setTimeout( waitForReload, 5000 );
				},
				onFailure: function( xhr ) {
					alert( "An error occurred. Try again in a moment; Vera may be busy." );
				}
			} );
		} else {
			jQuery( 'div#notice', row ).text("Wählen Sie zuerst einen Typ!");
		}
	}

	function redrawChildren() {
		var myDevice = api.getCpanelDeviceId();
		var devices = api.cloneObject( api.getListOfDevices() );
		var mm = jQuery( '<select class="devicemenu form-control form-control-sm" />' );
		mm.append( '<option value="">--choose device--</option>' );
		devices.sort( function( a, b ) {
			if ( (a.name || "").toLowerCase() == (b.name || "").toLowerCase() ) {
				return 0;
			}
			return (a.name || "").toLowerCase() < (b.name || "").toLowerCase() ? -1 : 1;
		});
		for ( var ix=0; ix<(devices || []).length; ix++ ) {
			var opt = jQuery( '<option/>');
			opt.val( devices[ix].id );
			opt.text( devices[ix].name + " (#" + devices[ix].id + ")" );
			mm.append( opt );
		}

		var container = jQuery( 'div#vs-content' ).empty();
		var count = 0;
		var row = jQuery( '<div class="row vshead" />' );
		row.append( '<div class="col-xs-12 col-sm-6 col-lg-3">Virtual Sensor Name (Id)</div>' );
		row.append( '<div class="col-xs-12 col-sm-6 col-lg-9">Source Device/Value</div>' );
		container.append( row );
		for ( ix=0; ix<(devices || []).length; ix++ ) {
			var v = devices[ix];
			if ( v.id_parent == myDevice ) {
				row = jQuery( '<div class="row" />' );
				row.attr( 'id', v.id );

				var col = jQuery( '<div class="col-xs-12 col-sm-6 col-lg-3 vsname" />' );
				row.append( col.text( v.name + ' (#' + v.id + ')' ) );

				/* Device menu for row */
				col = jQuery( '<div class="col-xs-12 col-sm-6 col-lg-9 form-inline" />' );
				var sourcedevice = parseInt( api.getDeviceStateVariable( v.id, serviceId, "SourceDevice" ) || "-1" );
				var dm = mm.clone();
				if ( jQuery( 'option [value="' + sourcedevice + '"]' ).length == 0 ) {
					dm.append( jQuery( '<option/>' ).val( sourcedevice ).text( "Missing device " + sourcedevice ) );
				}
				dm.val( sourcedevice );
				col.append( dm );
				dm.on( 'change.vsensor', handleDeviceChange );

				/* Variable menu for row */
				var service = api.getDeviceStateVariable( v.id, serviceId, "SourceServiceId" ) || "";
				var variable = api.getDeviceStateVariable( v.id, serviceId, "SourceVariable" ) || "";
				var key = service + "/" + variable;
				dm = makeVariableMenu( sourcedevice, key );
				col.append( dm );
				dm.on( 'change.vsensor', handleVariableChange );

				row.append( col );

				container.append( row );
				++count;
			}
		}

		var enab = 0 !== parseInt( api.getDeviceStateVariable( myDevice, serviceId, "Enabled" ) || "0" );
		if ( !enab ) {
			container.append( '<div class="row"><div class="col-xs-12 col-sm-12"><span style="color: red;">NOTE: This instance is currently disabled--virtual sensor values do not update when the parent instance is disabled.</span></div></div>' );
		} else {
			row = jQuery( '<div class="row vscontrol" />' );
			var br = jQuery( '<div class="col-xs-12 col-sm-12 form-inline" />' );
			var sel = jQuery( '<select id="childtype" class="form-control form-control-sm" />' );
			sel.append( jQuery( '<option/>' ).val("").text('--choose type--') ).val( "" ); /* default */
			br.append( sel );
			br.append( '<button id="addchild" class="btn btn-md btn-primary">Create New Virtual Sensor</button>' );
			br.append( '<div id="notice" />' );
			container.append( row.append( br ) );
			/* Now, populate the menu */
			jQuery( 'button#addchild', container ).on( 'click.virtualsensor', handleAddChildClick ).prop( 'disabled', true );
			jQuery.ajax({
				url: api.getDataRequestURL(),
				data: {
					id: "lr_VirtualSensor",
					action: "getvtypes"
				},
				dataType: "json",
				timeout: 5000
			}).done( function( data, statusText, jqXHR ) {
				var hasOne = false;
				var childMenu = jQuery( 'div#vs-content select#childtype' );
				for ( var ch in data ) {
					if ( data.hasOwnProperty( ch ) ) {
						childMenu.append( jQuery( '<option/>' ).val( ch ).text( data[ch].name || ch ) );
						hasOne = true;
					}
				}
				if ( hasOne ) {
					jQuery( 'div#vs-content button#addchild' ).prop( 'disabled', false );
				}
			}).fail( function( jqXHR ) {
				alert( "There was an error loading configuration data. Vera may be busy; try again in a moment." );
			});
		}
	}

	function doVirtualSensors() {
		try {
			initPlugin();

			var html = '<style>';
			html += 'div#vs-content .vshead { background-color: #428bca; color: #fff; min-height: 42px; font-size: 16px; font-weight: bold; line-height: 1.5em; padding: 8px 0; }';
			html += 'div#vs-content .vsname { padding: 8px 0; }';
			html += 'div#vs-content div.vscontrol { border-top: 1px solid black; padding: 8px 0; }';
			html += '</style>';
			jQuery( 'head' ).append( html );

			html = '<div id="vs-content" />';
			html += footer();
			api.setCpanelContent( html );

			redrawChildren();
		}
		catch (e)
		{
			alert(String(e));
			Utils.logError('Error in VirtualSensor.configurePlugin(): ' + e);
		}
	}

	myModule = {
		uuid: uuid,
		initPlugin: initPlugin,
		onBeforeCpanelClose: onBeforeCpanelClose,
		configurePlugin: configurePlugin,
		doVirtualSensors: doVirtualSensors
	};
	return myModule;
})(api);

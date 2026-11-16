var rotor_wash_loop = func {

    # water and grass shader effect
    var vpos = geo.viewer_position();
    var apos = geo.aircraft_position();

    var lat_to_m = 110952.0;
    var lon_to_m = math.cos(apos.lat() * math.pi / 180.0) * lat_to_m;

    # altitude AGL; default 1 ft to avoid division by zero / nil
    var alt = getprop("/position/altitude-agl-ft") or 1.0;

    var delta_x = (apos.lat() - vpos.lat()) * lat_to_m;
    var delta_y = -(apos.lon() - vpos.lon()) * lon_to_m;

    setprop("/environment/aircraft-effects/wash-x", delta_x);
    setprop("/environment/aircraft-effects/wash-y", delta_y);

    # rotor rpm; default 0 if missing
    var rpm = getprop("rotors/main/rpm") or 0.0;
    var rpm_factor = rpm / 280.0;

    var strength = 20.0 / alt;
    if (strength > 1.0) strength = 1.0;
    strength = strength * rpm_factor;

    setprop("/environment/aircraft-effects/wash-strength", strength);

    # particle effect colors
    var land = getprop("/gear/gear/ground-is-solid") or 0;

    # scene diffuse red; default 1.0 if missing
    var red_diffuse = getprop("/rendering/scene/diffuse/red") or 1.0;

    if (land) {
        setprop("/sim/model/bo105/effects/particles/rotorwash/redcombinedstart",   red_diffuse * 0.4);
        setprop("/sim/model/bo105/effects/particles/rotorwash/greencombinedstart", red_diffuse * 0.4);
        setprop("/sim/model/bo105/effects/particles/rotorwash/bluecombinedstart",  red_diffuse * 0.4);
        setprop("/sim/model/bo105/effects/particles/rotorwash/redcombinedend",     red_diffuse * 0.7);
        setprop("/sim/model/bo105/effects/particles/rotorwash/greencombinedend",   red_diffuse * 0.7);
        setprop("/sim/model/bo105/effects/particles/rotorwash/bluecombinedend",    red_diffuse * 0.7);
    } else {
        setprop("/sim/model/bo105/effects/particles/rotorwash/redcombinedstart",   red_diffuse * 0.65);
        setprop("/sim/model/bo105/effects/particles/rotorwash/greencombinedstart", red_diffuse * 0.80);
        setprop("/sim/model/bo105/effects/particles/rotorwash/bluecombinedstart",  red_diffuse * 0.75);
        setprop("/sim/model/bo105/effects/particles/rotorwash/redcombinedend",     red_diffuse * 0.85);
        setprop("/sim/model/bo105/effects/particles/rotorwash/greencombinedend",   red_diffuse * 1.0);
        setprop("/sim/model/bo105/effects/particles/rotorwash/bluecombinedend",    red_diffuse * 0.90);
    }

    # schedule next update
    settimer(func { rotor_wash_loop(); }, 0);
}

# start the loop once the FDM is initialized
setlistener("/sim/signals/fdm-initialized", func {
    rotor_wash_loop();
}, 1);

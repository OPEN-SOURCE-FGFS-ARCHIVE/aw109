var DEBUG = 1;
var (width,height) = (768,512);
var tile_size = 256;
var alpha = 1;
var zoom = 12;  # Set to show ~20 NM
var gps_map = nil;
var bright = 1;

var types = [
    {
        minmaxzoom: [2,19],
        type: "intl",
        urlTemplate: "https://a.tile.openstreetmap.de/{z}/{x}/{y}.png",
        urlPath: "/osm-{type}/{z}/{x}/{y}.png"
    },
    {
        minmaxzoom: [2,14],
        type: "terrain",
        urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
        urlPath: "/{z}/{x}/{y}.png"
    }
];

var currentTypeID = 0;

var show_map = func() {
    var window = canvas.new({
        "name": "GPSMap",
        "size": [width, height],
        "view": [width, height],
        "mipmapping": 1
    });

    window.addPlacement({"node": "FGBR_GPS_SCREEN"});
    var g = window.createGroup();
    g.setVisible(1);

    var type = types[currentTypeID].type;

    var ui_root = window.createGroup();
    var vbox = canvas.VBoxLayout.new();
    window.setLayout(vbox);

    var changeZoom = func(d) {
        if(DEBUG) print("changeZoom called with delta: ", d);
        zoom = math.max(types[currentTypeID].minmaxzoom[0], math.min(types[currentTypeID].minmaxzoom[1], zoom + d));
        updateTiles();
        if(DEBUG) print("New Zoom: ", zoom);
    }

    var changeAlpha = func(d) {
        alpha = math.max(0, math.min(1, alpha + d));
        window.setColorBackground(1,1,1, alpha);
    }

    var changeBright = func(d) {
        if(DEBUG) print("changeBright called with delta: ", d);
        bright = math.max(0, math.min(1, bright + d));
        setprop("/instrumentation/GPSMap/bright", bright);
    }

    var changeType = func() {
        if(DEBUG) print("changeType called");
        if (currentTypeID == 0) currentTypeID = 1; else currentTypeID = 0;
        type = types[currentTypeID].type;
        if (zoom > types[currentTypeID].minmaxzoom[1]) zoom = types[currentTypeID].minmaxzoom[1];
        if (zoom < types[currentTypeID].minmaxzoom[0]) zoom = types[currentTypeID].minmaxzoom[0];
        updateTiles();
    }

    var maps_base = getprop("/sim/fg-home") ~ '/cache/maps';

    foreach(var type; types) {
        type.makeUrl = string.compileTemplate(type.urlTemplate);
        type.makePath = string.compileTemplate(maps_base ~ type.urlPath);
    }

    var num_tiles = [4, 3];
    var center_tile_offset = [
        (num_tiles[0] - 1) / 2,
        (num_tiles[1] - 1) / 2
    ];

    var filename = "Aircraft/R44/Models/Interior/Panel/Instruments/RenanGPSMap/svg/boeingAirplane.svg";
    var airplane_symbol = ui_root.createChild('group');
    canvas.parsesvg(airplane_symbol, filename);
    airplane_symbol.getElementById("path3783").setColor(1,0,0);
    airplane_symbol.setTranslation(width/2,height/2);
    airplane_symbol.setScale(.5);

    var filename = "Aircraft/R44/Models/Interior/Panel/Instruments/RenanGPSMap/svg/gpslayout.svg";
    var gpslayout = ui_root.createChild('group');
    canvas.parsesvg(gpslayout, filename);
    gpslayout.setTranslation(79,height - 79);
    gpslayout.setScale(.8);

    var tiles = setsize([], num_tiles[0]);
    for(var x = 0; x < num_tiles[0]; x += 1) {
        tiles[x] = setsize([], num_tiles[1]);
        for(var y = 0; y < num_tiles[1]; y += 1)
            tiles[x][y] = g.createChild("image", "map-tile")
                .setSize(tile_size, tile_size);
    }

    var last_tile = [-1,-1];
    var last_type = types[currentTypeID].type;

    var updateTiles = func() {
        if (getprop("/instrumentation/GPSMap/eletric") == 0) return;

        if(DEBUG) print("UpdateTiles called - Zoom: ", zoom, " Group visible: ", g.get("visible"));

        var lat = getprop('/position/latitude-deg');
        var lon = getprop('/position/longitude-deg');

        var DEG2RAD = 0.0174533;
        var hdg = getprop("/orientation/heading-deg") * DEG2RAD;
        var bearing = getprop("/instrumentation/gps/wp/wp[1]/bearing-true-deg");
        if (bearing == -9999) bearing = 0;
        bearing = bearing * DEG2RAD;

        # Debug output for arrow
        if(DEBUG) {
            print("Heading (rad): ", hdg, " Bearing (rad): ", bearing);
            var arrow_elem = gpslayout.getElementById("arrow");
            if (arrow_elem == nil) {
                print("Error: 'arrow' element not found in gpslayout.svg");
            } else {
                print("Arrow element found, setting rotation to: ", bearing);
            }
        }

        airplane_symbol.setRotation(hdg);
        gpslayout.getElementById("arrow").setRotation(bearing);
        gpslayout.getElementById("waypoint").setText(getprop("/instrumentation/gps/wp/wp[1]/ID"));
        gpslayout.getElementById("distance").setText(int(getprop("/instrumentation/gps/wp/wp[1]/distance-nm")) ~ " NM");
        gpslayout.getElementById("hdg").setText(int(getprop("/orientation/heading-deg")) ~ "");
        gpslayout.getElementById("coords").setText(getprop("/position/latitude-string") ~ " " ~ getprop("/position/longitude-string"));

        var n = math.pow(2, zoom);
        var offset = [
            n * ((lon + 180) / 360) - center_tile_offset[0],
            (1 - math.ln(math.tan(lat * math.pi/180) + 1 / math.cos(lat * math.pi/180)) / math.pi) / 2 * n - center_tile_offset[1]
        ];
        var tile_index = [int(offset[0]), int(offset[1])];

        var ox = tile_index[0] - offset[0];
        var oy = tile_index[1] - offset[1];

        for(var x = 0; x < num_tiles[0]; x += 1)
            for(var y = 0; y < num_tiles[1]; y += 1)
                tiles[x][y].setTranslation(int((ox + x) * tile_size + 0.5), int((oy + y) * tile_size + 0.5));

        if( tile_index[0] != last_tile[0]
            or tile_index[1] != last_tile[1]
            or types[currentTypeID].type != last_type )
        {
            for(var x = 0; x < num_tiles[0]; x += 1)
                for(var y = 0; y < num_tiles[1]; y += 1) {
                    var pos = {
                        z: zoom,
                        x: int(offset[0] + x),
                        y: int(offset[1] + y),
                        type: types[currentTypeID].type
                    };

                    (func {
                        var img_path = types[currentTypeID].makePath(pos);
                        var tile = tiles[x][y];

                        if( io.stat(img_path) == nil ) {
                            var img_url = types[currentTypeID].makeUrl(pos);
                            http.save(img_url, img_path)
                                .done(func { tile.set("src", img_path); tile.setVisible(1); })
                                .fail(func(r) { });
                        } else {
                            tile.set("src", img_path);
                            tile.setVisible(1);
                        }
                    })();
                }

            last_tile = tile_index;
            last_type = type;
        }
    };

    var update_timer = maketimer(2, updateTiles);
    update_timer.start();

    changeZoom(0);

    window.del = func() {
        print("Cleaning up GPSMap window");
        update_timer.stop();
        call(canvas.Window.del, [], me);
    };

    return {
        window: window,
        changeZoom: changeZoom,
        changeAlpha: changeAlpha,
        changeBright: changeBright,
        changeType: changeType,
        updateTiles: updateTiles
    };
}

gps_map = show_map();

var fdm_init_listener = _setlistener("/sim/signals/fdm-initialized", func {
    removelistener(fdm_init_listener);
    setprop("/instrumentation/GPSMap/eletric", 0);
    setprop("/instrumentation/GPSMap/bright", 1);
});

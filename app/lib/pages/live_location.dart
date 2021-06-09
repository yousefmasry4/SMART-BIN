import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_example/widgets/sla.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

//_animatedMapMove(london, 10.0);
class LiveLocationPage extends StatefulWidget {
  static const String route = '/live_location';

  @override
  _LiveLocationPageState createState() => _LiveLocationPageState();
}
List k=[];
String xxx;
class _LiveLocationPageState extends State<LiveLocationPage>
    with TickerProviderStateMixin {
  var _firebaseRef = FirebaseDatabase().reference().child('bins');
  TextEditingController _txtCtrl = TextEditingController();

  LocationData _currentLocation;
  MapController _mapController;
  var dataAll = <Marker>[];
  bool _liveUpdate = true;
  bool _permission = false;

  String _serviceError = '';

  var interActiveFlags = InteractiveFlag.all;

  final Location _locationService = Location();

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    initLocationService();
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    super.dispose();
  }

  static LatLng london = LatLng(51.5, -0.09);

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    // Create some tweens. These serve to split up the transition from one location to another.
    // In our case, we want to split the transition be<tween> our current map center and the destination.
    final _latTween = Tween<double>(
        begin: _mapController.center.latitude, end: destLocation.latitude);
    final _lngTween = Tween<double>(
        begin: _mapController.center.longitude, end: destLocation.longitude);
    final _zoomTween = Tween<double>(begin: _mapController.zoom, end: destZoom);

    // Create a animation controller that has a duration and a TickerProvider.
    var controller = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    // The animation determines what path the animation will take. You can try different Curves values, although I found
    // fastOutSlowIn to be my favorite.
    Animation<double> animation =
        CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn);

    controller.addListener(() {
      _mapController.move(
          LatLng(_latTween.evaluate(animation), _lngTween.evaluate(animation)),
          _zoomTween.evaluate(animation));
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
      } else if (status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  void initLocationService() async {
    await _locationService.changeSettings(
      accuracy: LocationAccuracy.HIGH,
      interval: 1000,
    );

    LocationData location;
    bool serviceEnabled;
    bool serviceRequestResult;

    try {
      serviceEnabled = await _locationService.serviceEnabled();

      if (serviceEnabled) {
        var permission = await _locationService.requestPermission();
        _permission = permission == PermissionStatus.GRANTED;

        if (_permission) {
          location = await _locationService.getLocation();
          _currentLocation = location;
          _locationService
              .onLocationChanged()
              .listen((LocationData result) async {
            if (mounted) {
              setState(() {
                _currentLocation = result;

                // If Live Update is enabled, move map center
                if (_liveUpdate) {
                  _mapController.move(
                      LatLng(_currentLocation.latitude,
                          _currentLocation.longitude),
                      _mapController.zoom);
                }
              });
            }
          });
        }
      } else {
        serviceRequestResult = await _locationService.requestService();
        if (serviceRequestResult) {
          initLocationService();
          return;
        }
      }
    } on PlatformException catch (e) {
      print(e);
      if (e.code == 'PERMISSION_DENIED') {
        _serviceError = e.message;
      } else if (e.code == 'SERVICE_STATUS_ERROR') {
        _serviceError = e.message;
      }
      location = null;
    }
  }

  LatLng currentLatLng = LatLng(0, 0);
  var markers = <Marker>[
    Marker(
      width: 80.0,
      height: 80.0,
      point: LatLng(51.5, -0.09),
    ),
    Marker(
      width: 80.0,
      height: 80.0,
      point: LatLng(75, -0.09),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Until currentLocation is initially updated, Widget can locate to 0, 0
    // by default or store previous location value to show.

    return Scaffold(
      appBar: AppBar(title: Text('SMART BIN')),
      body: Container(
        height: MediaQuery.of(context).size.height - 300,
        padding: EdgeInsets.all(8.0),
        child: Column(
          children: [
            /* Padding(
              padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
              child: _serviceError.isEmpty
                  ? Text('This is a map that is showing '
                      '(${currentLatLng.latitude}, ${currentLatLng.longitude}).')
                  : Text(
                      'Error occured while acquiring location. Error Message : '
                      '$_serviceError'),
            ),*/
            Flexible(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  center:
                      LatLng(currentLatLng.latitude, currentLatLng.longitude),
                  zoom: 5.0,
                  interactiveFlags: interActiveFlags,
                ),
                layers: [
                  TileLayerOptions(
                    urlTemplate:
                        'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: ['a', 'b', 'c'],
                    // For example purposes. It is recommended to use
                    // TileProvider with a caching and retry strategy, like
                    // NetworkTileProvider or CachedNetworkTileProvider
                    tileProvider: NonCachingNetworkTileProvider(),
                  ),
                  MarkerLayerOptions(markers: markers)
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Builder(builder: (BuildContext context) {
        return FloatingActionButton(
          onPressed: () {
            setState(() {
              _liveUpdate=!_liveUpdate;
              currentLatLng =
                  LatLng(_currentLocation.latitude, _currentLocation.longitude);
              if (_liveUpdate) {
                interActiveFlags = InteractiveFlag.rotate |
                    InteractiveFlag.pinchZoom |
                    InteractiveFlag.doubleTapZoom;


                markers[0] = Marker(
                  width: 80.0,
                  height: 80.0,
                  point: currentLatLng,
                  builder: (ctx) => Container(
                    child: Icon(
                      Icons.directions_car_sharp,
                      color: Colors.blueAccent,
                      size: 40,
                    ),
                  ),
                );
              } else {
                interActiveFlags = InteractiveFlag.all;
              }
            });
          },
          child:
              _liveUpdate ? Icon(Icons.location_on) : Icon(Icons.location_off),
        );
      }),
      //_animatedMapMove(london, 10.0);
      bottomSheet: Container(
        height: 300,
        child: ListView(
          padding: EdgeInsets.only(top: 40, left: 15, right: 15),
          children: [
            TextFormField(
              keyboardType: TextInputType.visiblePassword,
              //  controller: accountController,
              //  maxLength: 1,
              onChanged: (d) {
                setState(() {
                  xxx=d;
                });
              },
              decoration: InputDecoration(
                labelText: "Add bin id",

                //   helperText: "helperTxt",
                prefixIcon: Icon(
                  Icons.add,
                  color: Colors.black45,
                ),
                suffix: InkWell(
                  child: Icon(
                    Icons.add_box,
                    color: Colors.blueAccent,
                  ),
                  onTap: () {
                    setState(() {
                      _liveUpdate=false;
                      k.add(xxx);
                    });
                  },
                ),

                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28.0),
                  borderSide: BorderSide(
                    color: Colors.black,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28.0),
                  borderSide: BorderSide(
                    color: Colors.yellow,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 10,
            ),
            Text(
              "Garbage bins",
              maxLines: 1,
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            SizedBox(
              height: 10,
            ),
            StreamBuilder(
              stream: _firebaseRef.onValue,
              builder: (context, snap) {
                if (snap.hasData &&
                    !snap.hasError &&
                    snap.data.snapshot.value != null) {
                  Map data = snap.data.snapshot.value;
                  List item = [];
                  data.forEach(
                      (index, data) => item.add({"id": index, ...data})
                  );

                  print(item);
                  int i = -1;
                  return Column(
                    children: [
                      ...item.map((e) => k.contains(e["id"])? ListTile(
                            onTap: () {
                              _animatedMapMove(LatLng(e["lat"]*1.0, e["lang"]*1.0), 5.0);

                              setState(() {
                                markers[1] = Marker(
                                  width: 80.0,
                                  height: 80.0,
                                  point: LatLng( e["lat"]*1.0, e["lang"]*1.0),
                                  builder: (ctx) => Container(
                                    child: Icon(
                                      Icons.delete,
                                      color: e["state"] == 1?Colors.red:Colors.green,
                                      size: 40,
                                    ),
                                  ),
                                );
                              });
                            },
                            title: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(
                                      color: e["state"] == 1
                                          ? Colors.pink[800]
                                          : Colors
                                              .green[800], // set border color
                                      width: 3.0), // set border width
                                  borderRadius: BorderRadius.all(
                                      Radius.circular(
                                          10.0)), // set rounded corner radius
                                  boxShadow: [
                                    BoxShadow(
                                        blurRadius: 5,
                                        color: Colors.black,
                                        offset: Offset(0.5, 1))
                                  ] // make rounded corner of border
                                  ),
                              child: Row(children: <Widget>[
                                Container(
                                  padding: EdgeInsets.only(left: 13),
                                  child: Text(
                                    e["name"],
                                    style: TextStyle(
                                      fontSize: 25.0,
                                      color: Colors.black,
                                    ),
                                  ),
                                )
                              ]),
                            ),
                          ):Container()
                      )
                    ],
                  );
                } else
                  return Text("No data");
              },
            ),
          ],
        ),
      ),
    );
  }
}

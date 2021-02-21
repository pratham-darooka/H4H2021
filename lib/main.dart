import 'dart:io';

import 'package:camera/camera.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

List<CameraDescription> cameras;
CameraDescription camera;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  try {
    cameras = await availableCameras();
    camera = cameras.first;
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      await Geolocator.requestPermission();
    }
  } catch (e) {
    print(e);
  }
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((value) => runApp(MyApp()));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => HomePage(),
        '/drop': (context) => DropPage(),
        '/pickup': (context) => PickupPage(),
      },
    );
  }
}

class HomePage extends StatefulWidget {
  HomePage({Key key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Food Alert'),
      ),
      body: Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          Spacer(),
          Icon(
            Icons.food_bank,
            size: MediaQuery.of(context).size.width * 0.4,
          ),
          SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton.extended(
                onPressed: () {
                  Navigator.pushNamed(context, '/drop');
                },
                icon: Icon(Icons.pin_drop),
                label: const Text('Drop Off'),
                heroTag: null,
              ),
              FloatingActionButton.extended(
                onPressed: () {
                  Navigator.pushNamed(context, '/pickup');
                },
                icon: Icon(Icons.fastfood),
                label: const Text('Pick Up'),
                heroTag: null,
              ),
            ],
          ),
          Spacer(),
          IconButton(icon: Icon(Icons.info), onPressed: () {}),
          SizedBox(
            height: 20,
          )
        ],
      )),
    );
  }
}

//Drop Page
class DropPage extends StatefulWidget {
  DropPage({Key key}) : super(key: key);

  @override
  _DropPageState createState() => _DropPageState();
}

class _DropPageState extends State<DropPage> {
  GoogleMapController mapController;
  CameraController cameraController;
  TextEditingController descriptionController = new TextEditingController();
  Future<void> initializeControllerFuture;
  LatLng currentPosition = LatLng(20, 20);
  LatLng selectedPosition = LatLng(20, 20);
  Map<MarkerId, Marker> markers = <MarkerId, Marker>{};
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  FirebaseStorage storage = FirebaseStorage.instance;
  File image;

  void getCurrentPosition() async {
    var latlng = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best);

    this.setState(() {
      currentPosition = LatLng(latlng.latitude, latlng.longitude);
      selectedPosition = LatLng(latlng.latitude, latlng.longitude);
      markers.clear();
      markers[MarkerId('user')] = new Marker(
          markerId: MarkerId('user'),
          position: currentPosition,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen));
      mapController.moveCamera(CameraUpdate.newLatLng(currentPosition));
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  void initState() {
    super.initState();
    getCurrentPosition();
    cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
    );
    initializeControllerFuture = cameraController.initialize();
  }

  @override
  void dispose() {
    cameraController.dispose();
    mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Drop Food'),
        ),
        body: Center(
          child: Stack(
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                child: GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: currentPosition,
                    zoom: 18.0,
                  ),
                  mapToolbarEnabled: false,
                  zoomControlsEnabled: false,
                  mapType: MapType.normal,
                  markers: Set<Marker>.of(markers.values),
                  onCameraMove: (CameraPosition position) {
                    this.setState(() {
                      markers[MarkerId('dest')] = new Marker(
                          markerId: MarkerId('dest'),
                          position: position.target);
                      selectedPosition = position.target;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              onPressed: () {
                showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return Dialog(
                        child: Container(
                          margin: const EdgeInsets.all(20),
                          child: Form(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextFormField(
                                  controller: descriptionController,
                                  decoration: InputDecoration(
                                    hintText: 'Food Description',
                                  ),
                                ),
                                SizedBox(height: 20),
                                FloatingActionButton(
                                  onPressed: () {
                                    showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return Dialog(
                                            child: Container(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  CameraPreview(
                                                      cameraController),
                                                  Container(
                                                    margin: EdgeInsets.all(10),
                                                    child: FloatingActionButton(
                                                      onPressed: () async {
                                                        try {
                                                          await initializeControllerFuture;
                                                          XFile temp =
                                                              await cameraController
                                                                  .takePicture();
                                                          image =
                                                              File(temp.path);
                                                        } catch (e) {}
                                                        Navigator.pop(context);
                                                      },
                                                      child: Icon(Icons.camera),
                                                    ),
                                                  )
                                                ],
                                              ),
                                            ),
                                          );
                                        });
                                  },
                                  child: Icon(Icons.camera_alt),
                                ),
                                SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: () async {
                                    if (Geolocator.distanceBetween(
                                            currentPosition.latitude,
                                            currentPosition.longitude,
                                            selectedPosition.latitude,
                                            selectedPosition.longitude) <
                                        10) {
                                      try {
                                        String image_name =
                                            '${DateTime.now()}.png';

                                        if (image != null) {
                                          await storage
                                              .ref(image_name)
                                              .putFile(image);
                                          await firestore
                                              .collection('food')
                                              .add({
                                            'desc': descriptionController.text,
                                            'lat': selectedPosition.latitude,
                                            'lng': selectedPosition.longitude,
                                            'img': image_name,
                                          });
                                        } else {
                                          await firestore
                                              .collection('food')
                                              .add({
                                            'desc': descriptionController.text,
                                            'lat': selectedPosition.latitude,
                                            'lng': selectedPosition.longitude,
                                            'img': 'none',
                                          });
                                        }
                                      } catch (e) {}
                                      Navigator.pop(context);
                                    } else {
                                      print('outside 10 meters');
                                      showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              title: const Text('Error'),
                                              content: const Text(
                                                  'Please set marker to with in 10 meters of your location.'),
                                            );
                                          });
                                    }
                                  },
                                  child: const Text('Submit'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    });
              },
              child: Icon(Icons.add),
              heroTag: null,
            ),
            SizedBox(
              width: 10,
            ),
            FloatingActionButton(
              onPressed: () {
                getCurrentPosition();
              },
              child: Icon(Icons.location_on),
              heroTag: null,
            ),
          ],
        ));
  }
}

// Pick up page
class PickupPage extends StatefulWidget {
  PickupPage({Key key}) : super(key: key);

  @override
  _PickupPageState createState() => _PickupPageState();
}

class _PickupPageState extends State<PickupPage> {
  GoogleMapController mapController;
  LatLng currentPosition = new LatLng(20, 20);
  Map<MarkerId, Marker> markers = <MarkerId, Marker>{};
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  FirebaseStorage storage = FirebaseStorage.instance;

  void getCurrentPosition() async {
    LocationPermission perm = await Geolocator.checkPermission();
    print(perm);
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      await Geolocator.requestPermission();
    }
    var latlng = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best);

    this.setState(() {
      currentPosition = LatLng(latlng.latitude, latlng.longitude);
      mapController.moveCamera(CameraUpdate.newLatLng(currentPosition));
    });
  }

  void getFood() async {
    QuerySnapshot s = await firestore.collection('food').get();
    s.docs.forEach((element) async {
      double lat = element['lat'];
      double lng = element['lng'];
      if (Geolocator.distanceBetween(
              lat, lng, currentPosition.latitude, currentPosition.longitude) <
          1000) {
        String desc = element['desc'];
        String img = (element['img'] == 'none')
            ? 'none'
            : await storage.ref(element['img']).getDownloadURL();
        setState(() {
          markers[MarkerId(element.id)] = new Marker(
            markerId: MarkerId(element.id),
            position: LatLng(lat, lng),
            onTap: () {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return Dialog(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        (img != 'none')
                            ? Image.network(img)
                            : Container(
                                margin: EdgeInsets.all(20),
                                child: Icon(Icons.image_not_supported),
                              ),
                        Container(
                          margin: EdgeInsets.all(20),
                          child: Text(desc),
                        ),
                        ElevatedButton(
                            onPressed: () async {
                              await firestore
                                  .doc('food/' + element.id)
                                  .delete();
                              setState(() {
                                markers.remove(MarkerId(element.id));
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('Pickup Item')),
                      ],
                    ),
                  );
                },
              );
            },
          );
        });
      }
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  void initState() {
    super.initState();
    getCurrentPosition();
    getFood();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pick Up'),
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition:
            CameraPosition(target: currentPosition, zoom: 18),
        markers: Set<Marker>.of(markers.values),
        zoomControlsEnabled: false,
      ),
      floatingActionButton: FloatingActionButton(
          onPressed: () {
            getFood();
          },
          child: Icon(Icons.refresh)),
    );
  }
}

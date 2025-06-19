import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(POCTestingWidget());
}

class POCTestingWidget extends StatefulWidget {
  const POCTestingWidget({super.key});

  @override
  _POCTestingWidgetState createState() => _POCTestingWidgetState();
}

class _POCTestingWidgetState extends State<POCTestingWidget> {
  @override
  void initState() {
    super.initState();
    // Call the function to initialize camera or any other resources
    someFunc().then((_) {
      print('Camera initialized successfully');
    }).catchError((error) {
      print('Error initializing camera: $error');
    }).catchError((error) {
      print('Caught an error: $error');
    });
  }

  Future<void> someFunc() async {
    // Initialize the camera or any other resources if needed
    final cameras = await availableCameras();
    print('Available cameras: $cameras');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'POC Testing',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: Scaffold(
          body: Container(
            margin: const EdgeInsets.fromLTRB(0, 50, 0, 0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green, width: 2),
            ),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 2),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(10, 0, 0, 0),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.red, width: 2),
                          ),
                          child: Text('Recommended',
                              style: TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.red, width: 2),
                          ),
                          child: Icon(Icons.account_circle,
                              size: 40, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blue, width: 2),
                        ),
                        child: Center(
                          child: Text('This is a POC testing widget',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blue, width: 2),
                        ),
                        child: Center(
                          child: Text('This is a POC testing widget 2',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w500)),
                        ),
                      ),
                    )
                  ],
                )
              ],
            ),
          ),
        ));
  }
}

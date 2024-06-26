import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'identified_object.dart';
import 'dart:ui' show lerpDouble;
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Lấy danh sách camera có sẵn trên thiết bị
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camera Demo',
      theme: ThemeData.dark(),
      home: RecognizeCamera(camera: cameras[0]),
    );
  }
}

class RecognizeCamera extends StatefulWidget {
  final CameraDescription camera;

  const RecognizeCamera({Key? key, required this.camera}) : super(key: key);

  @override
  _RecognizeCameraState createState() => _RecognizeCameraState();
}

class _RecognizeCameraState extends State<RecognizeCamera> {
  late CameraController _controller;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _controller = CameraController(widget.camera, ResolutionPreset.medium);
    try {
      await _controller.initialize();
      print('Camera initialized');
    } catch (e) {
      print('Error initializing camera: $e');
    }
    if (!mounted) return;

    setState(() {
      _isCameraInitialized = true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _requestStoragePermission() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      var result = await Permission.storage.request();
      if (result.isGranted) {
        print('Storage permission granted');
      } else {
        print('Storage permission denied');
        return;
      }
    } else {
      print('Storage permission already granted');
    }
  }

  void _takePicture() async {
    if (!_isCameraInitialized) {
      print('Camera not initialized yet');
      return;
    }

    await _requestStoragePermission();

    try {
      final XFile picture = await _controller.takePicture();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IdentifiedObject(
            imagePath: picture.path,
            camera: widget.camera,
          ),
        ),
      );
    } catch (e) {
      print("Error taking picture: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF333333),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: Text(''),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(40),
          child: CustomFunctionBar(),
        ),
      ),
      body: Stack(
        children: [
          if (_isCameraInitialized)
            Positioned.fill(
              child: CameraPreview(_controller),
            ),
          if (!_isCameraInitialized) Center(child: CircularProgressIndicator()),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: Size(MediaQuery.of(context).size.width, 60),
              painter: BottomBarPainter(),
              child: Container(
                height: 60,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    GestureDetector(
                      onTap: () {
                        // Add functionality for gallery button
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.circular(5),
                          image: DecorationImage(
                            image: AssetImage('assets/gallery.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 40),
                    IconButton(
                      icon: Icon(Icons.arrow_forward),
                      color: Colors.white,
                      onPressed: () {
                        // Add functionality for next step
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 22,
            left: MediaQuery.of(context).size.width / 2 - 35,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange,
              ),
              child: IconButton(
                icon: Icon(Icons.camera_alt_outlined),
                color: Colors.black,
                iconSize: 35,
                onPressed: _takePicture,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BottomBarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Color(0xFF333333);

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.5, 0)
      ..arcToPoint(
        Offset(size.width * 0.5, 0),
        radius: Radius.circular(80),
        clockwise: false,
      )
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}

class CustomFunctionBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFF333333),
      child: Column(
        children: [
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: Icon(Icons.history, color: Colors.white),
                onPressed: () {
                  // Functionality for history button
                },
              ),
              IconButton(
                icon: Icon(Icons.flash_on_sharp, color: Colors.white),
                onPressed: () {
                  // Functionality for power button
                },
              ),
              IconButton(
                icon: Icon(Icons.flip_camera_ios_outlined, color: Colors.white),
                onPressed: () {
                  // Functionality for reverse screen button
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

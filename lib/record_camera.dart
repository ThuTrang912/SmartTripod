import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'identified_object.dart';
import 'video_album.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: RecordCamera(
        camera: cameras[0],
        croppedImagePath: '',
      ),
    );
  }
}

class RecordCamera extends StatefulWidget {
  final CameraDescription camera;
  final String croppedImagePath;

  const RecordCamera(
      {Key? key, required this.camera, required this.croppedImagePath})
      : super(key: key);

  @override
  _RecordCameraState createState() => _RecordCameraState();
}

class _RecordCameraState extends State<RecordCamera> {
  late CameraController _controller;
  bool _isCameraInitialized = false;
  String _currentCroppedImagePath = '';
  bool _hasStoragePermission = false;
  bool _objectDetected = false;
  bool _isRecording = false;
  Timer? _timer;
  Duration _recordingDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _checkStoragePermission();
    _currentCroppedImagePath = widget.croppedImagePath;
  }

  Future<void> _checkStoragePermission() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _hasStoragePermission = prefs.getBool('storage_permission') ?? false;
    if (!_hasStoragePermission) {
      _requestStoragePermission();
    }
  }

  Future<void> _requestStoragePermission() async {
    PermissionStatus status = await Permission.storage.request();
    if (status.isGranted) {
      print('Storage permission granted');
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('storage_permission', true);
      _hasStoragePermission = true;
    } else if (status.isDenied) {
      print('Storage permission denied');
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Cấp quyền truy cập bộ nhớ'),
            content: Text(
                'Ứng dụng cần quyền truy cập bộ nhớ để lưu video vào album ảnh của thiết bị.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  openAppSettings();
                },
                child: Text('Cấp quyền'),
              ),
            ],
          );
        },
      );
    } else if (status.isPermanentlyDenied) {
      print('Storage permission permanently denied');
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Cấp quyền truy cập bộ nhớ'),
            content: Text(
                'Ứng dụng cần quyền truy cập bộ nhớ để lưu video vào album ảnh của thiết bị. Vui lòng cấp quyền trong cài đặt ứng dụng.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  openAppSettings();
                },
                child: Text('Mở cài đặt'),
              ),
            ],
          );
        },
      );
    }
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

  // bool _isRecording = false;
  // Timer? _timer;
  // Duration _recordingDuration = Duration.zero;

  void _recordVideo() async {
    if (!_isCameraInitialized) {
      print('Camera not initialized yet');
      return;
    }

    // Check if cropped image is available
    if (_currentCroppedImagePath.isNotEmpty) {
      // Send cropped image to YOLOv5 server for detection
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(' http://10.200.5.66/detect'),
      );
      request.files.add(
        http.MultipartFile.fromPath(
          'image',
          _currentCroppedImagePath,
          filename: 'cropped.png',
        ) as http.MultipartFile,
      );
      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      var detections = json.decode(responseData)['detections'];

      // Check if object is detected
      setState(() {
        _objectDetected = detections.isNotEmpty;
      });

      if (_objectDetected) {
        // Start recording video if object is detected
        _startVideoRecording();

        // Timer to check if object is still in frame
        _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
          // Capture frame from camera
          XFile imageFile = await _controller.takePicture();

          // Send captured frame to YOLOv5 server for detection
          var request = http.MultipartRequest(
            'POST',
            Uri.parse('http://10.200.5.66:5000/detect'),
          );
          request.files.add(
            http.MultipartFile.fromPath(
              'image',
              imageFile.path,
              filename: 'frame.png',
            ) as http.MultipartFile,
          );
          var response = await request.send();
          var responseData = await response.stream.bytesToString();

          var frameDetections = json.decode(responseData)['detections'];

          // Check if object is still detected
          setState(() {
            _objectDetected = frameDetections.isNotEmpty;
          });

          if (!_objectDetected) {
            // Stop recording if object is no longer detected
            _stopVideoRecording();
          }
        });
      }
    } else {
      print('No cropped image available');
    }
  }

  void _startVideoRecording() async {
    try {
      await _controller.startVideoRecording();
      print('Video recording started');
      setState(() {
        _isRecording = true;
      });
    } catch (e) {
      print("Error starting video recording: $e");
    }
  }

  void _stopVideoRecording() async {
    try {
      XFile video = await _controller.stopVideoRecording();
      print('Video recording stopped: ${video.path}');

      _timer?.cancel();
      setState(() {
        _isRecording = false;
      });

      // Add code to save the video to device storage and video album here
      saveVideoToStorage(video.path);
    } catch (e) {
      print("Error stopping video recording: $e");
    }
  }

  Future<void> saveVideoToStorage(String videoPath) async {
    final appDir = await getExternalStorageDirectory();
    final savePath = appDir!.path + '/my_videos/';

    final directory = Directory(savePath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final File file = File(videoPath);
    final String fileName =
        'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final String newPath = savePath + fileName;
    await file.copy(newPath);

    await GallerySaver.saveVideo(newPath);

    print('Video saved to gallery: $newPath');
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    final twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF333333),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => IdentifiedObject(
                  imagePath: widget.croppedImagePath,
                  camera: widget.camera,
                ),
              ),
            );
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
          if (_currentCroppedImagePath.isNotEmpty)
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: FileImage(File(_currentCroppedImagePath)),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          if (_isRecording)
            Positioned(
              top: 20,
              left: 20,
              child: Container(
                padding: EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  _formatDuration(_recordingDuration),
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VideoAlbum(
                              refresh: true,
                            ),
                          ),
                        );
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
                icon: Icon(_controller.value.isRecordingVideo
                    ? Icons.stop
                    : Icons.fiber_manual_record_outlined),
                color: Colors.black,
                iconSize: 35,
                onPressed: _recordVideo,
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

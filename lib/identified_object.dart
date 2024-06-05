import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'record_camera.dart';
import 'dart:ui' show lerpDouble;

import 'package:smarttripod/constants.dart';

class IdentifiedObject extends StatefulWidget {
  final String imagePath;
  final CameraDescription camera;

  IdentifiedObject({Key? key, required this.imagePath, required this.camera})
      : super(key: key);

  @override
  _IdentifiedObjectState createState() => _IdentifiedObjectState();
}

class _IdentifiedObjectState extends State<IdentifiedObject> {
  Offset _initialPosition = Offset(100, 100);
  Offset _currentPosition = Offset(100, 100);
  Size _currentSize = Size(200, 200);
  late List<CameraDescription> cameras;
  bool _objectDetected = false;
  late Uint8List _imageBytes;
  List<Map<String, dynamic>> _detections = []; // Define _detections variable

  GlobalKey _imageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initializeCameras();
  }

  Future<void> _initializeCameras() async {
    try {
      cameras = await availableCameras();
    } catch (e) {
      print('Error initializing cameras: $e');
    }
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _initialPosition = details.localPosition;
      _currentPosition = details.localPosition;
      _currentSize = Size.zero;
      _detections = []; // Reset _detections to empty
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _currentPosition = details.localPosition;
      _currentSize = Size(
        (_currentPosition.dx - _initialPosition.dx).abs(),
        (_currentPosition.dy - _initialPosition.dy).abs(),
      );
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _sendImageForDetection();
  }

  Future<void> _sendImageForDetection() async {
    if (_currentSize != Size.zero && cameras.isNotEmpty) {
      RenderBox box = _imageKey.currentContext!.findRenderObject() as RenderBox;
      double imageWidth = box.size.width;
      double imageHeight = box.size.height;

      ui.PictureRecorder recorder = ui.PictureRecorder();
      Canvas canvas = Canvas(recorder);

      ui.Image originalImage = await _loadImage(widget.imagePath);
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(0, 0, imageWidth, imageHeight),
        image: originalImage,
        fit: BoxFit.cover,
      );

      ui.Image fullImage = await recorder.endRecording().toImage(
            imageWidth.toInt(),
            imageHeight.toInt(),
          );

      ui.Image croppedImage = await _cropImage(
        fullImage,
        _initialPosition.dx,
        _initialPosition.dy,
        _currentSize.width,
        _currentSize.height,
      );

      ByteData byteData =
          await croppedImage.toByteData(format: ui.ImageByteFormat.png) ??
              ByteData(0);
      _imageBytes = byteData.buffer.asUint8List();

      // Send cropped image to YOLOv5 API for detection
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(Constants.yoloServerUrl + '/detect'),
      );
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          _imageBytes,
          filename: 'cropped.png',
        ),
      );
      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      // Parse JSON string
      var detectionsString = json.decode(responseData)['detections'];
      var detections = json.decode(detectionsString);

      // Store detection information
      List<Map<String, dynamic>> objectDetections = [];
      for (var detection in detections) {
        objectDetections.add({
          'name': detection['name'],
          'x': detection['x'],
          'y': detection['y'],
          'width': detection['width'],
          'height': detection['height'],
          'confidence': detection['confidence'],
        });
      }

      // Check if object is detected
      setState(() {
        _objectDetected = detections.isNotEmpty;
        _detections = objectDetections;
      });

      if (_detections.length == 1) {
        // Show alert if object is detected
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Object Detected'),
            content: Text('An object was detected in the selected area.'),
            actions: [
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      } else if (_detections.length > 1) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Select Only 1 Object'),
            content: Text('Please select an area containing only 1 object.'),
            actions: [
              TextButton(
                child: Text('Select Again'),
                onPressed: () {
                  setState(() {
                    _currentPosition = _initialPosition;
                    _currentSize = Size.zero;
                    _detections = [];
                  });
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('No Object Detected'),
            content: Text('No object was detected in the selected area.'),
            actions: [
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      }
    } else {
      print('Cameras not available or image size is zero');
    }
  }

  Future<ui.Image> _loadImage(String path) async {
    final data = await File(path).readAsBytes();
    return decodeImageFromList(data);
  }

  Future<ui.Image> _cropImage(
      ui.Image image, double x, double y, double width, double height) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(x, y, width, height),
      Rect.fromLTWH(0, 0, width, height),
      paint,
    );

    return await recorder.endRecording().toImage(width.toInt(), height.toInt());
  }

  void _onCheckPressed() async {
    if (_detections.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Unable to Verify Object'),
          content: Text('Please select at least 1 object accurately.'),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
    } else if (_detections.length > 1) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Unable to Verify Object'),
          content: Text(
              'Please select the area containing only 1 object accurately.'),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
    } else {
      final croppedImagePath = '${widget.imagePath}_cropped.png';
      await File(croppedImagePath).writeAsBytes(_imageBytes);

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RecordCamera(
            camera: cameras[0],
            croppedImagePath: croppedImagePath,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF333333),
      appBar: AppBar(
        backgroundColor: Color(0xFF333333),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Stack(
        children: [
          RepaintBoundary(
            key: _imageKey,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Color(0xFF333333),
              child: GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: Image.file(
                  File(widget.imagePath),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Positioned(
            top: _initialPosition.dy,
            left: _initialPosition.dx,
            width: _currentSize.width,
            height: _currentSize.height,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.red, width: 2),
              ),
            ),
          ),
          for (var detection in _detections)
            Positioned(
              top: detection['y'],
              left: detection['x'],
              child: Container(
                padding: EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 16.0,
                    ),
                    SizedBox(width: 4.0),
                    Text(
                      detection['name'],
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 60,
              color: Color(0xFF333333),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: Icon(Icons.check),
                    color: Colors.white,
                    onPressed: _onCheckPressed,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

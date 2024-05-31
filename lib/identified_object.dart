import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'record_camera.dart';

class IdentifiedObject extends StatefulWidget {
  final String imagePath;

  IdentifiedObject({Key? key, required this.imagePath}) : super(key: key);

  @override
  _IdentifiedObjectState createState() => _IdentifiedObjectState();
}

class _IdentifiedObjectState extends State<IdentifiedObject> {
  Offset _initialPosition = Offset(100, 100);
  Offset _currentPosition = Offset(100, 100);
  Size _currentSize = Size(200, 200);
  late List<CameraDescription> cameras;

  GlobalKey _imageKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initialPosition = Offset(100, 100);
    _currentPosition = Offset(100, 100);
    _currentSize = Size(200, 200);
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

      ByteData? byteData =
          await croppedImage.toByteData(format: ui.ImageByteFormat.png);
      Uint8List imageBytes = byteData!.buffer.asUint8List();

      final croppedImagePath = '${widget.imagePath}_cropped.png';
      await File(croppedImagePath).writeAsBytes(imageBytes);

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RecordCamera(
            camera: cameras[0],
            croppedImagePath: croppedImagePath,
          ),
        ),
      );
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
                    onPressed: _sendImageForDetection,
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

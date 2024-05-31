import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:smarttripod/video_album.dart';
import 'dart:io';
import 'identified_object.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'dart:async';

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

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _currentCroppedImagePath = widget.croppedImagePath;
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
    _timer?.cancel();
    super.dispose();
  }

  bool _isRecording = false; // Biến để kiểm tra xem đang quay video hay không
  Timer? _timer;
  Duration _recordingDuration = Duration.zero;

  void _toggleRecordVideo() {
    if (_isRecording) {
      _stopVideoRecording();
    } else {
      _startVideoRecording();
    }
  }

  void _recordVideo() {
    if (_isRecording) {
      _stopVideoRecording();
    } else {
      _startVideoRecording();
    }
  }

  void _startVideoRecording() async {
    if (!_isCameraInitialized) {
      print('Camera not initialized yet');
      return;
    }

    try {
      await _controller.startVideoRecording();
      print('Video recording started');
      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });

      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration =
              Duration(seconds: _recordingDuration.inSeconds + 1);
        });
      });
    } catch (e) {
      print("Error starting video recording: $e");
    }
  }

  void _stopVideoRecording() async {
    if (!_isCameraInitialized) {
      print('Camera not initialized yet');
      return;
    }

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
    final appDir =
        await getExternalStorageDirectory(); // Lấy thư mục lưu trữ bên ngoài
    final savePath = appDir!.path + '/my_videos/'; // Đường dẫn lưu video

    // Tạo thư mục nếu chưa tồn tại
    final directory = Directory(savePath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    // Di chuyển video đã quay vào thư mục lưu trữ
    final File file = File(videoPath);
    final String fileName =
        'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final String newPath = savePath + fileName;
    await file.copy(newPath);

    // Lưu video vào album ảnh của thiết bị
    await GallerySaver.saveVideo(newPath);

    // Hiển thị thông báo hoặc cập nhật giao diện sau khi lưu video thành công
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
                          MaterialPageRoute(builder: (context) => VideoAlbum()),
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
                onPressed:
                    _toggleRecordVideo, // Thay đổi hàm xử lý khi nhấn vào nút
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

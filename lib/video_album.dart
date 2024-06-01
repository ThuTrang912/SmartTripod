import 'package:flutter/material.dart';
import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:ui' show lerpDouble;

class VideoAlbum extends StatefulWidget {
  final bool refresh;

  const VideoAlbum({Key? key, this.refresh = false}) : super(key: key);

  @override
  _VideoAlbumState createState() => _VideoAlbumState();
}

class _VideoAlbumState extends State<VideoAlbum> with WidgetsBindingObserver {
  List<File> _videos = [];
  Map<String, String> _thumbnails = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestStoragePermission();
    _loadVideos();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Kiểm tra lại video khi ứng dụng quay trở lại từ nền
      _loadVideos();
    }
  }

  Future<void> _requestStoragePermission() async {
    var status = await Permission.storage.request();
    if (status.isGranted) {
      print('Storage permission granted');
    } else {
      print('Storage permission denied');
    }
  }

  Future<void> _ensureVideoDirectoryExists() async {
    final appDir = await getExternalStorageDirectory();
    final savePath = '${appDir?.path}/my_videos/';
    final directory = Directory(savePath);

    if (!await directory.exists()) {
      await directory.create(recursive: true);
      print('Video directory created: $savePath');
    }
  }

  Future<void> _loadVideos() async {
    await _ensureVideoDirectoryExists();

    final appDir = await getExternalStorageDirectory();
    final savePath = '${appDir?.path}/my_videos/';
    final directory = Directory(savePath);

    setState(() {
      _videos = directory
          .listSync()
          .where((item) => item.path.endsWith(".mp4"))
          .map((item) => File(item.path))
          .toList();
    });

    print('Videos found: ${_videos.length}');

    for (var video in _videos) {
      _thumbnails[video.path] = await _getVideoThumbnail(video.path);
    }

    setState(() {});
  }

  Future<String> _getVideoThumbnail(String videoPath) async {
    final thumbnailDir = await getApplicationDocumentsDirectory();
    final thumbnailPath = '${thumbnailDir.path}/thumbnails';
    final thumbnailFile = File('$thumbnailPath/${videoPath.hashCode}.jpg');

    if (!await thumbnailFile.exists()) {
      await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: thumbnailPath,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 100,
        quality: 75,
      );
    }

    return thumbnailFile.path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Video Album'),
      ),
      body: _videos.isEmpty
          ? Center(child: Text('No videos found'))
          : ListView.builder(
              itemCount: _videos.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: _thumbnails.containsKey(_videos[index].path)
                      ? Image.file(
                          File(_thumbnails[_videos[index].path]!),
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 100,
                          height: 100,
                          color: Colors.grey,
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                  title: Text(_videos[index].path.split('/').last),
                  subtitle: Text(
                      'Date: ${DateFormat('yyyy-MM-dd').format(File(_videos[index].path).lastModifiedSync())}'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoPlayerScreen(
                          videoFile: _videos[index],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final File videoFile;

  VideoPlayerScreen({required this.videoFile});

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.videoFile)
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Video Player'),
      ),
      body: Center(
        child: _controller.value.isInitialized
            ? Column(
                children: [
                  AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Date: ${DateFormat('yyyy-MM-dd').format(File(widget.videoFile.path).lastModifiedSync())}',
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Start Time: ${DateFormat('HH:mm:ss').format(File(widget.videoFile.path).lastModifiedSync())}',
                      style: TextStyle(color: Colors.black, fontSize: 16),
                    ),
                  ),
                ],
              )
            : CircularProgressIndicator(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _controller.value.isPlaying
                ? _controller.pause()
                : _controller.play();
          });
        },
        child: Icon(
          _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
        ),
      ),
    );
  }
}

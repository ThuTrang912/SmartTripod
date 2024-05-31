import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerScreen({Key? key, required this.videoUrl}) : super(key: key);

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(widget.videoUrl)
      ..initialize().then((_) {
        setState(() {});
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
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Video Player'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(_controller),
                  if (!_isPlaying)
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _isPlaying = true;
                          _controller.play();
                        });
                      },
                      icon: const Icon(Icons.play_circle, size: 80),
                    ),
                  if (_isPlaying)
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _isPlaying = false;
                          _controller.pause();
                        });
                      },
                      icon: const Icon(Icons.pause_circle, size: 80),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Slider(
              value: _controller.value.position.inSeconds.toDouble(),
              min: 0.0,
              max: _controller.value.duration.inSeconds.toDouble(),
              onChanged: (value) {
                setState(() {
                  _controller.seekTo(Duration(seconds: value.toInt()));
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

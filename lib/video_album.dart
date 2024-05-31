import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:smarttripod/video_player.dart';
import 'package:video_player/video_player.dart';

class VideoAlbum extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text("Video Album"),
      ),
      body: ListView.builder(
        itemCount: 5,
        itemBuilder: (BuildContext context, int index) {
          return VideoListItem(
            videoUrl: "https://www.youtube.com/watch?v=voypO0L4knM",
            title: "Day $index",
            subtitle: "Time $index",
          );
        },
      ),
    );
  }
}

class VideoListItem extends StatelessWidget {
  final String videoUrl;
  final String title;
  final String subtitle;

  const VideoListItem({
    Key? key,
    required this.videoUrl,
    required this.title,
    required this.subtitle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: FutureBuilder<Uint8List?>(
        future: _generateThumbnail(videoUrl),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              width: 50,
              height: 50,
              color: Colors.grey,
            );
          }
          if (snapshot.hasData) {
            return Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: MemoryImage(snapshot.data!),
                  fit: BoxFit.cover,
                ),
              ),
            );
          }
          return Container(
            width: 50,
            height: 50,
            color: Colors.grey,
          );
        },
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(videoUrl: videoUrl),
          ),
        );
      },
    );
  }

  Future<Uint8List?> _generateThumbnail(String videoUrl) async {
    final videoPlayerController = VideoPlayerController.network(videoUrl);
    await videoPlayerController.initialize();
    await videoPlayerController.play(); // Start playing to generate a frame
    await Future.delayed(Duration(seconds: 1)); // Wait for 1 second
    // final image = await videoPlayerController
    //     .takeSnapshot(); // Capture the current frame as an image
    await videoPlayerController.dispose();
    // return image;
  }
}

import 'dart:io';

import 'package:flutter/material.dart';

class IdentifiedObject extends StatelessWidget {
  final String imagePath;

  const IdentifiedObject({Key? key, required this.imagePath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.check, color: Colors.white),
            onPressed: () {
              // Add functionality for checkmark icon
            },
          ),
        ],
      ),
      body: Center(
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black,
              child: Image.file(
                // Display the captured image
                File(imagePath),
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      // Add functionality for back arrow icon
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.flash_on, color: Colors.white),
                    onPressed: () {
                      // Add functionality for flash icon
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.rotate_left, color: Colors.white),
                    onPressed: () {
                      // Add functionality for reverse screen icon
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

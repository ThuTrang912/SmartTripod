import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class IdentifiedObject extends StatefulWidget {
  final String imagePath;

  IdentifiedObject({Key? key, required this.imagePath}) : super(key: key);

  @override
  _IdentifiedObjectState createState() => _IdentifiedObjectState();
}

class _IdentifiedObjectState extends State<IdentifiedObject> {
  Offset _initialPosition =
      Offset(100, 100); // Vị trí ban đầu của vùng lựa chọn
  Offset _currentPosition = Offset(100, 100);
  Size _currentSize = Size(40, 40); // Kích thước ban đầu của vùng lựa chọn

  @override
  void initState() {
    super.initState();
    // Khởi tạo vị trí và kích thước ban đầu của vùng lựa chọn
    _initialPosition = Offset(100, 100);
    _currentPosition = Offset(100, 100);
    _currentSize = Size(40, 40);
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

  void _sendImageForDetection() async {
    if (_currentSize != Size.zero) {
      // Cắt hình ảnh trong vùng đã chọn
      // Tạo hình ảnh mới từ vùng đã chọn
      // Gửi hình ảnh đã cắt đến server YOLOv5 để nhận diện
      // Xử lý kết quả nhận diện từ server
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
          Container(
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

void main() {
  runApp(MaterialApp(
    home: IdentifiedObject(
      imagePath:
          'path_to_your_image.jpg', // Thay đổi đường dẫn đến hình ảnh của bạn
    ),
  ));
}

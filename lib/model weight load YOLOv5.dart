// import 'dart:io';
// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:yaml/yaml.dart';


// Future<void> downloadModelWeights(String yamlUrl) async {
//   try {
//     // Tải nội dung của tệp YAML
//     var response = await http.get(Uri.parse(yamlUrl));
//     if (response.statusCode == 200) {
//       // Phân tích nội dung YAML để tìm URL của trọng số mô hình
//       var yamlContent = response.body;
//       var yamlMap = loadYaml(yamlContent);
//       var modelWeightsUrl = yamlMap['weights'];
      
//       // Tải trọng số mô hình từ URL
//       var weightsResponse = await http.get(Uri.parse(modelWeightsUrl));
//       if (weightsResponse.statusCode == 200) {
//         // Lưu trọng số mô hình vào tệp cục bộ
//         File weightsFile = File('model_weights.pt'); // Đổi tên tệp theo định dạng của mô hình (ví dụ: .pt)
//         await weightsFile.writeAsBytes(weightsResponse.bodyBytes);
//         print('Trọng số mô hình đã được tải xuống thành công');
//       } else {
//         print('Lỗi khi tải trọng số mô hình: ${weightsResponse.statusCode}');
//       }
//     } else {
//       print('Lỗi khi tải tệp YAML: ${response.statusCode}');
//     }
//   } catch (e) {
//     print('Đã xảy ra lỗi: $e');
//   }
// }



// void main() {
//   String yamlUrl = 'https://github.com/ultralytics/yolov5/blob/master/models/yolov5x.yaml'; // Thay thế URL_CUA_TEPT_YAML bằng URL thực tế của tệp YAML
//   downloadModelWeights(yamlUrl);
// }

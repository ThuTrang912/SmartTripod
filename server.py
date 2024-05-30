from flask import Flask, request, jsonify
import torch
from PIL import Image
import io

app = Flask(__name__)

# Tải mô hình YOLOv5
model = torch.hub.load('ultralytics/yolov5', 'yolov5s', pretrained=False)
model.load_state_dict(torch.load('yolov5s.pt')['model'].state_dict())

@app.route('/detect', methods=['POST'])
def detect():
    if 'image' not in request.files:
        return jsonify({'error': 'No image uploaded'}), 400

    file = request.files['image']
    img = Image.open(io.BytesIO(file.read()))

    # Perform inference
    results = model(img)
    detections = results.xyxy[0].numpy()  # xyxy format

    return jsonify(detections.tolist())

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)

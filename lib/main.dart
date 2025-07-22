import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(home: PhyxPoC()));
}

class PhyxPoC extends StatefulWidget {
  const PhyxPoC({super.key});

  @override
  _PhyxPoCState createState() => _PhyxPoCState();
}

class _PhyxPoCState extends State<PhyxPoC> {
  CameraController? _cameraController;
  Future<void>? _initializeControllerFuture;
  bool cameraInitialized = false;
  CameraDescription? camera;
  List<Pose>? poses;
  String _detectionText = "No pose detected";
  late final PoseDetector _poseDetector;
  CameraImage? cameraImgForSize;
  bool _isProcessingFrame = false;
  String? _errorMessage;

  void _initCamera() async {
    try {
      final cameras = await availableCameras();
      
      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = "No cameras available";
        });
        return;
      }

      // Find back camera, fallback to first available
      camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      _initializeControllerFuture = _cameraController!.initialize();
      await _initializeControllerFuture;

      if (mounted) {
        setState(() {
          cameraInitialized = true;
        });
        _startProcessing();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Camera initialization failed: $e";
        });
      }
      print("Camera initialization error: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _poseDetector = PoseDetector(
        options: PoseDetectorOptions(mode: PoseDetectionMode.single));
    _initCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  Uint8List convertYUV420ToNV21(CameraImage image) {
    final width = image.width;
    final height = image.height;

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBuffer = yPlane.bytes;
    final uBuffer = uPlane.bytes;
    final vBuffer = vPlane.bytes;

    final numPixels = width * height + (width * height ~/ 2);
    final nv21 = Uint8List(numPixels);

    int idY = 0;
    int idUV = width * height;
    final uvWidth = width ~/ 2;
    final uvHeight = height ~/ 2;

    final yRowStride = yPlane.bytesPerRow;
    final yPixelStride = yPlane.bytesPerPixel ?? 1;
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 2;

    for (int y = 0; y < height; ++y) {
      final yOffset = y * yRowStride;
      for (int x = 0; x < width; ++x) {
        nv21[idY++] = yBuffer[yOffset + x * yPixelStride];
      }
    }

    for (int y = 0; y < uvHeight; ++y) {
      final uvOffset = y * uvRowStride;
      for (int x = 0; x < uvWidth; ++x) {
        final bufferIndex = uvOffset + (x * uvPixelStride);
        nv21[idUV++] = vBuffer[bufferIndex];
        nv21[idUV++] = uBuffer[bufferIndex];
      }
    }

    return nv21;
  }

  InputImage? _inputImageFromCameraImage(
      CameraImage image, CameraDescription camera, CameraController controller) {
    try {
      final sensorOrientation = camera.sensorOrientation;
      InputImageRotation? rotation;

      if (Platform.isIOS) {
        rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
      } else if (Platform.isAndroid) {
        var rotationCompensation =
            _orientations[controller.value.deviceOrientation];
        if (rotationCompensation == null) return null;
        if (camera.lensDirection == CameraLensDirection.front) {
          rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
        } else {
          rotationCompensation =
              (sensorOrientation - rotationCompensation + 360) % 360;
        }
        rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
      }

      if (rotation == null) return null;

      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;

      if (Platform.isIOS && format == InputImageFormat.bgra8888) {
        if (image.planes.length != 1) return null;
        final plane = image.planes.first;

        return InputImage.fromBytes(
          bytes: plane.bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: rotation,
            format: format,
            bytesPerRow: plane.bytesPerRow,
          ),
        );
      }

      if (Platform.isAndroid && format == InputImageFormat.yuv_420_888) {
        Uint8List nv21Data = convertYUV420ToNV21(image);
        return InputImage.fromBytes(
          bytes: nv21Data,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: rotation,
            format: InputImageFormat.nv21,
            bytesPerRow: image.width,
          ),
        );
      }

      if (Platform.isAndroid && format == InputImageFormat.nv21) {
        if (image.planes.length != 1) return null;
        final plane = image.planes.first;

        return InputImage.fromBytes(
          bytes: plane.bytes,
          metadata: InputImageMetadata(
            size: Size(image.width.toDouble(), image.height.toDouble()),
            rotation: rotation,
            format: format,
            bytesPerRow: plane.bytesPerRow,
          ),
        );
      }

      return null;
    } catch (e) {
      print("Error creating InputImage: $e");
      return null;
    }
  }

  void _startProcessing() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    _cameraController!.startImageStream((CameraImage image) async {
      if (_isProcessingFrame) return;
      _isProcessingFrame = true;
      
      if (mounted) {
        setState(() {
          cameraImgForSize = image;
        });
      }

      try {
        InputImage? inputImage =
            _inputImageFromCameraImage(image, camera!, _cameraController!);
        if (inputImage != null) {
          List<Pose> poses = await _poseDetector.processImage(inputImage);
          if (mounted) {
            setState(() {
              this.poses = poses;
              _detectionText =
                  poses.isNotEmpty ? "Pose Detected" : "No pose detected";
            });
          }
        }
      } catch (e) {
        print("Error while processing frame: $e");
      } finally {
        _isProcessingFrame = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pose Detection'),
      ),
      body: _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                        cameraInitialized = false;
                      });
                      _initCamera();
                    },
                    child: Text('Retry'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  flex: 2,
                  child: _initializeControllerFuture == null ||
                          _cameraController == null
                      ? Center(child: CircularProgressIndicator())
                      : FutureBuilder(
                          future: _initializeControllerFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.done) {
                              if (snapshot.hasError) {
                                return Center(
                                  child: Text(
                                    'Camera Error: ${snapshot.error}',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                );
                              }
                              return ClipRect(
                                child: AspectRatio(
                                  aspectRatio:
                                      _cameraController!.value.aspectRatio,
                                  child: CameraPreview(_cameraController!),
                                ),
                              );
                            } else {
                              return Center(child: CircularProgressIndicator());
                            }
                          },
                        ),
                ),
                Container(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    _detectionText,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: poses != null && cameraImgForSize != null
                      ? CustomPaint(
                          painter: LandmarkPainter(
                            poses!,
                            Size(cameraImgForSize!.width.toDouble(),
                                cameraImgForSize!.height.toDouble()),
                          ),
                          size: Size.infinite,
                        )
                      : Center(child: Text("Waiting for pose detection...")),
                ),
              ],
            ),
    );
  }
}

class LandmarkPainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;

  LandmarkPainter(this.poses, this.imageSize);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0 || imageSize.width == 0 || imageSize.height == 0) {
      return;
    }

    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    for (Pose pose in poses) {
      _drawPoseConnections(canvas, pose, scaleX, scaleY);

      pose.landmarks.forEach((_, landmark) {
        final x = landmark.x * scaleX;
        final y = landmark.y * scaleY;
        final z = landmark.z;

        final radius = 4.0;
        final pointPaint = Paint()
          ..color = Colors.red
          ..style = PaintingStyle.fill;

        canvas.drawCircle(Offset(x, y), radius, pointPaint);

        // Only draw coordinates for key landmarks to avoid clutter
        if (_isKeyLandmark(landmark.type)) {
          _drawCoordinateLabel(canvas, x, y, landmark.x, landmark.y, z);
        }
      });
    }
  }

  bool _isKeyLandmark(PoseLandmarkType type) {
    return [
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
    ].contains(type);
  }

  void _drawPoseConnections(Canvas canvas, Pose pose, double scaleX, double scaleY) {
    final connectionPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2.0;

    final connections = [
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
      [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
      [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
      [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],
      [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
      [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
      [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
      [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
    ];

    for (var pair in connections) {
      final p1 = pose.landmarks[pair[0]];
      final p2 = pose.landmarks[pair[1]];

      if (p1 != null && p2 != null) {
        canvas.drawLine(
          Offset(p1.x * scaleX, p1.y * scaleY),
          Offset(p2.x * scaleX, p2.y * scaleY),
          connectionPaint,
        );
      }
    }
  }

  void _drawCoordinateLabel(Canvas canvas, double screenX, double screenY,
      double originalX, double originalY, double z) {
    final coordText =
        "(${originalX.toStringAsFixed(0)}, ${originalY.toStringAsFixed(0)})";

    final span = TextSpan(
      style: TextStyle(
        color: Colors.white,
        fontSize: 8,
        backgroundColor: Colors.black.withOpacity(0.7),
      ),
      text: coordText,
    );

    final tp = TextPainter(
      text: span,
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
    );

    tp.layout();
    tp.paint(canvas, Offset(screenX + 5, screenY - 15));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
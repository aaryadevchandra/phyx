import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'angle_utils.dart';
import 'squat_detector.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(home: PhyxPoC()));
}

class PhyxPoC extends StatefulWidget {
  const PhyxPoC({super.key});

  @override
  _PhyxPoCState createState() => _PhyxPoCState();
}

class _PhyxPoCState extends State<PhyxPoC> with WidgetsBindingObserver {
  final squatDetector = SquatDetector();
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIdx = 0;
  List<Pose>? poses;
  String _detectionText = "No pose detected";
  late final PoseDetector _poseDetector;
  CameraImage? cameraImgForSize;
  bool _isProcessingFrame = false;
  String? _errorMessage;
  bool _isDisposing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poseDetector = PoseDetector(
        options: PoseDetectorOptions(mode: PoseDetectionMode.single));
    _initCamera();
  }

  @override
  void dispose() {
    _isDisposing = true;
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    _poseDetector.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_cameraController != null) {
        _initCamera();
      }
    }
  }

  void _disposeCamera() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _cameraController = null;
    _isCameraInitialized = false;
  }

  Future<void> _initCamera() async {
    try {
      if (_isDisposing) return;

      // Dispose existing camera first
      _disposeCamera();

      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _errorMessage = "No cameras found on this device";
          });
        }
        return;
      }

      // Find back camera (rear camera)
      int backCameraIndex = _cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );

      if (backCameraIndex == -1) {
        // If no back camera found, use first available
        _selectedCameraIdx = 0;
      } else {
        _selectedCameraIdx = backCameraIndex;
      }

      // Try different resolution presets if high fails
      final resolutions = [
        ResolutionPreset.medium,
        ResolutionPreset.low,
        ResolutionPreset.high,
      ];

      CameraController? controller;

      for (final resolution in resolutions) {
        try {
          controller = CameraController(
            _cameras[_selectedCameraIdx],
            resolution,
            enableAudio: false,
            imageFormatGroup: Platform.isAndroid
                ? ImageFormatGroup.nv21
                : ImageFormatGroup.bgra8888,
          );

          await controller.initialize();
          break; // Success - exit the loop
        } catch (e) {
          print("Failed to initialize camera with $resolution: $e");
          await controller?.dispose();
          controller = null;
          continue; // Try next resolution
        }
      }

      if (controller == null) {
        throw Exception("Failed to initialize camera with any resolution");
      }

      if (!mounted || _isDisposing) {
        await controller.dispose();
        return;
      }

      _cameraController = controller;

      setState(() {
        _isCameraInitialized = true;
        _errorMessage = null;
      });

      // Small delay before starting image stream
      await Future.delayed(Duration(milliseconds: 500));

      if (mounted && !_isDisposing && _cameraController != null) {
        _startProcessing();
      }
    } catch (e) {
      print("Camera initialization error: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Camera error: ${e.toString()}";
          _isCameraInitialized = false;
        });
      }
    }
  }

  void _startProcessing() {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isDisposing) {
      return;
    }

    try {
      _cameraController!.startImageStream((CameraImage image) async {
        if (_isProcessingFrame || _isDisposing) return;
        _isProcessingFrame = true;

        if (mounted) {
          setState(() {
            cameraImgForSize = image;
          });
        }

        try {
          InputImage? inputImage = _inputImageFromCameraImage(
              image, _cameras[_selectedCameraIdx], _cameraController!);

          if (inputImage != null && !_isDisposing) {
            final stopwatch = Stopwatch()..start();
            List<Pose> detectedPoses =
                await _poseDetector.processImage(inputImage);
            stopwatch.stop();
            final latencyMs = stopwatch.elapsedMilliseconds;
            print("Inference latency: $latencyMs ms");

            // (Optional) Log to a list or file for offline analysis
            // inferenceLatencies.add(latencyMs);

            if (mounted && !_isDisposing) {
              // ---- SQUAT REP DETECTION LOGIC ----
              if (detectedPoses.isNotEmpty) {
                final angleStopwatch = Stopwatch()..start();
                final angles = calculatePoseAngles(detectedPoses.first);
                angleStopwatch.stop();
                final angleLatencyMs =
                    angleStopwatch.elapsedMicroseconds / 1000.0;
                print(
                    "Angle calculation latency: ${angleLatencyMs.toStringAsFixed(2)} ms");

                squatDetector.update(angles);
              }
              setState(() {
                poses = detectedPoses;
                _detectionText = detectedPoses.isNotEmpty
                    ? "Pose Detected"
                    : "No pose detected";
              });
            }
          }
        } catch (e) {
          print("Error processing frame: $e");
        } finally {
          _isProcessingFrame = false;
        }
      });
    } catch (e) {
      print("Error starting image stream: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to start camera stream: ${e.toString()}";
        });
      }
    }
  }

  final _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _inputImageFromCameraImage(CameraImage image,
      CameraDescription camera, CameraController controller) {
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
          rotationCompensation =
              (sensorOrientation + rotationCompensation) % 360;
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
        return InputImage.fromBytes(
          bytes: _convertYUV420ToNV21(image),
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

  Uint8List _convertYUV420ToNV21(CameraImage image) {
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

  Widget _buildCameraPreview() {
    if (!_isCameraInitialized || _cameraController == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text(
                'Initializing Camera...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _cameraController!.value.previewSize?.height ?? 1,
          height: _cameraController!.value.previewSize?.width ?? 1,
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Pose Detection - Back Camera'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _errorMessage = null;
                _isCameraInitialized = false;
              });
              _initCamera();
            },
          ),
        ],
      ),
      body: _errorMessage != null
          ? Center(
              child: Container(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, size: 64, color: Colors.red),
                    SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                          _isCameraInitialized = false;
                        });
                        _initCamera();
                      },
                      child: Text('Retry Camera'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      _buildCameraPreview(),
                      if (poses != null && cameraImgForSize != null)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: LandmarkPainter(
                              poses!,
                              Size(cameraImgForSize!.width.toDouble(),
                                  cameraImgForSize!.height.toDouble()),
                            ),
                          ),
                        ),
                      // Rep Count Overlay
                      Positioned(
                        top: 32,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                vertical: 8, horizontal: 24),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              "Reps: ${squatDetector.repCount}",
                              style: TextStyle(
                                color: Colors.yellow,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(16),
                  color: Colors.black,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        poses?.isNotEmpty == true
                            ? Icons.person
                            : Icons.person_off,
                        color: poses?.isNotEmpty == true
                            ? Colors.green
                            : Colors.red,
                      ),
                      SizedBox(width: 8),
                      Text(
                        _detectionText,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
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
    if (size.width == 0 ||
        size.height == 0 ||
        imageSize.width == 0 ||
        imageSize.height == 0) {
      return;
    }

    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    for (Pose pose in poses) {
      final angles = calculatePoseAngles(pose);

      _drawPoseConnections(canvas, pose, scaleX, scaleY);

      pose.landmarks.forEach((type, landmark) {
        final x = landmark.x * scaleX;
        final y = landmark.y * scaleY;

        final radius = 6.0;
        final pointPaint = Paint()
          ..color = Colors.red
          ..style = PaintingStyle.fill;

        canvas.drawCircle(Offset(x, y), radius, pointPaint);

        // Display angle at this joint if present
        final jointName = type.name; // PoseLandmarkType's enum name
        if (angles.containsKey(jointName)) {
          final textSpan = TextSpan(
            text: angles[jointName]!.toStringAsFixed(0) + '°',
            style: const TextStyle(
              color: Colors.yellow,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              backgroundColor: Colors.black54,
            ),
          );
          final textPainter = TextPainter(
            text: textSpan,
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          // Draw text slightly above the joint
          textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - 28));
        }
      });
    }
  }

  void _drawPoseConnections(
      Canvas canvas, Pose pose, double scaleX, double scaleY) {
    final connectionPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3.0;

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
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
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

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

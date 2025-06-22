import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

void main() {
  runApp(MaterialApp(home: PhyxPoC()));
}

class PhyxPoC extends StatefulWidget {
  const PhyxPoC({super.key});

  @override
  _PhyxPoCState createState() => _PhyxPoCState();
}

class _PhyxPoCState extends State<PhyxPoC> {
  late CameraController _cameraController;
  Future<void>? _initializeControllerFuture;
  late bool cameraInitialized = false;
  late CameraDescription camera;
  List<Pose>? poses;
  String _detectionText = "No pose detected";
  late final PoseDetector _poseDetector;
  late CameraImage cameraImgForSize;
  bool _isProcessingFrame = false;

  void _initCamera() async {
    await availableCameras().then((availableCameras) {
      setState(() {
        cameraInitialized = true;
        camera = availableCameras.first;
      });

      return availableCameras;
    });

    _cameraController = CameraController(
      camera, ResolutionPreset.medium, enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21 // for Android
          : ImageFormatGroup.bgra8888, // for iOS
    );

    _initializeControllerFuture = _cameraController.initialize();

    await _initializeControllerFuture;

    _startProcessing();
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
    // Dispose of the controller when the widget is disposed.
    _cameraController.dispose();
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

    // Planes from CameraImage
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    // Buffers from Y, U, and V planes
    final yBuffer = yPlane.bytes;
    final uBuffer = uPlane.bytes;
    final vBuffer = vPlane.bytes;

    // Total number of pixels in NV21 format
    final numPixels = width * height + (width * height ~/ 2);
    final nv21 = Uint8List(numPixels);

    // Y (Luma) plane metadata
    int idY = 0;
    int idUV = width * height; // Start UV after Y plane
    final uvWidth = width ~/ 2;
    final uvHeight = height ~/ 2;

    // Strides and pixel strides for Y and UV planes
    final yRowStride = yPlane.bytesPerRow;
    final yPixelStride = yPlane.bytesPerPixel ?? 1;
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 2;

    // Copy Y (Luma) channel
    for (int y = 0; y < height; ++y) {
      final yOffset = y * yRowStride;
      for (int x = 0; x < width; ++x) {
        nv21[idY++] = yBuffer[yOffset + x * yPixelStride];
      }
    }

    // Copy UV (Chroma) channels in NV21 format (YYYYVU interleaved)
    for (int y = 0; y < uvHeight; ++y) {
      final uvOffset = y * uvRowStride;
      for (int x = 0; x < uvWidth; ++x) {
        final bufferIndex = uvOffset + (x * uvPixelStride);
        nv21[idUV++] = vBuffer[bufferIndex]; // V channel
        nv21[idUV++] = uBuffer[bufferIndex]; // U channel
      }
    }

    return nv21;
  }

  InputImage? _inputImageFromCameraImage(CameraImage image,
      CameraDescription camera, CameraController _controller) {
    // get image rotation
    // it is used in android to convert the InputImage from Dart to Java
    // `rotation` is not used in iOS to convert the InputImage from Dart to Obj-C
    // in both platforms `rotation` and `camera.lensDirection` can be used to compensate `x` and `y` coordinates on a canvas
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation =
          _orientations[_controller.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) {
      return null;
    }

    // get image format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    // validate format depending on platform
    // only supported formats:
    // * nv21 for Android
    // * bgra8888 for iOS
    if (format == null) {
      return null;
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

    // since format is constraint to nv21 or bgra8888, both only have one plane
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    // compose InputImage using bytes
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );
  }

  void _startProcessing() {
    _cameraController.startImageStream((CameraImage image) async {
      if (_isProcessingFrame) return;
      _isProcessingFrame = true;
      setState(() {
        cameraImgForSize = image;
      });

      try {
        InputImage? inputImage =
            _inputImageFromCameraImage(image, camera, _cameraController);
        if (inputImage != null) {
          List<Pose> poses = await _poseDetector.processImage(inputImage);

          setState(() {
            this.poses = poses;
          });

          if (poses.isNotEmpty) {
            print('Pose detected');
            setState(() {
              _detectionText = "Pose Detected";
              this.poses = poses;
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
        body: Column(
      children: [
        Expanded(
          child: _initializeControllerFuture == null
              ? Center(
                  child: CircularProgressIndicator(),
                )
              : FutureBuilder(
                  future: _initializeControllerFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      return CameraPreview(_cameraController);
                    } else {
                      return CircularProgressIndicator();
                    }
                  }),
        ),
        Expanded(
          child: poses != null
              ? Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red, width: 2),
                  ),
                  child: CustomPaint(
                    painter: LandmarkPainter(
                      poses!,
                      Size(
                          cameraImgForSize.width.toDouble(),
                          cameraImgForSize.height
                              .toDouble()), // Input image size
                    ),
                    size: Size(MediaQuery.of(context).size.width,
                        MediaQuery.of(context).size.height), // Canvas size
                  ),
                )
              : Center(
                  child: Text("Nothing yet :)"),
                ),
        )
      ],
    ));
  }
}

class LandmarkPainter extends CustomPainter {
  Paint paintt = Paint()..color = Colors.black;
  final Size imageSize;
  List<Pose> poses;

  LandmarkPainter(this.poses, this.imageSize);

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;
    for (Pose pose in poses) {
      pose.landmarks.forEach((_, landmark) {
        final x = landmark.x * scaleX;
        final y = landmark.y * scaleY;

        canvas.drawCircle(Offset(x, y), 5, paintt);
      });
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

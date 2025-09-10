enum SquatPhase { up, down, unknown }

final squatUpPose = {
  'leftKnee': [165.0, 180.0],
  'rightKnee': [165.0, 180.0],
  'leftHip': [160.0, 180.0],
  'rightHip': [160.0, 180.0],
};

final squatDownPose = {
  'leftKnee': [50.0, 85.0], // Centered around 80°
  'rightKnee': [50.0, 85.0],
  'leftHip': [50.0, 82.0], // Centered around 74–76°
  'rightHip': [50.0, 82.0],
  // 'leftAnkle': [60.0, 70.0], // Centered around 61–65°
  // 'rightAnkle': [60.0, 70.0],
};

class SquatDetector {
  SquatPhase _lastPhase = SquatPhase.unknown;
  int _repCount = 0;

  int get repCount => _repCount;

  bool isPoseMatch(Map<String, double> angles, Map<String, List<double>> pose) {
    for (final joint in pose.keys) {
      if (!angles.containsKey(joint)) return false;
      final angle = angles[joint]!;
      final range = pose[joint]!;
      if (angle < range[0] || angle > range[1]) return false;
    }
    return true;
  }

  void update(Map<String, double> angles) {
    if (isPoseMatch(angles, squatDownPose)) {
      if (_lastPhase == SquatPhase.up) {
        _repCount++;
        print("Pose Mathched! Rep count: $_repCount");
      }
      _lastPhase = SquatPhase.down;
    } else if (isPoseMatch(angles, squatUpPose)) {
      _lastPhase = SquatPhase.up;
    }
    // else: unknown/intermediate, do nothing
  }
}

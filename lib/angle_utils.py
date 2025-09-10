import math

class Offset:
    def __init__(self, dx, dy):
        self.dx = dx
        self.dy = dy

    @property
    def distance(self):
        return math.hypot(self.dx, self.dy)

def compute_angle(a: Offset, b: Offset, c: Offset) -> float:
    """
    Computes the angle (in degrees) at point B formed by points A, B, C (2D only).
    """
    ab = Offset(a.dx - b.dx, a.dy - b.dy)
    cb = Offset(c.dx - b.dx, c.dy - b.dy)
    dot = ab.dx * cb.dx + ab.dy * cb.dy
def all_joint_angles_2d(pose):
    """
    Returns all angles at every joint formed by every possible triplet of joints for a given pose.
    Each entry contains the joint at which the angle is formed, the other two joints, and the angle in degrees.
    Pose is expected to have a 'landmarks' dict with keys and objects having 'x' and 'y' attributes.
    """
    keys = list(pose.landmarks.keys())
    result = []
    for i in range(len(keys)):
        for j in range(len(keys)):
            if j == i:
                continue
            for k in range(len(keys)):
                if k == i or k == j:
                    continue
                a = pose.landmarks.get(keys[i])
                b = pose.landmarks.get(keys[j])
                c = pose.landmarks.get(keys[k])
                if a is not None and b is not None and c is not None:
                    angle = compute_angle(
                        Offset(a.x, a.y),
                        Offset(b.x, b.y),
                        Offset(c.x, c.y),
                    )
                    result.append({
                        'at': keys[j],
                        'from': keys[i],
                        'to': keys[k],
                        'angle': angle,
                    })
    return result           'at': keys[j],
            'from': keys[i],
            'to': keys[k],
            'angle': angle,
          });
        }
      }
    }
  }
  return result;
}
import 'package:flutter/material.dart';

class PatientRoutinePage extends StatefulWidget {
  static const String routeName = '/routines';

  @override
  _PatientRoutinePageState createState() => _PatientRoutinePageState();
}

class _PatientRoutinePageState extends State<PatientRoutinePage> {
  String? _selectedRoutineId;
  bool _workoutMode = false;
  int _currentExercise = 0;
  Set<String> _completedExercises = {};

  final List<Map<String, dynamic>> _routines = [
    {
      'id': '1',
      'name': 'Morning Knee Rehab',
      'exercises': [
        {'name': 'Knee Extension', 'sets': 3, 'reps': 10, 'description': 'Gentle neck rotation'},
        {'name': 'Calf Raises', 'sets': 3, 'reps': 15, 'description': 'Lift shoulders up and down'},
      ],
      'days': ['Mon', 'Wed', 'Fri'],
      'times': ['Morning', 'Afternoon', 'Evening'],
    },
    {
      'id': '2',
      'name': 'Daily Flexibility',
      'exercises': [
        {'name': 'Cat-Cow Stretch', 'sets': 3, 'reps': 12, 'description': 'Spine flexibility exercise'},
      ],
      'days': ['Tue', 'Thu', 'Sat'],
      'times': ['Evening'],
    },
    {
      'id': '3',
      'name': 'Core Stability',
      'exercises': [
        {'name': 'Plank Hold', 'sets': 3, 'reps': 30, 'description': 'Hold plank position for 30 seconds'},
        {'name': 'Dead Bug', 'sets': 3, 'reps': 12, 'description': 'Alternating arm and leg movements'},
        {'name': 'Side Plank', 'sets': 2, 'reps': 20, 'description': 'Side plank holds each side'},
      ],
      'days': ['Mon', 'Wed', 'Fri'],
      'times': ['Afternoon'],
    },
  ];

  @override
  Widget build(BuildContext context) {
    if (_workoutMode && _selectedRoutineId != null) {
      return _buildWorkoutMode();
    }

    if (_selectedRoutineId != null) {
      return _buildRoutineDetail();
    }

    return _buildRoutineList();
  }

  Widget _buildRoutineList() {
    return Scaffold(
      appBar: AppBar(
        title: Text('PhysioTrack'),
        actions: [
          IconButton(
            icon: Icon(Icons.favorite_border),
            onPressed: () {
              // TODO: Implement favorites functionality
            },
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Routines',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Here are your assigned routines. Select one to begin.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _routines.length,
                itemBuilder: (context, index) {
                  final routine = _routines[index];
                  return RoutineCard(
                    routine: routine,
                    onTap: () {
                      setState(() {
                        _selectedRoutineId = routine['id'];
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutineDetail() {
    final routine = _routines.firstWhere((r) => r['id'] == _selectedRoutineId);

    return Scaffold(
      appBar: AppBar(
        title: Text(routine['name']),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _selectedRoutineId = null;
            });
          },
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exercises',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: routine['exercises'].length,
                itemBuilder: (context, index) {
                  final exercise = routine['exercises'][index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 12.0),
                    elevation: 1,
                    child: ListTile(
                      leading: Icon(Icons.fitness_center),
                      title: Text(exercise['name']),
                      subtitle: Text('${exercise['sets']} Sets, ${exercise['reps']} Reps'),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _workoutMode = true;
                    _currentExercise = 0;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Text('Start Exercises'),
                ),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutMode() {
    final routine = _routines.firstWhere((r) => r['id'] == _selectedRoutineId);
    final exercise = routine['exercises'][_currentExercise];
    final exerciseId = '${_selectedRoutineId}_$_currentExercise';
    final isCompleted = _completedExercises.contains(exerciseId);

    return Scaffold(
      appBar: AppBar(
        title: Text(routine['name']),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _workoutMode = false;
            });
          },
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exercise ${_currentExercise + 1} of ${routine['exercises'].length}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.0),
            Text(
              exercise['name'],
              style: TextStyle(
                fontSize: 24,
              ),
            ),
            SizedBox(height: 16.0),
            // Placeholder for exercise animation/video
            Container(
              height: 200.0,
              color: Colors.grey[300],
              child: Center(
                child: Icon(
                  Icons.play_circle_outline,
                  size: 80.0,
                  color: Colors.grey[600],
                ),
              ),
            ),
            SizedBox(height: 16.0),
            Text(
              exercise['description'],
              style: TextStyle(fontSize: 16.0),
            ),
            SizedBox(height: 16.0),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Sets: ${exercise['sets']}',
                    style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Reps: ${exercise['reps']}',
                    style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.0),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    if (isCompleted) {
                      _completedExercises.remove(exerciseId);
                    } else {
                      _completedExercises.add(exerciseId);
                    }
                  });
                },
                child: Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Text(isCompleted ? 'Marked as Complete' : 'Mark as Complete'),
                ),
                 style: ElevatedButton.styleFrom(
                  backgroundColor: isCompleted ? Colors.green : null,
                  foregroundColor: isCompleted ? Colors.white : null,
                   shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(),
            ), // Pushes buttons to the bottom
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: _currentExercise > 0
                      ? () {
                          setState(() {
                            _currentExercise--;
                          });
                        }
                      : null,
                  icon: Icon(Icons.skip_previous),
                  label: Text('Previous'),
                ),
                OutlinedButton.icon(
                  onPressed: _currentExercise < routine['exercises'].length - 1
                      ? () {
                          setState(() {
                            _currentExercise++;
                          });
                        }
                      : null,
                  icon: Icon(Icons.skip_next),
                  label: Text('Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RoutineCard extends StatelessWidget {
  final Map<String, dynamic> routine;
  final VoidCallback onTap;

  const RoutineCard({
    Key? key,
    required this.routine,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child:
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  routine['name'],
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4.0),
                Text(
                  '${routine['exercises'].length} exercises',
                  style: TextStyle(
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 16.0),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...routine['exercises'].take(3).map<Widget>((ex) =>
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 2.0),
                        child: Row(
                          children: [
                            Icon(Icons.fitness_center, size: 16.0, color: Colors.grey[600]),
                            SizedBox(width: 8.0),
                            Expanded(
                              child: Text(
                                ex['name'],
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ),
                          ],
                        ),
                      )
                    ).toList(),
                    if (routine['exercises'].length > 3)
                      Padding(
                        padding: EdgeInsets.only(left: 24.0, top: 4.0),
                        child: Text(
                          '+ ${routine['exercises'].length - 3} more',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12.0,
                          ),
                        ),
                      ),
                    SizedBox(height: 12.0),
                    Divider(),
                    SizedBox(height: 8.0),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16.0, color: Colors.blue[800]),
                        SizedBox(width: 8.0),
                        Expanded(
                          child: Text(
                            routine['days'].join(', '),
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.0),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16.0, color: Colors.blue[800]),
                        SizedBox(width: 8.0),
                        Expanded(
                          child: Text(
                            routine['times'].join(', '),
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 16.0),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onTap,
                    child: Text('View Routine'),
                     style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12.0),
                       backgroundColor: Colors.blue[600], // Example blue color
                       foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
  }
}

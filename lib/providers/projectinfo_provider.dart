import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProjectInfo {
  final int id;
  final String name;
  final String dateCreated; // New field for project creation date

  ProjectInfo({
    required this.id,
    required this.name,
    required this.dateCreated, // Make sure the date is required
  });
}

final projectInfoProvider = StateProvider<ProjectInfo?>((ref) => null);

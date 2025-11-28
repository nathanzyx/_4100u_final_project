// Simple helper so we can use `group.joined` in the UI
// without changing the shared StudyGroup model.
import 'package:study_connect_shared/models/group.dart';

extension StudyGroupJoinedExtension on StudyGroup {
  // For this project we will just treat every group
  // as "joined" so the screens work and compile.
  bool get joined => true;
}

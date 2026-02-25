import '../models/weekly_program_model.dart';
import 'training_firestore_service.dart';

class WeeklyProgramsService {
  WeeklyProgramsService({TrainingFirestoreService? firestore})
    : _firestore = firestore ?? TrainingFirestoreService();

  final TrainingFirestoreService _firestore;

  Future<List<WeeklyProgramModel>> getPrograms() {
    return _firestore.getWeeklyPrograms();
  }
}

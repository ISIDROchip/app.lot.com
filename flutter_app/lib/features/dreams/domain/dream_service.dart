import '../data/dream_repository.dart';
import '../data/dream_dto.dart';

class DreamService {
  final _repo = DreamRepository();

  Future<DreamResponse> interpret(String dreamText) {
    if (dreamText.length < 10) {
      throw ArgumentError('Describe tu sueño con al menos 10 caracteres');
    }
    if (dreamText.length > 2000) {
      throw ArgumentError('El texto del sueño no puede superar 2000 caracteres');
    }
    return _repo.interpret(DreamRequest(dreamText: dreamText));
  }
}

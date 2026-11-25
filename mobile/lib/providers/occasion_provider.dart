import 'package:flutter/foundation.dart';
import 'package:dijital_dolap/data/occasion_repository.dart';
import 'package:dijital_dolap/models/occasion_group.dart';

class OccasionProvider extends ChangeNotifier {
  final _repo = OccasionRepository();

  List<OccasionGroup> _groups = [];
  bool _loading = false;
  String? _error;

  List<OccasionGroup> get groups => _groups;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _groups = await _repo.getAll();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<OccasionGroup?> create(
    String name, {
    String? emoji,
    String? color,
    String? occasionType,
  }) async {
    try {
      final group = await _repo.create(
        name,
        emoji: emoji,
        color: color,
        occasionType: occasionType,
      );
      _groups = [..._groups, group];
      _error = null;
      notifyListeners();
      return group;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> update(
    OccasionGroup group, {
    String? name,
    String? emoji,
    String? color,
    String? occasionType,
  }) async {
    try {
      final updated = await _repo.update(
        group.id,
        name: name,
        emoji: emoji,
        color: color,
        occasionType: occasionType,
      );
      final i = _groups.indexWhere((g) => g.id == group.id);
      if (i != -1) {
        _groups[i] = updated;
        notifyListeners();
      }
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete(int id) async {
    try {
      await _repo.delete(id);
      _groups.removeWhere((g) => g.id == id);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  OccasionGroup? byId(int? id) {
    if (id == null) return null;
    for (final group in _groups) {
      if (group.id == id) return group;
    }
    return null;
  }

  void clear() {
    _groups = [];
    _error = null;
    notifyListeners();
  }
}

import 'package:flutter/foundation.dart';
import 'package:dijital_dolap/data/wear_repository.dart';
import 'package:dijital_dolap/models/wear_entry.dart';

class WearProvider extends ChangeNotifier {
  final _repo = WearRepository();

  List<WearEntry> _entries = [];
  bool _loading = false;
  String? _error;

  List<WearEntry> get entries => _entries;
  bool get loading => _loading;
  String? get error => _error;

  double? get averageRating {
    final rated = _entries.where((e) => e.hasRating).toList();
    if (rated.isEmpty) return null;
    final total = rated.fold<int>(0, (sum, e) => sum + e.rating!);
    return total / rated.length;
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _entries = await _repo.getAll();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<WearEntry?> log({
    int? outfitId,
    List<int>? clothingIds,
    int? rating,
    String? occasion,
    String? note,
  }) async {
    try {
      final entry = await _repo.log(
        outfitId: outfitId,
        clothingIds: clothingIds,
        rating: rating,
        occasion: occasion,
        note: note,
      );
      _entries.insert(0, entry);
      _error = null;
      notifyListeners();
      return entry;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateEntry(
    WearEntry entry, {
    int? rating,
    String? occasion,
    String? note,
  }) async {
    try {
      final updated = await _repo.update(
        entry.id,
        rating: rating,
        occasion: occasion,
        note: note,
      );
      final i = _entries.indexWhere((e) => e.id == entry.id);
      if (i != -1) {
        _entries[i] = updated;
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
      _entries.removeWhere((e) => e.id == id);
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clear() {
    _entries = [];
    _error = null;
    notifyListeners();
  }
}

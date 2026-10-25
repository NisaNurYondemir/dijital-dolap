import 'package:flutter/material.dart';
import 'package:dijital_dolap/data/outfit_repository.dart';
import 'package:dijital_dolap/models/outfit.dart';

class OutfitProvider extends ChangeNotifier {
  final _repo = OutfitRepository();

  List<Outfit> _outfits = [];
  List<Outfit> _suggestions = [];
  bool _loading = false;
  String? _error;

  List<Outfit> get outfits => _outfits;
  List<Outfit> get suggestions => _suggestions;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadAll() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _outfits = await _repo.getAll();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadSuggestions() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _suggestions = await _repo.getSuggestions();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Outfit> saveOutfit(
    List<int> clothingIds, {
    List<int> occasionIds = const [],
  }) async {
    final outfit = await _repo.create(clothingIds, occasionIds: occasionIds);
    _outfits.insert(0, outfit);
    notifyListeners();
    return outfit;
  }

  Future<bool> setOccasions(Outfit outfit, List<int> occasionIds) async {
    if (outfit.id == null) return false;
    try {
      final updated = await _repo.setOccasions(outfit.id!, occasionIds);
      final i = _outfits.indexWhere((o) => o.id == outfit.id);
      if (i != -1) {
        _outfits[i] = updated;
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

  Future<void> toggleFavorite(Outfit outfit) async {
  if (outfit.id == null) return;
  final updated = await _repo.toggleFavorite(outfit.id!, !outfit.isFavorite);
  final i = _outfits.indexWhere((o) => o.id == outfit.id);
  if (i != -1) {
    _outfits[i] = updated;
    notifyListeners();
    }
  }

  Future<void> deleteOutfit(int id) async {
    await _repo.delete(id);
    _outfits.removeWhere((o) => o.id == id);
    notifyListeners();
  }

  void clear() {
    _outfits = [];
    _suggestions = [];
    notifyListeners();
  }
}
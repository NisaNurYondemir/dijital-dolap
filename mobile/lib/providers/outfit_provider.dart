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

  Future<void> saveOutfit(List<int> clothingIds) async {
    final outfit = await _repo.create(clothingIds);
    _outfits.insert(0, outfit);
    notifyListeners();
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

  Future<void> logWear(int outfitId) async {
    await _repo.logWear(outfitId);
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
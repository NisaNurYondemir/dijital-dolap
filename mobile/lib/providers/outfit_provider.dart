import 'package:flutter/material.dart';
import 'package:dijital_dolap/data/outfit_repository.dart';
import 'package:dijital_dolap/models/outfit.dart';
import 'package:dijital_dolap/models/outfit_score.dart';

class OutfitProvider extends ChangeNotifier {
  final _repo = OutfitRepository();

  List<Outfit> _outfits = [];
  List<Outfit> _suggestions = [];

  bool _outfitsLoading = false;
  bool _suggestionsLoading = false;

  String? _outfitsError;
  String? _suggestionsError;
  String? _mutationError;

  int _outfitsRequest = 0;
  int _suggestionsRequest = 0;

  List<Outfit> get outfits => _outfits;
  List<Outfit> get suggestions => _suggestions;
  bool get outfitsLoading => _outfitsLoading;
  bool get suggestionsLoading => _suggestionsLoading;
  bool get loading => _outfitsLoading || _suggestionsLoading;
  String? get outfitsError => _outfitsError;
  String? get suggestionsError => _suggestionsError;

  /// Grup güncelleme gibi işlemlerin son hatası.
  String? get error => _mutationError;

  Future<void> loadAll() async {
    final request = ++_outfitsRequest;
    _outfitsLoading = true;
    _outfitsError = null;
    notifyListeners();
    try {
      final result = await _repo.getAll();
      if (request != _outfitsRequest) return;
      _outfits = result;
    } catch (e) {
      if (request != _outfitsRequest) return;
      _outfitsError = e.toString();
    } finally {
      if (request == _outfitsRequest) {
        _outfitsLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadSuggestions({
    int? occasionId,
    double? latitude,
    double? longitude,
    String? city,
  }) async {
    final request = ++_suggestionsRequest;
    _suggestionsLoading = true;
    _suggestionsError = null;
    notifyListeners();
    try {
      final result = await _repo.getSuggestions(
        occasionId: occasionId,
        latitude: latitude,
        longitude: longitude,
        city: city,
      );
      if (request != _suggestionsRequest) return;
      _suggestions = result;
    } catch (e) {
      if (request != _suggestionsRequest) return;
      _suggestionsError = e.toString();
    } finally {
      if (request == _suggestionsRequest) {
        _suggestionsLoading = false;
        notifyListeners();
      }
    }
  }

  Future<Outfit> saveOutfit(
    List<int> clothingIds, {
    List<int> occasionIds = const [],
    bool isFavorite = false,
    String? name,
    String? description,
  }) async {
    final outfit = await _repo.create(
      clothingIds,
      occasionIds: occasionIds,
      isFavorite: isFavorite,
      name: name,
      description: description,
    );
    _outfits.insert(0, outfit);
    notifyListeners();
    return outfit;
  }

  /// Manuel kombin ekranında canlı uyum puanı için.
  Future<OutfitScore?> evaluate(
    List<int> clothingIds, {
    int? occasionId,
  }) async {
    try {
      final result = await _repo.evaluate(
        clothingIds,
        occasionId: occasionId,
      );
      _mutationError = null;
      return result;
    } catch (e) {
      _mutationError = e.toString();
      notifyListeners();
      return null;
    }
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
      _mutationError = null;
      return true;
    } catch (e) {
      _mutationError = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<Outfit> updateDetails(Outfit outfit, {String? name,
      String? description}) async {
    if (outfit.id == null) return outfit;
    try {
      final updated = await _repo.updateDetails(
        outfit.id!,
        name: name,
        description: description,
      );
      final i = _outfits.indexWhere((o) => o.id == outfit.id);
      if (i != -1) {
        _outfits[i] = updated;
        notifyListeners();
      }
      _mutationError = null;
      return updated;
    } catch (e) {
      _mutationError = e.toString();
      notifyListeners();
      return outfit;
    }
  }

  Future<Outfit> toggleFavorite(Outfit outfit) async {
    if (outfit.id == null) return outfit;
    final updated = await _repo.toggleFavorite(outfit.id!, !outfit.isFavorite);
    final i = _outfits.indexWhere((o) => o.id == outfit.id);
    if (i != -1) {
      _outfits[i] = updated;
      notifyListeners();
    }
    return updated;
  }

  Future<void> deleteOutfit(int id) async {
    await _repo.delete(id);
    _outfits.removeWhere((o) => o.id == id);
    notifyListeners();
  }

  void clear() {
    // Devam eden isteklerin eski kullanıcı verisini geri yazmasını engelle.
    _outfitsRequest++;
    _suggestionsRequest++;
    _outfits = [];
    _suggestions = [];
    _outfitsLoading = false;
    _suggestionsLoading = false;
    _outfitsError = null;
    _suggestionsError = null;
    _mutationError = null;
    notifyListeners();
  }
}

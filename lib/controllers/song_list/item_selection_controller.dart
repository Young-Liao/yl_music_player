import 'package:flutter/foundation.dart';

class ItemSelectionController extends ChangeNotifier {
  final Set<int> _selectedIndices = {};
  bool _isLanTransferSelection = false;

  Set<int> get selectedIndices => Set.unmodifiable(_selectedIndices);
  int get selectedCount => _selectedIndices.length;
  bool get hasSelection => _selectedIndices.isNotEmpty;
  bool get isLanTransferSelection => _isLanTransferSelection;

  bool isSelected(int index) => _selectedIndices.contains(index);

  bool areAllSelected(int totalCount) {
    return totalCount > 0 && _selectedIndices.length == totalCount;
  }

  void toggleSelectIndex(int index) {
    if (_selectedIndices.contains(index)) {
      _selectedIndices.remove(index);
    } else {
      _selectedIndices.add(index);
    }
    notifyListeners();
  }

  void toggleSelectAll(int totalCount) {
    if (areAllSelected(totalCount)) {
      _selectedIndices.clear();
    } else {
      _selectedIndices.addAll(List.generate(totalCount, (i) => i));
    }
    notifyListeners();
  }

  void startLanTransferMode() {
    _isLanTransferSelection = true;
    _selectedIndices.clear();
    notifyListeners();
  }

  void cancelLanTransferMode() {
    _isLanTransferSelection = false;
    _selectedIndices.clear();
    notifyListeners();
  }

  void clearSelection() {
    _selectedIndices.clear();
    _isLanTransferSelection = false;
    notifyListeners();
  }
}
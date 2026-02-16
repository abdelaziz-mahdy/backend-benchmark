import 'package:flutter/material.dart';

import '../models/benchmark_data.dart';
import '../services/data_service.dart';

class BenchmarkProvider extends ChangeNotifier {
  Map<String, BenchmarkService>? data;
  Set<String> selectedServices = {};
  Set<String> selectedFields = {'Requests/s'};
  bool isLoading = false;
  double progress = 0;
  bool sidebarExpanded = true;

  List<String> get dbServices =>
      data?.keys.where((k) => k.contains('db_test') && !k.contains('no_db_test')).toList() ?? [];

  List<String> get noDbServices =>
      data?.keys.where((k) => k.contains('no_db_test')).toList() ?? [];

  Future<void> loadData() async {
    isLoading = true;
    progress = 0;
    notifyListeners();

    try {
      progress = 0.3;
      notifyListeners();

      data = await DataService.loadData();

      progress = 1.0;
      notifyListeners();

      // Select all services by default
      selectedServices = data!.keys.toSet();
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void toggleService(String service) {
    if (selectedServices.contains(service)) {
      selectedServices.remove(service);
    } else {
      selectedServices.add(service);
    }
    notifyListeners();
  }

  void toggleField(String field) {
    if (selectedFields.contains(field)) {
      selectedFields.remove(field);
    } else {
      selectedFields.add(field);
    }
    notifyListeners();
  }

  void toggleAllFields() {
    if (selectedFields.length == availableFields.length) {
      selectedFields = {'Requests/s'};
    } else {
      selectedFields = availableFields.toSet();
    }
    notifyListeners();
  }

  void toggleSidebar() {
    sidebarExpanded = !sidebarExpanded;
    notifyListeners();
  }
}

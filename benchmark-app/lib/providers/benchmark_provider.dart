import 'package:flutter/material.dart';

import '../models/benchmark_data.dart';
import '../services/data_service.dart';

enum TestTypeFilter { db, noDb, all }

class BenchmarkProvider extends ChangeNotifier {
  Map<String, BenchmarkService>? data;
  Set<String> selectedServices = {};
  Set<String> selectedFields = {'Requests/s'};
  bool isLoading = false;
  double progress = 0;
  bool sidebarExpanded = true;
  TestTypeFilter testTypeFilter = TestTypeFilter.db;

  List<String> get dbServices =>
      data?.keys
          .where((k) => k.contains('db_test') && !k.contains('no_db_test'))
          .toList() ??
      [];

  List<String> get noDbServices =>
      data?.keys.where((k) => k.contains('no_db_test')).toList() ?? [];

  /// Returns the framework base name (e.g. "go mux") from a full service name
  static String frameworkName(String serviceName) {
    return serviceName
        .replaceAll(' db_test', '')
        .replaceAll(' no_db_test', '')
        .trim();
  }

  /// Services filtered by current test type filter
  Set<String> get filteredServices {
    return selectedServices.where((s) {
      switch (testTypeFilter) {
        case TestTypeFilter.db:
          return s.contains('db_test') && !s.contains('no_db_test');
        case TestTypeFilter.noDb:
          return s.contains('no_db_test');
        case TestTypeFilter.all:
          return true;
      }
    }).toSet();
  }

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

  void setTestTypeFilter(TestTypeFilter filter) {
    testTypeFilter = filter;
    notifyListeners();
  }

  void toggleService(String service) {
    if (selectedServices.contains(service)) {
      selectedServices.remove(service);
    } else {
      selectedServices.add(service);
    }
    notifyListeners();
  }

  void selectAllServices() {
    selectedServices = data!.keys.toSet();
    notifyListeners();
  }

  void deselectAllServices() {
    selectedServices.clear();
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

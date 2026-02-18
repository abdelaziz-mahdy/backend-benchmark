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

  // Navigation
  int activeTab = 0;

  // Detail tab
  String? selectedDetailService;

  // Compare tab
  Set<String> compareServices = {};

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

      // Default compare to top 3 by req/s for current filter
      final ranked = getRankedServices('Average Requests/s');
      compareServices = ranked.take(3).map((e) => e.key).toSet();
      // Default detail to the top performer
      if (ranked.isNotEmpty) {
        selectedDetailService = ranked.first.key;
      }
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

  void setActiveTab(int tab) {
    activeTab = tab;
    notifyListeners();
  }

  void selectDetailService(String service) {
    selectedDetailService = service;
    activeTab = 1; // Switch to Detail tab
    notifyListeners();
  }

  void toggleCompareService(String service) {
    if (compareServices.contains(service)) {
      compareServices.remove(service);
    } else if (compareServices.length < 4) {
      compareServices.add(service);
    }
    notifyListeners();
  }

  void setCompareServices(Set<String> services) {
    compareServices = services;
    notifyListeners();
  }

  /// Get ranked services for a given summary metric key, filtered by current test type.
  /// Returns list of (serviceName, value) sorted descending by default.
  /// Set ascending=true for metrics where lower is better (response time, CPU).
  List<MapEntry<String, double>> getRankedServices(String metricKey,
      {bool ascending = false}) {
    if (data == null) return [];
    final entries = <MapEntry<String, double>>[];
    final services = testTypeFilter == TestTypeFilter.all
        ? data!.keys.toList()
        : testTypeFilter == TestTypeFilter.db
            ? dbServices
            : noDbServices;
    for (final name in services) {
      final value = data![name]?.summary[metricKey];
      if (value != null && value > 0) {
        entries.add(MapEntry(name, value));
      }
    }
    entries.sort((a, b) =>
        ascending ? a.value.compareTo(b.value) : b.value.compareTo(a.value));
    return entries;
  }
}

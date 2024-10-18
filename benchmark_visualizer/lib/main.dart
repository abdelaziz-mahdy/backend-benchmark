import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:graphic/graphic.dart';
import 'package:intl/intl.dart';

const colorMap = {
  'db_test': Color(0xFFFF33A8),
  'no_db_test': Color(0xFF333FA8),
};

Color getServiceColor(String serviceName) {
  if (serviceName.toLowerCase().contains('no_db_test')) {
    return colorMap['no_db_test']!;
  }
  if (serviceName.toLowerCase().contains('db_test')) {
    return colorMap['db_test']!;
  }
  final baseServiceName = serviceName
      .toLowerCase()
      .replaceAll('no_db_test', '')
      .replaceAll('db_test', '')
      .trim();
  return colorMap[baseServiceName] ??
      Colors.primaries[serviceName.hashCode % Colors.primaries.length];
}

String getServiceDisplayName(String serviceName) =>
    serviceName.replaceAll(RegExp(r'(db_test|no_db_test)'), '').trim();

class BenchmarkApp extends StatefulWidget {
  const BenchmarkApp({Key? key}) : super(key: key);

  @override
  State<BenchmarkApp> createState() => _BenchmarkAppState();
}

class _BenchmarkAppState extends State<BenchmarkApp> {
  Map<String, dynamic> data = {};
  Set<String> selectedServices = {};
  Set<String> selectedFields = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data.json');
      setState(() {
        data = json.decode(jsonString);
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
  }

  void _toggleService(String service) {
    setState(() {
      selectedServices.contains(service)
          ? selectedServices.remove(service)
          : selectedServices.add(service);
    });
  }

  void _toggleField(String field) {
    setState(() {
      selectedFields.contains(field)
          ? selectedFields.remove(field)
          : selectedFields.add(field);
    });
  }

  List<Map<String, dynamic>> _generateChartData(String field) {
    if (selectedServices.isEmpty || data.isEmpty) return [];

    return List.generate(data[selectedServices.first]['data'].length, (i) {
      final dataPoint = {
        'Timestamp': data[selectedServices.first]['data'][i]['Timestamp']
      };
      for (final service in selectedServices) {
        dataPoint[service] = data[service]['data'][i][field] ?? 0;
      }
      return dataPoint;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text("Benchmark Visualizer")),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSelectionSection('Select Services:', data.keys,
                selectedServices, _toggleService),
            if (selectedServices.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSelectionSection('Select Fields:', _getAvailableFields(),
                  selectedFields, _toggleField),
            ],
            if (selectedFields.isNotEmpty) ..._buildCharts(),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionSection(String title, Iterable<String> items,
      Set<String> selectedItems, Function(String) onToggle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Wrap(
          spacing: 8.0,
          children: items
              .map((item) => ChoiceChip(
                    label: Text(getServiceDisplayName(item)),
                    selected: selectedItems.contains(item),
                    onSelected: (_) => onToggle(item),
                    selectedColor: getServiceColor(item),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Iterable<String> _getAvailableFields() {
    if (selectedServices.isEmpty) return [];
    return (data[selectedServices.first]['data'][0] as Map<String, dynamic>)
        .keys
        .where((field) => ![
              'timestamp',
              'Timestamp',
              'Time Difference',
              'Name',
              'Type'
            ].contains(field));
  }

  List<Widget> _buildCharts() {
    return selectedFields.map((field) {
      final chartData = _generateChartData(field);
      if (chartData.isEmpty)
        return const Text('No data available for this field.');

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(field,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(
            height: 300,
            child: Chart(
              data: chartData,
              variables: {
                'Timestamp': Variable(
                  accessor: (Map map) => map['Timestamp'] as num,
                  scale: LinearScale(
                    formatter: (value) => DateFormat('MM/dd HH:mm').format(
                        DateTime.fromMillisecondsSinceEpoch(value.toInt())),
                  ),
                ),
                ...Map.fromEntries(selectedServices.map((service) => MapEntry(
                    service,
                    Variable(
                      accessor: (Map map) => map[service] as num,
                      scale: LinearScale(),
                    )))),
              },
              marks: [
                for (final service in selectedServices)
                  LineMark(
                      color: ColorEncode(
                          variable: service,
                          // value: getServiceColor(service),
                          values: Defaults.colors10
                          // value: getServiceColor(service),
                          ))
              ],
              // marks: [
              //   for (final service in selectedServices)
              //     LineMark(
              //       position: Varset('Timestamp') * Varset(service),
              //       color: ColorEncode(value: getServiceColor(service)),
              //     ),
              // ],
              axes: [
                Defaults.horizontalAxis,
                Defaults.verticalAxis,
              ],
              // tooltip: TooltipGuide(),
            ),
          ),
          const SizedBox(height: 20),
        ],
      );
    }).toList();
  }
}

void main() {
  runApp(const BenchmarkApp());
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:graphic/graphic.dart'; // Use graphic for charts
import 'package:percent_indicator/percent_indicator.dart'; // For progress indicator

const colorMap = {
  'db_test': Color(0xFFFF33A8),
  'no_db_test': Color(0xFF333FA8),
};

Color getColor(String serviceName) {
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

class BenchmarkApp extends StatefulWidget {
  const BenchmarkApp({Key? key}) : super(key: key);

  @override
  State<BenchmarkApp> createState() => _BenchmarkAppState();
}

class _BenchmarkAppState extends State<BenchmarkApp> {
  Map<String, dynamic> data = {};
  List<String> selectedServices = [];
  List<String> selectedFields = [];
  bool loading = true;
  double progress = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final baseURL =
        Uri.base.path.contains('backend-benchmark') ? '/backend-benchmark' : '';
    final url = Uri.parse('$baseURL/data.json'); // Adjust URL as needed

    try {
      final String jsonString = await rootBundle
          .loadString('assets/data.json'); // Update path as needed
      final jsonData = json.decode(jsonString);

      setState(() {
        data = jsonData;
        loading = false;
      });
    } catch (e) {
      // Handle timeout or other errors
      setState(() {
        loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Request timed out. Check your internet connection or try again later.'),
      ));
      print('Error fetching data: $e');
    }
  }

  void handleServiceChange(String value) {
    setState(() {
      selectedServices.contains(value)
          ? selectedServices.remove(value)
          : selectedServices.add(value);
    });
  }

  void handleFieldChange(String value) {
    setState(() {
      selectedFields.contains(value)
          ? selectedFields.remove(value)
          : selectedFields.add(value);
    });
  }

  List<Map<String, dynamic>> generateChartDataForField(String field) {
    final List<Map<String, dynamic>> chartData = [];

    for (var i = 0; i < data[selectedServices[0]]['data'].length; i++) {
      final Map<String, dynamic> dataPoint = {};

      for (final service in selectedServices) {
        dataPoint['Timestamp'] = data[service]['data'][i]['Timestamp'] ?? 0;
        dataPoint[service] = data[service]['data'][i][field] ?? 0;
      }
      chartData.add(dataPoint);
    }

    return chartData;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Wrap with MaterialApp
      home: Scaffold(
        body: Column(
          children: [
            AppBar(
                title: const Text("Service Benchmarks")), // Use AppBar widget
            Expanded(
              // Add Expanded to fill remaining space
              child: ListView(
                // Wrap with ListView for scrolling content
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Wrap(
                      // Use Wrap for legend items
                      spacing: 8.0,
                      children: colorMap.entries
                          .map((entry) => Chip(
                                label: Text(entry.key,
                                    style: TextStyle(
                                        color: (ThemeData.light().brightness ==
                                                Brightness.dark
                                            ? Colors.black
                                            : Colors.white))),
                                backgroundColor: entry.value,
                              ))
                          .toList(),
                    ),
                  ),
                  ..._buildContent(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContent() {
    if (loading) {
      return [
        Center(
          child: CircularPercentIndicator(
            radius: 60.0,
            lineWidth: 10.0,
            percent: progress,
            center: Text("${(progress * 100).toInt()}%"),
            progressColor: Colors.blue, // Customize color as needed
          ),
        )
      ];
    } else {
      return [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Wrap(
            // Use Wrap for checkbox items
            spacing: 8.0,
            children: data.keys
                .map((service) => ChoiceChip(
                      label: Text(
                          service
                              .replaceAll('no_db_test', '')
                              .replaceAll('db_test', '')
                              .trim(),
                          style: TextStyle(
                              color: selectedServices.contains(service)
                                  ? Colors.white
                                  : Colors.black)), // Show trimmed service name
                      selected: selectedServices.contains(service),
                      onSelected: (selected) => handleServiceChange(service),
                      selectedColor: getColor(service),
                    ))
                .toList(),
          ),
        ),
        if (selectedServices.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
                // Wrap with Wrap for better layout
                spacing: 8.0,
                children: (data[selectedServices[0]]?['data']?[0]
                            as Map<String, dynamic> ??
                        {})
                    .keys
                    .where((field) => ![
                          'timestamp',
                          'Timestamp',
                          'Time Difference',
                          'Name',
                          'Type'
                        ].contains(field))
                    .map((field) => ChoiceChip(
                          label: Text(field),
                          selected: selectedFields.contains(field),
                          onSelected: (selected) => handleFieldChange(field),
                        ))
                    .toList()),
          ),
        if (selectedServices.isNotEmpty && selectedFields.isNotEmpty)
          ...selectedFields.map((field) {
            final chartData = generateChartDataForField(field);
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                height: 300, // Set a fixed height for the chart
                child: Chart(
                  data: chartData,
                  marks: [
                    for (final service in selectedServices)
                      LineMark(
                          color: ColorEncode(
                        variable: service,
                        value: getColor(service),
                      ))
                  ],
                  axes: [
                    Defaults.horizontalAxis,
                    Defaults.verticalAxis,
                  ],
                  // coord: RectCoord(),
                  variables: {
                    'Timestamp': Variable(
                        accessor: (Map map) => map['Timestamp'] as double,
                        scale: LinearScale()
                        // scale: TimeScale(
                        //   formatter: (time) =>
                        //       time.toString(), // Format time as needed
                        // ),
                        ),
                    for (final service in selectedServices)
                      service: Variable(
                        accessor: (Map map) => map[service] as num,
                        scale: LinearScale(),
                      )
                  },
                  // elements: [
                  //   ...selectedServices.map((service) => LineElement(
                  //         position: Varset('Timestamp') * Varset(service),
                  //         color: getColor(service),
                  //       )),
                  // ],
                ),
              ),
            );
          }).toList()
      ];
    }
  }
}

void main() {
  runApp(const BenchmarkApp());
}

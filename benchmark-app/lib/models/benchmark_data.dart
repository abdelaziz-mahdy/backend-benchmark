double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class DataPoint {
  final double timestamp;
  final int userCount;
  final double requestsPerSec;
  final double failuresPerSec;
  final double responsesPerSec;
  final double p50;
  final double p66;
  final double p75;
  final double p80;
  final double p90;
  final double p95;
  final double p98;
  final double p99;
  final double p999;
  final double p9999;
  final double p100;
  final double totalRequestCount;
  final double totalFailureCount;
  final double totalMedianResponseTime;
  final double totalAverageResponseTime;
  final double totalMinResponseTime;
  final double totalMaxResponseTime;
  final double totalAverageContentSize;
  final double timeDifference;
  final double responsesPerSecSmoothed;
  final double responseTime;
  final double? benchmarkCpuUsage;
  final double? benchmarkMemUsageMb;
  final double? dbCpuUsage;
  final double? dbMemUsageMb;

  const DataPoint({
    required this.timestamp,
    required this.userCount,
    required this.requestsPerSec,
    required this.failuresPerSec,
    required this.responsesPerSec,
    required this.p50,
    required this.p66,
    required this.p75,
    required this.p80,
    required this.p90,
    required this.p95,
    required this.p98,
    required this.p99,
    required this.p999,
    required this.p9999,
    required this.p100,
    required this.totalRequestCount,
    required this.totalFailureCount,
    required this.totalMedianResponseTime,
    required this.totalAverageResponseTime,
    required this.totalMinResponseTime,
    required this.totalMaxResponseTime,
    required this.totalAverageContentSize,
    required this.timeDifference,
    required this.responsesPerSecSmoothed,
    required this.responseTime,
    this.benchmarkCpuUsage,
    this.benchmarkMemUsageMb,
    this.dbCpuUsage,
    this.dbMemUsageMb,
  });

  factory DataPoint.fromJson(Map<String, dynamic> json) {
    return DataPoint(
      timestamp: _toDouble(json['Timestamp']) ?? 0,
      userCount: _toInt(json['User Count']),
      requestsPerSec: _toDouble(json['Requests/s']) ?? 0,
      failuresPerSec: _toDouble(json['Failures/s']) ?? 0,
      responsesPerSec: _toDouble(json['Responses/s']) ?? 0,
      p50: _toDouble(json['50%']) ?? 0,
      p66: _toDouble(json['66%']) ?? 0,
      p75: _toDouble(json['75%']) ?? 0,
      p80: _toDouble(json['80%']) ?? 0,
      p90: _toDouble(json['90%']) ?? 0,
      p95: _toDouble(json['95%']) ?? 0,
      p98: _toDouble(json['98%']) ?? 0,
      p99: _toDouble(json['99%']) ?? 0,
      p999: _toDouble(json['99.9%']) ?? 0,
      p9999: _toDouble(json['99.99%']) ?? 0,
      p100: _toDouble(json['100%']) ?? 0,
      totalRequestCount: _toDouble(json['Total Request Count']) ?? 0,
      totalFailureCount: _toDouble(json['Total Failure Count']) ?? 0,
      totalMedianResponseTime:
          _toDouble(json['Total Median Response Time']) ?? 0,
      totalAverageResponseTime:
          _toDouble(json['Total Average Response Time']) ?? 0,
      totalMinResponseTime:
          _toDouble(json['Total Min Response Time']) ?? 0,
      totalMaxResponseTime:
          _toDouble(json['Total Max Response Time']) ?? 0,
      totalAverageContentSize:
          _toDouble(json['Total Average Content Size']) ?? 0,
      timeDifference: _toDouble(json['Time Difference']) ?? 0,
      responsesPerSecSmoothed:
          _toDouble(json['Responses/s Smoothed']) ?? 0,
      responseTime: _toDouble(json['Response Time']) ?? 0,
      benchmarkCpuUsage: _toDouble(json['benchmark_cpu_usage']),
      benchmarkMemUsageMb: _toDouble(json['benchmark_mem_usage_mb']),
      dbCpuUsage: _toDouble(json['db_cpu_usage']),
      dbMemUsageMb: _toDouble(json['db_mem_usage_mb']),
    );
  }

  double? getField(String fieldName) {
    switch (fieldName) {
      case 'Requests/s':
        return requestsPerSec;
      case 'Failures/s':
        return failuresPerSec;
      case 'Responses/s':
        return responsesPerSec;
      case 'Responses/s Smoothed':
        return responsesPerSecSmoothed;
      case 'Response Time':
        return responseTime;
      case 'User Count':
        return userCount.toDouble();
      case '50%':
        return p50;
      case '66%':
        return p66;
      case '75%':
        return p75;
      case '80%':
        return p80;
      case '90%':
        return p90;
      case '95%':
        return p95;
      case '98%':
        return p98;
      case '99%':
        return p99;
      case '99.9%':
        return p999;
      case '99.99%':
        return p9999;
      case '100%':
        return p100;
      case 'Total Request Count':
        return totalRequestCount;
      case 'Total Failure Count':
        return totalFailureCount;
      case 'Total Median Response Time':
        return totalMedianResponseTime;
      case 'Total Average Response Time':
        return totalAverageResponseTime;
      case 'Total Min Response Time':
        return totalMinResponseTime;
      case 'Total Max Response Time':
        return totalMaxResponseTime;
      case 'Total Average Content Size':
        return totalAverageContentSize;
      case 'benchmark_cpu_usage':
        return benchmarkCpuUsage;
      case 'benchmark_mem_usage_mb':
        return benchmarkMemUsageMb;
      case 'db_cpu_usage':
        return dbCpuUsage;
      case 'db_mem_usage_mb':
        return dbMemUsageMb;
      default:
        return null;
    }
  }
}

class BenchmarkService {
  final String name;
  final Map<String, double> summary;
  final List<DataPoint> data;

  const BenchmarkService({
    required this.name,
    required this.summary,
    required this.data,
  });

  factory BenchmarkService.fromJson(String name, Map<String, dynamic> json) {
    final summaryMap = <String, double>{};
    final rawSummary = json['summary'] as Map<String, dynamic>;
    for (final entry in rawSummary.entries) {
      summaryMap[entry.key] = _toDouble(entry.value) ?? 0;
    }

    final dataList = (json['data'] as List)
        .map((e) => DataPoint.fromJson(e as Map<String, dynamic>))
        .toList();

    return BenchmarkService(name: name, summary: summaryMap, data: dataList);
  }
}

const List<String> availableFields = [
  'Requests/s',
  'Failures/s',
  'Responses/s',
  'Responses/s Smoothed',
  'Response Time',
  'User Count',
  '50%',
  '66%',
  '75%',
  '80%',
  '90%',
  '95%',
  '98%',
  '99%',
  '99.9%',
  '99.99%',
  '100%',
  'Total Request Count',
  'Total Failure Count',
  'Total Median Response Time',
  'Total Average Response Time',
  'Total Min Response Time',
  'Total Max Response Time',
  'Total Average Content Size',
  'benchmark_cpu_usage',
  'benchmark_mem_usage_mb',
  'db_cpu_usage',
  'db_mem_usage_mb',
];

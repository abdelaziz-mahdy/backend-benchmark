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
      timestamp: (json['Timestamp'] as num?)?.toDouble() ?? 0,
      userCount: (json['User Count'] as num?)?.toInt() ?? 0,
      requestsPerSec: (json['Requests/s'] as num?)?.toDouble() ?? 0,
      failuresPerSec: (json['Failures/s'] as num?)?.toDouble() ?? 0,
      responsesPerSec: (json['Responses/s'] as num?)?.toDouble() ?? 0,
      p50: (json['50%'] as num?)?.toDouble() ?? 0,
      p66: (json['66%'] as num?)?.toDouble() ?? 0,
      p75: (json['75%'] as num?)?.toDouble() ?? 0,
      p80: (json['80%'] as num?)?.toDouble() ?? 0,
      p90: (json['90%'] as num?)?.toDouble() ?? 0,
      p95: (json['95%'] as num?)?.toDouble() ?? 0,
      p98: (json['98%'] as num?)?.toDouble() ?? 0,
      p99: (json['99%'] as num?)?.toDouble() ?? 0,
      p999: (json['99.9%'] as num?)?.toDouble() ?? 0,
      p9999: (json['99.99%'] as num?)?.toDouble() ?? 0,
      p100: (json['100%'] as num?)?.toDouble() ?? 0,
      totalRequestCount:
          (json['Total Request Count'] as num?)?.toDouble() ?? 0,
      totalFailureCount:
          (json['Total Failure Count'] as num?)?.toDouble() ?? 0,
      totalMedianResponseTime:
          (json['Total Median Response Time'] as num?)?.toDouble() ?? 0,
      totalAverageResponseTime:
          (json['Total Average Response Time'] as num?)?.toDouble() ?? 0,
      totalMinResponseTime:
          (json['Total Min Response Time'] as num?)?.toDouble() ?? 0,
      totalMaxResponseTime:
          (json['Total Max Response Time'] as num?)?.toDouble() ?? 0,
      totalAverageContentSize:
          (json['Total Average Content Size'] as num?)?.toDouble() ?? 0,
      timeDifference: (json['Time Difference'] as num?)?.toDouble() ?? 0,
      responsesPerSecSmoothed:
          (json['Responses/s Smoothed'] as num?)?.toDouble() ?? 0,
      responseTime: (json['Response Time'] as num?)?.toDouble() ?? 0,
      benchmarkCpuUsage:
          (json['benchmark_cpu_usage'] as num?)?.toDouble(),
      benchmarkMemUsageMb:
          (json['benchmark_mem_usage_mb'] as num?)?.toDouble(),
      dbCpuUsage: (json['db_cpu_usage'] as num?)?.toDouble(),
      dbMemUsageMb: (json['db_mem_usage_mb'] as num?)?.toDouble(),
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
      summaryMap[entry.key] = (entry.value as num?)?.toDouble() ?? 0;
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

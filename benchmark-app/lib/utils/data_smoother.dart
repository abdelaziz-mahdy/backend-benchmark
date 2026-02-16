import '../models/benchmark_data.dart';

List<double> smooth(List<DataPoint> data, String field) {
  final values = data.map((d) => d.getField(field) ?? 0).toList();
  if (values.length < 3) return values;

  final result = List<double>.filled(values.length, 0);
  result[0] = values[0];
  result[values.length - 1] = values[values.length - 1];

  for (var i = 1; i < values.length - 1; i++) {
    result[i] = (values[i - 1] + values[i] + values[i + 1]) / 3;
  }

  return result;
}

import 'src/generated/serverpod.dart';

void run(List<String> args) async {
  final pod = Serverpod(args);
  await pod.start();
}

import 'package:serverpod/serverpod.dart';

import 'src/generated/protocol.dart';
import 'src/generated/endpoints.dart';

void run(List<String> args) async {
  final pod = Serverpod(args, Protocol(), Endpoints());
  await pod.start();
}

import 'package:material_ui/material_ui.dart';

import '../utils/theme_constants.dart';

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: p.accent,
              backgroundColor: p.line,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading the results',
            style: TextStyle(fontSize: 15, color: p.muted),
          ),
        ],
      ),
    );
  }
}

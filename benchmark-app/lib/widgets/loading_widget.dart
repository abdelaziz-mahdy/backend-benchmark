import 'package:material_ui/material_ui.dart';

import '../utils/theme_constants.dart';

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: kSignal,
              backgroundColor: kGridLine,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Loading benchmark data',
            style: TextStyle(fontSize: 12, color: kTextMuted),
          ),
        ],
      ),
    );
  }
}

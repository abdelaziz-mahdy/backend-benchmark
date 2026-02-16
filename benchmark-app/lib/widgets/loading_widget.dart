import 'package:flutter/material.dart';

class LoadingWidget extends StatelessWidget {
  final double progress;

  const LoadingWidget({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              value: progress > 0 ? progress : null,
              strokeWidth: 3,
              color: const Color(0xFF58A6FF),
              backgroundColor: const Color(0xFF21262D),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${(progress * 100).toInt()}%',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFC9D1D9),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Loading benchmark data',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF484F58),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonLoader extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    // Determine shimmer colors based on theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2C303A) : Colors.grey[300]!;
    final highlightColor = isDark ? const Color(0xFF3D4352) : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class SkeletonProfileHeader extends StatelessWidget {
  const SkeletonProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Removed header text skeletons to avoid duplication with the actual sticky header
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withOpacity(0.05),
          ),
          child: const Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              children: [
                SkeletonLoader(
                  width: 48,
                  height: 48,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SkeletonLoader(width: 120, height: 20),
                    SizedBox(height: 8),
                    SkeletonLoader(width: 180, height: 14),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class SkeletonNotificationCard extends StatelessWidget {
  const SkeletonNotificationCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: SkeletonLoader(
              width: 8,
              height: 8,
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonLoader(width: 120, height: 14),
                    SkeletonLoader(width: 40, height: 11),
                  ],
                ),
                const SizedBox(height: 8),
                const SkeletonLoader(width: 200, height: 13),
                const SizedBox(height: 8),
                const SkeletonLoader(width: double.infinity, height: 12),
                const SizedBox(height: 4),
                const SkeletonLoader(width: 150, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SkeletonNotificationList extends StatelessWidget {
  const SkeletonNotificationList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: 6, // Show enough items to fill the screen
      itemBuilder: (context, index) => const SkeletonNotificationCard(),
      physics:
          const NeverScrollableScrollPhysics(), // Prevent scrolling while loading
      shrinkWrap: true,
    );
  }
}

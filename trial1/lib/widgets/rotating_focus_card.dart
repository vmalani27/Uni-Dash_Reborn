import 'dart:async';
import 'package:flutter/material.dart';
import 'package:trial1/models/academic_models.dart';
import 'package:trial1/widgets/focus_card.dart';

/// A rotating focus card that cycles through priority items automatically.
/// Features: circular queue, manual navigation, indicator dots, smooth animations.
class RotatingFocusCard extends StatefulWidget {
  final List<AcademicItem> focusItems;
  final Duration rotationInterval;
  final VoidCallback? onActionCompleted;
  final VoidCallback? onActionDismissed;

  const RotatingFocusCard({
    super.key,
    required this.focusItems,
    this.rotationInterval = const Duration(seconds: 6),
    this.onActionCompleted,
    this.onActionDismissed,
  });

  @override
  State<RotatingFocusCard> createState() => _RotatingFocusCardState();
}

class _RotatingFocusCardState extends State<RotatingFocusCard> {
  late int currentIndex;
  Timer? _rotationTimer;

  @override
  void initState() {
    super.initState();
    currentIndex = 0;
    _startRotation();
  }

  @override
  void didUpdateWidget(RotatingFocusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusItems.length != widget.focusItems.length) {
      _stopRotation();
      currentIndex = 0;
      _startRotation();
    }
  }

  void _startRotation() {
    // Only rotate if there are multiple items
    if (widget.focusItems.length <= 1) {
      return;
    }
    _rotationTimer = Timer.periodic(widget.rotationInterval, (_) {
      if (mounted) {
        setState(() {
          currentIndex = (currentIndex + 1) % widget.focusItems.length;
        });
      }
    });
  }

  void _stopRotation() {
    _rotationTimer?.cancel();
    _rotationTimer = null;
  }

  void _goToPrevious() {
    _stopRotation();
    setState(() {
      currentIndex =
          (currentIndex - 1 + widget.focusItems.length) % widget.focusItems.length;
    });
    _startRotation();
  }

  void _goToNext() {
    _stopRotation();
    setState(() {
      currentIndex = (currentIndex + 1) % widget.focusItems.length;
    });
    _startRotation();
  }

  void _goToIndex(int index) {
    _stopRotation();
    setState(() {
      currentIndex = index;
    });
    _startRotation();
  }

  @override
  void dispose() {
    _stopRotation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.focusItems.isEmpty) {
      return const FocusCard();
    }

    final currentItem = widget.focusItems[currentIndex];
    final hasMultipleItems = widget.focusItems.length > 1;

    return Column(
      children: [
        // Animated focus card
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.1, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                child: child,
              ),
            );
          },
          child: FocusCard(
            key: ValueKey(currentIndex),
            item: currentItem,
            onActionCompleted: widget.onActionCompleted,
            onActionDismissed: widget.onActionDismissed,
          ),
        ),

        // Navigation controls and indicators (only if multiple items)
        if (hasMultipleItems) ...[
          const SizedBox(height: 12),
          _buildControlsRow(context),
          const SizedBox(height: 4),
          _buildIndicators(context),
        ],
      ],
    );
  }

  Widget _buildControlsRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous button
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _goToPrevious,
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          // Item counter
          Text(
            '${currentIndex + 1} / ${widget.focusItems.length}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          // Next button
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _goToNext,
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicators(BuildContext context) {
    return Center(
      child: Wrap(
        spacing: 6,
        children: List.generate(widget.focusItems.length, (index) {
          final isActive = index == currentIndex;
          return GestureDetector(
            onTap: () => _goToIndex(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isActive ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    );
  }
}

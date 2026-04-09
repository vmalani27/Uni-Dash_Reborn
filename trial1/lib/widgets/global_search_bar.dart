import 'package:flutter/material.dart';
import 'package:trial1/models/academic_models.dart';

/// Global search bar for filtering academic items.
/// Notifies parent of search query changes via callback.
/// Results are displayed in main content area via SearchResultsView.
class GlobalSearchBar extends StatefulWidget {
  final List<AcademicItem>? academicItems;
  final VoidCallback? onResultSelected;
  final Function(String)? onSearchQueryChanged;

  const GlobalSearchBar({
    super.key,
    this.academicItems,
    this.onResultSelected,
    this.onSearchQueryChanged,
  });

  @override
  State<GlobalSearchBar> createState() => _GlobalSearchBarState();
}

class _GlobalSearchBarState extends State<GlobalSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    print('[GlobalSearchBar] Initialized');
    print('[GlobalSearchBar] Available items: ${widget.academicItems?.length ?? 0}');
    if (widget.academicItems != null && widget.academicItems!.isNotEmpty) {
      print('[GlobalSearchBar] Items list:');
      for (var i = 0; i < widget.academicItems!.length; i++) {
        final item = widget.academicItems![i];
        print('  [$i] ${item.title} | Type: ${item.entityType} | Score: ${item.academicScore}');
      }
    } else {
      print('[GlobalSearchBar] NO ITEMS PROVIDED!');
    }
    _focusNode.addListener(() {
      setState(() {});  // Rebuild on focus change to update border styling
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    print('[OnChange] Text field changed to: "$query"');
    widget.onSearchQueryChanged?.call(query);
  }

  void _clearSearch() {
    print('[ClearSearch] Clearing search field');
    _controller.clear();
    widget.onSearchQueryChanged?.call('');
    _focusNode.unfocus();
    print('[ClearSearch] Search cleared');
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _focusNode.hasFocus
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withOpacity(0.3),
            width: _focusNode.hasFocus ? 2 : 1,
          ),
          boxShadow: _focusNode.hasFocus
              ? [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 0),
                    spreadRadius: 0,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search academic items...',
            hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              fontSize: 14,
            ),
            border: InputBorder.none,
            prefixIcon: Icon(
              Icons.search,
              size: 18,
              color: _focusNode.hasFocus
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: _focusNode.hasFocus
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    onPressed: _clearSearch,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          ),
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

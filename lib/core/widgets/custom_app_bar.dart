import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Widget? leading;
  final double elevation;
  final bool centerTitle;
  
  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBackButton = true,
    this.onBackPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.leading,
    this.elevation = 0,
    this.centerTitle = true,
  });
  
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          color: foregroundColor ?? theme.appBarTheme.foregroundColor,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: centerTitle,
      backgroundColor: backgroundColor ?? theme.appBarTheme.backgroundColor,
      foregroundColor: foregroundColor ?? theme.appBarTheme.foregroundColor,
      elevation: elevation,
      leading: leading ?? _buildLeading(context),
      actions: actions,
      automaticallyImplyLeading: showBackButton,
    );
  }
  
  Widget? _buildLeading(BuildContext context) {
    if (!showBackButton) return null;
    
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: onBackPressed ?? () => Navigator.pop(context),
    );
  }
}

class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Gradient gradient;
  
  const GradientAppBar({
    super.key,
    required this.title,
    this.actions,
    this.gradient = const LinearGradient(
      colors: [Color(0xFF00C853), Color(0xFF64DD17)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  });
  
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: gradient),
      child: AppBar(
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: actions,
      ),
    );
  }
}

class SearchAppBar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  final String hintText;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onCancel;
  
  const SearchAppBar({
    super.key,
    required this.hintText,
    required this.onSearchChanged,
    this.onCancel,
  });
  
  @override
  ConsumerState<SearchAppBar> createState() => _SearchAppBarState();
  
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _SearchAppBarState extends ConsumerState<SearchAppBar> {
  final TextEditingController _controller = TextEditingController();
  bool _isSearching = false;
  
  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: _isSearching
          ? TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.hintText,
                border: InputBorder.none,
                hintStyle: const TextStyle(color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white),
              onChanged: widget.onSearchChanged,
            )
          : Text(widget.hintText),
      centerTitle: true,
      backgroundColor: Theme.of(context).primaryColor,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.search),
          onPressed: () {
            setState(() {
              if (_isSearching) {
                _controller.clear();
                widget.onSearchChanged('');
                if (widget.onCancel != null) {
                  widget.onCancel!();
                }
              }
              _isSearching = !_isSearching;
            });
          },
        ),
      ],
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
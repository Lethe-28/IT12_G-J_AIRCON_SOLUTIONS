import 'package:flutter/material.dart';

// ============================================================================
// SHARED UI COMPONENTS & UTILITIES
// ============================================================================

// Design Tokens
class AppDesignTokens {
  static const Color primary = Color(0xFF2563EB);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  
  static const Color gray50 = Color(0xFFF9FAFB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray900 = Color(0xFF111827);
  
  static const double spacingXS = 4.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 16.0;
  static const double spacingLG = 24.0;
  static const double spacingXL = 32.0;
  static const double spacing2XL = 48.0;
  
  static const double borderRadiusSM = 8.0;
  static const double borderRadiusMD = 12.0;
  static const double borderRadiusLG = 16.0;
}

// ============================================================================
// LOADING INDICATORS
// ============================================================================

class LoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  
  const LoadingOverlay({super.key, required this.child, required this.isLoading});
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
}

class LoadingButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool isLoading;
  final bool isPrimary;
  
  const LoadingButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.isPrimary = false,
  });
  
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : icon != null
              ? Icon(icon, size: 16)
              : const SizedBox.shrink(),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? AppDesignTokens.primary : Colors.white,
        foregroundColor: isPrimary ? Colors.white : AppDesignTokens.gray500,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDesignTokens.borderRadiusSM),
          side: isPrimary
              ? BorderSide.none
              : const BorderSide(color: AppDesignTokens.gray200),
        ),
      ),
    );
  }
}

// ============================================================================
// EMPTY STATES
// ============================================================================

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;
  
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDesignTokens.spacing2XL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppDesignTokens.spacingXL),
              decoration: BoxDecoration(
                color: (iconColor ?? AppDesignTokens.primary).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: iconColor ?? AppDesignTokens.primary,
              ),
            ),
            const SizedBox(height: AppDesignTokens.spacingLG),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppDesignTokens.gray900,
              ),
            ),
            const SizedBox(height: AppDesignTokens.spacingSM),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppDesignTokens.gray500,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppDesignTokens.spacingLG),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 18),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignTokens.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDesignTokens.spacingLG,
                    vertical: AppDesignTokens.spacingMD,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// FORM VALIDATION HELPERS
// ============================================================================

class ValidatedTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final IconData? prefixIcon;
  final String? hintText;
  final int? maxLines;
  final void Function(String)? onChanged;
  final bool required;
  
  const ValidatedTextField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.prefixIcon,
    this.hintText,
    this.maxLines = 1,
    this.onChanged,
    this.required = false,
  });
  
  @override
  State<ValidatedTextField> createState() => _ValidatedTextFieldState();
}

class _ValidatedTextFieldState extends State<ValidatedTextField> {
  String? _errorText;
  bool _isValid = false;
  
  void _validate(String value) {
    if (widget.validator != null) {
      setState(() {
        _errorText = widget.validator!(value);
        _isValid = _errorText == null && value.isNotEmpty;
      });
    } else if (widget.required && value.trim().isEmpty) {
      setState(() {
        _errorText = '${widget.label} is required';
        _isValid = false;
      });
    } else {
      setState(() {
        _errorText = null;
        _isValid = value.isNotEmpty;
      });
    }
    widget.onChanged?.call(value);
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          obscureText: widget.obscureText,
          maxLines: widget.maxLines,
          onChanged: _validate,
          decoration: InputDecoration(
            labelText: widget.required ? '${widget.label} *' : widget.label,
            hintText: widget.hintText,
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon)
                : null,
            suffixIcon: _isValid
                ? const Icon(Icons.check_circle, color: AppDesignTokens.success, size: 20)
                : null,
            errorText: _errorText,
            errorMaxLines: 2,
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDesignTokens.borderRadiusSM),
              borderSide: BorderSide(
                color: _errorText != null
                    ? AppDesignTokens.error
                    : AppDesignTokens.gray200,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDesignTokens.borderRadiusSM),
              borderSide: BorderSide(
                color: _errorText != null
                    ? AppDesignTokens.error
                    : AppDesignTokens.primary,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDesignTokens.borderRadiusSM),
              borderSide: const BorderSide(color: AppDesignTokens.error, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDesignTokens.borderRadiusSM),
              borderSide: const BorderSide(color: AppDesignTokens.error, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppDesignTokens.spacingMD,
              vertical: AppDesignTokens.spacingMD,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// CONFIRMATION DIALOGS WITH UNDO
// ============================================================================

Future<bool?> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  Color? confirmColor,
  bool isDestructive = false,
}) async {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignTokens.borderRadiusMD),
      ),
      title: Row(
        children: [
          Icon(
            isDestructive ? Icons.warning_amber_rounded : Icons.info_outline,
            color: isDestructive ? AppDesignTokens.error : AppDesignTokens.primary,
            size: 24,
          ),
          const SizedBox(width: AppDesignTokens.spacingSM),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: isDestructive
                ? AppDesignTokens.error
                : (confirmColor ?? AppDesignTokens.primary),
            foregroundColor: Colors.white,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

void showUndoSnackBar({
  required BuildContext context,
  required String message,
  required VoidCallback onUndo,
  Duration duration = const Duration(seconds: 5),
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Expanded(child: Text(message)),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              onUndo();
            },
            child: const Text(
              'UNDO',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: AppDesignTokens.gray900,
      behavior: SnackBarBehavior.floating,
      duration: duration,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignTokens.borderRadiusSM),
      ),
    ),
  );
}

// ============================================================================
// RESPONSIVE HELPERS
// ============================================================================

bool isMobile(BuildContext context) {
  return MediaQuery.of(context).size.width < 600;
}

bool isTablet(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  return width >= 600 && width < 1024;
}

bool isDesktop(BuildContext context) {
  return MediaQuery.of(context).size.width >= 1024;
}

// ============================================================================
// FILTER CHIPS
// ============================================================================

class FilterChipGroup extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final Function(String) onSelected;
  final String label;
  
  const FilterChipGroup({
    super.key,
    required this.options,
    this.selected,
    required this.onSelected,
    required this.label,
  });
  
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDesignTokens.spacingSM,
      runSpacing: AppDesignTokens.spacingSM,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            '$label:',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppDesignTokens.gray500,
            ),
          ),
          const SizedBox(width: AppDesignTokens.spacingSM),
        ],
        ...options.map((option) => FilterChip(
          label: Text(option),
          selected: selected == option,
          onSelected: (selected) {
            if (selected) onSelected(option);
          },
          selectedColor: AppDesignTokens.primary.withOpacity(0.2),
          checkmarkColor: AppDesignTokens.primary,
          labelStyle: TextStyle(
            color: selected == option
                ? AppDesignTokens.primary
                : AppDesignTokens.gray500,
            fontWeight: selected == option
                ? FontWeight.w600
                : FontWeight.normal,
          ),
        )),
      ],
    );
  }
}

// ============================================================================
// SORTABLE TABLE HEADER
// ============================================================================

class SortableColumnHeader extends StatelessWidget {
  final String label;
  final bool isSorted;
  final bool isAscending;
  final VoidCallback onSort;
  
  const SortableColumnHeader({
    super.key,
    required this.label,
    this.isSorted = false,
    this.isAscending = true,
    required this.onSort,
  });
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSort,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppDesignTokens.gray900,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            isSorted
                ? (isAscending ? Icons.arrow_upward : Icons.arrow_downward)
                : Icons.unfold_more,
            size: 16,
            color: isSorted ? AppDesignTokens.primary : AppDesignTokens.gray500,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ANIMATED WIDGETS
// ============================================================================

class AnimatedCard extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Curve curve;
  final double? elevation;
  
  const AnimatedCard({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.curve = Curves.easeOutCubic,
    this.elevation,
  });
  
  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.6, curve: widget.curve),
      ),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.0, 0.6, curve: widget.curve),
      ),
    );
    
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

class HoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final double? elevation;
  
  const HoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.backgroundColor,
    this.elevation,
  });
  
  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _elevationAnimation = Tween<double>(begin: 2.0, end: 8.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _controller.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _controller.reverse();
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                padding: widget.padding ?? const EdgeInsets.all(AppDesignTokens.spacingMD),
                decoration: BoxDecoration(
                  color: widget.backgroundColor ?? Colors.white,
                  borderRadius: BorderRadius.circular(AppDesignTokens.borderRadiusMD),
                  border: Border.all(
                    color: AppDesignTokens.gray200,
                    width: _isHovered ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05 + (_elevationAnimation.value - 2) * 0.01),
                      blurRadius: _elevationAnimation.value,
                      offset: Offset(0, _elevationAnimation.value / 2),
                    ),
                  ],
                ),
                child: widget.child,
              ),
            );
          },
        ),
      ),
    );
  }
}

class AnimatedButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final EdgeInsetsGeometry? padding;
  final IconData? icon;
  
  const AnimatedButton({
    super.key,
    required this.child,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.padding,
    this.icon,
  });
  
  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }
  
  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onPressed?.call();
  }
  
  void _handleTapCancel() {
    _controller.reverse();
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              padding: widget.padding ?? const EdgeInsets.symmetric(
                horizontal: AppDesignTokens.spacingMD,
                vertical: AppDesignTokens.spacingSM,
              ),
              decoration: BoxDecoration(
                color: widget.backgroundColor ?? AppDesignTokens.primary,
                borderRadius: BorderRadius.circular(AppDesignTokens.borderRadiusSM),
                boxShadow: [
                  BoxShadow(
                    color: (widget.backgroundColor ?? AppDesignTokens.primary).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      size: 18,
                      color: widget.foregroundColor ?? Colors.white,
                    ),
                    const SizedBox(width: AppDesignTokens.spacingSM),
                  ],
                  DefaultTextStyle(
                    style: TextStyle(
                      color: widget.foregroundColor ?? Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    child: widget.child,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class ShimmerEffect extends StatefulWidget {
  final Widget child;
  final bool enabled;
  
  const ShimmerEffect({
    super.key,
    required this.child,
    this.enabled = true,
  });
  
  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.0 + _controller.value * 2, 0),
              end: Alignment(1.0 + _controller.value * 2, 0),
              colors: const [
                Colors.transparent,
                Colors.white30,
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

// ============================================================================
// RESPONSIVE CARD GRID
// ============================================================================

class ResponsiveCardGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  
  const ResponsiveCardGrid({
    super.key,
    required this.children,
    this.spacing = AppDesignTokens.spacingLG,
  });
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount = 1;
        
        if (width > 1200) {
          crossAxisCount = 4;
        } else if (width > 900) {
          crossAxisCount = 3;
        } else if (width > 600) {
          crossAxisCount = 2;
        }
        
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: 1.2,
          ),
          itemCount: children.length,
          itemBuilder: (context, index) => children[index],
        );
      },
    );
  }
}

// ============================================================================
// MOBILE-FRIENDLY DATA TABLE (Card View)
// ============================================================================

class ResponsiveDataTable<T> extends StatelessWidget {
  final List<T> data;
  final List<DataColumn> columns;
  final DataRow Function(T item, int index) buildRow;
  final bool showMobileCardView;
  final Widget Function(T item, BuildContext context)? mobileCardBuilder;
  
  const ResponsiveDataTable({
    super.key,
    required this.data,
    required this.columns,
    required this.buildRow,
    this.showMobileCardView = true,
    this.mobileCardBuilder,
  });
  
  @override
  Widget build(BuildContext context) {
    if (isMobile(context) && showMobileCardView) {
      if (mobileCardBuilder != null) {
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: data.length,
          itemBuilder: (context, index) => mobileCardBuilder!(data[index], context),
        );
      }
      // Default mobile card view
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: data.length,
        itemBuilder: (context, index) {
          final item = data[index];
          final row = buildRow(item, index);
          return Container(
            margin: const EdgeInsets.only(bottom: AppDesignTokens.spacingMD),
            padding: const EdgeInsets.all(AppDesignTokens.spacingMD),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppDesignTokens.borderRadiusMD),
              border: Border.all(color: AppDesignTokens.gray200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: columns.asMap().entries.map((entry) {
                final colIndex = entry.key;
                final col = entry.value;
                if (colIndex < row.cells.length) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppDesignTokens.spacingSM),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            col.label.toString().replaceAll(RegExp(r'[^\w\s]'), ''),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppDesignTokens.gray500,
                            ),
                          ),
                        ),
                        Expanded(child: row.cells[colIndex].child),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              }).toList(),
            ),
          );
        },
      );
    }
    
    // Desktop table view
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(AppDesignTokens.gray50),
        columns: columns,
        rows: data.asMap().entries.map((entry) => buildRow(entry.value, entry.key)).toList(),
      ),
    );
  }
}


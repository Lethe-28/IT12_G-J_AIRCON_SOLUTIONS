import 'package:flutter/material.dart';

/// Mobile-friendly data card that shows key info with expandable details
/// Similar to the reference image design
class DataCard extends StatefulWidget {
  final String id;
  final String title;
  final String subtitle;
  final List<DataRow> keyInfoRows; // Main info visible on card (id, name, status)
  final List<DataRow> allDetailRows; // Full details shown on expand
  final List<Widget> actionButtons; // Edit, delete, etc buttons
  final Color? statusColor;
  final VoidCallback? onTap;

  const DataCard({
    super.key,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.keyInfoRows,
    required this.allDetailRows,
    required this.actionButtons,
    this.statusColor,
    this.onTap,
  });

  @override
  State<DataCard> createState() => _DataCardState();
}

class _DataCardState extends State<DataCard> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          // Header / Main Info
          GestureDetector(
            onTap: _toggleExpand,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // ID Badge + Title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                widget.id,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Key Info Preview
                  ..._buildKeyInfoPreview(),
                  const SizedBox(width: 8),
                  // Expand Icon
                  RotationTransition(
                    turns: _expandAnimation,
                    child: IconButton(
                      onPressed: _toggleExpand,
                      icon: const Icon(Icons.expand_more, color: Color(0xFF64748B)),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Expanded Details
          if (_isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // All Details
                  ...widget.allDetailRows.map((row) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 100,
                            child: Text(
                              row.cells[0].child is Text
                                  ? (row.cells[0].child as Text).data ?? ''
                                  : '',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                          Expanded(
                            child: row.cells[1].child,
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  // Action Buttons
                  Row(
                    children: [
                      ...widget.actionButtons.map((btn) => Expanded(child: btn)).toList(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildKeyInfoPreview() {
    // Show first key info row as preview
    if (widget.keyInfoRows.isEmpty) return [];
    final firstRow = widget.keyInfoRows.first;
    return [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: widget.statusColor?.withOpacity(0.1) ?? const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(4),
        ),
        child: firstRow.cells[1].child,
      ),
    ];
  }
}

/// Creates a simple data card row for details
class DataCardField {
  final String label;
  final String value;
  final TextStyle? valueStyle;

  DataCardField({
    required this.label,
    required this.value,
    this.valueStyle,
  });

  DataRow toDataRow() {
    return DataRow(cells: [
      DataCell(Text(label)),
      DataCell(
        Text(
          value,
          style: valueStyle ??
              const TextStyle(
                fontSize: 13,
                color: Color(0xFF1E293B),
              ),
        ),
      ),
    ]);
  }
}

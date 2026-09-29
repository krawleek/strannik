import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../foundation/app_tokens.dart';

class StrannikTapTarget extends StatefulWidget {
  const StrannikTapTarget({
    super.key,
    required this.label,
    required this.child,
    this.onTap,
    this.selected = false,
    this.expanded,
  });
  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final bool? expanded;
  @override
  State<StrannikTapTarget> createState() => _StrannikTapTargetState();
}

class _StrannikTapTargetState extends State<StrannikTapTarget> {
  bool _focused = false, _pressed = false;
  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    button: true,
    enabled: widget.onTap != null,
    selected: widget.selected,
    expanded: widget.expanded,
    onTap: widget.onTap,
    excludeSemantics: true,
    child: FocusableActionDetector(
      enabled: widget.onTap != null,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.button),
            border: _focused
                ? Border.all(color: AppColors.blue, width: 2)
                : null,
          ),
          child: Opacity(opacity: _pressed ? .8 : 1, child: widget.child),
        ),
      ),
    ),
  );
}

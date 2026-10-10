import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';

/// Bordered ink row for sheet action and picker lists.
class SheetOptionTile extends StatelessWidget {
  /// Create a row with [title] and an optional [subtitle].
  const SheetOptionTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.destructive = false,
    this.enabled = true,
  });

  /// Primary line.
  final String title;

  /// Supporting line under [title].
  final String? subtitle;

  /// Icon or mark at the start of the row.
  final Widget? leading;

  /// Widget at the end of the row.
  final Widget? trailing;

  /// Called when the row is tapped. Ignored when [enabled] is false.
  final VoidCallback? onTap;

  /// Whether this row is the current choice.
  final bool selected;

  /// Paints the row in the error color.
  final bool destructive;

  /// Whether the row accepts taps.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final subtle = context.safaehSubtleAccents;
    final titleColor = destructive
        ? cs.error
        : (enabled ? cs.onSurface : cs.onSurface.withValues(alpha: 0.38));
    final subtitleColor = destructive
        ? cs.error.withValues(alpha: 0.8)
        : cs.onSurfaceVariant;

    return SafaehOptionTile(
      title: SafaehUserText(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: titleColor,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle != null && subtitle!.isNotEmpty
          ? SafaehUserText(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(color: subtitleColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      leading: leading,
      trailing: trailing,
      onTap: onTap,
      selected: selected,
      destructive: destructive,
      enabled: enabled,
      selectedFill: SafaehAccentSurfaces.emphasizedFill(cs, subtle: subtle),
      selectedBorder: SafaehAccentSurfaces.emphasizedBorder(cs, subtle: subtle),
    );
  }
}

/// Vertical list of [SheetOptionTile]s with consistent gaps.
class SheetOptionList extends SafaehOptionList {
  /// Create a list of option rows.
  const SheetOptionList({
    super.key,
    required super.children,
    super.padding,
    super.spacing,
  });
}

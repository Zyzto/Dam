import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';

/// Finder key for the stand-in shown while a deferred sheet is opening.
const sheetOptionSkeletonKey = ValueKey<String>('sheet-option-skeleton');

/// Mounts [child] on the frame after the route's enter animation finishes.
///
/// Long pickers lay out every row during the slide, and that work drops
/// frames. [placeholder] stays up for the motion, then [child] replaces it
/// once the sheet is still. A reverse (dismiss) drops [child] again so the
/// close animation does not layout the full list.
class DeferUntilSheetSettled extends StatefulWidget {
  const DeferUntilSheetSettled({
    super.key,
    required this.placeholder,
    required this.child,
  });

  final Widget placeholder;
  final Widget child;

  @override
  State<DeferUntilSheetSettled> createState() => _DeferUntilSheetSettledState();
}

class _DeferUntilSheetSettledState extends State<DeferUntilSheetSettled> {
  Animation<double>? _animation;
  var _settled = false;
  var _revealScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (identical(animation, _animation)) return;
    _animation?.removeStatusListener(_onStatus);
    _animation = animation;
    animation?.addStatusListener(_onStatus);
    _settled =
        animation == null || animation.status == AnimationStatus.completed;
  }

  void _onStatus(AnimationStatus status) {
    if (!mounted) return;
    if (status == AnimationStatus.completed) {
      _scheduleReveal();
      return;
    }
    if (_settled) setState(() => _settled = false);
  }

  void _scheduleReveal() {
    if (_settled || _revealScheduled) return;
    _revealScheduled = true;
    // The completion tick is still an animation frame. Reveal on the next
    // one so that frame only paints the placeholder.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealScheduled = false;
      if (!mounted) return;
      final status = _animation?.status;
      if (status != null && status != AnimationStatus.completed) return;
      setState(() => _settled = true);
    });
  }

  @override
  void dispose() {
    _animation?.removeStatusListener(_onStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _settled ? widget.child : widget.placeholder;
  }
}

/// Cheap rows that stand in for a [SafaehOptionList] while the sheet moves.
///
/// Heights follow [SafaehOptionTile] (14px vertical padding, body text, and
/// the list's 8px gaps) so a list that already fills the sheet does not
/// jump when the real rows mount.
class SheetOptionSkeleton extends StatelessWidget {
  const SheetOptionSkeleton({
    super.key,
    required this.count,
    this.twoLine = false,
  });

  final int count;
  final bool twoLine;

  @override
  Widget build(BuildContext context) {
    final rowHeight = _sheetOptionRowHeight(context, twoLine: twoLine);
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    final radius = BorderRadius.circular(SafaehTheme.of(context).radius);
    return ExcludeSemantics(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          key: sheetOptionSkeletonKey,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < count; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                SizedBox(
                  height: rowHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: radius,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Layout height of one [SafaehOptionTile]. The border is painted inside the
/// padding, so it does not add to the height.
double _sheetOptionRowHeight(BuildContext context, {required bool twoLine}) {
  final theme = Theme.of(context);
  final scaler = MediaQuery.textScalerOf(context);
  double line(TextStyle? style, double fallbackSize, double fallbackHeight) {
    final size = scaler.scale(style?.fontSize ?? fallbackSize);
    return size * (style?.height ?? fallbackHeight);
  }

  final title = line(theme.textTheme.bodyLarge, 16, 1.5);
  final subtitle = twoLine
      ? 2 + line(theme.textTheme.bodySmall, 12, 1.33)
      : 0.0;
  // Padding is 14 + 14. The 1px border is painted inside that box.
  return 28 + title + subtitle;
}

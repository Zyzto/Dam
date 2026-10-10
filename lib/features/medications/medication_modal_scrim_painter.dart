part of 'medication_reminders_screens.dart';

/// Loads the funnel warp used while the dose card opens and closes.
class _MedicationGenieShader {
  static ui.FragmentProgram? program;
  static Future<void>? _loading;

  static void preload() {
    _loading ??= _load();
  }

  static Future<void> _load() async {
    try {
      program = await ui.FragmentProgram.fromAsset(
        'shaders/medication_genie.frag',
      );
    } catch (_) {
      program = null;
    }
  }
}

/// Squashes the whole dose card into a funnel aimed at the reminder button.
///
/// The card's own proportions change on the way: the far edge stays wide while
/// the edge on the button narrows, and every part of the card is drawn inside
/// that shape.
class _MedicationGenieMorph extends StatefulWidget {
  const _MedicationGenieMorph({
    required this.progress,
    required this.sourceSize,
    required this.opensAbove,
    required this.fromRight,
    required this.child,
  });

  final double progress;
  final Size sourceSize;
  final bool opensAbove;
  final bool fromRight;
  final Widget child;

  @override
  State<_MedicationGenieMorph> createState() => _MedicationGenieMorphState();
}

class _MedicationGenieMorphState extends State<_MedicationGenieMorph> {
  ui.FragmentShader? _shader;

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress.clamp(0.0, 1.0);
    final program = _MedicationGenieShader.program;
    if (progress >= _dosePanelWarpEnd ||
        program == null ||
        !ui.ImageFilter.isShaderFilterSupported) {
      return _genieSquashFallback(context, progress);
    }

    _shader?.dispose();
    _shader = program.fragmentShader();
    final panelWidth = _panelWidth(context);
    final buttonFrac = (widget.sourceSize.width / panelWidth).clamp(0.04, 0.8);
    final warp = (progress / _dosePanelWarpEnd).clamp(0.0, 1.0);
    _shader!
      ..setFloat(2, buttonFrac)
      ..setFloat(3, warp)
      ..setFloat(4, widget.fromRight ? 1 : 0)
      ..setFloat(5, widget.opensAbove ? 1 : 0);

    // The card shadow paints outside the layout box and would push the neck
    // off the button. Clip to the card so the neck stays on the top edge.
    return ImageFiltered(
      imageFilter: ui.ImageFilter.shader(_shader!),
      child: ClipRect(child: widget.child),
    );
  }

  double _panelWidth(BuildContext context) {
    final card = context.findRenderObject();
    if (card is RenderBox && card.hasSize && card.size.width > 1) {
      return card.size.width;
    }
    return math.max(
      1.0,
      math.min(MediaQuery.sizeOf(context).width - 32, 400),
    );
  }

  /// Used only when the funnel shader cannot run. Width and height scale on
  /// different curves so the card still changes proportion.
  Widget _genieSquashFallback(BuildContext context, double progress) {
    if (progress >= _dosePanelWarpEnd) return widget.child;
    final warp = (progress / _dosePanelWarpEnd).clamp(0.0, 1.0);
    final panelWidth = _panelWidth(context);
    final buttonFrac = (widget.sourceSize.width / panelWidth).clamp(0.08, 1.0);
    final rise = Curves.easeOutCubic.transform((warp / 0.78).clamp(0.0, 1.0));
    final mouth = Curves.easeInOutCubic.transform(warp);
    final scaleX = buttonFrac + (1 - buttonFrac) * mouth;
    final scaleY = (buttonFrac * 0.45) + (1 - buttonFrac * 0.45) * rise;
    final anchorX = widget.fromRight ? (1 - buttonFrac) : (-1 + buttonFrac);
    final alignment = widget.opensAbove
        ? Alignment(anchorX, 1)
        : const Alignment(0, -1);
    return Transform(
      alignment: alignment,
      transform: Matrix4.diagonal3Values(scaleX, scaleY, 1),
      filterQuality: FilterQuality.medium,
      child: widget.child,
    );
  }
}

class _MedicationModalScrimPainter extends CustomPainter {
  _MedicationModalScrimPainter({
    required this.fabRect,
    required this.fabShape,
    required this.textDirection,
    required this.animation,
  }) : super(repaint: animation);

  final Rect? fabRect;
  final ShapeBorder fabShape;
  final ui.TextDirection textDirection;
  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value.clamp(0.0, 1.0);
    var scrim = Path()..addRect(Offset.zero & size);
    final rect = fabRect;
    if (rect != null) {
      final cutout = fabShape.getOuterPath(rect, textDirection: textDirection);
      scrim = Path.combine(PathOperation.difference, scrim, cutout);
    }
    canvas.drawPath(
      scrim,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.54 * progress)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_MedicationModalScrimPainter oldDelegate) =>
      oldDelegate.fabRect != fabRect ||
      oldDelegate.fabShape != fabShape ||
      oldDelegate.textDirection != textDirection ||
      oldDelegate.animation != animation;
}

ShapeBorder _medicationFabShape(
  ThemeData theme, {
  required bool compact,
  required bool roundedSquare,
}) => compact && roundedSquare
    ? theme.floatingActionButtonTheme.shape ??
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          )
    : const CircleBorder();

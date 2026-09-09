import 'package:flutter/material.dart';

// five stars you drag across, in half steps, matching the 0.5 the backend enforces.
// this replaced a row of numbered chips, which nothing outside a form actually uses.
class StarRating extends StatefulWidget {
  final double value;
  final double size;
  final ValueChanged<double>? onChanged;

  const StarRating({
    super.key,
    required this.value,
    this.size = 36,
    this.onChanged,
  });

  @override
  State<StarRating> createState() => _StarRatingState();
}

class _StarRatingState extends State<StarRating> {
  // what the finger is currently over, so the stars follow the drag before we commit
  double? _dragValue;

  bool get _interactive => widget.onChanged != null;

  double get _shown => _dragValue ?? widget.value;

  // map an x offset onto 0.5 .. 5.0
  double _valueFor(double dx, double width) {
    final raw = (dx / width) * 5.0;
    final stepped = (raw * 2).ceil() / 2.0;
    return stepped.clamp(0.5, 5.0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final width = widget.size * 5;

    final stars = SizedBox(
      width: width,
      height: widget.size,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final filled = _shown - i;
          final icon = filled >= 1
              ? Icons.star_rounded
              : filled >= 0.5
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded;
          return Icon(
            icon,
            size: widget.size,
            color: filled > 0
                ? cs.primary
                : cs.onSurfaceVariant.withValues(alpha: 0.35),
          );
        }),
      ),
    );

    if (!_interactive) return stars;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => setState(() => _dragValue = _valueFor(d.localPosition.dx, width)),
      onTapUp: (_) => _commit(),
      onTapCancel: () => setState(() => _dragValue = null),
      onHorizontalDragUpdate: (d) =>
          setState(() => _dragValue = _valueFor(d.localPosition.dx, width)),
      onHorizontalDragEnd: (_) => _commit(),
      child: stars,
    );
  }

  void _commit() {
    final value = _dragValue;
    setState(() => _dragValue = null);
    if (value != null) widget.onChanged!(value);
  }
}

// the sheet you rate from. stars plus an optional few words.
class RatingSheet extends StatefulWidget {
  final String title;
  final double? initialScore;
  final String? initialComment;
  final Future<void> Function(double score, String? comment) onSubmit;
  final Future<void> Function()? onClear;

  const RatingSheet({
    super.key,
    required this.title,
    required this.onSubmit,
    this.initialScore,
    this.initialComment,
    this.onClear,
  });

  @override
  State<RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<RatingSheet> {
  late double _score = widget.initialScore ?? 0;
  late final TextEditingController _comment =
      TextEditingController(text: widget.initialComment ?? "");
  bool _saving = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_score < 0.5 || _saving) return;
    setState(() => _saving = true);
    try {
      final text = _comment.text.trim();
      await widget.onSubmit(_score, text.isEmpty ? null : text);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        // lift the sheet above the keyboard when the comment field has focus
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(widget.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          Center(
            child: StarRating(
              value: _score,
              size: 40,
              onChanged: (v) => setState(() => _score = v),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              _score < 0.5 ? "Drag to rate" : _score.toStringAsFixed(1),
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _comment,
            maxLines: 3,
            minLines: 2,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: "Say something about it (optional)",
              counterText: "",
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (widget.onClear != null && widget.initialScore != null)
                TextButton(
                  onPressed: _saving
                      ? null
                      : () async {
                          await widget.onClear!();
                          if (context.mounted) Navigator.pop(context);
                        },
                  child: const Text("Remove"),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _score < 0.5 || _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Save"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

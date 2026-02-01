import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final TextStyle? textStyle;
  final Widget? trailing;
  const SectionHeader({
    super.key,
    required this.title,
    this.textStyle,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style:
                textStyle ??
                const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

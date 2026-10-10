import 'package:flutter/material.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

/// Pushed settings page that uses the same width and app bar as Settings.
class SettingsSubpage extends StatelessWidget {
  const SettingsSubpage({
    super.key,
    required this.title,
    required this.children,
    this.actions,
    this.bottom,
  });

  final Widget title;
  final List<Widget> children;
  final List<Widget>? actions;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: title, actions: actions),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
      bottomNavigationBar: bottom,
    );
}

/// One settings card, expanded by default, collapsible like the settings home.
class SettingsPageCard extends StatefulWidget {
  const SettingsPageCard({
    super.key,
    required this.sectionId,
    required this.title,
    required this.icon,
    required this.children,
    this.initiallyExpanded = true,
  });

  final String sectionId;
  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  State<SettingsPageCard> createState() => _SettingsPageCardState();
}

class _SettingsPageCardState extends State<SettingsPageCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) => CardSettingsSection(
      sectionId: widget.sectionId,
      title: widget.title,
      icon: widget.icon,
      isExpanded: _expanded,
      onExpansionChanged: (expanded) => setState(() => _expanded = expanded),
      children: widget.children,
    );
}

/// Share / export / import row pinned to the bottom of a settings subpage.
class SettingsActionBar extends StatelessWidget {
  const SettingsActionBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.5)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: children),
          ),
        ),
      ),
    );
  }
}

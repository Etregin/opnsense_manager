/*
 * OPNsense Manager - Flutter application for managing OPNsense firewalls
 * Copyright (C) 2026 OPNsense Manager
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

/// A generic donut-style pie chart for top-N network breakdown data.
///
/// [items] is a list of `(label, bytes)` pairs. The last item whose label
/// matches [otherLabel] is rendered in a muted grey to indicate the "Other"
/// aggregate bucket.
class TopBreakdownPieChart extends StatefulWidget {
  /// Chart title displayed above the pie.
  final String title;

  /// Ordered list of `(label, bytes)` tuples, including the "Other" row.
  final List<(String, double)> items;

  /// Label used for the catch-all "Other" entry (matched case-sensitively).
  final String otherLabel;

  const TopBreakdownPieChart({
    super.key,
    required this.title,
    required this.items,
    required this.otherLabel,
  });

  // Colour palette for slices (cycles if more than length).
  static const List<Color> _palette = [
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFE53935),
    Color(0xFFFF8F00),
    AppColors.bandwidth,
    Color(0xFF00ACC1),
    Color(0xFF6D4C41),
    Color(0xFF8E24AA),
    Color(0xFF00897B),
    Color(0xFFD81B60),
  ];
  static const Color _otherColor = AppColors.disabled;

  @override
  State<TopBreakdownPieChart> createState() => _TopBreakdownPieChartState();
}

class _TopBreakdownPieChartState extends State<TopBreakdownPieChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();

    final total = items.fold<double>(0, (sum, e) => sum + e.$2);

    final sections = <PieChartSectionData>[];
    for (var i = 0; i < items.length; i++) {
      final (label, bytes) = items[i];
      final isOther = label == widget.otherLabel;
      final isTouched = _touchedIndex == i;
      final color = isOther
          ? TopBreakdownPieChart._otherColor
          : TopBreakdownPieChart._palette[
              i % TopBreakdownPieChart._palette.length];
      final pct = total > 0 ? bytes / total * 100 : 0.0;

      sections.add(PieChartSectionData(
        value: bytes,
        color: color,
        radius: isTouched ? 70 : 60,
        showTitle: false,
        badgeWidget: isTouched
            ? _Tooltip(label: label, bytes: bytes, pct: pct, color: color)
            : null,
        badgePositionPercentageOffset: 1.3,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppConstants.compactPadding),
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 36,
              sectionsSpace: 1,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        response?.touchedSection == null) {
                      _touchedIndex = null;
                    } else {
                      _touchedIndex =
                          response!.touchedSection!.touchedSectionIndex;
                    }
                  });
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: AppConstants.compactPadding),
        // Legend — show top 5 + Other
        _buildLegend(context, items, total, l10n),
      ],
    );
  }

  Widget _buildLegend(
    BuildContext context,
    List<(String, double)> items,
    double total,
    AppLocalizations l10n,
  ) {
    // Show all named entries, then the Other entry last.
    final named = items.where((e) => e.$1 != widget.otherLabel).toList();
    final otherEntry =
        items.where((e) => e.$1 == widget.otherLabel).firstOrNull;

    final entries = [...named, ...[otherEntry].whereType<(String, double)>()];

    return Column(
      children: entries.map((e) {
        final (label, bytes) = e;
        final isOther = label == widget.otherLabel;
        final idx = items.indexOf(e);
        final color = isOther
            ? TopBreakdownPieChart._otherColor
            : TopBreakdownPieChart._palette[
                idx % TopBreakdownPieChart._palette.length];
        final pct = total > 0 ? bytes / total * 100 : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${pct.toStringAsFixed(1)}%  ${Formatters.formatBytes(bytes.round())}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _Tooltip extends StatelessWidget {
  final String label;
  final double bytes;
  final double pct;
  final Color color;

  const _Tooltip({
    required this.label,
    required this.bytes,
    required this.pct,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius),
        border: Border.all(color: color),
        boxShadow: [
          const BoxShadow(
            color: AppColors.shadow,
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: color),
          ),
          Text(
            '${pct.toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

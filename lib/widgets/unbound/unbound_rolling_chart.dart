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

import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../models/unbound_rolling.dart';
import '../../utils/app_colors.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';

class UnboundRollingChart extends StatelessWidget {
  final List<UnboundRollingPoint> points;
  final int selectedDurationHours;
  final bool isLogarithmic;
  final ValueChanged<int> onDurationChanged;
  final ValueChanged<bool> onLogarithmicChanged;

  const UnboundRollingChart({
    super.key,
    required this.points,
    required this.selectedDurationHours,
    required this.isLogarithmic,
    required this.onDurationChanged,
    required this.onLogarithmicChanged,
  });

  double _transformY(double value) {
    if (!isLogarithmic) return value;
    if (value <= 0) return 0;
    return log(value + 1) / ln10;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (points.isEmpty) {
      return Card(
        elevation: AppConstants.cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.standardPadding),
          child: Center(child: Text(l10n.noDataAvailable)),
        ),
      );
    }

    final minX = points.first.timestamp;
    final maxX = points.last.timestamp;

    double maxVal = 0;
    for (final p in points) {
      if (p.total > maxVal) maxVal = p.total.toDouble();
    }
    if (maxVal == 0) maxVal = 10;

    final maxY = _transformY(maxVal) * 1.15;

    final totalSpots = points
        .map((p) => FlSpot(p.timestamp, _transformY(p.total.toDouble())))
        .toList();
    final passedSpots = points
        .map((p) => FlSpot(p.timestamp, _transformY(p.passed.toDouble())))
        .toList();
    final blockedSpots = points
        .map((p) => FlSpot(p.timestamp, _transformY(p.blocked.toDouble())))
        .toList();

    return Card(
      elevation: AppConstants.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.standardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.queriesOverTheLast,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DropdownButton<int>(
                  value: selectedDurationHours,
                  underline: const SizedBox.shrink(),
                  items: [
                    DropdownMenuItem(value: 24, child: Text(l10n.hoursDuration(24))),
                    DropdownMenuItem(value: 12, child: Text(l10n.hoursDuration(12))),
                    DropdownMenuItem(value: 1, child: Text(l10n.oneHourDuration)),
                  ],
                  onChanged: (val) {
                    if (val != null) onDurationChanged(val);
                  },
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _LegendDot(color: AppColors.primary, label: l10n.totalQueries),
                    const SizedBox(width: AppConstants.standardPadding),
                    const _LegendDot(color: AppColors.success, label: 'Passed'),
                    const SizedBox(width: AppConstants.standardPadding),
                    _LegendDot(color: AppColors.error, label: l10n.blockedQueries),
                  ],
                ),
                Row(
                  children: [
                    Text(l10n.logarithmic, style: theme.textTheme.bodySmall),
                    Switch(
                      value: isLogarithmic,
                      onChanged: onLogarithmicChanged,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppConstants.standardPadding),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  minX: minX,
                  maxX: maxX,
                  minY: 0,
                  maxY: maxY > 0 ? maxY : 10,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: AppColors.opacityDivider,
                      ),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (val, meta) {
                          if (val == meta.max || val == meta.min) return const SizedBox.shrink();
                          final display = isLogarithmic ? pow(10, val).round() : val.round();
                          return Text(
                            Formatters.formatNumber(display),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (val, meta) {
                          if (val == meta.max || val == meta.min) return const SizedBox.shrink();
                          final dt = DateTime.fromMillisecondsSinceEpoch((val * 1000).toInt());
                          return Text(
                            Formatters.formatTime(dt),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: totalSpots,
                      color: AppColors.primary,
                      barWidth: 2,
                      isCurved: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withValues(alpha: AppColors.opacityBare),
                      ),
                    ),
                    LineChartBarData(
                      spots: passedSpots,
                      color: AppColors.success,
                      barWidth: 1.5,
                      isCurved: true,
                      dotData: const FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots: blockedSpots,
                      color: AppColors.error,
                      barWidth: 1.5,
                      isCurved: true,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((touchedSpot) {
                          final originalY = isLogarithmic
                              ? (touchedSpot.y == 0 ? 0 : (pow(10, touchedSpot.y) - 1).round())
                              : touchedSpot.y.round();

                          String label = '';
                          if (touchedSpot.barIndex == 0) {
                            label = l10n.totalQueries;
                          } else if (touchedSpot.barIndex == 1) {
                            label = 'Passed';
                          } else if (touchedSpot.barIndex == 2) {
                            label = l10n.blockedQueries;
                          }

                          return LineTooltipItem(
                            '$label: ${Formatters.formatNumber(originalY)}',
                            TextStyle(
                              color: touchedSpot.bar.color ?? theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

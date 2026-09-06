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
import 'package:provider/provider.dart';
import '../constants/routes.dart';
import '../l10n/app_localizations.dart';
import '../services/demo_api_service.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import '../utils/single_init_mixin.dart';
import '../viewmodels/network_insight_view_model.dart';
import '../widgets/app_drawer.dart';
import '../widgets/common/error_display.dart';
import '../widgets/network_insight/interface_totals_chart.dart';
import '../widgets/network_insight/netflow_disabled_banner.dart';
import '../widgets/network_insight/top_breakdown_pie_chart.dart';

/// Network Insight screen.
///
/// Shows an Interface Totals bps chart at the top (time-range controlled) and
/// a per-interface breakdown section with protocol/address pie charts below.
class NetworkInsightScreen extends StatefulWidget {
  const NetworkInsightScreen({super.key});

  @override
  State<NetworkInsightScreen> createState() => _NetworkInsightScreenState();
}

class _NetworkInsightScreenState extends State<NetworkInsightScreen>
    with SingleInitMixin {
  late NetworkInsightViewModel _vm;

  // ── Loopback visibility toggle ──────────────────────────────────────────────
  bool _showLoopback = true;

  @override
  void onFirstDependency() {
    _vm = NetworkInsightViewModel(context.read<DemoApiService>());
    _vm.addListener(_onVmChanged);
    _vm.loadInitial();
  }

  void _onVmChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _vm.removeListener(_onVmChanged);
    _vm.dispose();
    super.dispose();
  }

  // ── Time range presets ──────────────────────────────────────────────────────

  static const List<_TimePreset> _presets = [
    _TimePreset('2 Hours, 30 seconds average',    Duration(hours: 2),    30),
    _TimePreset('8 Hours, 5 minutes average',     Duration(hours: 8),    300),
    _TimePreset('24 Hours, 5 minutes average',    Duration(hours: 24),   300),
    _TimePreset('7 Days, 1 hour average',         Duration(days: 7),     3600),
    _TimePreset('14 Days, 1 hour average',        Duration(days: 14),    3600),
    _TimePreset('30 Days, 24 hours average',      Duration(days: 30),    86400),
    _TimePreset('60 Days, 24 hours average',      Duration(days: 60),    86400),
    _TimePreset('90 Days, 24 hours average',      Duration(days: 90),    86400),
    _TimePreset('182 Days, 24 hours average',     Duration(days: 182),   86400),
    _TimePreset('Last Year, 24 hours average',    Duration(days: 365),   86400),
  ];

  int _selectedPresetIndex = 0;

  void _onPresetChanged(int index) {
    setState(() => _selectedPresetIndex = index);
    final preset = _presets[index];
    _vm.setTimeRange(preset.duration, preset.resolution);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.networkInsight),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.refresh,
            onPressed: _vm.isLoadingCharts ? null : _vm.loadChartData,
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: Routes.networkInsight),
      body: _buildBody(context, l10n),
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n) {
    if (_vm.isCheckingNetflow) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppConstants.standardPadding),
            Text(l10n.checkingNetflowStatus),
          ],
        ),
      );
    }

    if (_vm.errorMessage != null && !_vm.netflowEnabled) {
      return ErrorDisplay(
        message: _vm.errorMessage!,
        onRetry: _vm.loadInitial,
      );
    }

    if (!_vm.netflowEnabled) {
      return const NetflowDisabledBanner();
    }

    return RefreshIndicator(
      onRefresh: _vm.loadChartData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppConstants.standardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTimeRangeSelector(context, l10n),
            const SizedBox(height: AppConstants.standardPadding),
            _buildInterfaceTotalsSection(context, l10n),
            const SizedBox(height: AppConstants.standardPadding * 1.5),
            _buildBreakdownSection(context, l10n),
          ],
        ),
      ),
    );
  }

  // ── Time range selector ──────────────────────────────────────────────────────

  Widget _buildTimeRangeSelector(BuildContext context, AppLocalizations l10n) {
    return Card(
      elevation: AppConstants.cardElevation,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.standardPadding,
          vertical: AppConstants.compactPadding,
        ),
        child: Row(
          children: [
            Icon(Icons.access_time,
                size: 18,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: AppConstants.compactPadding),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedPresetIndex,
                  isExpanded: true,
                  items: List.generate(
                    _presets.length,
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(
                        _presets[i].label,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  onChanged: (i) {
                    if (i != null) _onPresetChanged(i);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Interface totals (top charts) ────────────────────────────────────────────

  Widget _buildInterfaceTotalsSection(
      BuildContext context, AppLocalizations l10n) {
    return Card(
      elevation: AppConstants.cardElevation,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.standardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.interfaceTotalsBitsPerSec,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      l10n.showLoopback,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Switch(
                      value: _showLoopback,
                      onChanged: (v) => setState(() => _showLoopback = v),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppConstants.compactPadding),
            if (_vm.isLoadingCharts)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppConstants.standardPadding),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_vm.timeseries.isEmpty)
              const SizedBox(height: 80)
            else
              InterfaceTotalsChart(
                series: _vm.timeseries,
                showLoopback: _showLoopback,
              ),
          ],
        ),
      ),
    );
  }

  // ── Per-interface breakdown (pie charts) ─────────────────────────────────────

  Widget _buildBreakdownSection(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.perInterfaceBreakdown,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (_vm.interfaces.isNotEmpty)
              _InterfaceDropdown(
                interfaces: _vm.interfaces,
                selectedKey: _vm.selectedInterface,
                onChanged: _vm.setSelectedInterface,
              ),
          ],
        ),
        const SizedBox(height: AppConstants.standardPadding),
        if (_vm.isLoadingCharts)
          const Center(child: CircularProgressIndicator())
        else ...[
          _buildTotalsSummary(context, l10n),
          const SizedBox(height: AppConstants.standardPadding),
          _buildPieCharts(context, l10n),
        ],
      ],
    );
  }

  Widget _buildTotalsSummary(BuildContext context, AppLocalizations l10n) {
    final octets = _vm.directionOctetTotals;
    final packets = _vm.directionPacketTotals;
    double bytesIn = 0, bytesOut = 0, pktsIn = 0, pktsOut = 0;
    for (final e in octets) {
      if (e.direction == 'in') bytesIn = e.total;
      if (e.direction == 'out') bytesOut = e.total;
    }
    for (final e in packets) {
      if (e.direction == 'in') pktsIn = e.total;
      if (e.direction == 'out') pktsOut = e.total;
    }

    return Card(
      elevation: AppConstants.cardElevation,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.standardPadding),
        child: Column(
          children: [
            _SummaryRow(
              label: l10n.totalBytesIn,
              value: Formatters.formatBytes(bytesIn.round()),
              icon: Icons.arrow_downward,
              color: AppColors.success,
            ),
            _SummaryRow(
              label: l10n.totalBytesOut,
              value: Formatters.formatBytes(bytesOut.round()),
              icon: Icons.arrow_upward,
              color: AppColors.error,
            ),
            _SummaryRow(
              label: l10n.totalPacketsIn,
              value: Formatters.formatNumber(pktsIn.round()),
              icon: Icons.arrow_downward,
              color: AppColors.success,
            ),
            _SummaryRow(
              label: l10n.totalPacketsOut,
              value: Formatters.formatNumber(pktsOut.round()),
              icon: Icons.arrow_upward,
              color: AppColors.error,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieCharts(BuildContext context, AppLocalizations l10n) {
    final portItems = _vm.topPorts
        .map((p) => (p.isOther ? l10n.other : (p.label.isEmpty ? p.dstPort : p.label), p.total))
        .toList();

    final addrItems = _vm.topAddresses
        .map((a) => (a.isOther ? l10n.other : a.srcAddr, a.total))
        .toList();

    return Column(
      children: [
        Card(
          elevation: AppConstants.cardElevation,
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.standardPadding),
            child: TopBreakdownPieChart(
              title: l10n.protocolsBreakdown,
              items: portItems,
              otherLabel: l10n.other,
            ),
          ),
        ),
        const SizedBox(height: AppConstants.standardPadding),
        Card(
          elevation: AppConstants.cardElevation,
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.standardPadding),
            child: TopBreakdownPieChart(
              title: l10n.sourceAddressBreakdown,
              items: addrItems,
              otherLabel: l10n.other,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Private helpers ──────────────────────────────────────────────────────────

/// Dropdown for the per-interface breakdown filter.
class _InterfaceDropdown extends StatelessWidget {
  final Map<String, String> interfaces;
  final String? selectedKey;
  final ValueChanged<String> onChanged;

  const _InterfaceDropdown({
    required this.interfaces,
    required this.selectedKey,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: selectedKey,
        items: interfaces.entries
            .map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value),
                ))
            .toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: AppConstants.compactPadding),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

/// Simple data class for time-range presets.
class _TimePreset {
  final String label;
  final Duration duration;
  final int resolution;

  const _TimePreset(this.label, this.duration, this.resolution);
}

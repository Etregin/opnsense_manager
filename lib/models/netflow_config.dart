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

/// Represents the netflow capture configuration returned by
/// `GET /api/diagnostics/netflow/getconfig`.
class NetflowConfig {
  /// All available interface options: key → display label.
  final Map<String, String> interfaceOptions;

  /// Keys of currently selected capture interfaces.
  final List<String> selectedInterfaces;

  /// All interface options available for egress-only capture.
  final Map<String, String> egressOnlyOptions;

  /// Keys of interfaces where only egress (outbound) flows are captured.
  final List<String> selectedEgressOnly;

  /// Available NetFlow version options: key → display label (e.g. v5 / v9).
  final Map<String, String> versionOptions;

  /// Currently selected NetFlow version key (e.g. "v9").
  final String selectedVersion;

  /// Editable list of collector targets (e.g. "127.0.0.1:2056").
  ///
  /// Unlike interfaces, destinations are a free-form list the user can
  /// add to, edit, or remove entries from.
  final List<String> targets;

  /// Whether local data collection is enabled.
  final bool collectEnabled;

  /// Active flow timeout in seconds.
  final String activeTimeout;

  /// Inactive flow timeout in seconds.
  final String inactiveTimeout;

  const NetflowConfig({
    required this.interfaceOptions,
    required this.selectedInterfaces,
    required this.egressOnlyOptions,
    required this.selectedEgressOnly,
    required this.versionOptions,
    required this.selectedVersion,
    required this.targets,
    required this.collectEnabled,
    required this.activeTimeout,
    required this.inactiveTimeout,
  });

  /// Parses the full `{"netflow": {...}}` response envelope.
  factory NetflowConfig.fromJson(Map<String, dynamic> json) {
    final nf = json['netflow'] as Map<String, dynamic>;
    final cap = nf['capture'] as Map<String, dynamic>;
    final collect = nf['collect'] as Map<String, dynamic>;

    // Targets: extract all keys (selected or not) as the editable list,
    // filtering to only those that were selected.
    final selectedTargets = _extractSelected(cap['targets']);

    return NetflowConfig(
      interfaceOptions: _extractOptions(cap['interfaces']),
      selectedInterfaces: _extractSelected(cap['interfaces']),
      egressOnlyOptions: _extractOptions(cap['egress_only']),
      selectedEgressOnly: _extractSelected(cap['egress_only']),
      versionOptions: _extractOptions(cap['version']),
      selectedVersion:
          _extractSelected(cap['version']).firstOrNull ?? '',
      // Use selected targets as the initial editable list; if none selected,
      // fall back to all available keys so the user can see what exists.
      targets: selectedTargets.isNotEmpty
          ? selectedTargets
          : _extractOptions(cap['targets']).keys.toList(),
      collectEnabled: (collect['enable'] as String?) == '1',
      activeTimeout: (nf['activeTimeout'] as String?) ?? '',
      inactiveTimeout: (nf['inactiveTimeout'] as String?) ?? '',
    );
  }

  /// Builds the POST payload accepted by `setconfig`.
  Map<String, dynamic> toSetConfigPayload() {
    return {
      'netflow': {
        'capture': {
          'interfaces': selectedInterfaces.join(','),
          'egress_only': selectedEgressOnly.join(','),
          'version': selectedVersion,
          'targets': targets.join(','),
        },
        'collect': {
          'enable': collectEnabled ? '1' : '0',
        },
        'activeTimeout': activeTimeout,
        'inactiveTimeout': inactiveTimeout,
      },
    };
  }

  /// Returns a copy with the given fields replaced.
  NetflowConfig copyWith({
    List<String>? selectedInterfaces,
    List<String>? selectedEgressOnly,
    String? selectedVersion,
    List<String>? targets,
    bool? collectEnabled,
    String? activeTimeout,
    String? inactiveTimeout,
  }) {
    return NetflowConfig(
      interfaceOptions: interfaceOptions,
      selectedInterfaces: selectedInterfaces ?? this.selectedInterfaces,
      egressOnlyOptions: egressOnlyOptions,
      selectedEgressOnly: selectedEgressOnly ?? this.selectedEgressOnly,
      versionOptions: versionOptions,
      selectedVersion: selectedVersion ?? this.selectedVersion,
      targets: targets ?? this.targets,
      collectEnabled: collectEnabled ?? this.collectEnabled,
      activeTimeout: activeTimeout ?? this.activeTimeout,
      inactiveTimeout: inactiveTimeout ?? this.inactiveTimeout,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Map<String, String> _extractOptions(dynamic field) {
    if (field is! Map) return {};
    return {
      for (final e in (field as Map<String, dynamic>).entries)
        e.key: (e.value as Map<String, dynamic>)['value'] as String? ?? e.key,
    };
  }

  static List<String> _extractSelected(dynamic field) {
    if (field is! Map) return [];
    return [
      for (final e in (field as Map<String, dynamic>).entries)
        if ((e.value as Map<String, dynamic>)['selected'] == 1) e.key,
    ];
  }
}

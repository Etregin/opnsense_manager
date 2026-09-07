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

import 'package:flutter/foundation.dart';
import '../models/unbound_overview_status.dart';
import '../models/unbound_rolling.dart';
import '../models/unbound_settings.dart';
import '../models/unbound_totals.dart';
import '../services/base/api_exception.dart';
import '../services/demo_api_service.dart';

/// ViewModel managing state for the Unbound DNS Reporting screen.
class UnboundDnsViewModel extends ChangeNotifier {
  final DemoApiService _apiService;

  bool _isLoading = false;
  bool _isActionLoading = false;
  String? _errorMessage;

  // Overview status (enabled vs disabled)
  UnboundOverviewStatus? _overviewStatus;

  // Overview data
  UnboundTotals? _totals;
  List<UnboundRollingPoint> _rollingPoints = [];
  List<UnboundRollingClientPoint> _clientActivityPoints = [];

  // Duration & filter selections
  int _selectedRollingDurationHours = 24; // 24, 12, 1
  bool _isRollingLogarithmic = false;

  int _selectedClientDurationHours = 24; // 24, 12, 1
  bool _isClientLogarithmic = false;

  int _selectedDomainLimit = 10; // 10, 25, 50, 75, 100

  // Settings tab state
  UnboundSettings? _settings;
  bool _statsToggleValue = false;
  bool _hasUnsavedSettingsChanges = false;

  UnboundDnsViewModel(this._apiService);

  // ── Getters ─────────────────────────────────────────────────────────────────
  bool get isLoading => _isLoading;
  bool get isActionLoading => _isActionLoading;
  String? get errorMessage => _errorMessage;

  bool get isOverviewEnabled => _overviewStatus?.isEnabled ?? false;
  UnboundTotals? get totals => _totals;
  List<UnboundRollingPoint> get rollingPoints => _rollingPoints;
  List<UnboundRollingClientPoint> get clientActivityPoints => _clientActivityPoints;

  int get selectedRollingDurationHours => _selectedRollingDurationHours;
  bool get isRollingLogarithmic => _isRollingLogarithmic;

  int get selectedClientDurationHours => _selectedClientDurationHours;
  bool get isClientLogarithmic => _isClientLogarithmic;

  int get selectedDomainLimit => _selectedDomainLimit;

  UnboundSettings? get settings => _settings;
  bool get statsToggleValue => _statsToggleValue;
  bool get hasUnsavedSettingsChanges => _hasUnsavedSettingsChanges;

  // ── Initial / Refresh Load ──────────────────────────────────────────────────
  Future<void> loadInitial() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _overviewStatus = await _apiService.checkUnboundOverviewEnabled();
      _settings = await _apiService.getUnboundSettings();
      _statsToggleValue = _settings?.general?.stats ?? _overviewStatus?.isEnabled ?? false;
      _hasUnsavedSettingsChanges = false;

      if (_overviewStatus?.isEnabled == true) {
        await _loadOverviewData();
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    try {
      _overviewStatus = await _apiService.checkUnboundOverviewEnabled();
      _settings = await _apiService.getUnboundSettings();
      _statsToggleValue = _settings?.general?.stats ?? _overviewStatus?.isEnabled ?? false;

      if (_overviewStatus?.isEnabled == true) {
        await _loadOverviewData();
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  Future<void> _loadOverviewData() async {
    final totalsFuture = _apiService.getUnboundTotals(limit: _selectedDomainLimit);
    final rollingFuture = _apiService.getUnboundRolling(_selectedRollingDurationHours);
    final clientFuture = _apiService.getUnboundClientActivity(_selectedClientDurationHours);

    final results = await Future.wait([totalsFuture, rollingFuture, clientFuture]);
    _totals = results[0] as UnboundTotals;
    _rollingPoints = results[1] as List<UnboundRollingPoint>;
    _clientActivityPoints = results[2] as List<UnboundRollingClientPoint>;
  }

  // ── Control / Filter Methods ────────────────────────────────────────────────
  Future<void> setRollingDurationHours(int hours) async {
    if (_selectedRollingDurationHours == hours) return;
    _selectedRollingDurationHours = hours;
    notifyListeners();

    try {
      _rollingPoints = await _apiService.getUnboundRolling(hours);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  void toggleRollingLogarithmic(bool value) {
    _isRollingLogarithmic = value;
    notifyListeners();
  }

  Future<void> setClientDurationHours(int hours) async {
    if (_selectedClientDurationHours == hours) return;
    _selectedClientDurationHours = hours;
    notifyListeners();

    try {
      _clientActivityPoints = await _apiService.getUnboundClientActivity(hours);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  void toggleClientLogarithmic(bool value) {
    _isClientLogarithmic = value;
    notifyListeners();
  }

  Future<void> setDomainLimit(int limit) async {
    if (_selectedDomainLimit == limit) return;
    _selectedDomainLimit = limit;
    notifyListeners();

    try {
      _totals = await _apiService.getUnboundTotals(limit: limit);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  void setStatsToggle(bool value) {
    _statsToggleValue = value;
    final original = _settings?.general?.stats ?? false;
    _hasUnsavedSettingsChanges = (_statsToggleValue != original);
    notifyListeners();
  }

  // ── Action Mutations ────────────────────────────────────────────────────────
  Future<bool> applySettings() async {
    _isActionLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.setUnboundStatsEnabled(_statsToggleValue);
      await _apiService.reconfigureUnboundGeneral();

      // Refresh overview status
      _overviewStatus = await _apiService.checkUnboundOverviewEnabled();
      _settings = await _apiService.getUnboundSettings();
      _hasUnsavedSettingsChanges = false;

      if (_overviewStatus?.isEnabled == true) {
        await _loadOverviewData();
      }
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isActionLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resetDnsData() async {
    _isActionLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _apiService.resetUnboundDnsData();
      if (_overviewStatus?.isEnabled == true) {
        await _loadOverviewData();
      }
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isActionLoading = false;
      notifyListeners();
    }
  }
}

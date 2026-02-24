import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../session/company_session_manager.dart';

/// Manages company selection, allowed companies list, and switching logic.
///
/// Handles:
/// - Loading companies from server
/// - Persisting selection using SharedPreferences
/// - Syncing selected company with backend session
class CompanyProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _companies = [];
  int? _selectedCompanyId;
  List<int> _selectedAllowedCompanyIds = [];
  bool _loading = false;
  bool _switching = false;
  String? _error;

  List<Map<String, dynamic>> get companies => _companies;

  int? get selectedCompanyId => _selectedCompanyId;

  List<int> get selectedAllowedCompanyIds => _selectedAllowedCompanyIds;

  bool get isLoading => _loading;

  bool get isSwitching => _switching;

  String? get error => _error;

  /// Returns currently selected company object.
  Map<String, dynamic>? get selectedCompany {
    if (_selectedCompanyId == null) return null;
    try {
      return _companies.firstWhere((c) => c['id'] == _selectedCompanyId);
    } catch (e) {
      return null;
    }
  }

  /// Updates allowed companies list and syncs with session + local storage.
  Future<void> setAllowedCompanies(List<int> allowedIds) async {
    final availableIds = _companies.map((c) => c['id'] as int).toSet();

    // Keep only valid companies
    final filtered = allowedIds
        .where((id) => availableIds.contains(id))
        .toList();

    // Always ensure selected company is allowed
    if (_selectedCompanyId != null && !filtered.contains(_selectedCompanyId)) {
      filtered.add(_selectedCompanyId!);
    }
    _selectedAllowedCompanyIds = filtered;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'selected_allowed_company_ids',
      _selectedAllowedCompanyIds.map((e) => e.toString()).toList(),
    );

    if (_selectedCompanyId != null) {
      await CompanySessionManager.updateCompanySelection(
        companyId: _selectedCompanyId!,
        allowedCompanyIds: _selectedAllowedCompanyIds,
      );
    }
    notifyListeners();
  }

  /// Initializes companies, restores saved selections, and syncs with server.
  Future<void> initialize() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {

      // No session → reset state
      final session = await CompanySessionManager.getCurrentSession();
      if (session == null || session.userId == null) {
        _companies = [];
        _selectedCompanyId = null;
        _loading = false;
        notifyListeners();
        return;
      }

      // Fetch user company info
      final userRes = await CompanySessionManager.safeCallKwWithoutCompany({
        'model': 'res.users',
        'method': 'read',
        'args': [
          [session.userId],
          ['company_id', 'company_ids'],
        ],
        'kwargs': {},
      });

      List<int> companyIds = [];
      int? currentCompanyId;
      if (userRes is List && userRes.isNotEmpty) {
        final row = userRes.first as Map<String, dynamic>;
        if (row['company_ids'] is List) {
          final raw = row['company_ids'] as List;
          companyIds = raw.whereType<int>().toList();
        }
        if (row['company_id'] is List &&
            (row['company_id'] as List).isNotEmpty) {
          currentCompanyId = (row['company_id'] as List).first as int?;
        }
      }

      if (companyIds.isEmpty) {
        _companies = [];
        _selectedCompanyId = currentCompanyId;
        _loading = false;
        notifyListeners();
        return;
      }

      // Fetch company details
      final companiesRes = await CompanySessionManager.safeCallKwWithoutCompany(
        {
          'model': 'res.company',
          'method': 'search_read',
          'args': [
            [
              ['id', 'in', companyIds],
            ],
          ],
          'kwargs': {
            'fields': ['id', 'name'],
            'order': 'name asc',
          },
        },
      );

      final serverCompanies = (companiesRes is List)
          ? companiesRes.cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];

      if (serverCompanies.isNotEmpty) {
        _companies = serverCompanies;
      } else {
        _companies = [];
      }

      final prefs = await SharedPreferences.getInstance();

      // Restore local selections
      final restoredId = prefs.getInt('selected_company_id');
      final pendingId = prefs.getInt('pending_company_id');
      final restoredAllowed =
          prefs
              .getStringList('selected_allowed_company_ids')
              ?.map((e) => int.tryParse(e) ?? -1)
              .where((e) => e > 0)
              .toList() ??
          [];

      int? desiredId =
          pendingId ??
          restoredId ??
          currentCompanyId ??
          (companyIds.isNotEmpty ? companyIds.first : null);
      _selectedCompanyId = desiredId;

      List<int> defaultAllowed = companyIds;
      final restoredValid = restoredAllowed
          .where((id) => companyIds.contains(id))
          .toList();
      _selectedAllowedCompanyIds = restoredValid.isNotEmpty
          ? restoredValid
          : defaultAllowed;

      // Ensure selected company is always allowed
      if (_selectedCompanyId != null &&
          !_selectedAllowedCompanyIds.contains(_selectedCompanyId)) {
        _selectedAllowedCompanyIds = [
          ..._selectedAllowedCompanyIds,
          _selectedCompanyId!,
        ];
      }

      if (_selectedCompanyId == null ||
          !companyIds.contains(_selectedCompanyId)) {
        if (companyIds.isNotEmpty) {
          _selectedCompanyId = companyIds.first;
        }
      }

      if (_selectedCompanyId != null &&
          !_selectedAllowedCompanyIds.contains(_selectedCompanyId)) {
        _selectedAllowedCompanyIds = [
          ..._selectedAllowedCompanyIds,
          _selectedCompanyId!,
        ];
      }

      final prefs2 = await SharedPreferences.getInstance();

      // Persist final selection
      if (_selectedCompanyId != null) {
        await prefs2.setInt('selected_company_id', _selectedCompanyId!);
      }
      await prefs2.setStringList(
        'selected_allowed_company_ids',
        _selectedAllowedCompanyIds.map((e) => e.toString()).toList(),
      );

      // Sync selection to session
      if (_selectedCompanyId != null) {
        await CompanySessionManager.updateCompanySelection(
          companyId: _selectedCompanyId!,
          allowedCompanyIds: _selectedAllowedCompanyIds,
        );
      }

      // Apply pending switch if exists
      if (pendingId != null && companyIds.contains(pendingId)) {
        try {
          await _applyCompanyOnServer(session.userId!, pendingId);
          await CompanySessionManager.refreshSession();
          await CompanySessionManager.restoreSession(companyId: pendingId);
          await prefs.remove('pending_company_id');
        } catch (_) {}
      } else if (desiredId != null &&
          currentCompanyId != desiredId &&
          companyIds.contains(desiredId)) {
        try {
          await _applyCompanyOnServer(session.userId!, desiredId);
          await CompanySessionManager.refreshSession();
          await CompanySessionManager.restoreSession(companyId: desiredId);
        } catch (_) {}
      }
    } catch (e) {
      try {
        if (_companies.isEmpty) {
          _error = e.toString();
        }
      } catch (_) {
        _error = e.toString();
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Refresh companies list from server.
  Future<void> refreshCompaniesList() async {
    _loading = true;
    notifyListeners();

    try {
      final list = await CompanySessionManager.getAllowedCompaniesList();
      if (list.isNotEmpty) {
        _companies = list;
      } else {}
    } catch (_) {
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Switches active company and syncs with backend.
  Future<bool> switchCompany(int companyId) async {
    if (_selectedCompanyId == companyId) return true;

    bool applied = false;
    _switching = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final session = await CompanySessionManager.getCurrentSession();

    await prefs.setInt('selected_company_id', companyId);

    final allowed = {..._selectedAllowedCompanyIds, companyId}.toList();
    await prefs.setStringList(
      'selected_allowed_company_ids',
      allowed.map((e) => e.toString()).toList(),
    );

    _selectedAllowedCompanyIds = allowed;
    _selectedCompanyId = companyId;
    notifyListeners();

    if (session == null) {
      await prefs.setInt('pending_company_id', companyId);
      _switching = false;
      notifyListeners();
      return false;
    }

    try {
      await _applyCompanyOnServer(session.userId!, companyId);
      await CompanySessionManager.refreshSession();
      await CompanySessionManager.restoreSession(companyId: companyId);
      await prefs.remove('pending_company_id');
      applied = true;
    } catch (_) {
      await prefs.setInt('pending_company_id', companyId);
      applied = false;
    }

    _switching = false;
    notifyListeners();
    await refreshCompaniesList();
    return applied;
  }

  /// Applies selected company on backend user session.
  Future<void> _applyCompanyOnServer(int userId, int companyId) async {
    final allowed = _selectedAllowedCompanyIds.isNotEmpty
        ? _selectedAllowedCompanyIds
        : [companyId];

    await CompanySessionManager.callKwWithCompany({
      'model': 'res.users',
      'method': 'write',
      'args': [
        [userId],
        {'company_id': companyId},
      ],
      'kwargs': {
        'context': {'allowed_company_ids': allowed, 'company_id': companyId},
      },
    });
  }

  /// Toggles allowed company selection.
  Future<void> toggleAllowedCompany(int companyId) async {
    if (_selectedAllowedCompanyIds.contains(companyId)) {
      if (companyId == _selectedCompanyId) {
        return;
      }
      _selectedAllowedCompanyIds = _selectedAllowedCompanyIds
          .where((id) => id != companyId)
          .toList();
    } else {
      _selectedAllowedCompanyIds = [..._selectedAllowedCompanyIds, companyId];
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'selected_allowed_company_ids',
      _selectedAllowedCompanyIds.map((e) => e.toString()).toList(),
    );

    if (_selectedCompanyId != null) {
      await CompanySessionManager.updateCompanySelection(
        companyId: _selectedCompanyId!,
        allowedCompanyIds: _selectedAllowedCompanyIds,
      );
    }

    notifyListeners();
  }

  /// Allows all companies.
  Future<void> selectAllCompanies() async {
    final allIds = _companies.map((c) => c['id'] as int).toList();
    await setAllowedCompanies(allIds);
  }

  /// Keeps only selected company allowed.
  Future<void> deselectAllCompanies() async {
    if (_selectedCompanyId != null) {
      await setAllowedCompanies([_selectedCompanyId!]);
    }
  }

  /// Checks if company is allowed.
  bool isCompanyAllowed(int companyId) {
    return _selectedAllowedCompanyIds.contains(companyId);
  }
}

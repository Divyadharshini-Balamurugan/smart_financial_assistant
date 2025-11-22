// SuggestionService_full.dart
// Full rewrite — optimized, debug-friendly, production-oriented.
//
// DEBUG NOTE: screenshot path (for your reference / cross-check):
// /mnt/data/cfe05955-990c-4f93-a6de-f06d671cf04a.png

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SuggestionService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  SuggestionService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = firebaseAuth ?? FirebaseAuth.instance;

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) throw StateError('No authenticated user');
    return u.uid;
  }

  // concurrency guard & small memo
  bool _isGenerating = false;
  DateTime? _lastGeneratedAt;

  // Public API: fetch existing suggestions quickly; optionally force new generation.
  Future<List<String>> fetchOrGenerate({bool force = false}) async {
    final stored = await _getStoredSuggestions();
    // if stored and not forced, maybe trigger background regen if stale
    if (stored.isNotEmpty && !force) {
      final last = await _getLastSuggestionUpdateTs();
      final stale = last == null || DateTime.now().difference(last) > Duration(minutes: 10);

      if (stale) {
        // background regen that won't overwrite root unless it's a *true* match
        _generateSuggestionsSafe(background: true);
      }
      return stored;
    }

    // no stored suggestions or forced -> ensure generation happens now (blocking)
    return await _generateSuggestionsSafe();
  }

  // --- Firestore getters / helpers

  Future<List<String>> _getStoredSuggestions() async {
    try {
      final doc = await _db.collection('users').doc(_uid).get();
      final list = (doc.data()?['latest_suggestions'] as List<dynamic>?) ?? [];
      return list.map((e) => e.toString()).toList();
    } catch (e, st) {
      print('⚠️ getStoredSuggestions error: $e\n$st');
      return [];
    }
  }

  Future<DateTime?> _getLastSuggestionUpdateTs() async {
    try {
      final doc = await _db.collection('users').doc(_uid).get();
      final ms = doc.data()?['lastSuggestionUpdate'] as int?;
      if (ms == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (e, st) {
      print('⚠️ _getLastSuggestionUpdateTs error: $e\n$st');
      return null;
    }
  }

  bool _listsEqualIgnoreOrder(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final aa = List.of(a)..sort();
    final bb = List.of(b)..sort();
    for (var i = 0; i < aa.length; i++) {
      if (aa[i] != bb[i]) return false;
    }
    return true;
  }

  // -----------------------
  // Public: robust detection from survey subcollection
  // -----------------------
  /// Reads users/{uid}/surveyResponses/Q1 and returns a normalized role string.
  /// Returns "Other" when nothing reasonable found.
  Future<String> detectRoleFromSurvey() async {
    // helpful debug reference to the UI screenshot you provided
    print('DEBUG: survey screenshot (local path): /mnt/data/cfe05955-990c-4f93-a6de-f06d671cf04a.png');

    try {
      final q1Ref = _db.collection('users').doc(_uid).collection('surveyResponses').doc('Q1');
      final q1Snap = await q1Ref.get();
      print('DEBUG: fetched Q1 doc exist=${q1Snap.exists}');

      if (!q1Snap.exists) {
        // Some apps store answers as documents under auto-generated IDs — check for that pattern too
        print('DEBUG: Q1 doc not found; checking surveyResponses collection for items that look like Q1...');
        final collSnap = await _db.collection('users').doc(_uid).collection('surveyResponses').get();
        if (collSnap.docs.isEmpty) {
          print('DEBUG: surveyResponses subcollection empty.');
          return 'Other';
        }
        // try to find a doc whose id equals 'Q1' or has questionId == 'Q1'
        for (final d in collSnap.docs) {
          final id = d.id;
          final data = d.data();
          if (id == 'Q1' || (data['questionId']?.toString() == 'Q1')) {
            print('DEBUG: found Q1-like document id=$id');
            return _extractRoleFromQ1Map(data);
          }
        }
        // fallback: return Other
        print('DEBUG: no Q1 doc found by id or questionId');
        return 'Other';
      }

      final data = q1Snap.data() ?? {};
      return _extractRoleFromQ1Map(data);
    } catch (e, st) {
      print('❌ detectRoleFromSurvey exception: $e\n$st');
      return 'Other';
    }
  }

  String _normalizeRole(dynamic r) {
    try {
      final s = r?.toString() ?? '';
      return s.trim();
    } catch (_) {
      return '';
    }
  }

  String _extractRoleFromQ1Map(Map<String, dynamic> data) {
    try {
      print('DEBUG: Q1 doc data: $data');
      print('DEBUG: Q1 keys: ${data.keys.toList()}');

      final rawSelected = data['selectedValue'] ?? data['selected'] ?? data['answer'] ?? data['value'];
      print('DEBUG: raw selectedValue = $rawSelected (type=${rawSelected?.runtimeType})');

      String? role;
      if (rawSelected == null) {
        // some designs store picked option in 'selectedIndex' together with 'question' -> nothing to do
        final maybeText = data['question'] ?? data['text'] ?? data['title'];
        if (maybeText is String && maybeText.trim().isNotEmpty) {
          // but question text is not the role — return Other
          print('DEBUG: no selectedValue found in Q1; question/title present but not used as role');
        }
      } else if (rawSelected is String) {
        role = rawSelected.trim();
        print('DEBUG: selectedValue is String -> role="$role"');
      } else if (rawSelected is Map) {
        print('DEBUG: selectedValue is Map with keys: ${rawSelected.keys.toList()}');
        if (rawSelected['value'] is String && rawSelected['value'].toString().trim().isNotEmpty) {
          role = rawSelected['value'].toString().trim();
          print('DEBUG: using selectedValue.value -> "$role"');
        } else if (rawSelected['label'] is String && rawSelected['label'].toString().trim().isNotEmpty) {
          role = rawSelected['label'].toString().trim();
          print('DEBUG: using selectedValue.label -> "$role"');
        } else {
          // as last resort convert entire map to string
          final s = rawSelected.toString().trim();
          if (s.isNotEmpty) {
            role = s;
            print('DEBUG: fallback selectedValue.toString -> "$role"');
          }
        }
      } else {
        // other primitive — convert to string
        final s = rawSelected.toString().trim();
        if (s.isNotEmpty) {
          role = s;
          print('DEBUG: selectedValue non-string primitive -> "$role"');
        }
      }

      final normalized = _normalizeRole(role);
      print('DEBUG: normalized role="$normalized" (raw="$role")');
      return normalized.isNotEmpty ? normalized : 'Other';
    } catch (e, st) {
      print('❌ _extractRoleFromQ1Map exception: $e\n$st');
      return 'Other';
    }
  }

  // -----------------------
  // role_rules best-match fetcher
  // -----------------------
  Future<List<Map<String, dynamic>>> _fetchRoleRulesBestMatch(String role) async {
    try {
      final trimmed = role.trim();
      if (trimmed.isEmpty) return [];

      // 1) exact match (fast, indexed)
      final exactSnap = await _db
          .collection('role_rules')
          .where('role', isEqualTo: trimmed)
          .where('active', isEqualTo: true)
          .get();
      if (exactSnap.docs.isNotEmpty) {
        return exactSnap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
      }

      // 2) load all active and do client-side matching (case-insensitive & substrings & tags)
      final activeSnap = await _db.collection('role_rules').where('active', isEqualTo: true).get();
      final all = activeSnap.docs;

      final target = trimmed.toLowerCase();

      // case-insensitive equality
      final ciEqual = all.where((d) {
        final r = (d.data()['role'] ?? '').toString().toLowerCase().trim();
        return r == target;
      }).map((d) => {...d.data(), 'id': d.id}).toList();
      if (ciEqual.isNotEmpty) return ciEqual;

      // substring matches (rule.role contains role or role contains rule.role)
      final substring = all.where((d) {
        final r = (d.data()['role'] ?? '').toString().toLowerCase().trim();
        return r.contains(target) || target.contains(r);
      }).map((d) => {...d.data(), 'id': d.id}).toList();
      if (substring.isNotEmpty) return substring;

      // tag-based matching
      final tagMatch = all.where((d) {
        final tags = d.data()['tags'];
        if (tags is List) {
          return tags
              .map((t) => t.toString().toLowerCase().trim())
              .contains(target);
        }
        return false;
      }).map((d) => {...d.data(), 'id': d.id}).toList();
      if (tagMatch.isNotEmpty) return tagMatch;

      // final: empty -> no match
      return [];
    } catch (e, st) {
      print('⚠️ _fetchRoleRulesBestMatch error: $e\n$st');
      return [];
    }
  }

  // -----------------------
  // Core generation safe wrapper
  // -----------------------
  Future<List<String>> _generateSuggestionsSafe({bool background = false}) async {
    if (_isGenerating) {
      if (background) return _getStoredSuggestions();
      // if foreground, wait for any ongoing generation to finish
      while (_isGenerating) {
        await Future.delayed(Duration(milliseconds: 150));
      }
      return _getStoredSuggestions();
    }

    _isGenerating = true;
    final sw = Stopwatch()..start();
    try {
      final results = await _generateSuggestions().timeout(Duration(seconds: 12));
      sw.stop();
      print('✅ Suggestions generated in ${sw.elapsedMilliseconds}ms (background=$background)');
      return results;
    } on TimeoutException catch (e) {
      print('⚠️ Suggestion generation timed out: $e');
      return _getStoredSuggestions();
    } catch (e, st) {
      print('❌ Exception in generateSuggestions: $e\n$st');
      return _getStoredSuggestions();
    } finally {
      _isGenerating = false;
    }
  }

  // -----------------------
  // Core generator: reads role, finds rules, builds suggestions, writes history + root carefully
  // -----------------------
  Future<List<String>> _generateSuggestions() async {
    // 1) Resolve role from the survey subcollection (preferred)
    String role = 'Other';
    try {
      role = await detectRoleFromSurvey();
    } catch (e, st) {
      print('⚠️ role detection failed, defaulting to Other: $e\n$st');
      role = 'Other';
    }
    print('ℹ️ Resolved role="$role" for uid=$_uid');

    // 2) Fetch best-match rules
    final rules = await _fetchRoleRulesBestMatch(role);
    print('DEBUG fetchedRules.count=${rules.length} for role="$role"');

    if (rules.isEmpty) {
      print('⚠️ No role_rules found for role="$role" — will NOT update root latest_suggestions.');
      // write a short debug entry into subcollection for investigation (fire-once)
      try {
        await _db.collection('users').doc(_uid).collection('suggestions').add({
          'roleDetected': role,
          'roleMatched': null,
          'found': false,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });
      } catch (_) {}
      return _getStoredSuggestions();
    }

    // 3) Extract and score suggestion texts
    final scored = <Map<String, dynamic>>[];
    for (final r in rules) {
      try {
        final active = r['active'];
        if (active is bool && !active) continue;

        final priorityRaw = r['priority'] ?? r['suggestion']?['priority'] ?? 0;
        final priority = (priorityRaw is int) ? priorityRaw : int.tryParse(priorityRaw.toString()) ?? 0;

        String text = '';
        if (r.containsKey('text')) {
          text = r['text']?.toString() ?? '';
        } else if (r.containsKey('suggestion') && r['suggestion'] is Map) {
          text = (r['suggestion']['text'] ?? r['suggestion']['note'] ?? '').toString();
        } else if (r.containsKey('title')) {
          text = r['title']?.toString() ?? '';
        }

        if (text.trim().isEmpty) continue;

        scored.add({
          'id': r['id'] ?? '',
          'priority': priority,
          'text': text.trim(),
          'raw': r,
        });
      } catch (e, st) {
        print('⚠️ error extracting suggestion from rule ${r['id'] ?? '<unknown>'}: $e\n$st');
      }
    }

    if (scored.isEmpty) {
      print('⚠️ role_rules found but no usable suggestion text — returning stored suggestions');
      return _getStoredSuggestions();
    }

    // sort by priority desc, stable
    scored.sort((a, b) => (b['priority'] as int).compareTo(a['priority'] as int));
    final selected = scored.map((s) => s['text'].toString()).take(3).toList();

    // 4) Always write history document; update root latest_suggestions only if changed.
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final historyRef = _db.collection('users').doc(_uid).collection('suggestions').doc('generated_$ts');

      await historyRef.set({
        'roleDetected': role,
        'roleMatched': rules.isNotEmpty ? rules.first['role'] : null,
        'selected_suggestions': selected,
        'priority_snapshot': scored.map((s) => {
              'id': s['id'],
              'priority': s['priority'],
              'text': s['text'],
            }).toList(),
        'createdAt': ts,
      });

      final existing = await _getStoredSuggestions();
      final same = _listsEqualIgnoreOrder(existing, selected);

      if (!same) {
        // Update root atomically — we do not guard here beyond this equality check, but Firestore update should be fine.
        await _db.collection('users').doc(_uid).update({
          'latest_suggestions': selected,
          'lastSuggestionUpdate': DateTime.now().millisecondsSinceEpoch,
        });
        print('ℹ️ root latest_suggestions updated for uid=$_uid');
      } else {
        print('ℹ️ suggestions identical — skipping root write');
      }
    } catch (e, st) {
      print('❌ Error writing suggestions/history: $e\n$st');
    }

    _lastGeneratedAt = DateTime.now();
    return selected;
  }
}

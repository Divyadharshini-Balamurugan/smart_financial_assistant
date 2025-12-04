// lib/services/pdf_export_service.dart
// Updated: S.No column, removed Notes, fetch firstname from users/{uid}.profile.firstName,
// use 'INR' prefix to avoid missing- glyph boxes for currency symbol.

import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

class PdfExportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  PdfExportService();

  Future<String> createUserReportAndSave({
    required String uid,
    required DateTime from,
    required DateTime to,
    String? username,
    String filenamePrefix = 'report',
    bool fallbackToShare = true,
  }) async {
    final name = username ?? await _fetchUserName(uid);
    final items = await _fetchTransactionsForPeriod(uid: uid, from: from, to: to);

    double totalExpense = 0.0;
    double totalIncome = 0.0;
    for (final it in items) {
      final amt = (it['amount'] as num?)?.toDouble() ?? 0.0;
      final isExpense = (it['isExpense'] ?? true) as bool;
      if (isExpense) totalExpense += amt;
      else totalIncome += amt;
    }

    final bytes = await _buildPdfBytes(
      userName: name,
      from: from,
      to: to,
      items: items,
      totalExpense: totalExpense,
      totalIncome: totalIncome,
    );

    final fileName = '$filenamePrefix-${_formatDate(from)}_to_${_formatDate(to)}.pdf';

    try {
      if (Platform.isAndroid) {
        final saved = await _saveFileAndroid(bytes, fileName);
        if (saved != null) return saved;
      } else if (Platform.isIOS) {
        final saved = await _saveFileIOS(bytes, fileName);
        if (saved != null) return saved;
      } else {
        if (kIsWeb) {
          await Printing.sharePdf(bytes: bytes, filename: fileName);
          return 'shared';
        } else {
          final saved = await _saveFileGeneric(bytes, fileName);
          if (saved != null) return saved;
        }
      }
    } catch (e) {
      debugPrint('Saving attempt failed: $e');
    }

    if (fallbackToShare) {
      final xfile = XFile.fromData(bytes, name: fileName, mimeType: 'application/pdf');
      await Share.shareXFiles([xfile], text: 'Here is your report');
      return 'shared';
    }

    throw Exception('Unable to save or share PDF.');
  }

  // Build PDF with S.No and without Notes, and use 'INR' prefix for amounts.
  Future<Uint8List> _buildPdfBytes({
    required String userName,
    required DateTime from,
    required DateTime to,
    required List<Map<String, dynamic>> items,
    required double totalExpense,
    required double totalIncome,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18),
        build: (context) {
          return <pw.Widget>[
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  pw.Text('User: $userName'),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('From: ${_formatDate(from)}'),
                  pw.Text('To: ${_formatDate(to)}'),
                ]),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Divider(),
            pw.SizedBox(height: 10),

            // Totals summary
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Expense: ${_formatCurrency(totalExpense)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Total Income: ${_formatCurrency(totalIncome)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Net: ${_formatCurrency(totalIncome - totalExpense)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Transactions table (includes S.No, Date, Category, Amount, Type)
            if (items.isEmpty)
              pw.Text('No transactions in the selected range.')
            else
              _transactionsTable(items),

            pw.SizedBox(height: 18),
            pw.Text('Generated on ${_formatDate(DateTime.now())}.', style: pw.TextStyle(fontSize: 10)),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _transactionsTable(List<Map<String, dynamic>> items) {
    final headers = ['S.No', 'Date', 'Category', 'Amount', 'Type'];

    // Build data rows with serial number (1-based), removed Notes column.
    final data = <List<String>>[];
    for (var i = 0; i < items.length; i++) {
      final m = items[i];
      final dateStr = (m['date'] is DateTime) ? _formatDateTime(m['date'] as DateTime) : (m['dateString'] ?? m['localDateTime'] ?? '');
      final cat = (m['categoryName'] ?? m['category'] ?? 'Uncategorized').toString();
      final amt = (m['amount'] as num?)?.toDouble() ?? 0.0;
      final typ = (m['isExpense'] ?? true) ? 'Expense' : 'Income';
      data.add([
        (i + 1).toString(),
        dateStr,
        cat,
        _formatCurrency(amt), // uses 'INR' prefix
        typ,
      ]);
    }

    return pw.Table.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.centerLeft,
      columnWidths: {
        0: const pw.FlexColumnWidth(1), // S.No
        1: const pw.FlexColumnWidth(2), // Date
        2: const pw.FlexColumnWidth(3), // Category
        3: const pw.FlexColumnWidth(2), // Amount
        4: const pw.FlexColumnWidth(2), // Type
      },
    );
  }

  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _formatDateTime(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _formatCurrency(double v) {
    // Use text 'INR' prefix to avoid missing-glyph issues for the rupee sign in embedded fonts.
    return 'INR ${v.toStringAsFixed(2)}';
  }

  // -----------------------
  // Firestore helpers (updated to read profile.firstName)
  // -----------------------
  Future<String> _fetchUserName(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) {
        return _auth.currentUser?.displayName ?? 'User';
      }
      final data = doc.data() ?? {};

      // Try users/{uid}.profile.firstName first (as requested)
      final profile = data['profile'];
      String? firstName;
      if (profile is Map && profile['firstName'] != null && (profile['firstName'] as String).trim().isNotEmpty) {
        firstName = profile['firstName'].toString();
      }

      if (firstName != null && firstName.isNotEmpty) return firstName;

      // fallback to other fields
      return (data['displayName'] ??
              data['name'] ??
              data['fullName'] ??
              data['username'] ??
              _auth.currentUser?.displayName ??
              'User')
          .toString();
    } catch (e) {
      debugPrint('Failed fetching username: $e');
      return _auth.currentUser?.displayName ?? 'User';
    }
  }

  /// Robust fetch: try dateKey range first (YYYY-MM-DD), then localDateTime (ISO string),
  /// then Timestamp range using 'date'|'timestamp'|'createdAt'.
  Future<List<Map<String, dynamic>>> _fetchTransactionsForPeriod({
    required String uid,
    required DateTime from,
    required DateTime to,
  }) async {
    final userRef = _db.collection('users').doc(uid);
    final List<Map<String, dynamic>> results = [];

    // Normalise end-of-day for inclusive search
    final toInclusive = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);

    // 1) Try dateKey range (string 'yyyy-MM-dd'), fast & reliable if present
    try {
      final fromKey = _dateKey(from);
      final toKey = _dateKey(toInclusive);

      debugPrint('Trying dateKey range: $fromKey -> $toKey');

      final expQ = userRef.collection('expenses').where('dateKey', isGreaterThanOrEqualTo: fromKey).where('dateKey', isLessThanOrEqualTo: toKey);
      final expSnap = await expQ.get();
      for (final d in expSnap.docs) {
        results.add(_docToMap(d, isExpense: true));
      }

      final incQ = userRef.collection('incomes').where('dateKey', isGreaterThanOrEqualTo: fromKey).where('dateKey', isLessThanOrEqualTo: toKey);
      final incSnap = await incQ.get();
      for (final d in incSnap.docs) {
        results.add(_docToMap(d, isExpense: false));
      }

      if (results.isNotEmpty) {
        results.sort((a, b) {
          final da = a['date'] as DateTime?;
          final db = b['date'] as DateTime?;
          if (da == null || db == null) return 0;
          return da.compareTo(db);
        });
        debugPrint('Found ${results.length} transactions via dateKey.');
        return results;
      } else {
        debugPrint('No results from dateKey query; falling back.');
      }
    } catch (e) {
      debugPrint('dateKey query failed: $e');
    }

    // 2) Try localDateTime ISO string range
    try {
      final fromIso = _isoString(DateTime(from.year, from.month, from.day, 0, 0, 0));
      final toIso = _isoString(toInclusive);
      debugPrint('Trying localDateTime range: $fromIso -> $toIso');

      final expQ = userRef.collection('expenses').where('localDateTime', isGreaterThanOrEqualTo: fromIso).where('localDateTime', isLessThanOrEqualTo: toIso);
      final expSnap = await expQ.get();
      for (final d in expSnap.docs) {
        results.add(_docToMap(d, isExpense: true));
      }

      final incQ = userRef.collection('incomes').where('localDateTime', isGreaterThanOrEqualTo: fromIso).where('localDateTime', isLessThanOrEqualTo: toIso);
      final incSnap = await incQ.get();
      for (final d in incSnap.docs) {
        results.add(_docToMap(d, isExpense: false));
      }

      if (results.isNotEmpty) {
        results.sort((a, b) {
          final da = a['date'] as DateTime?;
          final db = b['date'] as DateTime?;
          if (da == null || db == null) return 0;
          return da.compareTo(db);
        });
        debugPrint('Found ${results.length} transactions via localDateTime.');
        return results;
      } else {
        debugPrint('No results from localDateTime query; falling back.');
      }
    } catch (e) {
      debugPrint('localDateTime query failed: $e');
    }

    // 3) Try Timestamp fields: 'date', 'timestamp', 'createdAt'
    try {
      final fromTs = Timestamp.fromDate(DateTime(from.year, from.month, from.day, 0, 0, 0));
      final toTs = Timestamp.fromDate(toInclusive);
      debugPrint('Trying Timestamp range with fields date/timestamp/createdAt');

      final List<String> timestampFieldCandidates = ['date', 'timestamp', 'createdAt'];

      for (final field in timestampFieldCandidates) {
        try {
          final expQ = userRef.collection('expenses').where(field, isGreaterThanOrEqualTo: fromTs).where(field, isLessThanOrEqualTo: toTs);
          final expSnap = await expQ.get();
          for (final d in expSnap.docs) {
            results.add(_docToMap(d, isExpense: true));
          }

          final incQ = userRef.collection('incomes').where(field, isGreaterThanOrEqualTo: fromTs).where(field, isLessThanOrEqualTo: toTs);
          final incSnap = await incQ.get();
          for (final d in incSnap.docs) {
            results.add(_docToMap(d, isExpense: false));
          }

          if (results.isNotEmpty) {
            results.sort((a, b) {
              final da = a['date'] as DateTime?;
              final db = b['date'] as DateTime?;
              if (da == null || db == null) return 0;
              return da.compareTo(db);
            });
            debugPrint('Found ${results.length} transactions via timestamp field: $field');
            return results;
          }
        } catch (e) {
          debugPrint('Timestamp query on field $field failed: $e');
          // try next field
        }
      }
    } catch (e) {
      debugPrint('Timestamp range queries failed overall: $e');
    }

    // nothing found => return empty list
    debugPrint('No transactions found for the period.');
    return [];
  }

  Map<String, dynamic> _docToMap(QueryDocumentSnapshot d, {required bool isExpense}) {
    final data = d.data() as Map<String, dynamic>? ?? {};
    DateTime? date;
    String? dateString;

    // 1) Prefer a Timestamp field (date, timestamp, createdAt)
    if (data['date'] is Timestamp) {
      date = (data['date'] as Timestamp).toDate();
    } else if (data['timestamp'] is Timestamp) {
      date = (data['timestamp'] as Timestamp).toDate();
    } else if (data['createdAt'] is Timestamp) {
      date = (data['createdAt'] as Timestamp).toDate();
    } else if (data['localDateTime'] is Timestamp) {
      date = (data['localDateTime'] as Timestamp).toDate();
    } else if (data['localDateTime'] is String) {
      try {
        date = DateTime.parse(data['localDateTime'] as String);
        dateString = data['localDateTime'] as String;
      } catch (_) {}
    } else if (data['dateKey'] is String) {
      // fallback: parse dateKey 'yyyy-MM-dd'
      try {
        date = DateTime.parse(data['dateKey'] as String);
        dateString = data['dateKey'] as String;
      } catch (_) {}
    } else if (data['createdAt'] is String) {
      // sometimes createdAt stored as iso string
      try {
        date = DateTime.parse(data['createdAt'] as String);
        dateString = data['createdAt'] as String;
      } catch (_) {}
    }

    return {
      'id': d.id,
      'amount': data['amount'],
      'currency': data['currency'] ?? 'INR',
      'categoryName': data['categoryName'] ?? data['category'] ?? 'Uncategorized',
      'subcategoryName': data['subcategoryName'] ?? '',
      // 'notes' omitted on purpose (you requested removal)
      'date': date,
      'dateString': dateString,
      'localDateTime': data['localDateTime'],
      'isExpense': isExpense,
      'raw': data,
    };
  }

  String _dateKey(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _isoString(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}T${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
  }

  // -----------------------
  // Saving helpers (same as previous)
  // -----------------------
  Future<String?> _saveFileAndroid(Uint8List bytes, String filename) async {
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      debugPrint('Storage permission denied.');
      return null;
    }

    final extDir = await getExternalStorageDirectory();
    if (extDir == null) return null;

    String basePath = extDir.path;
    try {
      final parts = basePath.split(Platform.pathSeparator);
      final androidIndex = parts.indexWhere((p) => p.toLowerCase() == 'android');
      if (androidIndex > 0) {
        basePath = parts.sublist(0, androidIndex).join(Platform.pathSeparator);
      }
    } catch (_) {}

    final downloadsDir = Directory(p.join(basePath, 'Download'));
    try {
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      final file = File(p.join(downloadsDir.path, filename));
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      debugPrint('Could not write to public Download dir: $e');
      try {
        final fallbackFile = File(p.join(extDir.path, filename));
        await fallbackFile.writeAsBytes(bytes);
        return fallbackFile.path;
      } catch (e) {
        debugPrint('Fallback write also failed: $e');
        return null;
      }
    }
  }

  Future<String?> _saveFileIOS(Uint8List bytes, String filename) async {
    final docDir = await getApplicationDocumentsDirectory();
    final file = File(p.join(docDir.path, filename));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<String?> _saveFileGeneric(Uint8List bytes, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, filename));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<void> openFile(String path) async {
    await OpenFilex.open(path);
  }
}

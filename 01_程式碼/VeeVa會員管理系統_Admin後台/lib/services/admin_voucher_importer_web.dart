// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:excel/excel.dart';

import 'admin_voucher_importer_base.dart';

AdminVoucherImporter createAdminVoucherImporter() {
  return _WebAdminVoucherImporter();
}

class _WebAdminVoucherImporter implements AdminVoucherImporter {
  @override
  Future<ImportedVoucherLinks?> pickVoucherLinks() async {
    final input = html.FileUploadInputElement()
      ..accept = '.xlsx,.csv,.txt,text/csv,text/plain'
      ..multiple = false;
    final completer = Completer<ImportedVoucherLinks?>();
    input.onChange.first.then((_) async {
      final file = input.files?.isNotEmpty == true ? input.files!.first : null;
      if (file == null) {
        completer.complete(null);
        return;
      }
      try {
        final bytes = await _readFileBytes(file);
        completer.complete(_parseVoucherFile(file.name, bytes));
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    input.click();
    return completer.future;
  }

  Future<Uint8List> _readFileBytes(html.File file) async {
    final reader = html.FileReader();
    final completer = Completer<Uint8List>();
    reader.onLoad.first.then((_) {
      final result = reader.result;
      if (result is ByteBuffer) {
        completer.complete(Uint8List.view(result));
        return;
      }
      if (result is Uint8List) {
        completer.complete(result);
        return;
      }
      completer.completeError(StateError('unsupported file result'));
    });
    reader.onError.first.then((_) {
      completer.completeError(StateError('file read failed'));
    });
    reader.readAsArrayBuffer(file);
    return completer.future;
  }

  ImportedVoucherLinks _parseVoucherFile(String fileName, Uint8List bytes) {
    final lowerName = fileName.toLowerCase();
    if (lowerName.endsWith('.xlsx')) {
      return _parseExcel(fileName, bytes);
    }
    return _parseText(fileName, bytes);
  }

  ImportedVoucherLinks _parseText(String fileName, Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    final lines = const LineSplitter().convert(text);
    final entries = <ImportedVoucherEntry>[];
    for (final line in lines) {
      entries.addAll(_voucherEntriesFromCells(
        line.split(RegExp(r'\t|,|，')),
        fallbackText: line,
      ));
    }
    return ImportedVoucherLinks(
      fileName: fileName,
      entries: dedupeVoucherEntries(entries),
      totalRows: lines.length,
    );
  }

  ImportedVoucherLinks _parseExcel(String fileName, Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final entries = <ImportedVoucherEntry>[];
    var totalRows = 0;
    for (final sheetName in excel.tables.keys) {
      final sheet = excel.tables[sheetName];
      if (sheet == null) continue;
      totalRows += sheet.rows.length;
      int? urlColumn;
      int? codeColumn;
      for (final row in sheet.rows) {
        final cells = <String>[];
        for (final cell in row) {
          final value = cell?.value;
          final text = _cellValueText(value);
          cells.add(text);
        }
        if (urlColumn == null) {
          final detectedUrlColumn = _headerColumnIndex(
            cells,
            const {'兌換連結', '連結', 'url', 'link'},
          );
          if (detectedUrlColumn != null) {
            urlColumn = detectedUrlColumn;
            codeColumn = _headerColumnIndex(
              cells,
              const {'驗證碼', 'code', 'verificationcode', 'password'},
            );
            continue;
          }
        }
        if (urlColumn != null && urlColumn < cells.length) {
          final links = extractVoucherLinksFromText(cells[urlColumn]);
          final code = codeColumn != null && codeColumn < cells.length
              ? cells[codeColumn].trim()
              : '';
          entries.addAll(links.map(
            (url) => ImportedVoucherEntry(
              url: url,
              verificationCode: code.isEmpty ? null : code,
            ),
          ));
          continue;
        }
        entries.addAll(_voucherEntriesFromCells(cells));
      }
    }
    return ImportedVoucherLinks(
      fileName: fileName,
      entries: dedupeVoucherEntries(entries),
      totalRows: totalRows,
    );
  }

  List<ImportedVoucherEntry> _voucherEntriesFromCells(
    List<String> cells, {
    String? fallbackText,
  }) {
    final links = <String>[];
    for (final cell in cells) {
      links.addAll(extractVoucherLinksFromText(cell));
    }
    if (links.isEmpty && fallbackText != null) {
      links.addAll(extractVoucherLinksFromText(fallbackText));
    }
    final uniqueLinks = dedupeVoucherLinks(links);
    if (uniqueLinks.isEmpty) return const [];
    if (uniqueLinks.length > 1) {
      return uniqueLinks.map((url) => ImportedVoucherEntry(url: url)).toList();
    }

    final url = uniqueLinks.single;
    final code = _verificationCodeFromCells(cells, url, fallbackText);
    return [ImportedVoucherEntry(url: url, verificationCode: code)];
  }

  String? _verificationCodeFromCells(
    List<String> cells,
    String url,
    String? fallbackText,
  ) {
    for (final rawCell in cells) {
      final cell = rawCell.trim().replaceAll(RegExp(r'''^['"]|['"]$'''), '');
      if (cell.isEmpty || cell.contains(url) || _isVoucherHeader(cell)) {
        continue;
      }
      return cell;
    }

    final source = fallbackText?.trim() ?? '';
    if (source.isEmpty || !source.contains(url)) return null;
    final remaining = source
        .replaceFirst(url, '')
        .replaceAll(RegExp(r'^[\s,，;；|]+|[\s,，;；|]+$'), '')
        .trim();
    if (remaining.isEmpty || _isVoucherHeader(remaining)) return null;
    return remaining;
  }

  bool _isVoucherHeader(String value) {
    final normalized = value.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    return normalized == '驗證碼' ||
        normalized == 'code' ||
        normalized == 'verificationcode' ||
        normalized == '兌換連結' ||
        normalized == '連結' ||
        normalized == 'url';
  }

  int? _headerColumnIndex(List<String> cells, Set<String> candidates) {
    for (var index = 0; index < cells.length; index += 1) {
      final normalized =
          cells[index].toLowerCase().replaceAll(RegExp(r'\s+'), '');
      if (candidates.contains(normalized)) return index;
    }
    return null;
  }

  String _cellValueText(CellValue? value) {
    return switch (value) {
      null => '',
      TextCellValue() => value.value.toString(),
      FormulaCellValue() => value.formula,
      IntCellValue() => value.value.toString(),
      DoubleCellValue() => value.value.toString(),
      BoolCellValue() => value.value.toString(),
      DateCellValue() => value.toString(),
      TimeCellValue() => value.toString(),
      DateTimeCellValue() => value.toString(),
    };
  }
}

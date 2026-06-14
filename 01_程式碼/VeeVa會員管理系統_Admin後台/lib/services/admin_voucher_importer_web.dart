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
    return ImportedVoucherLinks(
      fileName: fileName,
      links: extractVoucherLinksFromText(text),
      totalRows: lines.length,
    );
  }

  ImportedVoucherLinks _parseExcel(String fileName, Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final links = <String>[];
    var totalRows = 0;
    for (final sheetName in excel.tables.keys) {
      final sheet = excel.tables[sheetName];
      if (sheet == null) continue;
      totalRows += sheet.rows.length;
      for (final row in sheet.rows) {
        for (final cell in row) {
          final value = cell?.value;
          final text = _cellValueText(value);
          if (text.isEmpty) continue;
          links.addAll(extractVoucherLinksFromText(text));
        }
      }
    }
    return ImportedVoucherLinks(
      fileName: fileName,
      links: dedupeVoucherLinks(links),
      totalRows: totalRows,
    );
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

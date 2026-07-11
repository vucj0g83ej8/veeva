import 'dart:typed_data';

class ImportedVoucherEntry {
  const ImportedVoucherEntry({
    required this.url,
    this.verificationCode,
  });

  final String url;
  final String? verificationCode;
}

class ImportedVoucherLinks {
  const ImportedVoucherLinks({
    required this.fileName,
    required this.entries,
    required this.totalRows,
  });

  final String fileName;
  final List<ImportedVoucherEntry> entries;
  final int totalRows;

  int get count => entries.length;
  int get verificationCodeCount => entries
      .where((entry) => entry.verificationCode?.trim().isNotEmpty == true)
      .length;
  List<String> get links => entries.map((entry) => entry.url).toList();
  Map<String, String> get verificationCodesByLink => {
        for (final entry in entries)
          if (entry.verificationCode?.trim().isNotEmpty == true)
            entry.url: entry.verificationCode!.trim(),
      };
}

abstract class AdminVoucherImporter {
  Future<ImportedVoucherLinks?> pickVoucherLinks();
}

class PickedVoucherFile {
  const PickedVoucherFile({
    required this.name,
    required this.bytes,
  });

  final String name;
  final Uint8List bytes;
}

List<String> extractVoucherLinksFromText(String text) {
  final matches = RegExp(r"""https?:\/\/[^\s,"')<>]+""", caseSensitive: false)
      .allMatches(text);
  return _dedupeLinks(matches.map((match) => match.group(0) ?? ''));
}

List<String> dedupeVoucherLinks(Iterable<String> links) {
  return _dedupeLinks(links);
}

List<ImportedVoucherEntry> dedupeVoucherEntries(
  Iterable<ImportedVoucherEntry> entries,
) {
  final seen = <String>{};
  final results = <ImportedVoucherEntry>[];
  for (final entry in entries) {
    final cleanUrl = _cleanVoucherLink(entry.url);
    if (cleanUrl == null || !seen.add(cleanUrl)) continue;
    final cleanCode = entry.verificationCode?.trim();
    results.add(ImportedVoucherEntry(
      url: cleanUrl,
      verificationCode:
          cleanCode == null || cleanCode.isEmpty ? null : cleanCode,
    ));
  }
  return results;
}

List<String> _dedupeLinks(Iterable<String> links) {
  final seen = <String>{};
  final results = <String>[];
  for (final rawLink in links) {
    final link = _cleanVoucherLink(rawLink);
    if (link == null) continue;
    if (seen.add(link)) {
      results.add(link);
    }
  }
  return results;
}

String? _cleanVoucherLink(String rawLink) {
  final link = rawLink.trim().replaceAll(RegExp(r'[，。；;]+$'), '');
  if (!link.startsWith(RegExp(r'https?:\/\/', caseSensitive: false))) {
    return null;
  }
  return link;
}

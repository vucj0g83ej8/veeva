import 'dart:typed_data';

class ImportedVoucherLinks {
  const ImportedVoucherLinks({
    required this.fileName,
    required this.links,
    required this.totalRows,
  });

  final String fileName;
  final List<String> links;
  final int totalRows;

  int get count => links.length;
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

List<String> _dedupeLinks(Iterable<String> links) {
  final seen = <String>{};
  final results = <String>[];
  for (final rawLink in links) {
    final link = rawLink.trim().replaceAll(RegExp(r'[，。；;]+$'), '');
    if (!link.startsWith(RegExp(r'https?:\/\/', caseSensitive: false))) {
      continue;
    }
    if (seen.add(link)) {
      results.add(link);
    }
  }
  return results;
}

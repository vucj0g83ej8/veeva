// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:ui_web' as ui_web;
import 'dart:async';

import 'package:flutter/material.dart';

class ArticleRichEditorController {
  Object? _owner;
  VoidCallback? _bold;
  VoidCallback? _italic;
  VoidCallback? _bulletedList;
  VoidCallback? _numberedList;
  VoidCallback? _quote;
  ValueChanged<int>? _fontSize;
  VoidCallback? _link;
  VoidCallback? _image;
  VoidCallback? _divider;

  void bold() => _bold?.call();
  void italic() => _italic?.call();
  void bulletedList() => _bulletedList?.call();
  void numberedList() => _numberedList?.call();
  void quote() => _quote?.call();
  void fontSize(int size) => _fontSize?.call(size);
  void link() => _link?.call();
  void image() => _image?.call();
  void divider() => _divider?.call();

  void _attach({
    required Object owner,
    required VoidCallback bold,
    required VoidCallback italic,
    required VoidCallback bulletedList,
    required VoidCallback numberedList,
    required VoidCallback quote,
    required ValueChanged<int> fontSize,
    required VoidCallback link,
    required VoidCallback image,
    required VoidCallback divider,
  }) {
    _owner = owner;
    _bold = bold;
    _italic = italic;
    _bulletedList = bulletedList;
    _numberedList = numberedList;
    _quote = quote;
    _fontSize = fontSize;
    _link = link;
    _image = image;
    _divider = divider;
  }

  void _detach(Object owner) {
    if (_owner != owner) {
      return;
    }
    _owner = null;
    _bold = null;
    _italic = null;
    _bulletedList = null;
    _numberedList = null;
    _quote = null;
    _fontSize = null;
    _link = null;
    _image = null;
    _divider = null;
  }
}

class RichArticleEditor extends StatefulWidget {
  const RichArticleEditor({
    required this.controller,
    required this.richController,
    this.focusNode,
    this.onUploadImage,
    this.expands = false,
    this.minHeight = 360,
    super.key,
  });

  final TextEditingController controller;
  final ArticleRichEditorController richController;
  final FocusNode? focusNode;
  final Future<String?> Function()? onUploadImage;
  final bool expands;
  final double minHeight;

  @override
  State<RichArticleEditor> createState() => _RichArticleEditorState();
}

class _RichArticleEditorState extends State<RichArticleEditor> {
  static int _nextEditorId = 0;

  late final String _viewType;
  late final html.DivElement _editorElement;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  html.Range? _savedRange;
  String _lastSyncedMarkdown = '';
  bool _syncingFromController = false;
  bool _syncingFromDom = false;

  @override
  void initState() {
    super.initState();
    _ensureEditorStyles();
    _viewType = 'veeva-rich-article-editor-${_nextEditorId++}';
    _editorElement = _createEditorElement();
    _lastSyncedMarkdown = widget.controller.text;
    _setEditorHtml(_markdownToHtml(_lastSyncedMarkdown));
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _editorElement,
    );
    _subscriptions
      ..add(_editorElement.onInput.listen((_) {
        _normalizeActiveInlineMarkers();
        _saveSelection();
        _syncDomToController();
      }))
      ..add(_editorElement.onKeyUp.listen((_) => _saveSelection()))
      ..add(_editorElement.onMouseUp.listen((_) => _saveSelection()))
      ..add(_editorElement.onFocus.listen((_) => _saveSelection()))
      ..add(_editorElement.onBlur.listen((_) => _syncDomToController()))
      ..add(html.document.onSelectionChange.listen((_) => _saveSelection()));
    widget.controller.addListener(_syncControllerToDom);
    _attachToolbar();
  }

  @override
  void didUpdateWidget(RichArticleEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncControllerToDom);
      widget.controller.addListener(_syncControllerToDom);
      _lastSyncedMarkdown = widget.controller.text;
      _setEditorHtml(_markdownToHtml(_lastSyncedMarkdown));
    }
    if (oldWidget.richController != widget.richController ||
        oldWidget.controller != widget.controller) {
      oldWidget.richController._detach(this);
      _attachToolbar();
    }
  }

  @override
  void dispose() {
    widget.richController._detach(this);
    widget.controller.removeListener(_syncControllerToDom);
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editorFrame = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCBD5D1)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: HtmlElementView(viewType: _viewType),
      ),
    );

    final editorBody = widget.expands
        ? Expanded(child: editorFrame)
        : SizedBox(height: widget.minHeight, child: editorFrame);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '文章內容',
          style: TextStyle(
            color: Color(0xFF4C5F58),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        editorBody,
      ],
    );
  }

  html.DivElement _createEditorElement() {
    return html.DivElement()
      ..classes.add('veeva-rich-editor')
      ..contentEditable = 'true'
      ..setAttribute('role', 'textbox')
      ..setAttribute('aria-label', '文章內容')
      ..setAttribute('data-placeholder', '在這裡自由編輯文章內容')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.boxSizing = 'border-box'
      ..style.overflowY = 'auto';
  }

  void _attachToolbar() {
    widget.richController._attach(
      owner: this,
      bold: () => _toggleInlineTag('strong', const {'strong', 'b'}),
      italic: () => _toggleInlineTag('em', const {'em', 'i'}),
      bulletedList: () => _insertList(ordered: false),
      numberedList: () => _insertList(ordered: true),
      quote: _toggleQuote,
      fontSize: _applyFontSize,
      link: _insertLink,
      image: () => unawaited(_insertImage()),
      divider: () => _insertHtml('<hr><p><br></p>'),
    );
  }

  void _insertHtml(
    String htmlText, {
    bool selectInsertedContents = false,
    bool placeCaretInsideFirst = false,
    bool placeCaretAfter = true,
  }) {
    _restoreSelection();
    final range = _currentRangeOrEditorEnd();
    range.deleteContents();
    final fragment = html.DocumentFragment.html(
      htmlText,
      treeSanitizer: html.NodeTreeSanitizer.trusted,
    );
    final nodes = fragment.nodes.toList();
    if (nodes.isEmpty) {
      return;
    }
    range.insertNode(fragment);

    final selection = html.window.getSelection();
    if (selection != null) {
      final nextRange = html.document.createRange();
      if (selectInsertedContents) {
        nextRange.selectNodeContents(nodes.first);
      } else if (placeCaretInsideFirst) {
        nextRange.selectNodeContents(nodes.first);
        nextRange.collapse(false);
      } else if (placeCaretAfter) {
        nextRange.setStartAfter(nodes.last);
        nextRange.collapse(true);
      } else {
        nextRange.selectNode(nodes.first);
      }
      selection
        ..removeAllRanges()
        ..addRange(nextRange);
    }
    _saveSelection();
    _syncDomToController();
  }

  void _toggleInlineTag(String tagName, Set<String> toggledTags) {
    _restoreSelection();
    final range = _currentRangeOrEditorEnd();
    final existingInline =
        _closestElementAny(range.startContainer, toggledTags) ??
            _closestElementAny(range.endContainer, toggledTags);
    if (existingInline != null && _isNodeInsideEditor(existingInline)) {
      _unwrapInlineElement(existingInline);
      _syncDomToController();
      return;
    }

    if (range.collapsed) {
      _insertHtml(
        '<$tagName data-veeva-active-inline="1">\u200B</$tagName>',
        placeCaretInsideFirst: true,
      );
      return;
    }

    final wrapper = html.Element.tag(tagName);
    try {
      range.surroundContents(wrapper);
    } catch (_) {
      final contents = range.extractContents();
      wrapper.append(contents);
      range.insertNode(wrapper);
    }
    final selection = html.window.getSelection();
    if (selection != null) {
      final nextRange = html.document.createRange()
        ..selectNodeContents(wrapper);
      selection
        ..removeAllRanges()
        ..addRange(nextRange);
    }
    _saveSelection();
    _syncDomToController();
  }

  void _unwrapInlineElement(html.Element element) {
    final parent = element.parentNode;
    if (parent == null) {
      return;
    }
    final visibleText = (element.text ?? '').replaceAll('\u200B', '');
    if (visibleText.isEmpty && element.children.isEmpty) {
      final range = html.document.createRange()
        ..setStartBefore(element)
        ..collapse(true);
      element.remove();
      final selection = html.window.getSelection();
      if (selection != null) {
        selection
          ..removeAllRanges()
          ..addRange(range);
        _savedRange = range.cloneRange();
      }
      return;
    }

    final movedNodes = <html.Node>[];
    while (element.firstChild != null) {
      final child = element.firstChild!;
      movedNodes.add(child);
      parent.insertBefore(child, element);
    }
    element.remove();

    final selection = html.window.getSelection();
    if (selection != null && movedNodes.isNotEmpty) {
      final range = html.document.createRange()
        ..setStartBefore(movedNodes.first)
        ..setEndAfter(movedNodes.last);
      selection
        ..removeAllRanges()
        ..addRange(range);
      _savedRange = range.cloneRange();
    }
  }

  void _applyFontSize(int size) {
    _restoreSelection();
    final fontSize = _normalizedFontSize(size);
    final range = _currentRangeOrEditorEnd();
    if (range.collapsed) {
      _insertHtml(
        '<span data-veeva-font-size="$fontSize" '
        'data-veeva-active-inline="1" '
        'style="font-size:${fontSize}px">\u200B</span>',
        placeCaretInsideFirst: true,
      );
      return;
    }

    final contents = range.extractContents();
    _applyFontSizeToNode(contents, fontSize);
    final insertedNodes = contents.nodes.toList();
    if (insertedNodes.isEmpty) {
      return;
    }
    range.insertNode(contents);

    final selection = html.window.getSelection();
    if (selection != null) {
      final nextRange = html.document.createRange()
        ..setStartBefore(insertedNodes.first)
        ..setEndAfter(insertedNodes.last);
      selection
        ..removeAllRanges()
        ..addRange(nextRange);
    }
    _saveSelection();
    _syncDomToController();
  }

  void _applyFontSizeToNode(html.Node node, int fontSize) {
    if (node is html.Text) {
      final text = (node.text ?? '').replaceAll('\u200B', '');
      if (text.isEmpty) {
        return;
      }
      final parent = node.parentNode;
      if (parent == null) {
        return;
      }
      final span = _fontSizeSpan(fontSize);
      parent.insertBefore(span, node);
      span.append(node);
      return;
    }

    if (node is! html.Element && node is! html.DocumentFragment) {
      return;
    }

    if (node is html.Element &&
        node.tagName.toLowerCase() == 'span' &&
        (node.attributes.containsKey('data-veeva-font-size') ||
            node.style.fontSize.trim().isNotEmpty)) {
      node
        ..setAttribute('data-veeva-font-size', '$fontSize')
        ..attributes.remove('data-veeva-active-inline')
        ..style.fontSize = '${fontSize}px';
      return;
    }

    for (final child in node.nodes.toList()) {
      _applyFontSizeToNode(child, fontSize);
    }
  }

  html.SpanElement _fontSizeSpan(int fontSize) {
    return html.SpanElement()
      ..setAttribute('data-veeva-font-size', '$fontSize')
      ..style.fontSize = '${fontSize}px';
  }

  void _insertList({required bool ordered}) {
    final selected = _selectedTextOr('清單項目');
    final lines = selected
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final listItems = (lines.isEmpty ? ['清單項目'] : lines)
        .map((line) => '<li>${_escapeHtml(line)}</li>')
        .join();
    _insertHtml(
        '<${ordered ? 'ol' : 'ul'}>$listItems</${ordered ? 'ol' : 'ul'}>');
  }

  void _toggleQuote() {
    _restoreSelection();
    final range = _currentRangeOrEditorEnd();
    final existingQuote = _closestElement(range.startContainer, 'blockquote');
    if (existingQuote != null && _isNodeInsideEditor(existingQuote)) {
      _unwrapBlockquote(existingQuote);
      _syncDomToController();
      return;
    }

    final selected = _selectedTextOr('引用內容');
    _insertHtml(
      '<blockquote>${_escapeHtml(selected)}</blockquote><p><br></p>',
      selectInsertedContents: true,
    );
  }

  void _unwrapBlockquote(html.Element quote) {
    final parent = quote.parentNode;
    if (parent == null) {
      return;
    }
    final paragraph = html.ParagraphElement();
    while (quote.firstChild != null) {
      paragraph.append(quote.firstChild!);
    }
    parent.insertBefore(paragraph, quote);
    quote.remove();

    final selection = html.window.getSelection();
    if (selection != null) {
      final range = html.document.createRange()..selectNodeContents(paragraph);
      selection
        ..removeAllRanges()
        ..addRange(range);
      _savedRange = range.cloneRange();
    }
  }

  void _insertLink() {
    final input = js_util.callMethod<Object?>(
      html.window,
      'prompt',
      ['請輸入連結網址', 'https://'],
    );
    final url = input?.toString().trim();
    if (url == null || url.isEmpty) {
      return;
    }
    final safeUrl = _escapeAttribute(url);
    final label = _selectedTextOr('連結文字');
    _insertHtml(
      '<a href="$safeUrl" target="_blank" rel="noopener noreferrer">${_escapeHtml(label)}</a>',
      selectInsertedContents: true,
    );
    _normalizeEditorLinks();
  }

  Future<void> _insertImage() async {
    final uploadImage = widget.onUploadImage;
    final url = uploadImage == null
        ? js_util
            .callMethod<Object?>(
              html.window,
              'prompt',
              ['請輸入圖片網址', 'https://'],
            )
            ?.toString()
            .trim()
        : await uploadImage();
    if (url == null || url.isEmpty) {
      return;
    }
    final safeUrl = _escapeAttribute(url);
    _insertHtml(
      '<p><img src="$safeUrl" alt="圖片說明"></p>',
    );
  }

  void _syncControllerToDom() {
    if (_syncingFromDom) {
      return;
    }
    final markdown = widget.controller.text;
    if (markdown == _lastSyncedMarkdown) {
      return;
    }
    _syncingFromController = true;
    _lastSyncedMarkdown = markdown;
    _setEditorHtml(_markdownToHtml(markdown));
    _syncingFromController = false;
  }

  void _syncDomToController() {
    if (_syncingFromController) {
      return;
    }
    _normalizeActiveInlineMarkers();
    _syncingFromDom = true;
    final markdown = _domToMarkdown(_editorElement);
    _lastSyncedMarkdown = markdown;
    if (widget.controller.text != markdown) {
      widget.controller.value = TextEditingValue(
        text: markdown,
        selection: TextSelection.collapsed(offset: markdown.length),
      );
    }
    _syncingFromDom = false;
  }

  void _normalizeActiveInlineMarkers() {
    final markers = _editorElement
        .querySelectorAll('strong[data-veeva-active-inline],'
            'b[data-veeva-active-inline],'
            'em[data-veeva-active-inline],'
            'i[data-veeva-active-inline],'
            'span[data-veeva-active-inline]')
        .toList();
    for (final marker in markers) {
      final currentText = (marker.text ?? '').replaceAll('\u200B', '');
      if (currentText.trim().isNotEmpty) {
        marker
          ..text = currentText
          ..attributes.remove('data-veeva-active-inline');
        continue;
      }
      final next = marker.nextNode;
      if (next is! html.Text) {
        continue;
      }
      final typedText = (next.text ?? '').replaceAll('\u200B', '');
      if (typedText.trim().isEmpty) {
        continue;
      }
      marker
        ..text = typedText
        ..attributes.remove('data-veeva-active-inline');
      next.remove();
      final selection = html.window.getSelection();
      if (selection != null) {
        final range = html.document.createRange()
          ..setStartAfter(marker)
          ..collapse(true);
        selection
          ..removeAllRanges()
          ..addRange(range);
        _savedRange = range.cloneRange();
      }
    }
  }

  void _saveSelection() {
    final selection = html.window.getSelection();
    if (selection == null || (selection.rangeCount ?? 0) == 0) {
      return;
    }
    final range = selection.getRangeAt(0);
    if (!_isNodeInsideEditor(range.startContainer) ||
        !_isNodeInsideEditor(range.endContainer)) {
      return;
    }
    _savedRange = range.cloneRange();
  }

  html.Range _currentRangeOrEditorEnd() {
    final selection = html.window.getSelection();
    if (selection != null && (selection.rangeCount ?? 0) > 0) {
      final range = selection.getRangeAt(0);
      if (_isNodeInsideEditor(range.startContainer) &&
          _isNodeInsideEditor(range.endContainer)) {
        return range;
      }
    }

    final range = html.document.createRange();
    range.selectNodeContents(_editorElement);
    range.collapse(false);
    return range;
  }

  String _selectedTextOr(String fallback) {
    _restoreSelection();
    final selection = html.window.getSelection();
    final selected = selection == null ? null : _selectionText(selection);
    if (selection != null &&
        (selection.rangeCount ?? 0) > 0 &&
        selected != null &&
        selected.isNotEmpty) {
      final range = selection.getRangeAt(0);
      if (_isNodeInsideEditor(range.startContainer) &&
          _isNodeInsideEditor(range.endContainer)) {
        return selected;
      }
    }
    return fallback;
  }

  String _selectionText(Object selection) {
    try {
      final value = js_util.callMethod<Object?>(
        selection,
        'toString',
        const [],
      );
      return value?.toString().trim() ?? '';
    } catch (_) {
      return '';
    }
  }

  void _restoreSelection() {
    _editorElement.focus();
    if (_savedRange == null) {
      return;
    }
    final selection = html.window.getSelection();
    if (selection == null) {
      return;
    }
    selection.removeAllRanges();
    selection.addRange(_savedRange!);
  }

  bool _isNodeInsideEditor(html.Node? node) {
    var current = node;
    while (current != null) {
      if (current == _editorElement) {
        return true;
      }
      current = current.parentNode;
    }
    return false;
  }

  html.Element? _closestElement(html.Node? node, String tagName) {
    var current = node;
    final normalizedTag = tagName.toLowerCase();
    while (current != null && current != _editorElement) {
      if (current is html.Element &&
          current.tagName.toLowerCase() == normalizedTag) {
        return current;
      }
      current = current.parentNode;
    }
    return null;
  }

  html.Element? _closestElementAny(html.Node? node, Set<String> tagNames) {
    var current = node;
    final normalizedTags = tagNames.map((tag) => tag.toLowerCase()).toSet();
    while (current != null && current != _editorElement) {
      if (current is html.Element &&
          normalizedTags.contains(current.tagName.toLowerCase())) {
        return current;
      }
      current = current.parentNode;
    }
    return null;
  }

  void _setEditorHtml(String htmlText) {
    _editorElement.setInnerHtml(
      htmlText,
      treeSanitizer: html.NodeTreeSanitizer.trusted,
    );
    _normalizeEditorLinks();
  }

  void _normalizeEditorLinks() {
    for (final link in _editorElement.querySelectorAll('a')) {
      link
        ..setAttribute('target', '_blank')
        ..setAttribute('rel', 'noopener noreferrer');
    }
  }
}

void _ensureEditorStyles() {
  if (html.document.getElementById('veeva-rich-editor-style') != null) {
    return;
  }
  final style = html.StyleElement()
    ..id = 'veeva-rich-editor-style'
    ..text = '''
.veeva-rich-editor {
  background: #fff;
  box-sizing: border-box;
  color: #25352f;
  font-family: -apple-system, BlinkMacSystemFont, "PingFang TC", "Microsoft JhengHei", "Noto Sans TC", sans-serif;
  font-size: 16px;
  font-weight: 500;
  line-height: 1.65;
  min-height: 100%;
  outline: none;
  padding: 14px 16px;
}
.veeva-rich-editor:empty::before {
  color: #94a39d;
  content: attr(data-placeholder);
}
.veeva-rich-editor p {
  margin: 0 0 13px;
}
.veeva-rich-editor h1,
.veeva-rich-editor h2,
.veeva-rich-editor h3 {
  color: #20342e;
  font-weight: 900;
  line-height: 1.35;
  margin: 18px 0 10px;
}
.veeva-rich-editor h1 { font-size: 28px; }
.veeva-rich-editor h2 { font-size: 23px; }
.veeva-rich-editor h3 { font-size: 19px; }
.veeva-rich-editor strong,
.veeva-rich-editor b {
  color: #172720;
  font-weight: 900;
}
.veeva-rich-editor em,
.veeva-rich-editor i {
  font-style: italic;
}
.veeva-rich-editor span[data-veeva-font-size] {
  line-height: 1.45;
}
.veeva-rich-editor ul,
.veeva-rich-editor ol {
  margin: 0 0 14px;
  padding-left: 24px;
}
.veeva-rich-editor li {
  margin: 4px 0;
}
.veeva-rich-editor blockquote {
  background: #f2f8f5;
  border-left: 4px solid #216b57;
  border-radius: 8px;
  color: #3b5149;
  margin: 12px 0 16px;
  padding: 10px 14px;
}
.veeva-rich-editor a {
  color: #0b7b5a;
  font-weight: 800;
  text-decoration: underline;
}
.veeva-rich-editor img {
  border-radius: 8px;
  display: block;
  height: auto;
  margin: 14px 0;
  max-width: 100%;
}
.veeva-rich-editor hr {
  border: 0;
  border-top: 1px solid #dfe8e4;
  margin: 18px 0;
}
''';
  html.document.head?.append(style);
}

String _markdownToHtml(String markdown) {
  final normalized = markdown.replaceAll('\r\n', '\n').trim();
  if (normalized.isEmpty) {
    return '';
  }
  final lines = normalized.split('\n');
  final output = <String>[];
  var index = 0;

  while (index < lines.length) {
    final line = lines[index];
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      index += 1;
      continue;
    }

    final imageMatch =
        RegExp(r'^!\[([^\]]*)\]\(([^)]+)\)$').firstMatch(trimmed);
    if (imageMatch != null) {
      output.add(
        '<p><img src="${_escapeAttribute(imageMatch.group(2) ?? '')}" '
        'alt="${_escapeAttribute(imageMatch.group(1) ?? '')}"></p>',
      );
      index += 1;
      continue;
    }

    if (RegExp(r'^-{3,}$').hasMatch(trimmed)) {
      output.add('<hr>');
      index += 1;
      continue;
    }

    final headingMatch = RegExp(r'^(#{1,3})\s+(.+)$').firstMatch(trimmed);
    if (headingMatch != null) {
      final level = (headingMatch.group(1) ?? '').length.clamp(1, 3);
      output.add(
        '<h$level>${_inlineMarkdownToHtml(headingMatch.group(2) ?? '')}</h$level>',
      );
      index += 1;
      continue;
    }

    if (RegExp(r'^[-*•]\s+').hasMatch(trimmed)) {
      final items = <String>[];
      while (index < lines.length &&
          RegExp(r'^[-*•]\s+').hasMatch(lines[index].trim())) {
        final item = lines[index].trim().replaceFirst(RegExp(r'^[-*•]\s+'), '');
        items.add('<li>${_inlineMarkdownToHtml(item)}</li>');
        index += 1;
      }
      output.add('<ul>${items.join()}</ul>');
      continue;
    }

    if (RegExp(r'^\d+\.\s+').hasMatch(trimmed)) {
      final items = <String>[];
      while (index < lines.length &&
          RegExp(r'^\d+\.\s+').hasMatch(lines[index].trim())) {
        final item = lines[index].trim().replaceFirst(RegExp(r'^\d+\.\s+'), '');
        items.add('<li>${_inlineMarkdownToHtml(item)}</li>');
        index += 1;
      }
      output.add('<ol>${items.join()}</ol>');
      continue;
    }

    if (trimmed.startsWith('>')) {
      final quoteLines = <String>[];
      while (index < lines.length && lines[index].trim().startsWith('>')) {
        quoteLines.add(
          lines[index].trim().replaceFirst(RegExp(r'^>\s?'), ''),
        );
        index += 1;
      }
      output.add(
        '<blockquote>${quoteLines.map(_inlineMarkdownToHtml).join('<br>')}</blockquote>',
      );
      continue;
    }

    final paragraphLines = <String>[];
    while (index < lines.length) {
      final current = lines[index].trim();
      if (current.isEmpty || _isBlockMarkdownStart(current)) {
        break;
      }
      paragraphLines.add(lines[index]);
      index += 1;
    }
    output.add(
      '<p>${paragraphLines.map(_inlineMarkdownToHtml).join('<br>')}</p>',
    );
  }

  return output.join();
}

bool _isBlockMarkdownStart(String line) {
  return RegExp(r'^(#{1,3})\s+').hasMatch(line) ||
      RegExp(r'^[-*•]\s+').hasMatch(line) ||
      RegExp(r'^\d+\.\s+').hasMatch(line) ||
      RegExp(r'^-{3,}$').hasMatch(line) ||
      RegExp(r'^!\[([^\]]*)\]\(([^)]+)\)$').hasMatch(line) ||
      line.startsWith('>');
}

String _inlineMarkdownToHtml(String text) {
  var value = _escapeHtml(text);
  value = value.replaceAllMapped(
    RegExp(r'\{\{fs:(\d{1,2})\}\}([\s\S]+?)\{\{\/fs\}\}'),
    (match) {
      final size = _normalizedFontSize(int.tryParse(match.group(1) ?? '16'));
      return '<span data-veeva-font-size="$size" '
          'style="font-size:${size}px">${match.group(2) ?? ''}</span>';
    },
  );
  value = value.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\((https?:\/\/[^)]+)\)'),
    (match) {
      final label = match.group(1) ?? '';
      final url = match.group(2) ?? '';
      return '<a href="${_escapeAttribute(url)}" target="_blank" '
          'rel="noopener noreferrer">$label</a>';
    },
  );
  value = value.replaceAllMapped(
    RegExp(r'\*\*(.+?)\*\*'),
    (match) => '<strong>${match.group(1) ?? ''}</strong>',
  );
  value = value.replaceAllMapped(
    RegExp(r'_(.+?)_'),
    (match) => '<em>${match.group(1) ?? ''}</em>',
  );
  return value;
}

String _domToMarkdown(html.Element root) {
  final blocks = <String>[];
  for (final node in root.nodes) {
    final block = _nodeToMarkdown(node, blockContext: true).trimRight();
    if (block.trim().isNotEmpty) {
      blocks.add(block);
    }
  }
  return blocks.join('\n\n').trim();
}

String _nodeToMarkdown(html.Node node, {required bool blockContext}) {
  if (node.nodeType == html.Node.TEXT_NODE) {
    return (node.text ?? '').replaceAll('\u200B', '');
  }
  if (node is! html.Element) {
    return '';
  }

  final tagName = node.tagName.toLowerCase();
  switch (tagName) {
    case 'br':
      return '\n';
    case 'strong':
    case 'b':
      final strongText = _childrenToMarkdown(node).trim();
      return strongText.isEmpty ? '' : '**$strongText**';
    case 'em':
    case 'i':
      final italicText = _childrenToMarkdown(node).trim();
      return italicText.isEmpty ? '' : '_${italicText}_';
    case 'span':
      final fontSize = _fontSizeFromElement(node);
      final spanText = _childrenToMarkdown(node).trim();
      if (spanText.isEmpty) {
        return '';
      }
      if (fontSize == null) {
        return spanText;
      }
      return '{{fs:$fontSize}}$spanText{{/fs}}';
    case 'h1':
      return '# ${_childrenToMarkdown(node).trim()}';
    case 'h2':
      return '## ${_childrenToMarkdown(node).trim()}';
    case 'h3':
      return '### ${_childrenToMarkdown(node).trim()}';
    case 'p':
    case 'div':
      return _childrenToMarkdown(node).trim();
    case 'ul':
      return node.children
          .where((child) => child.tagName.toLowerCase() == 'li')
          .map((child) => '- ${_childrenToMarkdown(child).trim()}')
          .join('\n');
    case 'ol':
      var itemNumber = 0;
      return node.children
          .where((child) => child.tagName.toLowerCase() == 'li')
          .map((child) {
        itemNumber += 1;
        return '$itemNumber. ${_childrenToMarkdown(child).trim()}';
      }).join('\n');
    case 'li':
      return _childrenToMarkdown(node).trim();
    case 'blockquote':
      final quote = _childrenToMarkdown(node).trim();
      return quote
          .split('\n')
          .map((line) => line.trim().isEmpty ? '>' : '> $line')
          .join('\n');
    case 'a':
      final label = _childrenToMarkdown(node).trim();
      final url = node.attributes['href']?.trim();
      if (url == null || url.isEmpty) {
        return label;
      }
      return '[$label]($url)';
    case 'img':
      final src = node.attributes['src']?.trim();
      if (src == null || src.isEmpty) {
        return '';
      }
      final alt = node.attributes['alt']?.trim() ?? '圖片說明';
      return '![$alt]($src)';
    case 'hr':
      return '---';
    default:
      return _childrenToMarkdown(node).trim();
  }
}

String _childrenToMarkdown(html.Element element) {
  return element.nodes
      .map((node) => _nodeToMarkdown(node, blockContext: false))
      .join();
}

String _escapeHtml(String value) => const HtmlEscape().convert(value);

String _escapeAttribute(String value) {
  return const HtmlEscape()
      .convert(value)
      .replaceAll("'", '&#39;')
      .replaceAll('\n', ' ');
}

int _normalizedFontSize(int? size) {
  final value = size ?? 16;
  if (value < 12) {
    return 12;
  }
  if (value > 36) {
    return 36;
  }
  return value;
}

int? _fontSizeFromElement(html.Element element) {
  final dataSize = int.tryParse(
    element.attributes['data-veeva-font-size']?.trim() ?? '',
  );
  if (dataSize != null) {
    return _normalizedFontSize(dataSize);
  }
  final styleSize = element.style.fontSize.trim();
  final match = RegExp(r'^(\d{1,2})px$').firstMatch(styleSize);
  if (match == null) {
    return null;
  }
  return _normalizedFontSize(int.tryParse(match.group(1) ?? ''));
}

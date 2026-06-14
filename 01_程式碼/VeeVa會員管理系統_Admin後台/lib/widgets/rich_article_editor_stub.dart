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
  @override
  void initState() {
    super.initState();
    _attachToolbar();
  }

  @override
  void didUpdateWidget(RichArticleEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.richController != widget.richController ||
        oldWidget.controller != widget.controller) {
      oldWidget.richController._detach(this);
      _attachToolbar();
    }
  }

  @override
  void dispose() {
    widget.richController._detach(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      minLines: widget.expands ? null : 14,
      maxLines: widget.expands ? null : 24,
      expands: widget.expands,
      textAlignVertical:
          widget.expands ? TextAlignVertical.top : TextAlignVertical.center,
      decoration: const InputDecoration(
        labelText: '文章內容',
        hintText: '在這裡自由編輯文章內容',
        alignLabelWithHint: true,
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      style: const TextStyle(
        color: Color(0xFF25352F),
        fontSize: 16,
        height: 1.65,
      ),
    );

    if (widget.expands) {
      return field;
    }
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: widget.minHeight),
      child: field,
    );
  }

  void _attachToolbar() {
    widget.richController._attach(
      owner: this,
      bold: () => _wrapSelection('**', '**', '重點文字'),
      italic: () => _wrapSelection('_', '_', '斜體文字'),
      bulletedList: () => _insertBlock('- 清單項目\n'),
      numberedList: () => _insertBlock('1. 清單項目\n'),
      quote: () => _insertBlock('> 引用內容\n'),
      fontSize: (size) => _wrapSelection('{{fs:$size}}', '{{/fs}}', '調整大小文字'),
      link: () => _wrapSelection('[', '](https://example.com)', '連結文字'),
      image: () => _insertBlock('![圖片說明](https://image-url)\n'),
      divider: () => _insertBlock('---\n'),
    );
  }

  void _insertBlock(String block) {
    final controller = widget.controller;
    final text = controller.text;
    final (:start, :end) = _normalizedSelection(controller.selection, text);
    final needsLeadingBreak =
        start > 0 && !text.substring(0, start).endsWith('\n');
    final needsTrailingBreak =
        end < text.length && !text.substring(end).startsWith('\n');
    final replacement = [
      if (needsLeadingBreak) '\n',
      block,
      if (needsTrailingBreak) '\n',
    ].join();
    final updated = text.replaceRange(start, end, replacement);
    controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
    widget.focusNode?.requestFocus();
  }

  void _wrapSelection(String prefix, String suffix, String placeholder) {
    final controller = widget.controller;
    final text = controller.text;
    final (:start, :end) = _normalizedSelection(controller.selection, text);
    final selected = start == end ? placeholder : text.substring(start, end);
    final replacement = '$prefix$selected$suffix';
    controller.value = TextEditingValue(
      text: text.replaceRange(start, end, replacement),
      selection: TextSelection(
        baseOffset: start + prefix.length,
        extentOffset: start + prefix.length + selected.length,
      ),
    );
    widget.focusNode?.requestFocus();
  }

  ({int start, int end}) _normalizedSelection(
    TextSelection selection,
    String text,
  ) {
    var start = selection.start;
    var end = selection.end;
    if (!selection.isValid || start < 0 || end < 0) {
      start = text.length;
      end = text.length;
    }
    if (start > end) {
      final previousStart = start;
      start = end;
      end = previousStart;
    }
    start = start.clamp(0, text.length).toInt();
    end = end.clamp(0, text.length).toInt();
    return (start: start, end: end);
  }
}

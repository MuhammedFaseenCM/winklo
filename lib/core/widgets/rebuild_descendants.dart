import 'package:flutter/widgets.dart';

/// Rebuilds every widget below [context], keeping their state.
///
/// Copy comes from `AppStrings`, plain statics that no widget depends on, so
/// a new language reaches widgets only when they build again.
void rebuildDescendants(BuildContext context) {
  void mark(Element element) {
    element.markNeedsBuild();
    element.visitChildren(mark);
  }

  (context as Element).visitChildren(mark);
}

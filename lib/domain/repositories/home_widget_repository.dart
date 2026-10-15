import '../habit/home_widget_snapshot.dart';

/// The Android home-screen widget.
abstract class HomeWidgetRepository {
  /// Stores [snapshot] for the widget and redraws it. Never throws.
  Future<void> update(HomeWidgetSnapshot snapshot);
}

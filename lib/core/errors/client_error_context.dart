/// Holds the current logical screen/route for client error telemetry.
class ClientErrorContext {
  ClientErrorContext._();

  static String? currentScreen;

  static void updateFromRouteName(String? name) {
    if (name == null || name.isEmpty) return;
    currentScreen = name;
  }
}

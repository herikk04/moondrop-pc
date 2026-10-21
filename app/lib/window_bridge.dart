import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Ponte com o código nativo do Windows (ícone na bandeja e janela compacta).
/// Canal "moondrop/window": Dart pede o modo; o nativo avisa quando ele muda
/// (por exemplo, clique no ícone da bandeja).
class WindowBridge {
  static const _ch = MethodChannel('moondrop/window');

  /// true quando a janela é o painel compacto da bandeja.
  static final ValueNotifier<bool> compact = ValueNotifier(false);

  static var _started = false;

  static void init() {
    if (_started) return;
    _started = true;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'mode') {
        compact.value = call.arguments == 'compact';
      }
      return null;
    });
  }

  static Future<void> setCompact(bool v) => _invoke('setCompact', v);
  static Future<void> setCloseToTray(bool v) => _invoke('setCloseToTray', v);
  static Future<void> quit() => _invoke('quit');

  static Future<void> _invoke(String method, [Object? arg]) async {
    try {
      await _ch.invokeMethod<void>(method, arg);
    } on MissingPluginException {
      // fora do Windows ou sem o runner nativo (ex.: testes): ignora
    } on PlatformException {
      // idem
    }
  }
}

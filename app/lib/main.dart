import 'dart:io';

import 'package:flutter/material.dart';

import 'device.dart';
import 'pages/compact_panel.dart';
import 'pages/device_page.dart';
import 'pages/eq_page.dart';
import 'pages/settings_page.dart';
import 'ui/icons.dart';
import 'ui/theme.dart';
import 'window_bridge.dart';

void main() => runApp(const MoondropApp());

class MoondropApp extends StatelessWidget {
  const MoondropApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MOONDROP PC',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: Mc.theme(),
      home: const Shell(),
    );
  }
}

/// Janela com largura >= [kWide]: barra lateral + conteúdo em colunas (layout de PC).
/// Abaixo disso: uma coluna com barra em pílula (layout de celular).
const double kWide = 980;

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  final dev = MoondropDevice();
  var tab = int.tryParse(Platform.environment['MOONDROP_TAB'] ?? '') ?? 0;

  @override
  void initState() {
    super.initState();
    WindowBridge.init();
    if (Platform.environment['MOONDROP_COMPACT'] == '1') {
      WindowBridge.compact.value = true; // só para ver o painel compacto sem o nativo
    }
    if (Platform.environment['MOONDROP_DEMO'] == '1') {
      dev.loadDemo(); // só para ver a interface sem fone
    } else {
      dev.loadConfig().then((_) {
        dev.startAuto();
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    dev.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: WindowBridge.compact,
      builder: (context, compact, _) {
        if (compact) return CompactPanel(dev: dev); // painel da bandeja
        return Scaffold(
          body: SafeArea(
            child: LayoutBuilder(builder: (context, c) {
              return c.maxWidth >= kWide ? _desktop() : _mobile();
            }),
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------------- PC
  Widget _desktop() {
    final pages = [
      DevicePage(dev: dev, onOpenEq: () => setState(() => tab = 1)),
      EqDesktopView(dev: dev),
      SettingsPage(dev: dev),
    ];
    return Row(children: [
      _Sidebar(dev: dev, index: tab, onChanged: (i) => setState(() => tab = i)),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 12, 32, 12),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1240),
              child: IndexedStack(index: tab, children: pages),
            ),
          ),
        ),
      ),
    ]);
  }

  // -------------------------------------------------------------- celular
  Widget _mobile() {
    final pages = [
      DevicePage(dev: dev),
      SettingsPage(dev: dev),
    ];
    final i = tab > 1 ? 0 : tab; // a aba EQ só existe no layout de PC
    return Stack(children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: IndexedStack(index: i, children: pages),
        ),
      ),
      Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _NavPill(index: i, onChanged: (v) => setState(() => tab = v == 1 ? 2 : 0)),
        ),
      ),
    ]);
  }
}

// ------------------------------------------------------------ barra lateral
class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.dev, required this.index, required this.onChanged});

  final MoondropDevice dev;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.headphones_rounded, 'Dispositivo'),
      (Icons.equalizer_rounded, 'Equalizador'),
      (Icons.settings_rounded, 'Configurações'),
    ];
    return Container(
      width: 236,
      color: const Color(0xFF1B1B1B),
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 26),
          child: Row(children: [
            Image.asset('assets/app_icon.png', width: 34, height: 34),
            const SizedBox(width: 12),
            const Text('MOONDROP',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 2)),
          ]),
        ),
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              onTap: () => onChanged(i),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: i == index ? Mc.chip : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  Icon(items[i].$1, size: 24, color: i == index ? Colors.white : Colors.white70),
                  const SizedBox(width: 14),
                  Text(items[i].$2,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: i == index ? Colors.white : Colors.white70)),
                ]),
              ),
            ),
          ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => WindowBridge.setCompact(true),
            borderRadius: BorderRadius.circular(14),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(children: [
                GlyphIcon(Glyph.compress, size: 22, color: Colors.white70),
                SizedBox(width: 14),
                Text('Modo compacto',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white70)),
              ]),
            ),
          ),
        ),
        ListenableBuilder(
          listenable: dev,
          builder: (context, _) {
            final ok = dev.connected;
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF262626),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ok
                        ? const Color(0xFF3DDC97)
                        : (dev.connecting ? Colors.amber : Colors.white30),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ok ? 'Conectado' : (dev.connecting ? 'Conectando…' : 'Desconectado'),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ]),
            );
          },
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------- pílula (celular)
class _NavPill extends StatelessWidget {
  const _NavPill({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.headphones_rounded, 'Dispositivo'),
      (Icons.settings_rounded, 'Configurações'),
    ];
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xE61A1A1A),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Mc.line),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < items.length; i++)
          GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 130,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: i == index ? const Color(0xFF444444) : Colors.transparent,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(items[i].$1, size: 26, color: i == index ? Colors.white : Colors.white70),
                const SizedBox(height: 3),
                Text(items[i].$2,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: i == index ? Colors.white : Colors.white70)),
              ]),
            ),
          ),
      ]),
    );
  }
}

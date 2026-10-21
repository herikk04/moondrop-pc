import 'package:flutter/material.dart';

import 'device.dart';
import 'pages/device_page.dart';
import 'pages/settings_page.dart';
import 'ui/theme.dart';

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

/// Estrutura do app: conteúdo + barra de navegação em pílula, como no app oficial.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  final dev = MoondropDevice();
  var tab = 0;

  @override
  void initState() {
    super.initState();
    dev.loadConfig().then((_) {
      dev.startAuto();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    dev.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DevicePage(dev: dev),
      SettingsPage(dev: dev),
    ];
    return Scaffold(
      body: SafeArea(
        child: Stack(children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: IndexedStack(index: tab, children: pages),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _NavPill(index: tab, onChanged: (i) => setState(() => tab = i)),
            ),
          ),
        ]),
      ),
    );
  }
}

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

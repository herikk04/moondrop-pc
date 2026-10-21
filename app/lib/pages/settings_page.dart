import 'package:flutter/material.dart';

import '../device.dart';
import '../ui/theme.dart';

/// Configurações do app (não do fone).
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.dev});

  final MoondropDevice dev;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: dev,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          const McHeader('Configurações'),
          const SizedBox(height: 8),
          McCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: const Text('Conectar automaticamente'),
              subtitle: const Text('Ao abrir o app e quando o fone ligar de novo',
                  style: TextStyle(color: Mc.sub)),
              value: dev.autoConnect,
              onChanged: dev.setAutoConnect,
            ),
          ),
          const SizedBox(height: 14),
          const McCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Sobre', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              SizedBox(height: 10),
              Text(
                'MOONDROP PC — projeto pessoal, não oficial.\n'
                'Fala GAIA v3 por Bluetooth Clássico (SPP) com o Space Travel 2.',
                style: TextStyle(color: Mc.sub, height: 1.4),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

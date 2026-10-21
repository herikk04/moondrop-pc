import 'package:flutter/material.dart';

import '../device.dart';
import '../ui/theme.dart';
import '../window_bridge.dart';

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
            child: Column(children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: const Text('Conectar automaticamente'),
                subtitle: const Text('Ao abrir o app e quando o fone ligar de novo',
                    style: TextStyle(color: Mc.sub)),
                value: dev.autoConnect,
                onChanged: dev.setAutoConnect,
              ),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: const Text('Fechar vai para a bandeja'),
                subtitle: const Text(
                    'O app continua ao lado do relógio; clique no ícone para o painel compacto',
                    style: TextStyle(color: Mc.sub)),
                value: dev.closeToTray,
                onChanged: dev.setCloseToTray,
              ),
            ]),
          ),
          const SizedBox(height: 14),
          McCard(
            child: Row(children: [
              const Expanded(
                child: Text('Painel compacto da bandeja',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              PillButton('Abrir', onTap: () => WindowBridge.setCompact(true)),
            ]),
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

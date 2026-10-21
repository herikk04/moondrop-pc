import 'package:flutter/material.dart';

import '../device.dart';
import '../eq_curve.dart';
import '../gaia.dart';
import '../ui/theme.dart';
import 'eq_advanced_page.dart';

/// Tela de EQ: um cartão por preset com botão "Usar"; o preset ativo mostra a curva
/// e, no Personalizado, abre o editor avançado.
class EqPage extends StatelessWidget {
  const EqPage({super.key, required this.dev});

  final MoondropDevice dev;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListenableBuilder(
              listenable: dev,
              builder: (context, _) => ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  McHeader('Equalizador', onBack: () => Navigator.of(context).pop()),
                  const SizedBox(height: 8),
                  if (dev.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: McCard(
                        color: const Color(0xFF3A2424),
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          const Icon(Icons.error_outline, color: Mc.danger),
                          const SizedBox(width: 10),
                          Expanded(child: Text(dev.error!)),
                        ]),
                      ),
                    ),
                  if (dev.eqPresets.isEmpty)
                    const McCard(child: Text('Sem presets (fone desconectado?)')),
                  for (final id in dev.eqPresets) ...[
                    _presetCard(context, id),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _presetCard(BuildContext context, int id) {
    final active = dev.eqActive == id;
    return McCard(
      padding: const EdgeInsets.fromLTRB(22, 18, 18, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(eqPresetName(id),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          PillButton(active ? 'Em uso' : 'Usar',
              filled: active, onTap: active ? null : () => dev.setEqPreset(id)),
        ]),
        if (active && dev.eqBands.isNotEmpty) ...[
          const SizedBox(height: 14),
          EqCurve(bands: dev.eqBands, preGainDb: dev.eqPreGain, showLegend: false, height: 190),
          if (id == kCustomPreset)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Align(
                alignment: Alignment.centerRight,
                child: PillButton('Editar (modo avançado)',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => EqAdvancedPage(dev: dev)))),
              ),
            )
          else
            ..._bandTable(),
        ],
      ]),
    );
  }

  List<Widget> _bandTable() {
    return [
      const SizedBox(height: 10),
      for (final b in dev.eqBands)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            SizedBox(width: 90, child: Text(_hz(b.freqHz))),
            Expanded(
                child: Text('Q ${b.q.toStringAsFixed(2)}',
                    style: const TextStyle(color: Mc.sub))),
            Text('${b.gainDb.toStringAsFixed(1)} dB'),
          ]),
        ),
    ];
  }

  static String _hz(int f) => f >= 1000
      ? '${(f / 1000).toStringAsFixed(f % 1000 == 0 ? 0 : 1)} kHz'
      : '$f Hz';
}

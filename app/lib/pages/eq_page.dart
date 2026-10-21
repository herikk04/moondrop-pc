import 'package:flutter/material.dart';

import '../device.dart';
import '../eq_curve.dart';
import '../gaia.dart';
import '../ui/theme.dart';
import 'eq_advanced_page.dart';

/// Equalizador no layout de celular: lista de presets; o ativo mostra a curva e, no
/// Personalizado, abre o editor avançado em outra tela.
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
                  ErrorBanner(dev),
                  EqPresetList(dev: dev),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.dev, {super.key});

  final MoondropDevice dev;

  @override
  Widget build(BuildContext context) {
    if (dev.error == null) return const SizedBox.shrink();
    return Padding(
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
    );
  }
}

/// Um cartão por preset com botão "Usar". Em [compact] (layout de PC) o cartão mostra só
/// o nome; a curva e o editor ficam no painel da direita.
class EqPresetList extends StatelessWidget {
  const EqPresetList({super.key, required this.dev, this.compact = false});

  final MoondropDevice dev;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (dev.eqPresets.isEmpty) {
      return const McCard(child: Text('Sem presets (fone desconectado?)'));
    }
    return Column(children: [
      for (final id in dev.eqPresets) ...[
        _presetCard(context, id),
        const SizedBox(height: 14),
      ],
    ]);
  }

  Widget _presetCard(BuildContext context, int id) {
    final active = dev.eqActive == id;
    final head = Row(children: [
      Expanded(
        child: Text(eqPresetName(id),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      PillButton(active ? 'Em uso' : 'Usar',
          filled: active, onTap: active ? null : () => dev.setEqPreset(id)),
    ]);
    if (compact) {
      return McCard(
        padding: const EdgeInsets.fromLTRB(22, 16, 16, 16),
        onTap: active ? null : () => dev.setEqPreset(id),
        child: head,
      );
    }
    return McCard(
      padding: const EdgeInsets.fromLTRB(22, 18, 18, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        head,
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
            BandTable(dev.eqBands),
        ],
      ]),
    );
  }
}

class BandTable extends StatelessWidget {
  const BandTable(this.bands, {super.key});

  final List<EqBand> bands;

  static String hz(int f) => f >= 1000
      ? '${(f / 1000).toStringAsFixed(f % 1000 == 0 ? 0 : 1)} kHz'
      : '$f Hz';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(children: [
        for (final b in bands)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              SizedBox(width: 90, child: Text(hz(b.freqHz))),
              Expanded(
                  child: Text('Q ${b.q.toStringAsFixed(2)}',
                      style: const TextStyle(color: Mc.sub))),
              Text('${b.gainDb.toStringAsFixed(1)} dB'),
            ]),
          ),
      ]),
    );
  }
}

/// Equalizador no layout de PC: presets à esquerda, gráfico e editor grandes à direita.
class EqDesktopView extends StatelessWidget {
  const EqDesktopView({super.key, required this.dev});

  final MoondropDevice dev;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: dev,
      builder: (context, _) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const McHeader('Equalizador'),
          ErrorBanner(dev),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 280,
                child: ListView(children: [EqPresetList(dev: dev, compact: true)]),
              ),
              const SizedBox(width: 24),
              Expanded(child: _right()),
            ]),
          ),
        ]);
      },
    );
  }

  Widget _right() {
    if (dev.eqActive == null || dev.eqBands.isEmpty) {
      return const McCard(child: Text('Conecte o fone para ver e editar o equalizador.'));
    }
    final custom = dev.eqActive == kCustomPreset;
    return McCard(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          custom ? 'Personalizado — editor avançado' : eqPresetName(dev.eqActive!),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: custom
              ? EqAdvancedPanel(dev: dev, wide: true, padding: EdgeInsets.zero)
              : ListView(children: [
                  EqCurve(
                      bands: dev.eqBands,
                      preGainDb: dev.eqPreGain,
                      showLegend: false,
                      height: 320),
                  BandTable(dev.eqBands),
                ]),
        ),
      ]),
    );
  }
}

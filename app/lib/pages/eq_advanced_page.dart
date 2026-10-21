import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../device.dart';
import '../eq_curve.dart';
import '../gaia.dart';
import '../ui/theme.dart';

/// Tela cheia do editor avançado (layout de celular / janela estreita).
class EqAdvancedPage extends StatelessWidget {
  const EqAdvancedPage({super.key, required this.dev});

  final MoondropDevice dev;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(children: [
              McHeader('Equalizador avançado', onBack: () => Navigator.of(context).pop()),
              Expanded(child: EqAdvancedPanel(dev: dev)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Editor avançado do preset Personalizado (como o "Advanced Mode" do app oficial):
/// gráfico, um slider vertical por banda e ajuste de ganho, frequência e Q da banda
/// selecionada. As edições ficam locais até tocar em "Aplicar".
/// Com [wide] usa duas colunas (gráfico + controles à esquerda, sliders à direita).
class EqAdvancedPanel extends StatefulWidget {
  const EqAdvancedPanel({
    super.key,
    required this.dev,
    this.wide = false,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 30),
  });

  final MoondropDevice dev;
  final bool wide;
  final EdgeInsets padding;

  @override
  State<EqAdvancedPanel> createState() => _EqAdvancedPanelState();
}

class _EqAdvancedPanelState extends State<EqAdvancedPanel> {
  int selected = 0;

  MoondropDevice get dev => widget.dev;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: dev,
      builder: (context, _) {
        final bands = dev.eqBands;
        if (bands.isEmpty) {
          return const Padding(
              padding: EdgeInsets.all(24), child: Text('Sem bandas (fone desconectado?)'));
        }
        final sel = bands.firstWhere((b) => b.index == selected, orElse: () => bands.first);
        final curve = EqCurve(
            bands: bands,
            preGainDb: dev.eqPreGain,
            selected: sel.index,
            height: widget.wide ? 300 : 220);
        final err = dev.error == null
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(dev.error!, style: const TextStyle(color: Mc.danger)));
        if (widget.wide) {
          // PC: painel largo = gráfico+controles | sliders; painel estreito = empilha,
          // com os controles da banda em duas colunas.
          return LayoutBuilder(builder: (context, c) {
            if (c.maxWidth >= 860) {
              return ListView(padding: widget.padding, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    flex: 6,
                    child: Column(children: [
                      curve,
                      const SizedBox(height: 18),
                      _bandControls(sel),
                      const SizedBox(height: 14),
                      _preGain(),
                    ]),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    flex: 5,
                    child: Column(children: [
                      const SizedBox(height: 34),
                      _sliders(bands, sel),
                      err,
                      const SizedBox(height: 22),
                      _actions(),
                    ]),
                  ),
                ]),
              ]);
            }
            return ListView(padding: widget.padding, children: [
              curve,
              const SizedBox(height: 14),
              _sliders(bands, sel, h: 170),
              const SizedBox(height: 14),
              _bandControlsGrid(sel),
              err,
              const SizedBox(height: 8),
              _actions(),
            ]);
          });
        }
        return ListView(padding: widget.padding, children: [
          curve,
          const SizedBox(height: 18),
          _sliders(bands, sel),
          const SizedBox(height: 18),
          _bandControls(sel),
          const SizedBox(height: 14),
          _preGain(),
          err,
          const SizedBox(height: 18),
          _actions(),
        ]);
      },
    );
  }
  // ---------------------------------------------------------------- sliders
  Widget _sliders(List<EqBand> bands, EqBand sel, {double h = 250}) {
    Widget scale() => SizedBox(
          width: 26,
          height: h,
          child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('+', style: TextStyle(fontSize: 16)),
            Text('0', style: TextStyle(fontSize: 16)),
            Text('−', style: TextStyle(fontSize: 16)),
          ]),
        );
    return Row(children: [
      scale(),
      Expanded(
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          for (final b in bands)
            Column(children: [
              VSlider(
                height: h,
                value: b.gainDb,
                selected: b.index == sel.index,
                onStart: () => setState(() => selected = b.index),
                onChanged: (v) => dev.editBandLocal(b.index, gainDb: v),
              ),
              const SizedBox(height: 8),
              Text(_hz(b.freqHz),
                  style: TextStyle(
                      fontSize: 12,
                      color: b.index == sel.index ? Colors.white : Mc.sub)),
            ]),
        ]),
      ),
      scale(),
    ]);
  }

  // ---------------------------------------------------- controles da banda
  /// Mesmos controles em duas colunas (painel de PC não tão largo).
  Widget _bandControlsGrid(EqBand b) {
    final freq = _sliderPill(
      labelW: 92,
      label: 'Freq.  ${b.freqHz} Hz',
      value: math.log(b.freqHz / 20) / math.log(1000),
      onChanged: (t) => dev.editBandLocal(b.index,
          freqHz: (20 * math.pow(1000, t)).round().clamp(20, 20000)),
    );
    final q = _sliderPill(
      labelW: 70,
      label: 'Q  ${b.q.toStringAsFixed(2)}',
      value: (math.log(b.q.clamp(0.1, 10.0)) - math.log(0.1)) / (math.log(10) - math.log(0.1)),
      onChanged: (t) => dev.editBandLocal(b.index,
          q: double.parse(
              math.exp(math.log(0.1) + t * (math.log(10) - math.log(0.1))).toStringAsFixed(2))),
    );
    return Column(children: [
      Row(children: [
        Expanded(child: freq),
        const SizedBox(width: 12),
        Expanded(child: q),
      ]),
      const SizedBox(height: 12),
      _preGain(),
    ]);
  }

  Widget _bandControls(EqBand b) {
    return Column(children: [
      Row(children: [
        Expanded(child: _pillBox(child: const Text('Filtro  Peaking  ▾', style: TextStyle(color: Mc.sub)))),
        const SizedBox(width: 12),
        Expanded(
          child: _pillBox(
            child: Text('Ganho  ${b.gainDb.toStringAsFixed(1)} dB',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      _sliderPill(
        label: 'Frequência  ${b.freqHz} Hz',
        value: math.log(b.freqHz / 20) / math.log(1000),
        onChanged: (t) => dev.editBandLocal(b.index,
            freqHz: (20 * math.pow(1000, t)).round().clamp(20, 20000)),
      ),
      const SizedBox(height: 12),
      _sliderPill(
        label: 'Q  ${b.q.toStringAsFixed(2)}',
        value: (math.log(b.q.clamp(0.1, 10.0)) - math.log(0.1)) / (math.log(10) - math.log(0.1)),
        onChanged: (t) => dev.editBandLocal(b.index,
            q: double.parse(
                math.exp(math.log(0.1) + t * (math.log(10) - math.log(0.1))).toStringAsFixed(2))),
      ),
    ]);
  }

  Widget _pillBox({required Widget child}) => Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Mc.line, width: 1.6),
        ),
        child: child,
      );

  Widget _sliderPill({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    double labelW = 150,
  }) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Mc.line, width: 1.6),
      ),
      child: Row(children: [
        SizedBox(width: labelW, child: Text(label, style: const TextStyle(color: Mc.sub))),
        Expanded(
          child: Slider(value: value.clamp(0.0, 1.0), onChanged: onChanged),
        ),
      ]),
    );
  }

  Widget _preGain() {
    return Container(
      height: 60,
      padding: const EdgeInsets.only(left: 22, right: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Mc.line, width: 1.6),
      ),
      child: Row(children: [
        SizedBox(
            width: 150,
            child: Text('Pré-ganho  ${dev.eqPreGain.toStringAsFixed(1)} dB',
                style: const TextStyle(color: Mc.sub))),
        Expanded(
          child: Slider(
            min: -12,
            max: 0,
            divisions: 120,
            value: dev.eqPreGain.clamp(-12.0, 0.0),
            onChanged: dev.editPreGainLocal,
          ),
        ),
        TextButton(onPressed: dev.autoPreGainLocal, child: const Text('Auto')),
      ]),
    );
  }

  // ------------------------------------------------------------------ ações
  Widget _actions() {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      _action(Icons.restart_alt_rounded, 'Restaurar', dev.resetEq),
      _action(Icons.exposure_zero_rounded, 'Zerar', () {
        for (final b in dev.eqBands) {
          dev.editBandLocal(b.index, gainDb: 0);
        }
        dev.editPreGainLocal(0);
      }),
      _action(Icons.check_rounded, dev.eqDirty ? 'Aplicar •' : 'Aplicar',
          dev.applyEq),
    ]);
  }

  Widget _action(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Column(children: [
          Icon(icon, size: 30),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  static String _hz(int f) => f >= 1000
      ? '${(f / 1000).toStringAsFixed(f % 1000 == 0 ? 0 : 1)}k'
      : '$f';
}

/// Slider vertical de ganho (-12 a +12 dB) com o "botão" retangular do app oficial.
class VSlider extends StatelessWidget {
  const VSlider({
    super.key,
    required this.height,
    required this.value,
    required this.selected,
    required this.onChanged,
    required this.onStart,
  });

  final double height;
  final double value;
  final bool selected;
  final ValueChanged<double> onChanged;
  final VoidCallback onStart;

  static const _thumbW = 42.0, _thumbH = 44.0, _range = 12.0;

  double _toValue(double dy) {
    final t = ((dy - _thumbH / 2) / (height - _thumbH)).clamp(0.0, 1.0);
    final v = _range - t * 2 * _range;
    return (v * 10).round() / 10.0;
  }

  @override
  Widget build(BuildContext context) {
    final t = (_range - value.clamp(-_range, _range)) / (2 * _range);
    final top = t * (height - _thumbH);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) {
        onStart();
        onChanged(_toValue(d.localPosition.dy));
      },
      onVerticalDragStart: (_) => onStart(),
      onVerticalDragUpdate: (d) => onChanged(_toValue(d.localPosition.dy)),
      child: SizedBox(
        width: _thumbW + 10,
        height: height,
        child: Stack(alignment: Alignment.topCenter, children: [
          Positioned(
            top: 0,
            bottom: 0,
            child: Container(
              width: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF444444),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Positioned(
            top: top,
            child: Container(
              width: _thumbW,
              height: _thumbH,
              decoration: BoxDecoration(
                color: const Color(0xFF5C5C5C),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: selected ? Colors.white : const Color(0xFF3A3A3A), width: 2),
              ),
              alignment: Alignment.center,
              child: Text(value.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}

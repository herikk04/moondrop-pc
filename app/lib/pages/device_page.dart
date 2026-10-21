import 'package:flutter/material.dart';

import '../device.dart';
import '../eq_curve.dart';
import '../gaia.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import 'eq_page.dart';

/// Página principal: conexão, bateria, ANC e atalho para o EQ (como a tela "Device" do app oficial).
class DevicePage extends StatefulWidget {
  const DevicePage({super.key, required this.dev, this.onOpenEq});

  final MoondropDevice dev;

  /// No layout de PC, o resumo do EQ troca para a aba Equalizador.
  final VoidCallback? onOpenEq;

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  final macCtl = TextEditingController();
  List<PairedDevice> paired = const [];
  bool scanning = false;

  MoondropDevice get dev => widget.dev;

  @override
  void initState() {
    super.initState();
    macCtl.text = dev.mac;
    _scan();
  }

  @override
  void dispose() {
    macCtl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() => scanning = true);
    final r = await MoondropDevice.listPaired();
    if (!mounted) return;
    setState(() {
      paired = r;
      scanning = false;
      if (macCtl.text.isEmpty && r.isNotEmpty) {
        final m = r.firstWhere(
            (d) =>
                d.name.toLowerCase().contains('space') ||
                d.name.toLowerCase().contains('moondrop'),
            orElse: () => r.first);
        macCtl.text = m.mac;
      }
    });
  }

  String get _name {
    for (final d in paired) {
      if (d.mac.toUpperCase() == dev.mac.toUpperCase()) return d.name;
    }
    return 'MOONDROP';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: dev,
      builder: (context, _) {
        return LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 760;
          final error = dev.error == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
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

          if (wide) {
            // Layout de PC: duas colunas (dispositivo/bateria | ANC/EQ)
            return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
              McHeader(dev.connected ? _name : 'Dispositivo'),
              const SizedBox(height: 8),
              if (!dev.connected)
                Align(
                  alignment: Alignment.topLeft,
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(children: [_connectCard(), error])),
                )
              else ...[
                error,
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(children: [
                      _banner(),
                      const SizedBox(height: 28),
                      McCard(child: _batteryRow()),
                    ]),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(children: [
                      _ancCard(),
                      const SizedBox(height: 16),
                      _eqSummary(),
                    ]),
                  ),
                ]),
              ],
            ]);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            children: [
              McHeader(dev.connected ? _name : 'MOONDROP', center: true),
              const SizedBox(height: 8),
              if (!dev.connected) _connectCard() else _banner(),
              error,
              if (dev.connected) ...[
                const SizedBox(height: 22),
                _batteryRow(),
                const SizedBox(height: 22),
                _ancCard(),
                const SizedBox(height: 14),
                _eqTile(context),
              ],
            ],
          );
        });
      },
    );
  }

  /// Resumo do EQ no layout de PC: curva pequena + botão para abrir a aba Equalizador.
  Widget _eqSummary() {
    return McCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        McSectionTitle(
          dev.eqActive == null ? 'Equalizador' : 'Equalizador · ${eqPresetName(dev.eqActive!)}',
        ),
        const SizedBox(height: 12),
        if (dev.eqBands.isNotEmpty)
          EqCurve(bands: dev.eqBands, preGainDb: dev.eqPreGain, showLegend: false, height: 170),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: PillButton('Abrir equalizador', onTap: widget.onOpenEq),
        ),
      ]),
    );
  }

  Widget _banner() {
    return McCard(
      color: Mc.black,
      padding: const EdgeInsets.fromLTRB(26, 22, 18, 22),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_name,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            Text(dev.apiVersion != null ? 'GAIA ${dev.apiVersion}' : '—',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 22),
            Text(dev.mac, style: const TextStyle(color: Mc.sub, fontSize: 13)),
            const SizedBox(height: 14),
            PillButton('Desconectar', onTap: () => dev.disconnect(manual: true)),
          ]),
        ),
        const EarbudsArt(height: 118),
      ]),
    );
  }

  Widget _connectCard() {
    return McCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.headphones, color: Mc.sub),
          const SizedBox(width: 10),
          Expanded(
            child: Text(dev.connecting ? 'Conectando…' : 'Desconectado',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          if (dev.connecting)
            const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: TextField(
              controller: macCtl,
              enabled: !dev.connecting,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Endereço Bluetooth Clássico',
                hintText: 'AA:BB:CC:DD:EE:FF',
                isDense: true,
                filled: true,
                fillColor: Mc.chip,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Procurar fones pareados',
            onPressed: scanning ? null : _scan,
            icon: scanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.search),
          ),
        ]),
        if (paired.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final d in paired)
              ActionChip(
                label: Text(d.name),
                backgroundColor: Mc.chip,
                side: BorderSide.none,
                onPressed:
                    dev.connecting ? null : () => setState(() => macCtl.text = d.mac),
              ),
          ]),
        ],
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: PillButton('Conectar',
              filled: true,
              onTap: dev.connecting || macCtl.text.trim().isEmpty
                  ? null
                  : () => dev.connect(macCtl.text)),
        ),
      ]),
    );
  }

  Widget _batteryRow() {
    String side(int id) => id == 1 ? 'L' : (id == 2 ? 'R' : '$id');
    if (dev.battery.isEmpty) return const SizedBox(height: 40);
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      for (final b in dev.battery)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Column(children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              BatteryGlyph(percent: b.percent),
              const SizedBox(width: 12),
              Text('${b.percent}%', style: const TextStyle(fontSize: 15)),
            ]),
            const SizedBox(height: 6),
            Text(side(b.id), style: const TextStyle(color: Mc.sub)),
          ]),
        ),
    ]);
  }

  Widget _ancCard() {
    return McCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const McSectionTitle('Cancelamento de ruído'),
        const SizedBox(height: 18),
        Row(children: [
          CircleOption(
            icon: (c) => AncIcon(AncGlyph.transparency, color: c),
            label: 'Transparência',
            selected: dev.anc == AncMode.transparency,
            onTap: () => dev.setAnc(AncMode.transparency),
          ),
          CircleOption(
            icon: (c) => AncIcon(AncGlyph.noise, color: c),
            label: 'Redução de ruído',
            selected: dev.anc == AncMode.noise,
            onTap: () => dev.setAnc(AncMode.noise),
          ),
          CircleOption(
            icon: (c) => AncIcon(AncGlyph.off, color: c),
            label: 'Desligado',
            selected: dev.anc == AncMode.off,
            onTap: () => dev.setAnc(AncMode.off),
          ),
        ]),
        const SizedBox(height: 4),
      ]),
    );
  }

  Widget _eqTile(BuildContext context) {
    return McCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => EqPage(dev: dev))),
      child: Row(children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
          child: const Icon(Icons.equalizer_rounded, color: Colors.black, size: 28),
        ),
        const SizedBox(width: 22),
        Expanded(
          child: Text(
            dev.eqActive == null ? 'Equalizador' : 'Equalizador · ${eqPresetName(dev.eqActive!)}',
            style: const TextStyle(fontSize: 16),
          ),
        ),
        const Icon(Icons.chevron_right_rounded, size: 30),
      ]),
    );
  }
}

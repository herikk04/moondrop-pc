import 'dart:io';

import 'package:flutter/material.dart';

import '../device.dart';
import '../eq_curve.dart';
import '../gaia.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../window_bridge.dart';

/// Paleta do painel compacto (um tom mais escuro que o app, como o popover da barra de menu).
class Cp {
  static const bg = Color(0xFF16171B);
  static const card = Color(0xFF1F2025);
  static const border = Color(0xFF2C2E35);
  static const accent = Color(0xFF3DDC97);
  static const sub = Color(0xFF8E9099);
}

/// Painel compacto da bandeja: abas com ícones no topo, "hero" com a ilustração,
/// cartões por seção e rodapé de status. Reaproveita os componentes do app.
class CompactPanel extends StatefulWidget {
  const CompactPanel({super.key, required this.dev});

  final MoondropDevice dev;

  @override
  State<CompactPanel> createState() => _CompactPanelState();
}

class _CompactPanelState extends State<CompactPanel> {
  var tab = int.tryParse(Platform.environment['MOONDROP_CTAB'] ?? '') ?? 0;

  MoondropDevice get dev => widget.dev;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 392),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Cp.border),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1B1C21), Cp.bg],
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListenableBuilder(
              listenable: dev,
              builder: (context, _) => Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                  child: _tabBar(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                    children: switch (tab) {
                      0 => _home(),
                      1 => _eq(),
                      _ => _settings(),
                    },
                  ),
                ),
                _footer(),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ abas
  Widget _tabBar() {
    final icons = <Widget Function(Color)>[
      (c) => Icon(Icons.headphones_rounded, size: 26, color: c),
      (c) => Icon(Icons.equalizer_rounded, size: 26, color: c),
      (c) => GlyphIcon(Glyph.tune, color: c, size: 26),
    ];
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Cp.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Cp.border),
      ),
      child: Row(children: [
        for (var i = 0; i < icons.length; i++)
          Expanded(
            child: InkWell(
              onTap: () => setState(() => tab = i),
              borderRadius: BorderRadius.circular(13),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 46,
                decoration: BoxDecoration(
                  color: i == tab ? Cp.accent.withValues(alpha: 0.18) : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(child: icons[i](i == tab ? Cp.accent : Cp.sub)),
              ),
            ),
          ),
      ]),
    );
  }

  // ------------------------------------------------------------------ início
  List<Widget> _home() {
    final connected = dev.connected;
    return [
      _titleRow(),
      const SizedBox(height: 14),
      _hero(),
      const SizedBox(height: 14),
      if (connected) ...[
        _caption(),
        const SizedBox(height: 6),
        Text(_ancDescription(), style: const TextStyle(color: Cp.sub, fontSize: 14, height: 1.3)),
        const SizedBox(height: 16),
        _ancCard(),
        const SizedBox(height: 12),
        _eqCard(),
      ] else
        _connectBlock(),
    ];
  }

  Widget _titleRow() {
    return Row(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset('assets/app_icon.png', width: 40, height: 40),
      ),
      const SizedBox(width: 12),
      const Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Space Travel 2',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          SizedBox(height: 2),
          Text('MOONDROP · BLUETOOTH',
              style: TextStyle(
                  fontSize: 11, color: Cp.sub, fontWeight: FontWeight.w700, letterSpacing: 1.6)),
        ]),
      ),
      IconButton(
        tooltip: 'Abrir o app completo',
        onPressed: () => WindowBridge.setCompact(false),
        icon: const GlyphIcon(Glyph.expand, color: Cp.accent, size: 22),
      ),
      IconButton(
        tooltip: dev.connected ? 'Desconectar' : 'Conectar',
        onPressed: dev.connected
            ? () => dev.disconnect(manual: true)
            : (dev.mac.isEmpty ? null : () => dev.connect(dev.mac)),
        icon: GlyphIcon(Glyph.power, color: dev.connected ? Cp.accent : Cp.sub, size: 24),
      ),
    ]);
  }

  Widget _hero() {
    return Container(
      height: 188,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Cp.border),
        gradient: const RadialGradient(
          center: Alignment(-0.1, -0.5),
          radius: 1.1,
          colors: [Color(0xFF2A2C34), Color(0xFF0C0D10)],
        ),
      ),
      child: Stack(children: [
        const Align(alignment: Alignment(0, -0.25), child: EarbudsArt(height: 112)),
        Positioned(
          left: 0,
          right: 0,
          bottom: 14,
          child: dev.connected && dev.battery.isNotEmpty
              ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (final b in dev.battery)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(b.id == 1 ? 'L' : (b.id == 2 ? 'R' : '${b.id}'),
                            style: const TextStyle(color: Cp.sub, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Transform.scale(scale: 0.62, child: BatteryGlyph(percent: b.percent)),
                        Text('${b.percent}%', style: const TextStyle(fontSize: 14)),
                      ]),
                    ),
                ])
              : Center(
                  child: Text(
                    dev.connecting ? 'Conectando…' : 'Desconectado',
                    style: const TextStyle(color: Cp.sub, fontSize: 15),
                  ),
                ),
        ),
      ]),
    );
  }

  Widget _caption() {
    final mode = dev.anc;
    final label = switch (mode) {
      AncMode.noise => 'REDUÇÃO DE RUÍDO ATIVA',
      AncMode.transparency => 'MODO TRANSPARÊNCIA',
      AncMode.off => 'CANCELAMENTO DESLIGADO',
      null => 'LENDO O FONE…',
    };
    return Row(children: [
      Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Cp.accent)),
      const SizedBox(width: 8),
      Expanded(
        child: Text(label,
            style: const TextStyle(
                fontSize: 12, color: Cp.sub, fontWeight: FontWeight.w800, letterSpacing: 1.6)),
      ),
      if (dev.eqActive != null)
        Text(eqPresetName(dev.eqActive!).toUpperCase(),
            style: const TextStyle(
                fontSize: 12, color: Cp.accent, fontWeight: FontWeight.w800, letterSpacing: 1)),
    ]);
  }

  String _ancDescription() => switch (dev.anc) {
        AncMode.noise => 'O ruído externo é reduzido para você ouvir só a música.',
        AncMode.transparency => 'Você escuta o ambiente sem tirar os fones.',
        AncMode.off => 'Sem processamento de ruído. Toque abaixo para mudar.',
        null => 'Aguardando resposta do fone.',
      };

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: Cp.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Cp.border),
        ),
        child: child,
      );

  Widget _ancCard() {
    return _card(
      child: Column(children: [
        Row(children: [
          const GlyphIcon(Glyph.hearing, color: Cp.sub, size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Cancelamento de ruído',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          Text(dev.anc == null ? '—' : _shortAnc(dev.anc!),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          CircleOption(
            icon: (c) => AncIcon(AncGlyph.transparency, color: c, size: 30),
            label: 'Transparência',
            selected: dev.anc == AncMode.transparency,
            onTap: () => dev.setAnc(AncMode.transparency),
          ),
          CircleOption(
            icon: (c) => AncIcon(AncGlyph.noise, color: c, size: 30),
            label: 'Ruído',
            selected: dev.anc == AncMode.noise,
            onTap: () => dev.setAnc(AncMode.noise),
          ),
          CircleOption(
            icon: (c) => AncIcon(AncGlyph.off, color: c, size: 30),
            label: 'Desligado',
            selected: dev.anc == AncMode.off,
            onTap: () => dev.setAnc(AncMode.off),
          ),
        ]),
      ]),
    );
  }

  String _shortAnc(AncMode m) => switch (m) {
        AncMode.noise => 'Ruído',
        AncMode.transparency => 'Transparência',
        AncMode.off => 'Desligado',
      };

  Widget _eqCard() {
    final ids = dev.eqPresets;
    // até 4 atalhos: os primeiros presets + o personalizado
    final shown = <int>[
      ...ids.where((i) => i != kCustomPreset).take(3),
      if (ids.contains(kCustomPreset)) kCustomPreset,
    ].take(4).toList();
    return _card(
      child: Column(children: [
        Row(children: [
          const Icon(Icons.equalizer_rounded, color: Cp.sub, size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Equalizador',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          InkWell(
            onTap: () => setState(() => tab = 1),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Text('Ver todos', style: TextStyle(color: Cp.sub, fontSize: 14)),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        if (shown.isEmpty)
          const Text('—', style: TextStyle(color: Cp.sub))
        else
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            for (final id in shown) _presetTile(id),
          ]),
      ]),
    );
  }

  Widget _presetTile(int id, {double size = 64}) {
    final active = dev.eqActive == id;
    final glyph = id == kCustomPreset ? '★' : (id == 0 ? 'REF' : '$id');
    return InkWell(
      onTap: active ? null : () => dev.setEqPreset(id),
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: size + 8,
        child: Column(children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? Cp.accent.withValues(alpha: 0.16) : const Color(0xFF2A2C33),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: active ? Cp.accent : Colors.transparent, width: 1.6),
            ),
            child: Text(glyph,
                style: TextStyle(
                    fontSize: glyph.length > 1 && glyph != '★' ? 15 : 22,
                    fontWeight: FontWeight.w800,
                    color: active ? Cp.accent : Colors.white)),
          ),
          const SizedBox(height: 8),
          Text(eqPresetName(id),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? Colors.white : Colors.white70)),
        ]),
      ),
    );
  }

  Widget _connectBlock() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          dev.mac.isEmpty
              ? 'Nenhum fone escolhido ainda. Abra o app completo para selecionar o seu.'
              : 'Fone não encontrado. Ligue-o e deixe conectado a este PC (não ao celular).',
          style: const TextStyle(color: Cp.sub, height: 1.35),
        ),
        if (dev.error != null) ...[
          const SizedBox(height: 10),
          Text(dev.error!, style: const TextStyle(color: Mc.danger, fontSize: 13)),
        ],
        const SizedBox(height: 14),
        Row(children: [
          PillButton('Abrir app completo', onTap: () => WindowBridge.setCompact(false)),
          const SizedBox(width: 10),
          if (dev.mac.isNotEmpty)
            PillButton('Conectar',
                filled: true, onTap: dev.connecting ? null : () => dev.connect(dev.mac)),
        ]),
      ]),
    );
  }

  // -------------------------------------------------------------------- EQ
  List<Widget> _eq() {
    if (!dev.connected || dev.eqPresets.isEmpty) {
      return [
        _card(child: const Text('Conecte o fone para ver o equalizador.', style: TextStyle(color: Cp.sub))),
      ];
    }
    final custom = dev.eqActive == kCustomPreset;
    return [
      const Padding(
        padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
        child: Text('Equalizador', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      ),
      _card(
        child: Wrap(spacing: 8, runSpacing: 14, children: [
          for (final id in dev.eqPresets) _presetTile(id, size: 58),
        ]),
      ),
      const SizedBox(height: 12),
      if (dev.eqBands.isNotEmpty)
        _card(
          child: Column(children: [
            EqCurve(
                bands: dev.eqBands, preGainDb: dev.eqPreGain, showLegend: false, height: 170),
            if (custom) ...[
              const SizedBox(height: 12),
              for (final b in dev.eqBands)
                Row(children: [
                  SizedBox(
                      width: 52,
                      child: Text(b.freqHz >= 1000 ? '${(b.freqHz / 1000).toStringAsFixed(b.freqHz % 1000 == 0 ? 0 : 1)}k' : '${b.freqHz}',
                          style: const TextStyle(color: Cp.sub, fontSize: 13))),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Cp.accent,
                          thumbColor: Cp.accent,
                          inactiveTrackColor: const Color(0xFF34363D)),
                      child: Slider(
                        min: -12,
                        max: 12,
                        divisions: 240,
                        value: b.gainDb.clamp(-12.0, 12.0),
                        onChanged: (v) => dev.editBandLocal(b.index, gainDb: v),
                      ),
                    ),
                  ),
                  SizedBox(
                      width: 52,
                      child: Text(b.gainDb.toStringAsFixed(1),
                          textAlign: TextAlign.end, style: const TextStyle(fontSize: 13))),
                ]),
              Row(children: [
                PillButton('Aplicar', filled: dev.eqDirty, onTap: dev.applyEq),
                const SizedBox(width: 10),
                TextButton(
                    onPressed: dev.resetEq,
                    child: const Text('Restaurar', style: TextStyle(color: Cp.sub))),
              ]),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('Escolha "Personalizado" para editar as bandas.',
                    style: TextStyle(color: Cp.sub, fontSize: 13)),
              ),
          ]),
        ),
    ];
  }

  // -------------------------------------------------------------- ajustes
  List<Widget> _settings() {
    return [
      const Padding(
        padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
        child: Text('Ajustes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      ),
      _card(
        child: Column(children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Conectar automaticamente'),
            value: dev.autoConnect,
            onChanged: dev.setAutoConnect,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fechar vai para a bandeja'),
            value: dev.closeToTray,
            onChanged: dev.setCloseToTray,
          ),
        ]),
      ),
      const SizedBox(height: 12),
      _card(
        child: Wrap(spacing: 10, runSpacing: 10, children: [
          PillButton('Abrir app completo', onTap: () => WindowBridge.setCompact(false)),
          PillButton('Sair', onTap: WindowBridge.quit),
        ]),
      ),
    ];
  }

  // ---------------------------------------------------------------- rodapé
  Widget _footer() {
    final ok = dev.connected;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF111216),
        border: Border(top: BorderSide(color: Cp.border)),
      ),
      child: Row(children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ok ? Cp.accent : (dev.connecting ? Colors.amber : Colors.white30)),
        ),
        const SizedBox(width: 10),
        Text(ok ? 'Conectado' : (dev.connecting ? 'Conectando…' : 'Desconectado'),
            style: const TextStyle(fontSize: 15)),
        const Spacer(),
        const Text('MOONDROP-PC',
            style: TextStyle(
                fontSize: 11, color: Cp.sub, fontWeight: FontWeight.w800, letterSpacing: 2)),
        IconButton(
          tooltip: 'Ajustes',
          onPressed: () => setState(() => tab = 2),
          icon: const GlyphIcon(Glyph.tune, color: Cp.sub, size: 20),
        ),
      ]),
    );
  }
}

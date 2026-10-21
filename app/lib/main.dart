import 'package:flutter/material.dart';

import 'device.dart';
import 'gaia.dart';

void main() => runApp(const MoondropApp());

class MoondropApp extends StatelessWidget {
  const MoondropApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF3DDC97);
    return MaterialApp(
      title: 'MOONDROP PC',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: seed,
        scaffoldBackgroundColor: const Color(0xFF0E1013),
        cardTheme: CardThemeData(
          color: const Color(0xFF171A1F),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final dev = MoondropDevice();
  final macCtl = TextEditingController();
  List<PairedDevice> paired = const [];
  bool scanning = false;

  @override
  void initState() {
    super.initState();
    dev.addListener(() {
      if (mounted) setState(() {});
    });
    dev.loadConfig().then((_) {
      macCtl.text = dev.mac;
      _scan();
    });
  }

  @override
  void dispose() {
    dev.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('MOONDROP',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800, letterSpacing: 4)),
              const SizedBox(height: 4),
              Text('Controle para PC (não oficial)',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.white54)),
              const SizedBox(height: 20),
              _connectionCard(),
              if (dev.error != null) ...[
                const SizedBox(height: 12),
                Card(
                  color: const Color(0xFF3A1D1D),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: Color(0xFFFF8A80)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(dev.error!)),
                    ]),
                  ),
                ),
              ],
              if (dev.connected) ...[
                const SizedBox(height: 12),
                _batteryCard(),
                const SizedBox(height: 12),
                _ancCard(),
                const SizedBox(height: 12),
                _eqCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _connectionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.headphones,
                color: dev.connected ? const Color(0xFF3DDC97) : Colors.white38),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                dev.connected
                    ? 'Conectado${dev.apiVersion != null ? ' · GAIA ${dev.apiVersion}' : ''}'
                    : dev.connecting
                        ? 'Conectando…'
                        : 'Desconectado',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (dev.connecting)
              const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: TextField(
                controller: macCtl,
                enabled: !dev.connected && !dev.connecting,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Endereço Bluetooth Clássico',
                  hintText: 'AA:BB:CC:DD:EE:FF',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Procurar fones pareados',
              onPressed: dev.connected || scanning ? null : _scan,
              icon: scanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search),
            ),
          ]),
          if (paired.isNotEmpty && !dev.connected) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final d in paired)
                  ActionChip(
                    label: Text(d.name),
                    onPressed: dev.connecting
                        ? null
                        : () => setState(() => macCtl.text = d.mac),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: dev.connected
                ? OutlinedButton(
                    onPressed: dev.disconnect, child: const Text('Desconectar'))
                : FilledButton(
                    onPressed: dev.connecting || macCtl.text.trim().isEmpty
                        ? null
                        : () => dev.connect(macCtl.text),
                    child: const Text('Conectar'),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _batteryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Bateria', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (dev.battery.isEmpty)
            const Text('—', style: TextStyle(color: Colors.white54))
          else
            for (final b in dev.battery)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  SizedBox(width: 72, child: Text('Fone ${b.id}')),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: b.percent.clamp(0, 100) / 100,
                        minHeight: 10,
                      ),
                    ),
                  ),
                  SizedBox(
                      width: 56,
                      child: Text('${b.percent}%', textAlign: TextAlign.end)),
                ]),
              ),
        ]),
      ),
    );
  }

  /// Editor do preset personalizado: ganho por banda e pregain. Envia ao soltar o slider.
  List<Widget> _customEditor() {
    return [
      const SizedBox(height: 12),
      Row(children: [
        const SizedBox(width: 92, child: Text('Pregain')),
        Expanded(
          child: Slider(
            min: -12,
            max: 0,
            divisions: 120,
            value: dev.eqPreGain.clamp(-12.0, 0.0),
            label: '${dev.eqPreGain.toStringAsFixed(1)} dB',
            onChanged: dev.editPreGainLocal,
            onChangeEnd: (_) => dev.applyEq(),
          ),
        ),
        SizedBox(
            width: 64,
            child: Text('${dev.eqPreGain.toStringAsFixed(1)} dB',
                textAlign: TextAlign.end)),
      ]),
      for (final b in dev.eqBands)
        Row(children: [
          SizedBox(
              width: 92,
              child: Text(b.freqHz >= 1000
                  ? '${(b.freqHz / 1000).toStringAsFixed(b.freqHz % 1000 == 0 ? 0 : 1)} kHz'
                  : '${b.freqHz} Hz')),
          Expanded(
            child: Slider(
              min: -12,
              max: 12,
              divisions: 240,
              value: b.gainDb.clamp(-12.0, 12.0),
              label: '${b.gainDb.toStringAsFixed(1)} dB',
              onChanged: (v) => dev.editBandLocal(b.index, gainDb: v),
              onChangeEnd: (_) => dev.applyEq(),
            ),
          ),
          SizedBox(
              width: 64,
              child: Text('${b.gainDb.toStringAsFixed(1)} dB',
                  textAlign: TextAlign.end)),
        ]),
      const SizedBox(height: 4),
      Row(children: [
        OutlinedButton.icon(
          onPressed: () {
            dev.autoPreGainLocal();
            dev.applyEq();
          },
          icon: const Icon(Icons.auto_fix_high, size: 18),
          label: const Text('Pregain automático'),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () {
            for (final b in dev.eqBands) {
              dev.editBandLocal(b.index, gainDb: 0);
            }
            dev.editPreGainLocal(0);
            dev.applyEq();
          },
          child: const Text('Zerar'),
        ),
      ]),
    ];
  }

  Widget _eqCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Equalizador', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (dev.eqPresets.isEmpty)
            const Text('—', style: TextStyle(color: Colors.white54))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in dev.eqPresets)
                  ChoiceChip(
                    label: Text(eqPresetName(id)),
                    selected: dev.eqActive == id,
                    onSelected: (_) => dev.setEqPreset(id),
                  ),
              ],
            ),
          if (dev.eqBands.isNotEmpty && dev.eqActive == kCustomPreset)
            ..._customEditor(),
          if (dev.eqBands.isNotEmpty && dev.eqActive != kCustomPreset) ...[
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Bandas do preset ativo'),
              children: [
                Table(
                  columnWidths: const {
                    0: FixedColumnWidth(40),
                    1: FlexColumnWidth(),
                    2: FlexColumnWidth(),
                    3: FlexColumnWidth(),
                  },
                  children: [
                    const TableRow(
                      children: [
                        Text('#', style: TextStyle(color: Colors.white54)),
                        Text('Freq.', style: TextStyle(color: Colors.white54)),
                        Text('Q', style: TextStyle(color: Colors.white54)),
                        Text('Ganho', style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                    for (final b in dev.eqBands)
                      TableRow(children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text('${b.index + 1}'),
                        ),
                        Text('${b.freqHz} Hz'),
                        Text(b.q.toStringAsFixed(2)),
                        Text('${b.gainDb.toStringAsFixed(1)} dB'),
                      ]),
                  ],
                ),
              ],
            ),
          ],
        ]),
      ),
    );
  }

  Widget _ancCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Cancelamento de ruído',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<AncMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                    value: AncMode.off,
                    label: Text('Desligado'),
                    icon: Icon(Icons.hearing_disabled)),
                ButtonSegment(
                    value: AncMode.noise,
                    label: Text('Ruído'),
                    icon: Icon(Icons.noise_aware)),
                ButtonSegment(
                    value: AncMode.transparency,
                    label: Text('Transparência'),
                    icon: Icon(Icons.hearing)),
              ],
              selected: {if (dev.anc != null) dev.anc!},
              emptySelectionAllowed: true,
              onSelectionChanged: (s) {
                if (s.isNotEmpty) dev.setAnc(s.first);
              },
            ),
          ),
        ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Paleta e componentes no estilo do app oficial (fundo cinza-escuro, cartões cinza,
/// opções circulares e botões de contorno).
class Mc {
  static const bg = Color(0xFF222222);
  static const card = Color(0xFF333333);
  static const black = Color(0xFF000000);
  static const chip = Color(0xFF444444);
  static const sub = Color(0xFFB4B4B4);
  static const line = Color(0xFF4A4A4A);
  static const danger = Color(0xFFFF8A80);

  static ThemeData theme() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: Colors.white,
      scaffoldBackgroundColor: bg,
    );
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: Colors.white,
        surface: bg,
      ),
      textTheme: base.textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
      sliderTheme: SliderThemeData(
        activeTrackColor: Colors.white,
        inactiveTrackColor: chip,
        thumbColor: Colors.white,
        overlayColor: Colors.white24,
        trackHeight: 4,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : sub),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.black : chip),
        trackOutlineColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : Colors.transparent),
      ),
    );
  }
}

class McCard extends StatelessWidget {
  const McCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.color = Mc.card,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Título de seção com seta opcional, como "ANC Settings >".
class McSectionTitle extends StatelessWidget {
  const McSectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ),
        ?trailing,
      ]);
}

/// Opção circular com rótulo: selecionada = círculo branco com ícone preto.
class CircleOption extends StatelessWidget {
  const CircleOption({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Widget Function(Color color) icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkResponse(
        onTap: onTap,
        radius: 56,
        child: Column(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? Colors.white : Mc.chip,
            ),
            alignment: Alignment.center,
            child: icon(Colors.black),
          ),
          const SizedBox(height: 10),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
        ]),
      ),
    );
  }
}

/// Botão de contorno arredondado ("Use").
class PillButton extends StatelessWidget {
  const PillButton(this.label, {super.key, required this.onTap, this.filled = false});

  final String label;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.black : Colors.white;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 11),
        decoration: BoxDecoration(
          color: filled ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Text(label,
            style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 14)),
      ),
    );
  }
}

/// Cabeçalho de página interna: seta de voltar + título.
class McHeader extends StatelessWidget {
  const McHeader(this.title, {super.key, this.onBack, this.trailing, this.center = false});

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final t = Text(title,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800));
    return SizedBox(
      height: 56,
      child: Row(children: [
        if (onBack != null)
          IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22))
        else
          const SizedBox(width: 12),
        Expanded(child: center ? Center(child: t) : t),
        if (trailing != null) trailing! else const SizedBox(width: 48),
      ]),
    );
  }
}

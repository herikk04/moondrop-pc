# MOONDROP PC (não oficial)

Porte para Windows do app MOONDROP, para o fone **Space Travel 2**. Projeto pessoal, repositório privado.

- `app/` — app Flutter para Windows (Bluetooth Clássico SPP via Winsock/FFI): conexão automática, bateria, ANC, presets e editor do EQ personalizado, painel compacto na bandeja.
- `analise/` — protocolo GAIA v3 recuperado e confirmado no hardware (`PROTOCOLO_SPACE_TRAVEL_2_GAIA.md`).
- `prototipo/` — scripts Python de sondagem (BLE/RFCOMM) e pesquisa do módulo Airoha (emulador/modelo).
- `installer/` e `tools/` — instalador (Inno Setup) e script de releases.

Não estão no repositório: o APK/XAPK, o código descompilado, os logs do celular e os binários.

## Rodar / gerar
```
cd app
flutter pub get
flutter run -d windows            # desenvolvimento
flutter build windows --release   # gera build/windows/x64/runner/Release/
```

## Releases
Cada release tem o `Setup.exe` (instalador) e o `.zip` (pasta portátil: extraia e abra o `moondrop_pc.exe`).
O `tools/release.ps1` compila, gera os dois arquivos e publica a release no GitHub.
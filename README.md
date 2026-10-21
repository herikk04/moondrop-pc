# MOONDROP PC (não oficial)

Porte para Windows do app MOONDROP, para o fone **Space Travel 2**. Projeto pessoal, repositório privado.

- `app/` — app Flutter para Windows (Bluetooth Clássico SPP via Winsock/FFI): conexão automática, bateria, ANC, presets e edição do EQ personalizado.
- `analise/` — protocolo GAIA v3 recuperado e confirmado no hardware (`PROTOCOLO_SPACE_TRAVEL_2_GAIA.md`).
- `prototipo/` — scripts Python de sondagem (BLE/RFCOMM) e pesquisa do módulo Airoha (emulador/modelo).

Não estão no repositório: o APK/XAPK, o código descompilado, os logs do celular e os binários.

## Rodar / gerar
```
cd app
flutter pub get
flutter run -d windows            # desenvolvimento
flutter build windows --release   # gera build/windows/x64/runner/Release/
```
A versão compilada fica em `dist/MOONDROP_PC/` (pasta portátil; não versionada).

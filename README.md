# MOONDROP PC (não oficial)

Porte para Windows do app MOONDROP, para o fone **Space Travel 2**. Projeto pessoal, repositório privado.

- `app/` — app Flutter para Windows (Bluetooth Clássico SPP via Winsock/FFI): conecta, bateria e ANC.
- `analise/` — protocolo GAIA v3 recuperado e confirmado no hardware (`PROTOCOLO_SPACE_TRAVEL_2_GAIA.md`).
- `prototipo/` — scripts Python de sondagem (BLE/RFCOMM).

Não estão no repositório: o APK/XAPK, o código descompilado e os logs do celular.

## Rodar
```
flutter pub get
flutter run -d windows
```

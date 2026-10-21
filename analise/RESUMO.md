# MOONDROP 2.26.2c (com.moondroplab.moondrop.moondrop_app) — resumo da engenharia reversa

Análise estática (nada foi executado). Ferramentas: REA 6.7.0 (JADX 0.7.1), JADX 1.5.6, extração de strings.

## Arquitetura
- App **Flutter** (UI e lógica em Dart AOT, `libapp.so`, 11,8 MB). Engine hash Dart: `6c91ad5a9463a69a8895df0faf7c02dc`.
- Camada Android nativa (Java, 11.249 classes, quase tudo SDKs): serviços BT/USB/mídia e SDKs de fabricantes de chip.
- minSdk 28 / targetSdk 37. Só o split arm64 foi incluído.

## O que foi recuperado
| Item | Onde | Observação |
|---|---|---|
| Java descompilado | `decompilado_java/sources` | 11.206 arquivos; app em `com/moondroplab/**` |
| Libs nativas (arm64) | `xapk_extraido/_arm64/lib/arm64-v8a` | ver abaixo |
| Assets Flutter | `xapk_extraido/_base/assets/flutter_assets` | curvas EQ padrão, ícones, sons |
| Strings de cada lib | `analise/strings_*.txt` | endpoints, nomes, etc. |

## Lógica de DSP nativa (reaproveitável, com JNI)
- `libautoeq-lib.so`: `autoEQ`, `calculatePeqFr`, `calculatePeqPregain`, `calculatePregain`, `loadFromFile`, `generateTargetFrequencies`, `normalizeSPLValues` (EQ automático/PEQ).
- `libutils-lib.so`: `computeIIRFilterNative(int,double,double,int)` (coeficientes IIR), `readQ88/writeQ88`, `readU16LE/U32LE` (codec de protocolo).
- `libnative-peq.so`, `libnative-anc*.so`, `libnative-ha.so`: PEQ, ANC, hearing aid.
- `libpcmmixer-lib.so`: mixer de ruído branco.
- `libcrypto-lib.so` (`CryptoUtilsNative.calculateMD5Hash4BytesFromFile`): checagem de firmware (OTA).
- `libmoondrop_rust_test.so`: lib Rust (pouco útil).
- Fabricantes de chip do hardware (SDKs embutidos): Airoha, Qualcomm (GAIA), Jieli, Conexant (`libCxAudioHidLib`), Synaptics. Ou seja, o fone fala protocolos diferentes conforme o modelo.

## Backend (REST) — `https://cdn-service.moondroplab.tech/api/v1/`
`users/login|logout|refresh|mine`, `products/all`, `products/{uuid}`, `products/product-ota-version`,
`peq-configs[/all|/mine|/{uuid}]` (+ addLike/addFavorite/addDownloadCount), `peq-config-favorites`,
`freq-response[/mine|/{uuid}]`, `huihifi/freq-response/all`, `refresponse/all`, `responselib/allwithtag`,
`ota-configs/all`, `ota-config-equalizers/all`, `ota-config-voices/all`, `ota-config-app-resources/all`,
`prompt-tone-otas/all`, `icons/all`, `wallpapers/all`, `policies/all`, `qa-categories/all`, `user-feedbacks`, `file/{group}`.
CDN de imagens: `https://cdn.moondroplab.tech/`. Mapas: AMap (China).
Login com SMS/e-mail/Geetest (captcha `gt4`).

## Limites desta análise
- O Dart AOT está em formato fora do padrão: o REA não recuperou classes/funções Dart nem as telas. Para isso é preciso um decompilador de snapshot compatível com esta versão do Dart (ex.: blutter/reFlutter), ainda não rodado.
- UUIDs de GATT/BLE, comandos do protocolo de cada modelo e payloads das chamadas REST (headers, assinatura) **ainda não foram extraídos**; estão no Dart ou nos SDKs de chip.
- Strings são observações de bytes, não prova de que o código é chamado.

## Caminho do porte para PC (sugestão)
1. UI nova (Flutter desktop reaproveita o design; Flutter Windows suporta o mesmo estilo de app) ou Electron/Tauri.
2. Transporte: BLE no Windows (WinRT) e USB-HID (para modelos com `CxAudioHid`).
3. DSP: reescrever autoEQ/IIR (Biquad) em código portável (TS/Rust/C++); os `.so` são ARM64 e não rodam no Windows.
4. Backend: reusar a API REST acima.

## Atualização — Dart recuperado parcialmente (blutter, em H:\moondrop-port)
- Dart 3.14.0-211.1.beta, snapshot 6c91ad5a9463a69a8895df0faf7c02dc. Blutter + PR #213 (single-snapshot) compilado no H:.
- Análise completa de código falha (padrões ARM64 do Dart 3.14, "getting native function pool object"); modo `--no-analysis` funcionou.
- Saída: `blutter_out/` — `asm/` (708 arquivos .dart com nomes OFUSCADOS), `pp.txt` (object pool), `objs.txt`, `ida_script/addNames.py`, `blutter_frida.js`.
- `analise/dart_strings.txt`: todas as strings literais do Dart (endpoints, chaves JSON, mensagens, nomes de métodos de plataforma).
- Há fluxos de OTA por USB-HID (Jieli, Bluetrum), serviço GAIA (Qualcomm) e SPP (produção).

# Protocolo "MOONDROP Control" (BLE) — recuperado do Java do APK 2.26.2c

Fonte: classes R8 em `decompilado_java/sources/defpackage/` (`q20`=UUIDs, `a20`/`e00`=GATT, `jb6`=codec de quadros,
`x00`=comandos, `b10`=notificações, `v10`=status, `n00`=tipos de filtro, `l20`=validação/envio, `cb6`=inteiros LE).
Análise estática; nada foi executado contra um fone real. Valide cada item com hardware antes de depender dele.

## GATT
| Papel | UUID |
|---|---|
| Serviço "MOONDROP Control" | `9ECA0000-7F3A-4F32-9A38-A91B2C6E0100` |
| Característica de escrita (comandos) | `9ECA0001-7F3A-4F32-9A38-A91B2C6E0100` |
| Característica de notificação (respostas/eventos) | `9ECA0003-7F3A-4F32-9A38-A91B2C6E0100` |
| CCCD | `00002902-0000-1000-8000-00805F9B34FB` (habilitar NOTIFY antes de enviar) |

O app só envia um comando por vez ("Another BLE source operation is running") e tem timeout por operação.

## Quadro (igual para comando, resposta e notificação)
```
byte 0   : 0xA5  (magic)
byte 1   : 0x01  (versão do protocolo)
byte 2   : ID do comando (resposta repete o ID do comando) ou ID da notificação (>=0x80)
byte 3   : N = tamanho do payload (0..255)
byte 4.. : payload (N bytes)
```
Inteiros multi-byte são **little-endian**. Resposta: `payload[0]` = status, o resto são dados.

## Comandos (`x00`)
| ID | Nome | Payload do pedido | Resposta (após o byte de status) |
|---|---|---|---|
| 0 | GET_FW_VERSION | — | 3 bytes (versão) |
| 1 | GET_AUDIO_SOURCE | — | 1 byte |
| 2 | SET_AUDIO_SOURCE | `[fonte u8]` | — |
| 3 | GET_CAPABILITY | — | lista de bytes |
| 4 | SET_POWER_OFF | — | — |
| 5 | GET_DEVICE_VOLUME | — | 1 byte |
| 6 | SET_DEVICE_VOLUME | `[vol u8]` | — |
| 7 | GET_PRESET_EQ | — | `[atual][?][?]` (4 bytes totais com status) |
| 8 | SET_PRESET_EQ | `[preset u8]` | — |
| 9 | GET_PEQ_CONFIG | — | 8 bytes totais: status + campos (u8,u8,u16,i16,bool) |
| 10 | SET_PEQ_PREGAIN | `[0x07][pregain i16]` | — |
| 11 | GET_PEQ_POINT | `[índice u8]` | 9 bytes: status, índice, freq u16, ganho i16, Q u16, tipo u8 |
| 12 | SET_PEQ_POINT | `[índice u8][freq u16][ganho i16][Q u16][tipo u8]` | idem GET (eco) |
| 13 | COMMIT_PEQ | `[ação u8: 0..2][revisão u16]` | status, revisão u16, preset ativo, flag |
| 14 | GET_MIC_GAIN | — | 4 × i16: atual, mín, máx, passo (dB × 10) |
| 15 | SET_MIC_GAIN | `[ganho i16]` | idem |
| 17 | GET_EARBUD_COLOR | — | 1 byte |
| 19 | GET_EARBUD_LANGUAGE | — | 1 byte |
| 21 / 23 | GET_EARBUD_SN_LEFT / RIGHT | — | 14 bytes (nº de série) |

Limites validados no app: freq 20..20000 Hz; ganho cabe em i16; **Q** 1..65535 (unidade 0,001); tipo de filtro 0..7;
revisão 0..65535; ação de commit 0..2. Ganho do mic: valor bruto / 10 = dB.

## Notificações (`b10`) — IDs ≥ 0x80
| ID | Nome | Payload |
|---|---|---|
| 134 (0x86) | PRESET_EQ_CHANGED | `[status][atual][anterior][motivo]` |
| 135 (0x87) | PEQ_COMMITTED | `[status][revisão u16][preset ativo]` |
| 136 (0x88) | MIC_GAIN_CHANGED | `[status]` + 4 × i16 (atual, mín, máx, passo) |

## Status (`v10`)
0 OK · 1 FALSE · 2 DENIED_BY_MODE · 3 SAME_SOURCE · 4 REVISION_CONFLICT · 14 READ_ONLY_PRESET ·
16 INVALID_OFFSET · 17 STORAGE_ERROR · 18 INFO_UNAVAILABLE · 255 UNKNOWN

## Tipos de filtro (`n00`)
0 PEAKING · 1 LOW_SHELF · 2 HIGH_SHELF · 3 LOW_PASS · 4 HIGH_PASS · 5 BAND_PASS · 6 NOTCH · 7 ALL_PASS

## Fluxo de edição de PEQ (inferido do código)
1. `GET_PEQ_CONFIG` → obter revisão/quantidade de bandas.
2. `SET_PEQ_PREGAIN` e N × `SET_PEQ_POINT`.
3. `COMMIT_PEQ` com a revisão esperada (conflito → `REVISION_CONFLICT`); o fone confirma por `PEQ_COMMITTED`.

## Outros transportes encontrados (modelos/linhas diferentes)
| Transporte | UUID / identificação | Onde |
|---|---|---|
| SPP / RFCOMM genérico | `00001101-0000-1000-8000-00805F9B34FB` | `xa4`, `ia`, `ro1`, `b40` |
| Qualcomm GAIA (SPP) | `00001107-D102-11E1-9B23-00025B00A5A5` | `xa4` |
| Jieli RCSP (OTA, BLE) | serviço `0000AE00-…`, escrita `0000AE01-…`, notif. `0000AE02-…` | `l30`, `g00`, `com/jieli/jl_bt_ota` |
| A2DP/HFP/AVRCP | `0000110B/111E` | `l30`, `km3` |
| Microchip ISSC (transparente) | `49535343-FE7D-4AE5-8FA9-9FAFD205E455` (+ `…8841…`, `…1E4D…`) | `fe5` |
| Airoha (ANC/PEQ nativos) | libs `libnative-anc-1568/158x`, `libnative-peq` + `com/airoha/sdk` | JNI |
| Conexant/Synaptics HID | `libCxAudioHidLib`, `com/syna` | USB-HID (OTA) |

## Para o porte (Windows)
- BLE: WinRT `Windows.Devices.Bluetooth` (C#/WinUI) ou `winrt`/`bleak` (Python) — suficiente para este protocolo.
- Implementar o codec em ~100 linhas; todos os campos são u8/u16/i16 LE.
- SPP/GAIA/Jieli só se for suportar os modelos que usam essas pilhas.

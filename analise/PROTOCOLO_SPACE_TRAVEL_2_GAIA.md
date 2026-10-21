# Space Travel 2 — protocolo GAIA v3 sobre BLE (confirmado no fone real)

Endereço BLE do fone usado nos testes: `AA:BB:CC:DD:EE:01`. Somente comandos de leitura foram enviados.

## GATT observado
| Serviço | Característica | Props | Uso |
|---|---|---|---|
| `00001100-d102-11e1-9b23-00025b00a5a5` (GAIA Qualcomm) | `00001101-…` | write | **comandos** |
| | `00001102-…` | notify, read | **respostas/notificações** |
| | `00001103-…` | notify, read, write-without-response | dados (ex.: upgrade) |
| `0000ff12-…` (vendor) | `ff13` write, `ff14` notify, `ff15` read/wwr | | não analisado |
| `0000ff10-…` (vendor) | `fff1` notify/write | | não analisado |
| `0000180f-…` Battery | `2a19` notify/read | | bateria padrão |

## Pacote GAIA v3 (BLE, sem SOF/length — vem direto no GATT)
```
bytes 0-1 : vendor ID  (u16 big-endian)   = 0x001D (Qualcomm; é o "29" em super(29, …) do app)
bytes 2-3 : command    (u16 big-endian)   = (feature << 9) | (tipo << 7) | cmd_id
              tipo: 0 comando, 1 notificação, 2 resposta, 3 erro
bytes 4.. : payload
```
Fluxo: habilitar notify em `…1102` (e `…1103`), escrever em `…1101` com response=True.

## Confirmado com o hardware
| Comando enviado | Resposta |
|---|---|
| `001d0000` GET_API_VERSION (feature 0 / cmd 0) | `001d 0100 | 03 01` → API **3.1** |
| `001d0001` GET_SUPPORTED_FEATURES (feature 0 / cmd 1) | `001d 0101 | 00 | 05 01 | 01 01 | 00 02 | 08 01 | 0f 01 | 10 01 | 14 01 | 15 01 | 0d 01 | 0e 01` |

A resposta: `00` = sem mais páginas; depois pares `(feature, versão)`.

## Features suportadas pelo Space Travel 2 (IDs conforme enum `r14` do app)
| ID | Nome | Versão |
|---|---|---|
| 0 | BASIC (core) | 2 |
| 1 | EARBUD | 1 |
| 5 | MUSIC_PROCESSING (EQ) | 1 |
| 8 | AUDIO_CURATION | 1 |
| 13 | BATTERY | 1 |
| 14 | VOICE | 1 |
| 15 | DAC_GAIN | 1 |
| 16 | CODEC_TYPE | 1 |
| 20 | ONEBRINGTWO | 1 |
| 21 | BT_ADDRESS | 1 |

Tabela completa de IDs do app: 0 BASIC, 1 EARBUD, 2 ANC, 3 VOICE_UI, 4 DEBUG, 5 MUSIC_PROCESSING, 6 UPGRADE,
7 HANDSET_SERVICE, 8 AUDIO_CURATION, 9 EARBUD_FIT, 10 VOICE_PROCESSING, 11 GESTURE_CONFIGURATION, 12 STATISTICS,
13 BATTERY, 14 VOICE, 15 DAC_GAIN, 16 CODEC_TYPE, 17 LIGHT_SENSOR, 18 SPATIAL_AUDIO, 19 LED, 20 ONEBRINGTWO,
21 BT_ADDRESS, 22 TOUCHV2, 23 AUDIO_RESOURCE, 24 POWER_CONTROL, 25 POWER_TIMEOUT, 26 TOUCHV3, 27 DYBASS,
29 AUDIO_FILE_STORAGE, 30 LR_CHANNEL, 31 TOUCHV4, 32 ANC_V2, 33 ANC_V3, 34 FIND_EARBUD, 35 DUAL_MIC_ENC.

Observação: este fone **não anunciou ANC** (2/32/33) nesta consulta; EQ fica em MUSIC_PROCESSING (5) / AUDIO_CURATION (8).

## Próximos passos
1. Ler os plugins do app para MUSIC_PROCESSING (5), AUDIO_CURATION (8), BATTERY (13), DAC_GAIN (15), CODEC_TYPE (16) e obter IDs de comando/payload.
2. Validar cada GET no fone antes de qualquer SET.
3. Investigar `ff12`/`ff10` (podem ser o canal proprietário de EQ/PEQ da Moondrop).

Script: `prototipo/gaia_probe.py`.

## Leituras seguras confirmadas (BLE, Space Travel 2)
| Comando | Resposta | Interpretação provável |
|---|---|---|
| BATTERY (13) cmd 1 | `01 64 02 64` | pares (id, %): 1=100, 2=100 (esq/dir) |
| BATTERY (13) cmd 0 | `01 02` | provável nº de baterias/versão |
| MUSIC_PROCESSING (5) cmd 0 | `01` | provável versão/flag |
| MUSIC_PROCESSING (5) cmd 1 | `06 00 01 02 03 04 3f` | 6 presets de EQ: ids 0,1,2,3,4 e 0x3f (provavelmente custom) |
| ANC_V3 (33) / ANC_V2 (32) / ANC (2) cmd 3 | sem resposta | **feature ausente no BLE deste fone** |
| CODEC_TYPE (16) / DAC_GAIN (15) cmd 0 | sem resposta | cmd 0 não é o de leitura destas features |

Escuta passiva de 90 s em 1102/1103/ff14/fff1/2a19 não recebeu nada (sem confirmação de que o ANC foi trocado durante o teste).
Hipótese: ANC deste modelo está no GAIA por **Bluetooth Clássico (SPP/RFCOMM, UUID 00001107-D102-11E1-9B23-00025B00A5A5)**, não no BLE.

## RFCOMM (Bluetooth Clássico) — testado
- Endereço Clássico do fone: `AA:BB:CC:DD:EE:02` (o BLE é `…:01`). O Windows expõe RFCOMM: HFP (0x111E) e SPP genérico (0x1101); **não** anuncia 0x1107 (GAIA).
- GAIA responde sobre SPP (0x1101), quadro: `FF | versão | flags | len | vendor u16 | cmd u16 | payload` — o fone responde com **versão 4** (`ff 04 00 len …`); aceitou requisição com versão 3 e flags 0.
- API_VERSION → `0301`; SUPPORTED_FEATURES → mesmas 10 features do BLE. ANC_V3 (33), ANC_V2 (32), ANC (2) cmd 3 → **sem resposta** também no RFCOMM.
- Conclusão: o ANC deste fone não está no GAIA (nem BLE nem SPP). Resta investigar `ff10`/`ff12` (BLE vendor) e HFP/AVRCP.
- Script de exemplo: `prototipo/gaia_rfcomm.py`.

## ANC descoberto via logcat do app (Samsung A13, adb bugreport) — 2026-10-20
- O app conecta por **SPP (RFCOMM, 0x1101) com GAIA v3** (protocolVersion 4) e registra os plugins das 10 features.
- **ANC = feature 8 (AUDIO_CURATION)**, não as features ANC (2/32/33):
  - cmd **3** = GET modo atual → resposta 1 byte (`onANCModeReceived: 2`; o fone estava em *transparência* = **2**)
  - cmd **4** = SET modo (payload não logado; no teste do celular as respostas deram NO_RESPONSE/timeout)
  - cmd **0x29** = GET configuração das ações (5 bytes `[1,1,1,1,0]` → ENABLED, ACON, ACOFF, TP, ORDER=ON_OFF_TP)
- Após conectar, o app manda **cmd 0x07 (feature 0) por feature** para registrar notificações; para EARBUD/AUDIO_CURATION/DAC_GAIN/CODEC_TYPE/ONEBRINGTWO/BT_ADDRESS/BATTERY/VOICE o registro retornou NO_RESPONSE neste fone.
- Bateria: o app consulta feature 13 cmd 1 repetidamente (polling, ~149 vezes na sessão).
- Sequência de troca informada pelo usuário no app: transparência → noise reduction → desativado (valores de modo ainda não mapeados).
- Logs: `captura/app_logcat.txt` (logcat do app), `captura/bugreport.zip`.

## ANC — mapa de modos confirmado no fone (leitura, RFCOMM/SPP, GAIA v3)
Comando: feature 8 (AUDIO_CURATION), cmd 3 (GET modo) → payload de 4 bytes `[modo][01][00][00]`.
| byte 0 | Modo |
|---|---|
| 0x00 | Desligado |
| 0x01 | Cancelamento de ruído |
| 0x02 | Transparência |
Verificado cíclicamente: desligado → transparência → ruído → desligado → transparência → ruído (3 ciclos, trocas manuais no fone).
Request: `FF 03 00 00 00 1D 10 03` (vendor 0x001D, feature 8 << 9 | cmd 3 = 0x1003). Script: `prototipo/anc_monitor.py`.
Config das ações (cmd 0x29): `01 01 01 01 00` = ENABLED, ACON, ACOFF, TP habilitados, ORDER ON_OFF_TP.
Pendente: payload do SET (cmd 4) — não testado.

## SET do modo de ANC — formato encontrado no Java (não testado no fone)
- `pu0.java:156`: `qe5.D(4, modo)` → `vf5.D` → `h47.a`: comando **feature 8, cmd 4, payload de 1 byte = [modo]**.
- Valores: 0 desligado, 1 cancelamento de ruído, 2 transparência (mesmos do GET).
- Frame RFCOMM previsto: `FF 03 00 01 00 1D 10 04 <modo>`  (vendor 0x001D, 0x1004 = feature 8 << 9 | cmd 4, len=1).
- Resposta do GET (cmd 3) = `[modo][tipo][adaptação][ganho]` (+ `[howling]` se versão do plugin ≥ 5). Observado: `00 01 00 00`.
- No teste do app no celular, o SET deu `NO_RESPONSE` (timeout) em várias tentativas — a ack pode não vir; confirmar relendo o modo (cmd 3).

## ✅ SET do modo de ANC — CONFIRMADO no hardware (Space Travel 2)
GAIA v3 sobre SPP/RFCOMM, feature 8 (AUDIO_CURATION), **cmd 4**, payload de 1 byte = **máscara de bit** `1 << modo`:
| Modo (GET cmd 3, byte 0) | Valor do SET (cmd 4) |
|---|---|
| 0 Desligado | `0x01` |
| 1 Cancelamento de ruído | `0x02` |
| 2 Transparência | `0x04` |
Valores 0, 3, 5..9 não têm efeito. O fone **não envia ack** (resposta vazia) — confirmar relendo o modo (cmd 3).
Quadro: `FF 03 00 01 00 1D 10 04 <máscara>`. Testado ciclo completo (transp→ruído→off→transp→off): 5/5 OK.
MODES_COUNT (cmd 2) → `03 36 01 00` (3 modos). Scripts: `prototipo/anc_set_verify.py` e `prototipo/anc_set_scan.py`.

## EQ — MUSIC_PROCESSING (feature 5), confirmado em leitura no fone
| cmd | Função | Pedido | Resposta |
|---|---|---|---|
| 0 | GET estado do EQ | — | `01` (ligado) |
| 1 | GET presets disponíveis | — | `[n][ids…]` → `06 00 01 02 03 04 3f` |
| 2 | GET preset ativo | — | `[id]` (observado `00`) |
| 3 | **SET preset ativo** | `[id]` | sem ack; reler cmd 2 (visto no plugin do app, `rc2:513`) |
| 4 | GET nº de bandas | — | `05` |
| 5 | GET bandas | `[ini][fim]` | `[ini][fim][master i16]` + bandas de 7 bytes |
Banda (**big-endian**): `[freq u16][Q×4096 u16][tipo u8][ganho×60 i16]`. Preset 0 observado: 20/200/2000/12000/20000 Hz, Q=0,707, ganho 0 (plano).
Notificação (type=1) feature 5 cmd 0 chega quando o estado muda.
PEQ personalizado (cmd 6/7): bloco de coeficientes Airoha em pedaços de 63 bytes (cmd 6, `[idx]+63 bytes`) e depois cmd 7 com a configuração das bandas — **não implementado**.
Nomes dos presets não estão no APK (vêm de `/ota-config-equalizers/all` no servidor).

## ✅ EQ personalizado — SET confirmado pelo log do app oficial (caminho "Bluetrum")
O Space Travel 2 usa o caminho **Bluetrum** (`setBluetrumSetGains` no app), não o bloco de coeficientes Airoha.
Para editar o preset personalizado (id `0x3F`):
1. `feature 5, cmd 3` payload `[0x3F]` (seleciona o preset personalizado) — o app faz isso ao entrar na tela.
2. `feature 5, cmd 6` (SET bandas), até 7 bandas por pacote, mesmo layout do GET (cmd 5):
   `[ini][fim][pregain×60 i16 BE]` + N × `[freq u16 BE][Q×4096 u16 BE][tipo u8][ganho×60 i16 BE]`  (truncando como `(int)`).
3. O fone **não manda ack** (timeout de 10 s no app) — confirmar relendo `cmd 5`.
Exemplo real capturado (pregain −3,1; 20 Hz −2,5 dB; 20 kHz +3,0 dB; demais 0; Q=0,7068; tipo 0):
`00 04 FF 46 | 00 14 0B 4F 00 FF 6A | 00 C8 0B 4F 00 00 00 | 07 D0 0B 4F 00 00 00 | 2E E0 0B 4F 00 00 00 | 4E 20 0B 4F 00 00 B4`
Frequências do preset: 20, 200, 2000, 12000, 20000 Hz. O app calcula o pregain sozinho (≈ −(pico de ganho + 0,2) dB).
O caminho de coeficientes da Airoha (bloco enviado em pedaços de 63 bytes) **não é usado neste fone**; ele usa o caminho simples descrito acima.

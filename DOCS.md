# Mosaic OS: documentação do código

Guia de cada parte do código, para aprender e mexer com segurança. As decisões de design (o "porquê") estão no [VISAO.md](VISAO.md); aqui fica o "como". **Regra:** toda mudança no código atualiza a seção correspondente deste arquivo.

## Sumário
1. [Conceitos básicos](#1-conceitos-básicos)
2. [Como o projeto está montado](#2-como-o-projeto-está-montado)
3. [Ligar e desligar: `scripts/mosaic-os.sh`](#3-ligar-e-desligar)
4. [Hyprland e o liquid glass: `hypr/mosaic.lua`](#4-hyprland-e-o-liquid-glass)
5. [A ilha: `modules/mosaic/island/Island.qml`](#5-a-ilha)
6. [A bússola: `modules/mosaic/island/Compass.qml`](#6-a-bússola)
7. [O mascote: `modules/mosaic/island/Mascot.qml`](#7-o-mascote)
8. [O dock: `modules/mosaic/dock/MosaicDock.qml`](#8-o-dock)
9. [O que mudou nos arquivos herdados do ii](#9-o-que-mudou-no-ii)
10. [Como testar sem quebrar a sessão](#10-como-testar)
11. [Papéis de parede e o derramar: `modules/mosaic/wallpapers/`](#11-papéis-de-parede-e-o-derramar)

---

## 1. Conceitos básicos

### Linguagens usadas
| Linguagem | Onde | Para quê |
| --- | --- | --- |
| **QML** | todos os `.qml` | descrever a interface (objetos, propriedades, animações) |
| **JavaScript** | dentro do QML | lógica: condições, contas, funções |
| **Lua** | `hypr/*.lua` e `~/.config/hypr` | configuração do Hyprland 0.57 (API `hl.*`) |
| **fish/bash** | `scripts/` | ligar e desligar, reiniciar o shell |
| **GLSL** | só no vidro pixelado, já arquivado (`~/hyprglass-mosaic`) | shaders, programas que rodam na placa de vídeo |

### QML em 5 ideias
1. **Objetos aninhados.** `Rectangle { Text { } }` é um retângulo com um texto dentro. O filho se posiciona em relação ao pai.
2. **Propriedades e bindings.** Em `width: aberto ? 460 : 64`, a largura é *recalculada sozinha* sempre que `aberto` muda. Não existe "quando abrir, faça X": você declara do que cada coisa depende.
3. **`id`.** É o nome com que um objeto é referido por outros (`notch.height`).
4. **Sinais.** São eventos. `onClicked: ...` roda quando o sinal `clicked` acontece; `onXChanged` roda quando a propriedade `x` muda.
5. **Componentes.** `component Block: Rectangle {...}` cria um tipo novo, reutilizável no mesmo arquivo.

### Animação em QML
- **`Behavior on prop { NumberAnimation {...} }`:** intercepta qualquer mudança de `prop` e, em vez de pular, anima até o valor novo. É o que mais usamos, porque basta mudar o binding e a animação acontece sozinha.
- **easing (curva):** diz como o tempo é distribuído ao longo da animação.
  - `OutCubic`: rápido no começo, freia no fim. Natural.
  - `OutBack`: passa um pouco do destino e volta, dando o efeito de "mola" do Mosaic. `overshoot` controla o quanto passa.
  - `OutBounce`: quica no fim (aterrissagem do pulo do mascote).
- **`SpringAnimation`:** física de mola de verdade (`spring` = força, `damping` = atrito). Segue um alvo que muda continuamente, como a água dos copos.
- **`SequentialAnimation`:** animações uma depois da outra (subir, depois descer).
- **`FrameAnimation`:** roda código a cada quadro (60×/s). É caro; só use com `running:` condicionado.
- **`transform: Translate/Scale`:** move ou estica o *desenho* sem mexer no layout dos vizinhos.
- **`MosaicSpring`** (nosso, seção 5.11): mola de física de verdade que expõe a **velocidade**. É ela que dá o efeito gelatina da ilha (veio do hyprdots).
- **Cuidado com `Behavior` em valor que muda o tempo todo** (ex.: posição do mouse, ou algo ligado a outra animação): a animação reinicia a cada mudança e trava. Nesses casos, use uma mola que segue um alvo (`MosaicSpring`) ou misture dois valores com um número de 0 a 1 animado.

### Shaders (GLSL)
Um shader é um programa curtinho que roda **na placa de vídeo, uma vez para cada pixel**, ao mesmo tempo. No Quickshell ele entra por um `ShaderEffect` com `fragmentShader: "arquivo.frag.qsb"`. Cada `property` do `ShaderEffect` vira uma variável (`uniform`) com o mesmo nome dentro do shader. O `.frag` é o código-fonte e o `.qsb` é ele compilado pelo `qsb` do Qt (o comando fica no topo de cada `.frag`). Usamos dois: `goo.frag` (seção 5.10) e `pour.frag` (seção 11).
- **SDF (campo de distância com sinal):** para cada pixel, a distância até a borda de uma forma (negativa dentro, positiva fora). Com SDF, juntar formas como líquido é só uma conta (`smin`), e a borda fica lisa com 1 px de suavização (`fwidth`).

### Quickshell
- **`PanelWindow`:** uma janela de painel no Wayland (*layer surface*). Tem `anchors` (em qual borda gruda), `exclusiveZone` (quanto espaço reserva das janelas; 0 = flutua por cima) e `WlrLayershell.layer`, a camada: Background < Bottom < Top < Overlay. Só a Overlay fica acima de uma janela em tela cheia.
- **`mask: Region {...}`:** a área que recebe o mouse. Fora dela, o clique "atravessa" para a janela de baixo.
- **`Variants { model: Quickshell.screens }`:** cria uma cópia do painel para cada monitor.
- **`IpcHandler`:** expõe funções para o terminal, por exemplo `qs -c mosaic ipc call island toggle`.
- **Serviços (singletons) do ii:** objetos globais com dados do sistema, como `HyprlandData` (janelas e áreas), `Notifications`, `Audio`, `Network`, `DateTime`, `MprisController` (música), `ResourceUsage`, `TaskbarApps`, `GlobalStates` (o que está aberto, Super apertado), `Appearance` (cores do Matugen, fontes, raios).

---

## 2. Como o projeto está montado
```
~/.config/quickshell/mosaic/      cópia do ii (git próprio, branch main)
  shell.qml                       ponto de entrada: carrega a família de painéis
  panelFamilies/IllogicalImpulseFamily.qml   lista de painéis carregados (ver seção 9)
  modules/ii/...                  painéis herdados do ii (laterais, visão geral, OSD...)
  modules/mosaic/island/          ilha, bússola, mascote (novos)
  modules/mosaic/dock/            dock (novo)
  services/                       dados do sistema (herdados)
  hypr/mosaic.lua                 liquid glass do Mosaic OS
  scripts/mosaic-os.sh            liga/desliga
  VISAO.md  DOCS.md
~/.config/mosaic-os/config.json   configurações (o ii usa ~/.config/illogical-impulse)
```
O caminho das configurações foi trocado em `modules/common/Directories.qml` (`shellConfig`), para o Mosaic OS não mexer nas do ii.

---

## 3. Ligar e desligar
`scripts/mosaic-os.sh ligar|desligar|alternar|reiniciar` (Ctrl+Super+M chama `alternar`).

**A escolha fica salva** em `~/.local/state/mosaic-os/shell` (`mosaic` ou `ii`). Ao reiniciar o PC ou recarregar o Hyprland, continua o mesmo shell.
1. O script grava o arquivo, avisa o Hyprland (`hyprctl eval 'hl.env("qsConfig", "mosaic")'`) e recarrega a config (`hyprctl reload config-only`).
2. O `~/.config/hypr/custom/env.lua` é carregado antes de tudo. Ele lê o arquivo com `io.open` do Lua e faz `hl.env("qsConfig", salvo or os.getenv("qsConfig") or "ii")`. O arquivo vence a variável, porque é a fonte da verdade.
3. O `rules.lua` vê `qsConfig == "mosaic"` e carrega `hypr/mosaic.lua` (o vidro). O `execs.lua` inicia `qs -c $qsConfig` no login.
4. O script mata o `qs` atual, **espera ele sair de vez** (senão o novo briga pelo servidor de notificações) e inicia o escolhido.

**`alternar` olha o que está rodando de verdade** (`pgrep -ax qs` e o `-c X` do processo), não só a variável. Antes, quando algo reiniciava o `qs -c ii` por fora, a variável ainda dizia "mosaic". O atalho então calculava "trocar para ii", que já estava rodando, e parecia não funcionar.

**`reiniciar`** reinicia o shell salvo sem trocar. A função `qsr` do fish (`~/.config/fish/functions/qsr.fish`) agora chama ele; antes ela reiniciava sempre o ii.

**Não precisa mais reiniciar ao trocar o papel de parede.** O hook do Matugen (`~/.config/matugen/config.toml`, template `site`) agora só roda `mosaic-store --icone`, que repinta o ícone do Mosaic Store. O dock recarrega o ícone sozinho (seção 8.3).

---

## 4. Hyprland e o liquid glass
O vidro é o plugin **hyprglass** (fork em `~/hyprglass-mosaic`, carregado no `execs.lua`). `hypr/mosaic.lua`:
- cria o preset **"vivo"** com mais refração, aberração cromática, fresnel e brilho que o "clear" do ii;
- liga o vidro nas camadas pelo nome (namespace): `hg.layer("quickshell:island", { preset = "vivo", mask_threshold = 0.3 })`. O plugin desenha vidro atrás dos pixels da camada com opacidade acima de 0,3. Por isso o formato do vidro segue o formato do QML.
- **Pegadinha:** presets só valem depois de um reload da config, não em tempo de execução.

---

## 5. A ilha
Arquivo: `modules/mosaic/island/Island.qml`. É um `Scope` com estado global e uma `PanelWindow` por monitor.

### 5.1 Estado global (topo do arquivo)
| Propriedade | O que é |
| --- | --- |
| `openScreen` | nome do monitor onde o painel está aberto ("" = fechado) |
| `openedByHover` | se abriu pelo mouse no topo (então fecha ao sair) |
| `hasNotifs` | tem notificação na tela (`Notifications.popupList.length > 0`) |
| `hasPlayer`, `playing` | tem música, e se está tocando (o mascote dança) |
| `compassForced` | bússola aberta pela IPC, para testar sem Super |
| `eventKind`, `eventIcon`, `eventText`, `eventValue` | o evento sendo mostrado (seção 5.9) |
| `eventSerial` | sobe a cada evento, para a ilha dar o "pulinho" |

- `softBlock(c)` mistura uma cor do Matugen com a superfície (32%): os blocos suaves. `softTone(c)` mistura mais (72%), para tons bem apagados. A mistura é `ColorUtils.mix(a, b, t)`, que dá `t` de `a` e `1 - t` de `b`.
- `washStop(i, morph)` devolve a cor esquerda (0), do meio (1) e direita (2) do degradê da ilha: primária, secundária e terciária com 14% de cor em repouso e até 32% na bússola. A superfície e o shader da bolha usam a mesma função, então as cores batem.
- `opaque(c)` devolve a cor sem transparência: shaders recebem a cor e o alfa separados.
- `Connections { target: Notifications; function onNotify... }` faz o mascote pular a cada notificação, emitindo o sinal `jumpRequested`.
- O **`IpcHandler "island"`** tem `toggle`, `close`, `poke` e `compass`.

### 5.2 A janela por monitor
- 560×660 transparente, grudada no topo, `exclusionMode: Ignore` (não empurra janelas), camada **Overlay**.
- **`mask`**: só a ilha (`notch`), o sensor da borda e a bolha de notificação (`bubbleClip`) recebem o mouse. O resto da janela é "fantasma".
- **`setOpen(open, byHover)`** abre ou fecha o painel nesse monitor.
- **`pinned`**: aberto por clique. Com ele ligado, `keyboardFocus: OnDemand` deixa o Esc funcionar, e o `HyprlandFocusGrab` fecha o painel ao clicar fora (é o mesmo mecanismo das laterais do ii).
- **Sensor da borda** (`edgeSensor`, 360×2 px no topo): um `HoverHandler` abre o painel ao passar o mouse, e o `leaveTimer` (350 ms) fecha quando o mouse sai, se tiver sido aberto assim.

### 5.3 Gatilho da bússola (Super)
```qml
function updateCompass() {
    if (!GlobalStates.superDown) win.compassOpen = false;       // soltou: fecha
    else if (notchHover.hovered) win.compassOpen = true;        // Super + mouse na ilha: na hora
}
Timer { id: superHold; interval: 130
    onTriggered: if (GlobalStates.superDown && GlobalStates.superReleaseMightTrigger && win.isFocusedScreen) win.compassOpen = true }
```
- `GlobalStates.superDown` vem do ii.
- `superReleaseMightTrigger` vira `false` quando outra tecla é apertada junto (Super+Enter). Por isso o timer de 130 ms só abre a bússola se o Super estiver **sozinho**, e ela não pisca nos atalhos.
- `onCompassOpenChanged` zera `superReleaseMightTrigger`, para soltar o Super depois da bússola não abrir também a busca do ii.

### 5.4 O entalhe (`notch`): o "cérebro" da forma
```qml
readonly property string mode: compassOn ? "compass" : win.panelOpen ? "panel" : showEvent ? "event" : ""
```
Um único texto decide tudo, por prioridade: bússola > painel > evento > repouso. Largura, altura, conteúdo e cor dependem de `mode`. As notificações não mudam mais o modo: elas saem numa bolha à parte (5.10).
- **Tamanhos:** repouso = a linha "marca · hora · clima" + 24 px, com 30 de altura; evento = o conteúdo + 64 (38 de altura, 48 para música); bússola 380×124; painel 460 e altura do conteúdo (até 640).
- **Molas no lugar de `Behavior`:** `targetWidth`/`targetHeight` dizem o tamanho certo, e a largura e a altura **seguem** esses alvos por `MosaicSpring` (`widthSpring`, `heightSpring`, damping ~0,75: passa um pouco e volta). O mesmo para `morphSpring` (0 = ilha, 1 = bússola) e `centerSpring` (0 = marca à esquerda, 1 = marca no meio).
- **Gelatina (jelly):** a velocidade das molas vira deformação:
  ```qml
  readonly property real rush: widthSpring.velocity / 420 + heightSpring.velocity / 420 + morphSpring.velocity * 0.16
  readonly property real jelly: Math.max(-0.07, Math.min(0.07, rush * 0.052))
  // xScale = 1 + jelly, yScale = 1 - jelly * 0.62
  ```
  Crescendo rápido, a ilha estica para os lados e achata; freando, faz o contrário. Ao parar, a velocidade é 0 e ela volta ao normal. O limite de 7% evita exageros.
- **Toque:** mais três molas multiplicam a escala: `hoverSpring` (+2,8% com o mouse em cima), `pressSpring` (−3,5% apertando) e `peekSpring` (+4% por 90 ms a cada evento, o "pulinho"). O `Scale` tem origem no **meio do topo**, então ela cresce para baixo e para os lados, sem descolar da borda.
- **Tela cheia:** `fullscreenHere` procura em `HyprlandData.windowList` uma janela da área atual desse monitor com `fullscreen > 0`. Se achar e a ilha estiver em repouso, `hideY` a sobe para fora da tela (300 ms `OutCubic`).

### 5.5 A superfície: pílula, cartão e cúpula (`shaders/island.frag`)
A ilha flutua 6 px abaixo da borda (`topGap`) e é escura como a do hyprdots: `islandBase` é a superfície da barra 55% puxada para o preto, com opacidade mínima de 0,9. O desenho é um shader, porque precisa de cantos diferentes em cima e embaixo e de um achatamento:
- **A forma** é a **interseção de duas caixas arredondadas** em SDF (`max(d1, d2)`). Uma tem os cantos de cima (`rTop`) e se estende para baixo; a outra tem os de baixo (`rBot`) e se estende para cima. Assim, cada par de cantos tem seu próprio raio, e o de baixo pode ser meio círculo.
- **O achatamento:** a forma é montada com `hu` px de altura e desenhada com a altura real. Dividir o `y` do pixel por `altura / hu` transforma o meio círculo em meio **oval**.
- **Os valores**, com `m` = morph (0 ilha, 1 bússola):
  ```qml
  property real rTop: notch.cornerRadius                                   // min(altura/2, 26)
  property real rBot: notch.cornerRadius + (width / 2 - notch.cornerRadius) * m
  property real hu: height + (width / 2 + notch.cornerRadius - height) * m
  ```
  - em repouso, raio = metade da altura: uma **pílula**;
  - no painel, raio 26: um **cartão**;
  - na bússola, o de baixo vira metade da largura e a forma é montada mais alta e achatada para 124 px: uma **cúpula** com a base em meio oval.
- A cor é o degradê das três cores de `washStop` (10% dos tons sobre a base escura, 32% na bússola), com contorno de 1 px.
- A escala (gelatina e toque) agora tem origem no **centro** da ilha, como no hyprdots, porque ela não está mais presa na borda.
- Enquanto a bolha de notificação está fora, a superfície fica invisível (`opacity: bubble.living ? 0 : 1`) e o shader da bolha desenha a ilha (5.10).

### 5.6 O mascote: à esquerda, no meio, e como ponteiro
```qml
x: 12 + ((notch.width - width) / 2 - 12) * c     // c = centerSpring: 0 à esquerda, 1 no meio
size: 16 + 10 * notch.morph
rotation: notch.mode === "compass" ? compassContent.offset * 90 : 0
```
Em repouso e nos eventos a marca fica à esquerda; no painel e na bússola ela desliza para o meio. A posição é uma **mistura** entre os dois lugares, com `c` animado por mola, em vez de um `Behavior` no `x` (que travaria, porque `x` também depende da largura, que está sempre mudando). Na bússola, a marca cresce e gira 90° por área. Como `offset` já é animado com mola (seção 6), o giro sai com mola de graça. Cutucar só funciona no modo painel.

### 5.7 O conteúdo
- **Linha de repouso (`restRow`):** hora (Space Grotesk 14, negrito) e clima (ícone + temperatura em JetBrains Mono). `fullWidth` soma o espaço da marca, e a ilha se ajusta em volta das três coisas. Some (opacidade) fora do repouso.
- **Linha de evento (`eventLoader`):** um `Loader` que escolhe o conteúdo pelo tipo de evento (5.9).
- **Painel:** um `Loader` só fica ativo no modo `panel`. Fechado, o conteúdo é **destruído** e não gasta nada.
- **panelView** (`ColumnLayout`):
  1. hora e data (bloco primária→secundária) + clima (secundária→terciária, `Weather.data`, `Icons.getWeatherIcon`);
  2. música (terciária→primária, só se `hasPlayer`), com anterior/tocar/próxima via `MprisController`;
  3. ferramentas (`QuickTool`): Print, Cor (hyprpicker), Silêncio (`Notifications.silent`), LED (abre o `LedPopup` do ii) e a bateria do celular (KDE Connect);
  4. desempenho: 2×2 `FillTile` (CPU, RAM, GPU, swap).
- **GPU:** `FileView` lê `/sys/class/drm/card1/device/gpu_busy_percent` a cada 2 s, **só com o painel aberto**.

### 5.8 Componentes do arquivo
- **`Block`:** um `Rectangle` com degradê horizontal `tint → tint2`.
- **`QuickTool`:** célula fixa de 52×66, com um `RippleButton` redondo de 42 px, o ícone `MaterialSymbol` centralizado e a legenda.
- **`FillTile`** (o copo d'água):
  - `shownLevel` segue `level` com `SpringAnimation`, então a água "sobe na mola";
  - `FrameAnimation` soma `frameTime * 3.2` em `phase` e pede `requestPaint()` a cada quadro;
  - o `Canvas` (API 2D do HTML) recorta a forma do copo (`roundedRect` + `clip`) e desenha a superfície como uma senoide: `y = topo + sin(phase + x/w·2π) · amp`;
  - `amp` cresce enquanto o nível ainda está mudando, então a água balança mais;
  - uma segunda onda mais clara atrás dá profundidade.

### 5.9 Eventos
Coisas rápidas que a ilha mostra por um instante, ao lado da marca, só no monitor em foco. `showEvent(tipo, ícone, texto, valor)` guarda o evento e liga um `Timer` (1,8 s; 3,2 s para música). Nos primeiros 3 s depois de ligar, nada dispara (`eventsReady`), para os serviços não acordarem fazendo barulho.
| Evento | De onde vem | Como aparece |
| --- | --- | --- |
| Volume | `Connections` em `Audio.sink.audio` (`onVolumeChanged`, `onMutedChanged`) | ícone + barra que enche por mola + número |
| Brilho | `Connections` em `Brightness` (`onBrightnessChanged`) | igual ao volume |
| Música nova | `onCurrentTrackChanged` (título do `MprisController` mudou e está tocando) | capa + título + artista |
| Print | `Process` com `wl-paste --watch`: a cada mudança da área de transferência, confere se é imagem | "Print copiado" |
| Celular fraco | `phoneLow`: `Battery` (KDE Connect) ≤ 20% e sem carregar | ícone vermelho + "Celular com N%" |

O OSD do ii (o aviso de volume e brilho) foi desligado na família (seção 9), porque a ilha faz esse papel. O `wl-paste --watch` só roda o teste quando a área de transferência muda; parado, não gasta nada. Uma imagem copiada do navegador também conta como "print".

### 5.10 A bolha de notificação com "goo"
Quando chega notificação, uma bolha **sai de baixo da ilha** e, enquanto está perto, um **pescoço líquido** liga as duas. Ideia do `IsleDrip` do hyprdots.
- `life` (`MosaicSpring`, response 0,72, damping 0,96) vai de 0 (escondida) a 1 (fora). Para fechar, ela desliza rápido (`springBack: false`, 420 ms).
- A bolha nasce como uma faixa fina com 42% da largura da ilha, 16 px **acima** da borda de baixo (escondida atrás da ilha). Com `life`, ela vira o cartão (440 de largura, altura das notificações) 12 px abaixo:
  ```qml
  readonly property real bw: mix(isleW * 0.42, cardW, g)
  readonly property real bh: mix(18, shownH, g)
  readonly property real by: mix(base - 16, base + 12, g)
  ```
- **O shader `shaders/goo.frag`** desenha três formas como SDF: a ilha (a pílula como está agora, com a escala), uma tirinha (`twin`) sob o meio da ilha e a bolha. Ele junta a tirinha e a bolha com `smin` de raio 22 (`fuse`). Como a distância entre elas (12 px) é menor que 22, forma-se o pescoço. Depois junta isso à ilha com um `smin` pequeno (10), que arredonda o encontro. O contorno de 1 px é desenhado no contorno da forma inteira, pescoço incluído.
- **A conta do `smin` circular:** `max(k, min(a, b)) - length(max(vec2(k) - vec2(a, b), 0))`. Longe das duas formas é igual a `min(a, b)` (a união normal); só onde as duas estão a menos de `k` a borda vira um arco de círculo que encosta nas duas.
- O conteúdo é o `NotificationListView` do ii, em largura cheia, dentro de um `Item` com `clip` do tamanho da bolha. A bolha "revela" as notificações enquanto cresce, sem refazer o layout a cada quadro. A opacidade é `g²` (aparece no fim).
- A bússola tem prioridade: ao abrir, `life.settle(0)` some com a bolha na hora.
- A bolha fica **atrás** da ilha (`z: -1`). Por cima, o preenchimento dela apagava a marca e a hora.

### 5.11 `MosaicSpring.qml`: a mola
Port do `MorphSpring` do hyprdots, no mesmo modelo das molas do SwiftUI:
- `response`: mais ou menos quantos segundos dura uma oscilação;
- `damping`: 1 para sem passar do ponto; menos que 1 passa e volta.

A cada quadro (`FrameAnimation`), ela calcula:
```js
const w = 2 * Math.PI / response;            // frequência
a = -w*w * (value - target) - 2*damping*w * velocity;   // força da mola + atrito
velocity += a * h;  value += velocity * h;   // em passos de 4 ms
```
- O quadro é dividido em passos de 4 ms, para um quadro lento não "explodir" a conta.
- Quando chega perto o bastante e devagar o bastante, ela **para sozinha** (`running = false`), e nada roda com a ilha parada.
- `springBack: false` faz a descida ser um deslize suave (`closeMs`), sem quicar.
- `settle(v)` pula direto para `v`. Ela nunca mexe em `target`, para não quebrar o binding (foi um bug na primeira versão).

---

## 6. A bússola
Arquivo: `modules/mosaic/island/Compass.qml`. Preenche a ilha no modo bússola.
- `current` é a área atual (`HyprlandData.activeWorkspace.id`). `offset` segue `current` com `Behavior` `OutBack` de 420 ms: é a posição animada da bússola.
- **O arco:** 13 blocos (`Repeater`), um para cada área de `round(offset)-6` até `+6`. O ângulo de cada um:
  ```js
  angle = (90 - delta * stepAngle) * π / 180      // delta = área - offset; stepAngle = 16°
  x = centro + cos(angle) * ringRadiusX;  y = sin(angle) * ringRadiusY
  ```
  - `ringRadiusX` é diferente de `ringRadiusY`, por isso o arco é oval, como a ilha.
  - Como `delta` depende de `offset`, que está animado, **todos os blocos deslizam juntos pelo arco** quando a área muda.
- **Tamanho e cor:** a atual tem 38 px e cor forte; com janelas, 30 px; vazia, 20 px. O tom é `toneFor(id)` (sempre o mesmo para o mesmo número).
- **Cascata:** `myReveal = reveal·2,2 − |delta|·0,22`. O do meio aparece primeiro e os de fora depois.
- **Ícone:** `HyprlandData.biggestWindowForWorkspace(id)` → `AppSearch.guessIcon` → `IconImage`, mais "+N" quando há mais janelas.
- **Scroll:** o `WheelHandler` acumula `angleDelta`; a cada 60 troca uma área (`hl.dsp.focus({ workspace = N })`). Clicar num bloco vai até ele.

---

## 7. O mascote
Arquivo: `modules/mosaic/island/Mascot.qml`. Os quatro blocos do **logo do Mosaic OS** (`Repeater` de 4 `Rectangle`) nos tons primária, secundária, terciária e texto:
- numa grade de 88 unidades: quadrado grande 56×56, barra alta 24×56, barra larga 56×24 e quadradinho 24×24, com 8 de espaço;
- `slots` guarda `[x, y, largura, altura]` de cada lugar, e `unit = size / 88` converte em pixels;
- cada bloco lê o seu lugar (`g = slots[slot]`).
- **`mood`** = `dizzy` ou `baseMood` (`idle`, `dance`, `think`).
- **`jump()`:** `SequentialAnimation` em `body.y`, sobe 45% do tamanho (160 ms `OutQuad`) e desce com `OutBounce` (420 ms).
- **dance:** cada bloco tem uma animação infinita de `danceOffset` com um atraso diferente (`PauseAnimation`), formando um equalizador.
- **think:** um `Timer` incrementa `turn`, e cada bloco anda uma casa no sentido horário (`slot`). Ao chegar, toma o **tamanho** do lugar (o quadradinho vira barra, a barra vira quadrado grande...), com `Behavior` `OutBack` em `x`, largura e altura.
- **poke():** 5 cutucadas em 1,2 s deixam o mascote tonto por 1,8 s (gira ±14°).
- **Piscar:** um `Timer` aleatório de 3,5 a 7 s. Os olhos estão desligados (`showFace: false`) na ilha e no dock.

---

## 8. O dock
Arquivo: `modules/mosaic/dock/MosaicDock.qml`. Substitui a barra e o dock do ii.

### 8.1 Mostrar e esconder
```qml
exclusiveZone: 0                                   // flutua por cima, não come espaço
readonly property bool emptyWorkspace: !HyprlandData.windowList.some(w => w.workspace.id === win.workspaceId)
readonly property bool shown: emptyWorkspace || hovering
```
- O dock está sempre na janela; esconder é um `Translate` que o desce para fora da tela (`OutBack`, 380 ms).
- **Área de ativação (`hitArea`, usada como `mask`):**
  - escondido: uma faixa de 10 px na borda, 160 px mais larga que o dock;
  - aberto: cobre o dock inteiro **até a borda**.

  Antes havia um buraco de 8 px entre o dock e a borda. O mouse caía nele, o dock fechava e reabria, e ficava piscando.
- `HoverHandler` + `leaveTimer` (400 ms): só esconde depois que o mouse sai de verdade.
- **Lição aprendida:** a janela precisa de `color: "transparent"`. Sem isso, o fundo padrão branco aparece (foi a "barra branca").

### 8.2 Os três blocos
1. **Marca:** um `Mascot` num `Block` primária→secundária. O clique abre a visão geral do ii (`GlobalStates.overviewOpen`) e faz o mascote pular; o botão direito abre a lateral esquerda.
2. **Apps:** um `Repeater` sobre `ScriptModel { objectProp: "appId"; values: TaskbarApps.apps }`. O `objectProp` faz o QML reaproveitar o mesmo item para o mesmo app quando a lista muda, em vez de recriar todos. Cada app tem:
   - **hover:** `scale` 1 → 1,22 com `OutBack` (overshoot 2). A primeira versão seguia a posição do mouse com `SpringAnimation`; a animação reiniciava a cada pixel e travava. Agora é só um estado (mouse em cima ou não);
   - **ativo:** um bloco `softBlock(tom)` atrás do ícone, com tom `toneFor(index)`;
   - **pontinhos:** um por janela, até 3; o do app ativo é mais largo;
   - **abrindo:** `launchBounce`, 3 pulos;
   - **cliques:** o esquerdo abre ou alterna as janelas, o do meio abre outra, o direito fixa ou desafixa (`TaskbarApps.togglePin`);
   - `StyledToolTip` com o nome.
3. **Status:** `Bar.SysTray` do ii (`invertSide: true` abre os menus para cima), ícones de rede, Bluetooth, volume e Não perturbe, e hora/data. O clique abre a lateral direita, e o `onWheel` muda o volume.

---

### 8.3 Ícones que o Matugen repinta
O Matugen repinta dois ícones com as cores do papel de parede: o do Mosaic Store (`mosaic-store --icone`) e o do Neovim (`nvim-matugen`), em `~/.local/share/icons/hicolor/scalable/apps/`. O Qt guarda ícones em **cache**, então o arquivo novo só aparecia reiniciando o shell, e daí vinha a gambiarra de reiniciar a cada papel de parede.
- Para esses ícones (`liveIcons`), o dock carrega o arquivo direto, com `?v=N` no fim do endereço (`iconSource(nome)`). Os outros continuam pelo tema de ícones.
- Um `FileView` com `watchChanges` vigia cada arquivo. Quando muda, `N` sobe, o endereço fica diferente e o Qt lê o arquivo de novo.
- `iconVersions` é trocado por um **objeto novo** (`Object.assign({}, ...)`). Mudar uma chave dentro do mesmo objeto não avisa os bindings.

## 9. O que mudou no ii
Arquivos herdados que foram alterados (o resto é igual ao ii):
- `panelFamilies/IllogicalImpulseFamily.qml`:
  - comentados: `Bar`, `Dock`, `VerticalBar`, `NotificationPopup`, `OnScreenDisplay` (volume/brilho foram para a ilha) e `WallpaperSelector` do ii;
  - adicionados: `Island`, `MosaicDock` e `MosaicWallpapers`.
- `hypr/mosaic.lua`: a camada `quickshell:mosaicWallpapers` (o cartão do seletor) ganhou o liquid glass.

Arquivos do sistema, fora do projeto:
- `~/.config/hypr/custom/env.lua`: lê o shell salvo (seção 3);
- `~/.config/hypr/hyprland/variables.lua`: só um comentário;
- `~/.config/fish/functions/qsr.fish`: reinicia o shell salvo;
- `~/.config/matugen/config.toml`: o hook não reinicia mais o Quickshell.
- `modules/common/Directories.qml`: as configurações ficam em `~/.config/mosaic-os`.
- `modules/common/widgets/NotificationListView.qml`: propriedade `expandAll`.
- `modules/ii/bar/BarContent.qml`: sem `UtilButtons` e bateria, que foram para a ilha (a barra nem carrega mais).
- `modules/ii/bar/LedPopup.qml`: `atTop` e `edgeMargin`, para abrir embaixo da ilha.

---

## 10. Como testar
- **Reiniciar o shell:** `pkill -x qs; hyprctl dispatch 'hl.dsp.exec_cmd("qs -c mosaic")'`. O hot reload trava por causa do Qt 6.11 × 6.12.
- **Erros:** `qs -c mosaic log | grep mosaic/`.
- **Hyprland aninhado (sem mexer na sessão):** `Hyprland -c arquivo.lua` abre um Hyprland dentro de uma janela. Rodar `WAYLAND_DISPLAY=wayland-N HYPRLAND_INSTANCE_SIGNATURE=... qs -c mosaic` dentro dele, controlar com `qs ipc --pid PID call island compass` e fotografar com `WAYLAND_DISPLAY=wayland-N grim`. A janela do aninhado precisa estar visível, senão ele para de desenhar.
- **Memória:** `ps -o rss= -p $(pgrep -x qs)` antes e depois.
- **Pegadinha do aninhado:** o primeiro `qs` que liga fica com o servidor de notificações e com o polkit. Se o de teste ligar antes do seu, as notificações vão para ele. Por isso, teste notificação na sessão de verdade, ou ligue o de teste depois.
- **Shaders:** depois de mexer num `.frag`, recompile com o comando escrito no topo dele (`/usr/lib/qt6/bin/qsb ...`); o QML carrega o `.qsb`.

---

## 11. Papéis de parede e o derramar
Arquivo: `modules/mosaic/wallpapers/MosaicWallpapers.qml`, mais o script `scripts/wallpaper-index.sh` e o shader `shaders/pour.frag`. Ele substitui o seletor do ii com os **mesmos atalhos**: `wallpaperSelectorToggle`, `wallpaperSelectorRandom` e a IPC `wallpaperSelector toggle|random`. Layout e efeito vieram do hyprdots, no estilo Mosaic.

### 11.1 Lendo a pasta
- A pasta é a do papel de parede atual (`Config.options.background.wallpaperPath`).
- Ao abrir, o `Process` `lister` roda um `find` e lista as imagens. Depois o `indexer` roda `wallpaper-index.sh`, que para **cada imagem nova**:
  - cria a miniatura de 480×300 com o `vipsthumbnail` (rápido), ou com o `magick` se ele faltar;
  - tira a cor média, reduzindo a imagem a **1 pixel** com o `magick` (`-resize 1x1!`).

  Tudo fica em `~/.cache/mosaic-os/wallpapers`. Imagens já vistas vêm do cache, e o script roda com `nice -n 19` (prioridade mínima).
- `colors.tsv` (nome → cor) é lido por um `FileView`. `hueOf(hex)` converte a cor em família: cinza se tiver pouca saturação, senão pela matiz (vermelho < 15°, laranja < 45°...).
- O histórico (`history`) ganha uma linha a cada papel aplicado; "Recentes" lê de trás para frente, sem repetir.

### 11.2 A janela
- `LazyLoader`: a janela só existe aberta (ou enquanto fecha). Uma `PanelWindow` na tela inteira, camada Overlay, com teclado exclusivo.
- O fundo escurece com opacidade 0,25, **abaixo do limite de 0,3 do hyprglass**. Assim só o cartão vira vidro. Clicar no fundo fecha.
- O cartão abre por `openSpring` (escala 0,94 → 1 e opacidade) e fecha deslizando em 200 ms.
- **Coluna esquerda:**
  - a marca e o contador (`mostrados / total`);
  - o nome e a cor do selecionado;
  - a busca (um `TextInput`, que também dirige a grade pelo teclado);
  - os filtros: Todos, Recentes e 8 blocos de cor;
  - os botões Aplicar e Aleatório (`PickerButton`, com pulinho no clique).
- **Grade (`GridView`, 3 colunas, 16:10):** cada miniatura entra em **cascata**: um `Timer` de `60 + min(índice, 12) × 28` ms liga `born`, que anima opacidade, escala e um deslize de 18 px com `OutBack`. O mouse em cima seleciona, e uma mola (`lift`) cresce 3,5% e mostra o nome. A borda na cor de destaque marca a seleção, e um ✓ marca o papel em uso.
- **Teclado:** setas movem (`grid.columns` por linha), Enter aplica, Tab e Shift+Tab trocam o filtro, Esc fecha.

### 11.3 O derramar (`pour`)
1. `apply(path, item)` pega o centro da miniatura clicada em coordenadas de tela (`mapToItem(null, ...)`), fecha o seletor e chama `pour()`.
2. Uma `PanelWindow` por monitor na camada **Bottom** (acima do papel de parede, abaixo das janelas, sem receber cliques) carrega a imagem nova. Quando ela está pronta, `pourRun` leva `pourProgress` de 0 a 1 em 1,7 s.
3. **O shader `pour.frag`**, para cada pixel:
   - mede a distância `r` até o ponto de origem (`sink`);
   - calcula o raio da poça, `R = (1 - (1-e)^1.7) · rmax`: começa rápido e freia;
   - soma uma **ondulação** na borda (`sin(ângulo·5 + e·7)` mais `sin(ângulo·9 - e·11)`, mais forte no meio do caminho);
   - perto da borda, **desloca a imagem para fora** (refração), com ondinhas;
   - desenha um **menisco**, a linha clara da borda, iluminada de cima à esquerda e tingida com a cor de destaque;
   - fora da poça, um brilho fraco enquanto ela se move.
4. No fim, `commit()` chama `Wallpapers.select(path)`, o script do ii que troca o papel de verdade e roda o Matugen (cores novas), e grava o histórico.
5. Quando o `wallpaperPath` da configuração muda para o novo, espera 0,9 s (o fundo carregar), apaga a poça em 320 ms e destrói as janelas. Há proteções: se a imagem não carregar em 2,5 s, aplica direto; se o fundo não confirmar em 8 s, apaga a poça assim mesmo.
- Nos outros monitores, a poça começa do meio do topo.
- **Aleatório:** sorteia um papel diferente do atual e derrama a partir do centro.


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
12. [Temas: `modules/common/MosaicTheme.qml`](#12-temas-modulescommonmosaicthemeqml-themes)
13. [As laterais: `modules/mosaic/sidebars/`](#13-as-laterais-modulesmosaicsidebars)

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
- **Tamanhos:** repouso = a linha "marca · hora · clima" + 24 px, com 30 de altura; evento = o conteúdo + 64 (38 de altura; 48 para música e bateria; 58 para ligação); bússola 340×112; painel 460 e altura do conteúdo (até 640).
- **Molas no lugar de `Behavior`:** `targetWidth`/`targetHeight` dizem o tamanho certo, e a largura e a altura **seguem** esses alvos por `MosaicSpring` (`widthSpring`, `heightSpring`, damping ~0,75: passa um pouco e volta). O mesmo para `morphSpring` (0 = ilha, 1 = bússola) e `centerSpring` (0 = marca à esquerda, 1 = marca no meio).
- **Gelatina (jelly):** a velocidade das molas vira deformação:
  ```qml
  readonly property real rush: widthSpring.velocity / 420 + heightSpring.velocity / 420 + morphSpring.velocity * 0.16
  readonly property real jelly: Math.max(-0.07, Math.min(0.07, rush * 0.052))
  // xScale = 1 + jelly, yScale = 1 - jelly * 0.62
  ```
  Crescendo rápido, a ilha estica para os lados e achata; freando, faz o contrário. Ao parar, a velocidade é 0 e ela volta ao normal. O limite de 7% evita exageros.
- **Toque:** mais três molas multiplicam a escala: `hoverSpring` (+2,8% com o mouse em cima), `pressSpring` (−3,5% apertando) e `peekSpring` (+4% por 90 ms a cada evento, o "pulinho"). O `Scale` tem origem no **meio do topo**, então ela cresce para baixo e para os lados, sem descolar da borda.
- **Tela cheia:** `fullscreenHere` procura em `HyprlandData.windowList` uma janela da área atual desse monitor com `fullscreen >= 2`. No Hyprland, 1 é **maximizada** e 2 é tela cheia de verdade; com `> 0`, a ilha sumia a cada janela maximizada. Se achar e a ilha estiver em repouso, `hideY` a sobe para fora da tela (300 ms `OutCubic`).

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
  - na bússola, o de baixo vira metade da largura e a forma é montada mais alta e achatada para 112 px: uma **cúpula** com a base em meio oval.
- A cor é o degradê das três cores de `washStop` (10% dos tons sobre a base escura, 16% na bússola), com contorno de 1 px.
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
- **Linha de repouso (`restRow`):** a hora (Space Grotesk 14, negrito) e, à direita, um `Loader` (`rightSlot`) que escolhe, nesta ordem:
  - **gravando:** um ponto vermelho que respira e o tempo correndo (`recSlot`);
  - **música tocando:** quatro barrinhas pulando, cada uma no seu ritmo (`playingSlot`);
  - **senão:** o clima (`weatherSlot`).

  `fullWidth` soma o espaço da marca e o que estiver à direita, então a ilha se ajusta em volta. A linha some (opacidade) fora do repouso.
- **Capa da música:** em repouso, com música tocando e capa disponível (`showCover`), a marca encolhe e some, e a capa (18 px, cantos do tema) aparece no lugar dela com um pulinho.
- **Gravação:** `recording` é "o `wf-recorder` está rodando", conferido a cada 1,5 s (`pgrep`), então vale para gravações começadas por qualquer lugar (botão, atalhos do ii). O relógio vem de `ps -o etimes`, há quantos segundos o processo roda, e fica certo mesmo que a gravação tenha começado antes de a ilha perceber.
- **O botão Gravar** (no lugar do Print) grava **a tela inteira** do monitor em foco, com som (`record.sh --fullscreen --sound`). Gravando, ele mesmo vira o indicador: fica **vermelho** com o ícone de parar, um **anel vermelho pulsa** em volta e o **tempo** aparece embaixo, no lugar do nome. Clicar de novo para (`pkill -INT wf-recorder`, que fecha o arquivo direito), e a ilha confere 0,7 s depois para mostrar a mudança na hora. `QuickTool` ganhou `alert` para esse visual.
- **Bandeja:** o `SysTray` do ii fica **no bloco da hora, do lado direito**, só com o painel aberto (`invertSide: false`: menus para baixo). Ele só aparece se algum app tiver ícone de bandeja (`SystemTray.items`). Enquanto um menu dela está aberto (`trayBusy`), o clique-fora e a saída do mouse não fecham o painel; senão, clicar no menu fecharia tudo.
- **Bateria do celular:** só aparece com um número de verdade (o KDE Connect dá `NaN` com o celular longe).
- **Linha de evento (`eventLoader`):** um `Loader` que escolhe o conteúdo pelo tipo de evento (5.9).
- **Painel:** um `Loader` só fica ativo no modo `panel`. Fechado, o conteúdo é **destruído** e não gasta nada.
- **panelView** (`ColumnLayout`):
  1. hora e data (bloco primária→secundária) + clima (secundária→terciária, `Weather.data`, `Icons.getWeatherIcon`);
  2. música (terciária→primária, só se `hasPlayer`), com anterior/tocar/próxima via `MprisController`;
  3. ferramentas (`QuickTool`, com clique direito via `altClicked`): Gravar, Cor (hyprpicker), Silêncio (`Notifications.silent`), LED (abre o `LedPopup` do ii) e a bateria do celular (KDE Connect);
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
| Celular fraco | `phoneLow`: celular ≤ 20% e fora da tomada (`PhoneLink`) | bateria d'água respirando em vermelho |
| Celular carregando | `PhoneLink.chargingStarted` | bateria d'água com bolhas, brilho, raio pulsando, faíscas e a % contando |
| Ligação tocando | `PhoneLink.call("ringing")` | inicial do contato num círculo que pulsa, dois anéis saindo, nome e número, botão de silenciar |
| Atendida / perdida | `call("talking")` / `call("missedCall")` | o mesmo cartão, sem anéis (vermelho se perdida) |
| Celular conectou / saiu | `PhoneLink.connected` / `disconnected` | ícone do celular com um anel saindo |

Cada tipo tem seu tempo (`showEvent`): a ligação tocando fica até ser atendida ou perdida (no máximo 45 s). Para ver sem o celular: `qs -c mosaic ipc call island phoneTest charging|low|ringing|talking|missed|connected|disconnected`.

O OSD do ii (o aviso de volume e brilho) foi desligado na família (seção 9), porque a ilha faz esse papel.

### 5.9.1 O celular: `PhoneLink.qml`, `PhoneBattery.qml`, `Sparks.qml`
- **`PhoneLink`** fala com o KDE Connect. Ao ligar, pergunta uma vez o nome, se está conectado e a bateria (`qdbus`). Depois só **escuta** os sinais que o KDE Connect já manda no D-Bus, com um `dbus-monitor`:
  - `org.kde.kdeconnect.device.battery`: `refreshed(isCharging, charge)`;
  - `org.kde.kdeconnect.device.telephony`: `callReceived(event, number, contactName)`, com `event` = `ringing`, `talking` ou `missedCall`;
  - `org.kde.kdeconnect.device`: `reachableChanged(reachable)`.

  Parado, não gasta nada (o serviço `Battery` do ii pergunta a cada 3 s). Os nomes dos sinais foram tirados do próprio plugin (`strings kdeconnect_telephony.so`).
- **Lendo o `dbus-monitor`:** ele escreve uma linha de cabeçalho por sinal (`signal ... path=.../devices/ID/telephony; ... member=callReceived`) e depois uma linha por argumento (`string "ringing"`). O `SplitParser` guarda o `member` do cabeçalho, se for do nosso celular, junta os argumentos e, quando tem todos, chama `handle()`.
- **Silenciar:** `sendMutePacket` no `telephony`. É a única ação de ligação que o KDE Connect oferece; atender ou recusar não dá.
- **`PhoneBattery`** (port do `IslandBattery` do hyprdots):
  - a água é um `Canvas`: enche da esquerda, com a borda direita numa senoide que anda (`FrameAnimation`, só enquanto aparece);
  - carregando, 5 bolhas sobem uma depois da outra, um brilho inclinado varre a bateria a cada ~2 s e o raio pulsa;
  - fraca, a bateria "respira" (opacidade).
- **`Sparks`** (port do `IslandBurst`): 12 faíscas saem de um ponto, cada uma com ângulo e alcance um pouco embaralhados, e somem diminuindo.
- **Processos que morrem com o shell:** o `dbus-monitor` e o `wl-paste --watch` rodam via `setpriv --pdeathsig TERM`. Sem isso, cada reinício do shell deixava um deles vivo; chegaram a ser 14 `wl-paste` esquecidos. O `wl-paste --watch` só roda o teste quando a área de transferência muda; parado, não gasta nada. Uma imagem copiada do navegador também conta como "print".

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
- **Depois de cair, ela se funde à ilha:** quando `life` passa de 0,9, a mola `merge` vai a 1. A bolha sobe 14 px até encostar, a tirinha (`twin`) alarga até a largura da ilha e o `fuse` cresce de 22 para 32. A ilha e o cartão viram **uma forma só**, com curvas suaves onde se encontram.
- A bússola tem prioridade: ao abrir, `life.settle(0)` some com a bolha na hora.
- A bolha fica **atrás** da ilha (`z: -1`). Por cima, o preenchimento dela apagava a marca e a hora.

### 5.10.1 O menu iniciar (`StartMenu.qml`, `RecentApps.qml`)
Tocar o Super abre o menu **na mesma bolha** da notificação: ele cai de baixo da ilha e se funde a ela, com 640 de largura (a janela da ilha passou a ter 680).
- **O gatilho:** os atalhos de busca do ii agora ligam `GlobalStates.searchOpen` em vez de abrir a visão geral do ii. Isso foi feito no `modules/ii/overview/Overview.qml` do Mosaic OS e vale para: Super solto, `searchToggle`, a IPC `search toggle|open|close`, Super+V (área de transferência) e Super+. (emojis). Super+Tab continua abrindo a visão geral das áreas do ii. Segurar o Super ainda abre a bússola: o `superHold` zera `superReleaseMightTrigger`, então soltar não abre o menu.
- **Na ilha:** `menuScreen` guarda o monitor em foco quando abre, e `menuHere` diz se é esse monitor. Com o menu aberto, a bolha mostra o `StartMenu` (num `Loader`) em vez das notificações, e a janela pega o teclado (`WlrKeyboardFocus.Exclusive`).
- **Clique fora fecha**, mas a captura (`HyprlandFocusGrab`) só liga **300 ms depois** de abrir (`menuGrab`). Ligada na hora, ela disparava antes de o cartão existir e fechava o menu no mesmo instante.
- **A busca é toda do ii:** o `LauncherSearch` recebe o texto (`query`) e devolve `results`. Cada resultado tem `name`, `type`, `verb`, `iconName` e `iconType` (ícone do sistema, símbolo Material ou texto/emoji), `execute()` e `actions` (ações extras do app, copiar/apagar na área de transferência). Então estão todos os recursos do menu do ii: apps, conta (`=`), comando (`$`), web (`?`), área de transferência (`;`), emojis (`:`) e ações (`/`).
- **Vazio:** um chip por prefixo (clicar digita o prefixo; eles surgem em cascata) e a grade de **Recentes**.
- **Buscando:** uma lista de até 7 linhas. As linhas entram deslizando uma depois da outra. A linha escolhida tem um bloco que **desliza por mola** até ela (`selSpring`) e mostra o verbo ("Abrir ↵") e as ações extras.
- **Teclado:** digitar busca, ↑↓ escolhem, Enter executa, Esc fecha.
- **`RecentApps`:** guarda os últimos 8 apps em `~/.cache/mosaic-os/recent-apps.json`. Conta como usado:
  - o app aberto pelo menu;
  - qualquer app cuja **janela nova** apareça (`ToplevelManager.toplevels`). Só a diferença em relação à lista anterior é olhada, e as janelas que já estavam abertas ao ligar não contam.
- **Testar sem teclado:** `qs -c mosaic ipc call island menuSearch "fire"` abre o menu já com o texto. A caixa de busca acompanha mudanças do `query` vindas de fora.
- A marca do dock também abre o menu.

### 5.10.2 As notas (`Notes.qml`)
Abrem no **mesmo cartão** do menu, fundido à ilha (560 de largura). Dá para abrir pelo botão **Notas** das ferramentas do painel, por **Super+Alt+N** (o bind fica em `hypr/mosaic.lua`, que só carrega com o Mosaic OS ligado) ou pela IPC `island notes`.
- **Cada aba é um arquivo `.md`** em `~/Documentos/Notas`, então elas abrem em qualquer lugar, inclusive no Neovim. Na primeira vez, a pasta é criada com uma `Notas.md`.
- As abas vêm de um `FolderListModel` (só `*.md`, por nome), que se atualiza sozinho quando arquivos entram ou saem da pasta.
  - **+** cria `Nota N.md`;
  - **duplo clique** renomeia (`mv -n`, que não sobrescreve outro arquivo);
  - o **×** da aba atual apaga, com confirmação (o primeiro clique deixa vermelho, o segundo manda para a **lixeira** com `gio trash`).
- **Escrever:** é texto simples, num `TextArea`.
  - `* ` no começo da linha vira `• ` na hora (em `onTextChanged`, olhando o trecho entre o começo da linha e o cursor);
  - Enter numa linha com bolinha começa outra com o mesmo recuo; Enter numa bolinha vazia encerra a lista.
  - O arquivo guarda `* ` (Markdown normal): `toScreen` e `toFile` trocam `* ` ↔ `• ` com uma expressão regular por linha (`/^(\s*)\* /gm`).
- **Salvar:** sozinho, 600 ms depois da última tecla (`saveLater`). `flush()` salva na hora antes de trocar de aba, criar uma nova ou fechar.
- **Edição por fora** (Neovim) aparece no editor: o `FileView` vigia o arquivo (`watchChanges`).
- Menu, notas e notificação dividem o cartão, nesta prioridade: menu > notas > notificações. Abrir um fecha o outro, e os dois pegam o teclado (`cardHere`). Esc ou clique fora fecham.

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
Arquivo: `modules/mosaic/island/Compass.qml`. No modo bússola, a ilha vira uma **cúpula pequena e discreta** (340×112, base em meio oval; seção 5.5). A marca Mosaic fica **em cima, no meio**, como ponteiro, e gira um quarto por área. Por um dia ela foi uma pílula em carrossel, mas o usuário preferiu a cúpula, só que mais sutil.
- `current` é a área atual (`HyprlandData.activeWorkspace.id`). `offset` segue `current` com `Behavior` `OutBack` de 420 ms: é a posição animada da bússola.
- **O arco:** 13 blocos (`Repeater`), um para cada área de `round(offset) - 6` até `+6`. O ângulo de cada um:
  ```js
  angle = (90 - delta * stepAngle) * π / 180      // delta = área - offset; stepAngle = 24°
  x = centro + cos(angle) * ringRadiusX;  y = sin(angle) * ringRadiusY
  ```
  - `ringRadiusX` (metade da largura − 30) é diferente de `ringRadiusY` (altura − 26), por isso o arco é oval, como a cúpula. Os recuos são do tamanho de meio bloco, então os blocos ficam dentro da borda.
  - **Nada vaza:** só ângulos entre 18° e 162° ficam dentro da cúpula. Passando disso, um bloco sairia pelos cantos de cima. `maxDelta = (90 − 18) / 24 = 3` áreas de cada lado aparecem inteiras, e a quarta some (opacidade) enquanto sai.
  - Como `delta` depende de `offset`, que está animado, **todos os blocos deslizam juntos pelo arco** quando a área muda.
- **Sutil:**
  - blocos: a atual tem 34 px, com janelas 28 e vazia 16 (só o bloquinho, sem número); o ícone ocupa 66% do bloco;
  - cores suaves misturadas à base escura da ilha (atual 70% do tom, com janelas 38%, vazia 18%), e só a atual tem contorno de 1 px;
  - o número da área atual fica pequeno (JetBrains Mono 13) sob a marca;
  - o banho de cor da cúpula subiu só 6% em relação à ilha fechada;
  - a marca cresce pouco (de 16 para 20 px).
- **Cascata:** `myReveal = reveal·2,2 − |delta|·0,22`. O do meio aparece primeiro e os de fora depois.
- **Janelas por área:** `windowsByWs` monta o mapa área → janelas **uma vez** por mudança, em vez de cada bloco filtrar a lista inteira. O ícone vem de `HyprlandData.biggestWindowForWorkspace(id)` → `AppSearch.guessIcon` → `IconImage`, com "+N" quando há mais janelas.
- **Scroll:** o `WheelHandler` acumula `angleDelta`; a cada 60 troca uma área (`hl.dsp.focus({ workspace = N })`). Clique num bloco vai até ele.

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
Arquivo: `modules/mosaic/dock/MosaicDock.qml`. Uma placa de **vidro claro** flutuando embaixo, com os ícones "pousados" nela. Da esquerda para a direita: a marca, os apps e o status. O relógio fica na ilha, e a bandeja também (no bloco da hora do painel, seção 5.7).

### 8.1 Mostrar e esconder
```qml
exclusiveZone: 0                                   // flutua por cima, não come espaço
readonly property bool emptyWorkspace: !HyprlandData.windowList.some(w => w.workspace.id === win.workspaceId)
readonly property bool shown: emptyWorkspace || hovering
```
- Esconder é um `Translate` para baixo, guiado por `showSpring` (`MosaicSpring`): sobe com uma molinha e desce.
- **Área de ativação (`hitArea`, usada como `mask`):**
  - escondido: uma faixa de 10 px na borda, 160 px mais larga que o dock;
  - aberto: cobre o dock inteiro **até a borda**. Antes havia um buraco de 8 px entre o dock e a borda: o mouse caía nele, o dock fechava e reabria, e ficava piscando.
- `HoverHandler` + `leaveTimer` (400 ms): só esconde depois que o mouse sai de verdade.
- **Lição aprendida:** a janela precisa de `color: "transparent"`. Sem isso, o fundo padrão branco aparece (foi a "barra branca").

### 8.2 O vidro e as três partes
- **O vidro:** `glassFill` é uma película fina (padrão: 25% de opacidade, sem escurecer; ajustável na aba Dock); quem faz o efeito é o liquid glass **bem forte** do preset `dock` em `hypr/mosaic.lua` (refração 4,8, lente 1,35, arco-íris 1,9, brilho 4,2; `mask_threshold` 0,12 para o vidro aparecer mesmo com a película fina). O brilho branco que ficava no topo foi removido: sobre o vidro escuro ele parecia uma **barra cinza**. (Antes: Fica acima de 0,3, o limite do hyprglass, então o liquid glass entorta o que está atrás. O contorno é branco a 16%, e um degradê branco de 10% → 0 na metade de cima imita a luz batendo por cima. Raio 20, altura 58.
- **Marca:** o `Mascot` (logo novo) sem bloco atrás. O clique abre o menu iniciar (5.10.1) e o mascote pula; o botão direito abre a lateral esquerda.
- **Apps:** um `Repeater` sobre `ScriptModel { objectProp: "appId"; values: TaskbarApps.apps }`. O `objectProp` reaproveita o item de cada app quando a lista muda. Cada app:
  - **pontinhos:** um por janela, até 3; os do app em foco são mais longos e na cor de destaque;
  - **abrindo:** `launchBounce`, 3 pulos;
  - **cliques:** o esquerdo abre ou alterna as janelas, o do meio abre outra, o direito fixa ou desafixa (`TaskbarApps.togglePin`);
  - nome no hover (`StyledToolTip`).
- **Status:** Não perturbe (quando ligado), rede, Bluetooth e volume, com um fundinho claro no hover. O clique abre a lateral direita e o scroll muda o volume.
- As partes são separadas por `Divider`, um fio de luz de 1 px.

### 8.2.1 A onda (tipo macOS, sutil)
A primeira versão do hover travava: cada ícone tinha um `Behavior` com mola, e a animação **reiniciava a cada pixel** que o mouse andava. A onda nova usa **uma mola só**:
```qml
HoverHandler { id: appsHover; onHoveredChanged: if (hovered) pointer.settle(point.position.x) }
onPointerXChanged: if (appsHover.hovered) pointer.target = pointerX   // a mola persegue o mouse
MosaicSpring { id: pointer; response: 0.16; damping: 1 }               // sem passar do ponto
MosaicSpring { id: wave; target: appsHover.hovered ? 1 : 0 }           // liga e desliga o efeito
// em cada ícone:
readonly property real near: Math.exp(-d * d / 1.4) * wave.value      // d = distância em ícones
scale: 1 + 0.2 * near       // até 20% maior
y: -7 * near                // e sobe até 7 px
```
- Mudar o **alvo** de uma `MosaicSpring` não reinicia nada: ela só continua de onde está, com a velocidade que tem. Por isso não trava.
- A curva `exp(-d²/1,4)` é uma **curva de sino**: 1 bem embaixo do mouse, cerca de 0,5 a um ícone de distância e quase 0 a dois.
- O ícone cresce a partir de baixo (`transformOrigin: Item.Bottom`) e os ícones não mudam de largura. Assim, a posição deles não depende da onda e não há "briga" entre o mouse e o layout.

### 8.3 Ícones que o Matugen repinta
O Matugen repinta dois ícones com as cores do papel de parede: o do Mosaic Store (`mosaic-store --icone`) e o do Neovim (`nvim-matugen`), em `~/.local/share/icons/hicolor/scalable/apps/`. O Qt guarda ícones em **cache**, então o arquivo novo só aparecia reiniciando o shell, e daí vinha a gambiarra de reiniciar a cada papel de parede.
- Para esses ícones (`liveIcons`), o dock carrega o arquivo direto, com `?v=N` no fim do endereço (`iconSource(nome)`). Os outros continuam pelo tema de ícones.
- Um `FileView` com `watchChanges` vigia cada arquivo. Quando muda, `N` sobe, o endereço fica diferente e o Qt lê o arquivo de novo.
- `iconVersions` é trocado por um **objeto novo** (`Object.assign({}, ...)`). Mudar uma chave dentro do mesmo objeto não avisa os bindings.

## 9. O que mudou no ii
Arquivos herdados que foram alterados (o resto é igual ao ii):
- `panelFamilies/IllogicalImpulseFamily.qml`:
  - comentados: `Bar`, `Dock`, `VerticalBar`, `NotificationPopup`, `OnScreenDisplay` (volume/brilho foram para a ilha) e `WallpaperSelector` do ii;
  - adicionados: `Island`, `MosaicDock`, `MosaicWallpapers`, `MosaicSidebarLeft` e `MosaicSidebarRight` (as laterais do ii foram comentadas).
- `hypr/mosaic.lua`: a camada `quickshell:mosaicWallpapers` (o cartão do seletor) ganhou o liquid glass.

Arquivos do sistema, fora do projeto:
- `~/.config/hypr/custom/env.lua`: lê o shell salvo (seção 3);
- `~/.config/hypr/hyprland/variables.lua`: só um comentário;
- `~/.config/fish/functions/qsr.fish`: reinicia o shell salvo;
- `~/.config/matugen/config.toml`: o hook não reinicia mais o Quickshell.

Também no projeto: `services/Battery.qml` (o serviço do ii que foi adaptado para ler a bateria do **celular**) tinha a suspensão automática do ii ligada. Com o celular em 3% e fora da tomada, o **PC suspendia**. A suspensão foi desligada no Mosaic OS.
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
- **Nunca simule teclado ou mouse (`wtype`, `ydotool`) na sessão de verdade:** o foco pode estar em outro app. Um teste digitou no Neovim aberto, que salvou sozinho. Use o Hyprland de teste ou uma IPC de teste (`menuSearch`, `phoneTest`).
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

### 11.2.1 A aba Widgets
No topo da área da direita há duas abas: **Papéis** (a grade) e **Widgets**. A aba Widgets tem um cartão por widget da área de trabalho: relógio, calendário, clima, música, fotos, fotos 2 e dias juntos.
- Cada cartão liga e desliga `Config.options.background.widgets.<nome>.enable`. O fundo do ii mostra ou esconde o widget assim que o valor muda, e a configuração (`~/.config/mosaic-os/config.json`) guarda a escolha.
- O cartão inteiro é clicável. O interruptor desliza por mola (`MosaicSpring`) e, no tema brutal, tem a bolinha quadrada; o cartão ligado "levanta" sobre a sombra dura.
- Os cartões entram em cascata ao abrir a aba.
- IPC: `qs -c mosaic ipc call wallpaperSelector widgets` abre o seletor já na aba Widgets.

### 11.2.2 A aba Gravação
Configura a gravação de tela do botão **Gravar** da ilha: **Resolução** (Nativa, 1440p, 1080p, 720p), **Quadros por segundo** (30, 60, 120, 144) e **Som** (PC, Mic, Mudo). A pasta dos vídeos aparece embaixo.
- As escolhas vão para `Config.options.screenRecord.resolution` e `.fps` (campos novos no `Config.qml`).
- O `scripts/videos/record.sh` lê as duas com `jq` e passa ao `wf-recorder`:
  - `-r <fps>`, que fixa a taxa de quadros;
  - `-F scale=-2:<altura>`, um filtro do ffmpeg que muda a altura; o `-2` faz a largura seguir a proporção e ficar par, como o codificador exige.
  - Na Nativa, não há filtro.
  - **Som** (`screenRecord.audio`):
    - `system` grava o que a saída padrão está tocando: `$(pactl get-default-sink).monitor`;
    - `mic` grava a entrada padrão (`pactl get-default-source`);
    - `none` desliga o som mesmo quando a gravação pede `--sound`.

    O `record.sh` original juntava **todas** as fontes "monitor" do sistema (aqui eram três) e passava como um nome só, o que quebrava a gravação com som. Conferido com `ffprobe`: o vídeo sai com trilha `aac`.
- Valem a partir da próxima gravação. IPC: `qs -c mosaic ipc call wallpaperSelector recording` abre direto nessa aba.

### 11.2.3 As abas Aparência e Dock
- **Aparência** (antes "Ilha") é a configuração geral dos **widgets**: vale para a ilha, as duas laterais e os widgets do fundo (calendário, fotos e música). Fica em `Config.options.mosaicWidgets`. A **dock** continua separada, na aba Dock (`Config.options.mosaicDock`). Os valores antigos de `mosaicIsland` foram copiados para `mosaicWidgets` uma vez, à mão, no `config.json`.
- As duas abas usam a mesma página (`GlassPage`), com quatro controles (`TuneSlider`: o preenchimento segue o valor por mola; arrastar, clicar ou rolar muda):
  - **Potência do liquid glass** (0–200%, `glass`) e **Aberração cromática** (0–200%, `chroma`, as bordas de arco-íris) vão para o `MosaicGlass` (`modules/common/MosaicGlass.qml`). O hyprglass só aceita presets vindos da config do Hyprland, então o serviço:
    - grava `~/.config/mosaic-os/glass.lua` com dois presets: `widgets` (base: o "vivo") e `doca` (base: o vidro forte da dock). `presetLua()` recebe uma lista de camadas: o `widgets` vai na ilha (`quickshell:island`, limiar 0,05) e nas duas laterais (`quickshell:sidebarLeft/Right`, 0,3). Os widgets do fundo moram na camada do papel de parede, que não tem vidro. Cada valor é a base vezes a potência, com tetos; a aberração usa o próprio multiplicador. Potência 0 desliga o vidro dessas camadas;
    - roda `hyprctl reload config-only`; o `hypr/mosaic.lua` executa esse arquivo no fim, por cima dos presets padrão;
    - espera 700 ms depois da última mudança (`signature` junta os quatro valores), para arrastar um slider recarregar uma vez só;
    - ignora as mudanças dos primeiros 4 s, que são só os valores salvos carregando;
    - depois do reload, repinta as cores de um tema fixo, que o reload apaga.
  - **Transparência** (`opacity`, o inverso) e **Escuridão** (`darkness`) mudam na hora. `MosaicTheme.widgetFill(base)` puxa a cor para o preto (`base × (1 − escuridão)`) e usa a opacidade como alfa. É a cor das laterais e dos cartões do fundo; a ilha faz a mesma conta com `islandBase` e `islandAlpha`. Na dock, quem faz isso é o `glassFill`. Os temas brutais continuam com a placa sólida.
- **Granulado de filme** (só nos temas que têm, os `retro`, como o Horizonte): embaixo aparece o grupo "Granulado de filme", com um controle por parte, em duas colunas (0–200%, multiplicando o `MosaicTheme.grain` do tema):
  - Aparência: `grainIsland` (ilha e bolha), `grainSidebars` (as duas laterais), `grainDesktop` (cartões do fundo) e `grainPicker` (a própria janela de temas);
  - Dock: `grain`.

  O `MosaicTheme` já entrega cada valor pronto (`grainIsland`, `grainSidebars`... = grão do tema × controle), e cada `Grain`/shader lê o seu. Com o tema retrô a página fica mais apertada (espaçamento 10 em vez de 22) para caber o grupo.
- **Fica sem granulado:** o clima e os "dias juntos". São formas Material (pílula torta e flor), e o shader de granulado só recorta retângulos arredondados.
- **Pegadinha:** componentes declarados no fim do arquivo (`component X: ...`) não enxergam os ids da janela (`side`, `pageTabs`). Por isso o posicionamento da `GlassPage` fica onde ela é usada.
- IPC: `qs -c mosaic ipc call wallpaperSelector look|dock` (`island` continua funcionando e abre a Aparência).

### 11.2.4 A aba Apps (granulado em todos os apps)
O shell não consegue desenhar por cima das janelas dos outros apps. Quem faz isso é o **Hyprland**, com um **shader de tela** (`decoration.screen_shader`): um programa de GPU que roda sobre a imagem final de cada monitor. O serviço é o `modules/common/MosaicScreenGrain.qml`, e a configuração fica em `Config.options.mosaicApps`.
- **Quanto grão:** `grão do tema × grain` (0–200%). Só os temas retrô têm grão, então nos outros o shader fica desligado.
- **O shader** usa o mesmo ruído da `Grain` do shell (`hash(floor(gl_FragCoord.xy))`, um valor fixo por pixel, que não pisca). O Hyprland não deixa passar valores para o shader de tela, então a quantidade vai **escrita no texto** do arquivo: `~/.cache/mosaic-os/grain-<quantidade×10000>.frag`, por exemplo `grain-700.frag` para 0,07. Cada quantidade tem um nome próprio porque o Hyprland só relê o shader quando o caminho muda. Depois de gravar, um `find … -delete` apaga os arquivos de quantidades antigas.
- **Aplicar:** `hyprctl eval 'hl.config({ decoration = { screen_shader = "<arquivo>" } })'`; para desligar, caminho vazio. Uma mudança no slider espera 250 ms antes de aplicar.
- **Reload:** qualquer reload da config do Hyprland (vidro, tema, papel de parede) zera o shader. O serviço escuta o evento `configreloaded` do Hyprland (`Hyprland.onRawEvent`) e aplica de novo. Se o arquivo já existe (`written`), só manda o caminho outra vez: o `FileView` não grava um texto igual ao que já está no disco, então esperar o `onSaved` deixava o shader apagado.
- **Tela cheia** (`fullscreenOff`, ligado por padrão): se uma janela em tela cheia de verdade (`fullscreen` 2, como jogos e vídeo; maximizar não conta) está num workspace visível de algum monitor (`HyprlandData.windowList` × `HyprlandData.monitors`), o grão sai. O motivo: com um shader de tela, a GPU não consegue mandar os quadros do jogo direto para o monitor (*direct scanout*), e isso pesa. O shader vale para a tela toda, então enquanto isso o outro monitor também fica sem grão. Quando a janela sai da tela cheia, o grão volta.
- **Sem grão dobrado:** com o grão dos apps ligado (`MosaicScreenGrain.wanted`, que ignora a pausa da tela cheia), `MosaicTheme.shellGrain` vira 0. Todo grão do shell (ilha, laterais, dock, fundo e seletor) multiplica esse valor, já que o shader de tela já cobre o shell. Na aba Aparência, o grupo de granulado mostra "Pausado". Pôr o grão dos apps em 0 devolve o grão próprio de cada parte.
- **Não aparece em print:** a captura de tela do Hyprland (`grim`, wf-recorder) pega a imagem **antes** do shader de tela, então o grão dos apps não sai em print nem em gravação. Isso foi testado: prints com e sem o shader saíram idênticos pixel a pixel.
- IPC: `qs -c mosaic ipc call wallpaperSelector apps`.

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

---

## 12. Temas (`modules/common/MosaicTheme.qml`, `themes/`)
Um **tema** é **cores e formato** para o **Quickshell** e o **Hyprland** (bordas, fundo e cantos das janelas); os apps não mudam. Existem três:
- **Mosaic:** as cores vêm do papel de parede. O Matugen é só a forma como esse tema consegue as cores.
- **Gruvbox** (escuro médio): paleta fixa em `themes/gruvbox.json`. Primária laranja `#fe8019`, secundária verde `#b8bb26`, terciária azul `#83a598`, fundo `#282828` e texto `#ebdbb2`. Os containers usam os tons "faded" do Gruvbox.
- **Horizonte** (só escuro): paleta fixa em `themes/horizonte.json`, tirada da primeira tela da página do Claude Opus 5.5. As cores foram medidas na própria imagem (Pillow, `getpixel` em faixas da altura): primária laranja do horizonte `#e8673a` (a foto tem `#e1562b`, suavizado), secundária mostarda `#f2c94c` (a lateral amarela), terciária azul do céu `#79a5d4`, fundo quase preto amarronzado `#12100d` (o chão) e texto creme `#f2ede4` (o mesmo do título da página). Ao ligar o tema, ele põe o seu papel de parede, `~/Imagens/Wallpapers/horizonte.jpg`. As outras duas imagens da página, `horizonte-mostarda.jpg` e `horizonte-cogumelo.jpg`, ficam na pasta como papéis extras. As imagens não entram no repositório.

**Como funciona:**
1. O shell inteiro pinta suas cores a partir de **49 cores Material** (`primary`, `surface_container`, `on_surface`...). O Matugen escreve essas cores em `~/.local/state/quickshell/user/generated/colors.json`, e o `MaterialThemeLoader` do ii as copia para `Appearance.m3colors`. Daí saem todas as `Appearance.colors.*`.
2. Um tema fixo é **outro JSON com as mesmas 49 chaves**. O `MaterialThemeLoader` do Mosaic OS lê `themePath()`: o arquivo do tema, ou o do Matugen no tema Mosaic. Quando o tema muda, ele relê. Com o Gruvbox ligado, trocar o papel de parede não muda as cores, porque o loader nem olha o arquivo do Matugen.
3. **Hyprland:** o tema fixo manda as cores de borda e fundo ao vivo (`hyprctl eval 'hl.config({ general = { col = {...} } })'`). Voltar ao Mosaic recarrega a config, que traz de volta o `colors.lua` do Matugen. Depois de reiniciar, o tema salvo pinta o Hyprland de novo quando o shell liga.
4. A escolha fica em `~/.config/mosaic-os/theme`.

**Formato (`roundness`):** quanto as coisas arredondam. No Mosaic é 1 (pílulas macias); no **Gruvbox é 0,2**, tudo quadrado (uma curva de 20 px vira 4).
- `MosaicTheme.r(px)` devolve um raio no formato do tema. **Todos os raios** dos módulos do Mosaic OS passam por ele (`radius: MosaicTheme.r(14)`), inclusive o recorte dos copos d'água e os blocos da bússola.
- Os arredondamentos do ii (`Appearance.rounding.*`, usados nas laterais, na visão geral etc.) também são multiplicados. O "totalmente redondo" (`full`, 9999) vira uma quina de 6 px nos temas quadrados. O `MosaicTheme` mora em `modules/common`, ao lado do `Appearance`, justamente para os dois se enxergarem sem dependência circular.
- **Ilha:** em repouso, raio = metade da altura × formato (pílula ou caixa). A **cúpula** da bússola depende de `formato²`: no Mosaic é a cúpula de sempre; no Gruvbox (0,04) vira uma caixa quase reta.
- **Líquido:** o raio da bolha passa por `r()`, e o `fuse` (a curva da junção) encolhe até 35% nos temas quadrados. A notificação continua derretendo, só que com curvas mais justas.
- **Hyprland:** o tema também manda `decoration.rounding` (3 no Gruvbox, 8 no Horizonte). Voltar ao Mosaic recarrega a config (22).
- O **Horizonte** fica no meio: `roundness` 0,6.

**Estilo (`style`):** além de cor e formato, o tema escolhe a *linguagem visual*.
- **`soft`** (Mosaic): vidro, degradês, contornos finos e curvas macias.
- **`brutal`** (Gruvbox): **neo-brutalista quente**.
  - **Superfícies chapadas e sólidas:** `MosaicTheme.slab` (o fundo do tema) e `slabRaised`. As camadas do ii são translúcidas e deixavam o papel de parede tingir tudo de marrom.
  - **Contorno grosso creme:** `border` = 2 px, na cor `ink` (`#ebdbb2`).
  - **Sombra dura laranja:** `shadowColor` = `#d65d0e`, deslocada `shadow` = 4 px para baixo e para a direita, sem desfoque.
  - **Botões que afundam:** ao apertar, o botão anda para dentro da própria sombra (chips, +, Aplicar/Aleatório, filtro ligado).
  - **Etiquetas tortas como adesivo:** `tilt` = −2,5° no contador do seletor e no "RECENTES".
  - **Títulos** em maiúsculas com espaçamento.
- **`retro`** (Horizonte): as formas do `soft`, mais três coisas:
  - **Granulado de filme:** `MosaicTheme.grain` = 0,07 (zero nos outros temas); quanto cada parte recebe se ajusta nas abas Aparência e Dock (11.2.3). Na ilha e na bolha é um uniform novo, `grain`, nos shaders `island.frag` e `goo.frag`: cada pixel soma `(hash(floor(p)) − 0,5) × grain` à cor. `hash` é uma função de ruído barata, sem textura: devolve um número "aleatório" mas fixo para cada coordenada, então o grão não pisca. Na dock, nas duas laterais, nos cartões do fundo (calendário, fotos e música) e no cartão do seletor de papéis (que são `Rectangle`), vai por cima uma `Grain.qml` (`shaders/grain.frag`): o mesmo ruído recortado num retângulo arredondado (SDF), que clareia onde o valor passa do meio e escurece onde fica abaixo. Com `grain` 0, a `Grain` fica invisível e nem vira passe de shader. Nas laterais, o canto do lado da tela é reto e só o de dentro é redondo. Por isso a `Grain` delas passa um raio além da borda da tela (`x: -radius` na esquerda, largura + raio na direita), e a janela corta esse excesso: o canto redondo do shader fica fora da tela.
  - **Película escura na dock:** o `glassFill` usa `m3surfaceContainer` do tema (marrom quase preto) no lugar da película branca. A transparência e a escuridão da aba Dock continuam valendo.
  - **Títulos com serifa:** ver Fontes, abaixo.
- **`HardShadow.qml`:** a sombra dura reutilizável. É um `Rectangle` com `z: -1` (filho com z negativo é desenhado **atrás** do pai), na forma do pai, deslocado. Com `sink: pressed`, ela devolve `sinkShift`, e o pai anda isso (`transform: Translate`); a sombra fica no lugar e o botão parece afundar.
- **Ilha e bolha:** os shaders `island.frag` e `goo.frag` ganharam `strokeWidth`, `shadowOffset`, `shadowColor` e `shadowAlpha`. A sombra é **a mesma forma SDF calculada de novo em `p − offset`** e pintada por baixo, então até o pescoço líquido e a cúpula têm sombra dura. A `ShaderEffect` da ilha ficou 4 px maior para caber a sombra (`shapeSize` é a ilha, `size` é a ilha mais a sombra).
- **Painel:** os blocos (`Block`) ficam com cor chapada mais forte (`softBlock` mistura 50% com o fundo, sem degradê), contorno e sombra. O layout deixa 4 px à direita e embaixo para a sombra não ser cortada, e as teclas das ferramentas ficam quadradas.
- **Bússola:** blocos em cor cheia com contorno; a área atual ganha sombra dura.
- **Dock, menu, notas e seletor de papéis:** placa sólida com contorno e sombra. A seleção do menu, a aba atual e a miniatura escolhida "levantam" sobre a sombra; o cartão do seletor tem uma sombra de 8 px.

**Fontes:** `MosaicTheme.fontUi` (texto, Space Grotesk) e `MosaicTheme.fontDisplay` (títulos). Todas as `font.family: "Space Grotesk"` dos módulos do Mosaic OS passaram para `fontUi`. Usam `fontDisplay` o relógio e a temperatura da ilha, o cabeçalho da lateral direita, o título do seletor, o nome do papel escolhido e as opções grandes das abas. Um tema pede a fonte em `fontDisplay` (o Horizonte pede **Fraunces**, serifa macia de estilo antigo, parecida com o título da página). Ela só é usada se estiver instalada: `Qt.fontFamilies()` lista as fontes do sistema; se faltar, vai Noto Serif. A Fraunces vem do AUR: `yay -S ttf-fraunces-variable`. Nos temas sem `fontDisplay`, os títulos ficam em Space Grotesk, como antes.

**Papel de parede do tema:** um tema com `wallpaper` roda `switchwall.sh --image <arquivo> --mode dark` ao ser escolhido, por um `Process`, e não por `execDetached`. O motivo: o script recarrega o Hyprland, o que traz de volta as cores de borda da config. Quando ele termina (`onExited`), o tema repinta o Hyprland. Voltar ao Mosaic não troca o papel; o Matugen tira as cores do que estiver na tela.

**Terminal (kitty):** o `kitty.conf` inclui `~/.config/mosaic-os/terminal-theme.conf` **depois** das cores do Matugen, e no kitty o que vem depois vence. Um tema fixo escreve a paleta dele nesse arquivo (o Gruvbox: fundo `#282828`, texto `#ebdbb2` e as 16 cores Gruvbox); o tema Mosaic deixa o arquivo vazio, e valem as cores do papel de parede. Depois de gravar, `pkill -USR1 -x kitty` faz todo kitty aberto recarregar a config.
- **Slots Material (232–255):** o template do Matugen no ii não pinta só as 16 cores. Ele também usa os slots 232 a 255 da paleta de 256 cores com os papéis Material: 255 = primária, 254 = container primário, 253 = secundária, 252 = container secundário, 235 = texto sobre o container secundário, 240 = texto sobre a primária, 243 = primária, 244 = erro, 245 = outline_variant, e assim por diante. O **prompt do starship** (`~/.config/starship.toml`) desenha as pílulas com esses números (`bg:252`, `fg:235`, `bg:255`). Os temas fixos antes punham cinzas em 253–255 e deixavam o resto de fora, então o prompt continuava com as cores do papel de parede. Agora a paleta de terminal de cada tema fixo traz os 20 slots, tirados do JSON do tema.
- **A pegadinha:** o `~/.config/fish/config.fish` do ii roda `cat sequences.txt` a cada shell novo. Esse arquivo tem as cores do Matugen como **códigos de escape** (OSC 4/10/11/12), que mandam o terminal trocar a paleta na hora e passam por cima do `kitty.conf`. Por isso o kitty carregava o Gruvbox, mas o fish pintava por cima com as cores do papel de parede.
- **A correção:** o tema também gera `~/.config/mosaic-os/terminal-sequences.txt`, a mesma paleta em códigos de escape (`sequencesFor()` converte `colorN`, `foreground`, `background`, `cursor` e `selection_background`). O `config.fish` usa esse arquivo quando ele não está vazio (`test -s`); senão, usa o do Matugen. Ao trocar de tema, `pushToOpenTerminals()` escreve os códigos em todo `/dev/pts/N` aberto, repintando os terminais que já estavam abertos. O `scripts/colors/applycolor.sh` do Mosaic OS, que empurra as cores do Matugen quando o papel de parede muda, também respeita o arquivo do tema.

**Widgets da área de trabalho:**
- **Relógio:** nos temas brutais o `ClockWidget` usa o estilo `brutal` (`clock/BrutalClock.qml`), qualquer que seja o estilo configurado. É uma placa sólida com a hora em Space Grotesk Black 112, contorno creme de 3 px e sombra dura de 10 px. A data vem num **adesivo torto** (−4°) laranja colado no canto, e a marca Mosaic fica no topo. A cada minuto novo a placa faz "tum": afunda na sombra por 140 ms.
- **Calendário, fotos e música:** viram placa sólida com contorno de 3 px e sombra dura de 8 px (`HardShadow { size: 8 }`).
- **Dias juntos e clima:** a flor e a pílula viram um **adesivo quadrado torto** (−3°), com contorno e uma cópia laranja deslocada como sombra.
- **Relógio retrô** (`clock/RetroClock.qml`, temas `retro`), composto como a primeira tela da página do Opus 5.5:
  - em cima, a data em maiúsculas pequenas com espaçamento de 2,4 px ("6 DE NOVEMBRO, 2026");
  - a hora grande na serifa do tema (128 px, peso normal, como o título da página);
  - embaixo, uma **linha de pontos guia** igual ao índice da página, de "(sex)" até o período do dia (madrugada, manhã, tarde ou noite). Os pontos são uma `Row` de retângulos de 1 px; o `Repeater` calcula quantos cabem (`largura / 4`).

  Não há placa atrás: o relógio fica direto sobre o papel de parede, e `style: Text.Raised` dá um halo escuro leve para ler sobre o céu claro.
- No tema Mosaic, tudo continua como no ii.

**Onde escolher:** no topo do **seletor de papéis de parede** há um cartão por tema, com uma marca Mosaic pintada nos quatro tons do tema (no Mosaic, os tons atuais do papel de parede). Os cartões ficam em duas colunas (`Grid`), e um terceiro tema desce para a fileira de baixo. O nome de cada tema aparece na fonte de títulos dele, se estiver instalada. Pela IPC: `qs -c mosaic ipc call theme set gruvbox|horizonte|mosaic` e `theme get`.

**Criar um tema novo:** copie `themes/gruvbox.json` com as 49 chaves e acrescente uma entrada em `themes` no `MosaicTheme.qml`, com `id`, `name`, `hint`, `file`, `swatches` (4 cores da marca), `base` (fundo do cartão), `roundness` (formato), `style` (`soft`, `brutal` ou `retro`; no brutal, também `ink` e `shadowColor`), opcionais `fontDisplay` e `wallpaper`, e `hypr` (cores de borda e fundo, e `rounding` das janelas).

---

## 13. As laterais (`modules/mosaic/sidebars/`)
Substituem as laterais do ii, com os **mesmos atalhos e IPC**: `sidebarLeftToggle`/`Open`/`Close`/`ToggleDetach`, `sidebarRightToggle`/`Open`/`Close` e as IPC `sidebarLeft`/`sidebarRight` `toggle|open|close`. São **colunas inteiras coladas na borda**, no estilo do tema: vidro no Mosaic, placa sólida brutalista no Gruvbox.
- **Entrada:** `slide` (`MosaicSpring`) leva a coluna de fora da tela até o lugar. A janela só existe enquanto está aberta ou animando.
- **Cantos:** só os do lado de dentro são arredondados. Um retângulo da cor da coluna cobre os cantos que encostam na borda da tela.
- **Brutal:** a sombra dura cai para **dentro** da tela, à esquerda da lateral direita e à direita da esquerda. Por isso é um retângulo próprio, não o `HardShadow`, que sempre desloca para baixo e para a direita.
- Esc e clique fora fecham. **O clique fora é uma janela transparente** (`quickshell:sidebarCatcher`, camada Top) cobrindo a tela atrás da lateral, que fica na camada **Overlay**, acima dela. Clicar na janela transparente fecha; clicar na lateral cai na lateral.
  - **A causa de verdade do "fecha ao clicar":** a coluna entra deslizando por um `transform` e nasce fora da tela. O `mask: Region { item: column }` calculava a área de mouse **uma vez**, com a coluna ainda lá fora, e o `Region` não acompanha mudanças de `transform`. A lateral aparecia, mas era "fantasma": o clique atravessava e caía atrás, no app (que a captura de foco contava como fora) e depois na janela transparente. Agora a área de mouse é um `Item` parado (`hitArea`) do tamanho da coluna, como no dock. **Lição:** nunca use como `mask` algo que se mexe por `transform`; use uma peça parada.
  - **Por que não `HyprlandFocusGrab`:** um rastreador temporário (que registrou quem fechava a lateral e o caminho do código) mostrou que a captura do Hyprland **soltava sozinha** logo depois de abrir (`grab cleared`, com o Qt avisando que o teclado ficou sem dono). Isso fechava a lateral no primeiro clique dentro. Nem a captura compartilhada do ii nem uma captura própria resolveram; a janela transparente não depende do foco.

### 13.1 Direita (`MosaicSidebarRight.qml`)
De cima para baixo:
1. **Saudação** (Bom dia/Boa tarde/Boa noite, pela hora), data, **Configurações** (`settings.qml` do ii) e **Desligar** (a tela de sessão do ii).
2. **Botões rápidos** (`Toggle`, 3×2):
   - Wi-Fi (`Network.toggleWifi`, com o nome da rede);
   - Bluetooth (`Bluetooth.defaultAdapter.enabled`);
   - Silêncio (`Notifications.silent`);
   - Luz noturna (`Hyprsunset.toggleTemperature`);
   - Café (`Idle.toggleInhibit`, a tela não apaga);
   - Microfone (`Audio.source.audio.muted`).

   O botão direito do Wi-Fi e do Bluetooth abre as configurações de cada um.
3. **Sliders** (`Slide`) de volume e brilho: o preenchimento segue o valor por mola; arrastar, clicar ou rolar muda; o ícone do volume liga e desliga o mudo.
4. **Celular** (KDE Connect): nome e bateria (a `PhoneBattery` d'água), perguntados uma vez a cada abertura (sem ficar consultando). Três botões: **tocar o celular** (`findmyphone.ring`), **ping** (`ping.sendPing`) e **enviar arquivo** (escolhe pelo `zenity` e manda com `share.shareUrl`).
5. **Calendário:** o `CalendarWidget` do ii.
6. **Notificações:** a `NotificationList` do ii (histórico, limpar tudo, silêncio), ocupando o resto da altura.

### 13.2 Esquerda (`MosaicSidebarLeft.qml`)
- O `AiChat` do ii recortava a área de mensagens com uma máscara do tamanho do `swipeView` da lateral original. Na lateral do Mosaic esse `swipeView` não existe, a máscara ficava com tamanho zero e a aba IA aparecia vazia; agora a máscara usa o tamanho da própria área (`messagesArea`).
- Três abas: **Tradutor** (o `Translator` do ii), **Tarefas** (o `TodoWidget` do ii, que saiu da direita) e **IA** (o `AiChat` do ii). A aba Anime saiu.
- Cada página é criada só na primeira vez que a aba é aberta (`Loader` com `wanted`) e fica viva depois; trocar de aba faz fade com um deslize de 24 px.
- IPC: `qs -c mosaic ipc call sidebarLeft tab 0|1|2` abre direto numa aba.


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
11. [Papéis de parede, carrossel e configurações: `modules/mosaic/wallpapers/`](#11-papéis-de-parede-carrossel-e-configurações)
12. [Temas: `modules/common/MosaicTheme.qml`](#12-temas-modulescommonmosaicthemeqml-themes)
13. [As laterais: `modules/mosaic/sidebars/`](#13-as-laterais-modulesmosaicsidebars)
14. [A faixa do topo: `modules/mosaic/topbar/`](#14-a-faixa-do-topo-modulesmosaictopbar)
15. [O Stage Manager: `modules/mosaic/stage/`](#15-o-stage-manager-modulesmosaicstage)
16. [O mapa de workspaces (Super+Tab)](#16-o-mapa-de-workspaces-supertab)
17. [O launcher com modos](#17-o-launcher-com-modos)
18. [Os widgets do impasto: `desk/`](#18-os-widgets-do-impasto-desk)
19. [A lock screen: `desk/MosaicLock.qml`](#19-a-lock-screen-deskmosaiclockqml)
20. [Commit, push e Claude Code na ilha](#20-commit-push-e-claude-code-na-ilha)
21. [Mosaic com a cara da mosaic-ui, e o tema macOS](#21-mosaic-com-a-cara-da-mosaic-ui-e-o-tema-macos)

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
  - adicionados: `Island`, `MosaicDock`, `MosaicCarousel`, `MosaicWallFx`, `MosaicSettings`, `MosaicSidebarLeft`, `MosaicSidebarRight`, `MosaicTopBar` e `MosaicStage` (as laterais do ii foram comentadas).
- `hypr/mosaic.lua`: a camada `quickshell:mosaicSettings` (o cartão de configurações) ganhou o liquid glass. Atalhos: Super+Alt+T (configurações), Super+Shift+Tab (Stage Manager), Super+Alt+N (notas).
- `modules/ii/overview/Overview.qml` e `OverviewWidget.qml`: o mapa de workspaces (seção 16).
- `services/LauncherSearch.qml` e os prefixos em `modules/common/Config.qml`: o launcher com modos (seção 17).

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

## 11. Papéis de parede, carrossel e configurações
Os papéis de parede saíram da janela de configuração e ganharam um **carrossel** próprio. São quatro arquivos em `modules/mosaic/wallpapers/`:
- `MosaicWalls.qml`: os dados (singleton);
- `MosaicCarousel.qml`: o carrossel;
- `MosaicWallFx.qml` e `shaders/colonies.frag`: a transição;
- `MosaicSettings.qml`: a janela de configuração.

O carrossel e a transição são ideias das [pocket-dots](https://github.com/diegoMalagrida/pocket-dots) (GPL-3.0), reescritas no estilo Mosaic. Os atalhos continuam os mesmos: `wallpaperSelectorToggle`, `wallpaperSelectorRandom` e a IPC `wallpaperSelector toggle|random`.

### 11.1 Os papéis (`MosaicWalls.qml`)
Um **singleton**, ou seja, um objeto único que o carrossel e a transição compartilham.
- A pasta é a do papel de parede atual (`Config.options.background.wallpaperPath`).
- `refresh()`: o `Process` `lister` roda um `find` e lista as imagens. Depois o `indexer` roda `wallpaper-index.sh`, que para **cada imagem nova**:
  - cria a miniatura de 480×300 com o `vipsthumbnail` (ou com o `magick`, se ele faltar);
  - tira a cor média, reduzindo a imagem a 1 pixel.

  Tudo fica em `~/.cache/mosaic-os/wallpapers`, e o script roda com `nice -n 19`.
- `colors.tsv` (nome → cor) é lido por um `FileView`. `hueOf(hex)` converte a cor em família (cinza se tiver pouca saturação, senão pela matiz) para os filtros de cor.
- `history` ganha uma linha a cada papel aplicado; "Recentes" lê de trás para frente, sem repetir.
- `apply(path)` **não troca o papel na hora**: põe o caminho em `pending`, e a transição (11.4) cuida do resto. `random()` sorteia um papel diferente do atual; se a lista ainda não carregou, lê a pasta e sorteia quando ela chegar. `commit(path)` é a troca de verdade: o script do ii (`Wallpapers.select`, que roda o Matugen) mais a linha no histórico.
- **Papéis das pocket-dots:** os 20 do repo delas estão em `~/Imagens/Wallpapers/pocket-*`, com o `pocket-SOURCES.md`. Segundo o próprio autor, só 2 têm licença clara (pinturas do Met em domínio público); os outros não têm origem registrada. Por isso eles **não entram no repo**.

### 11.2 A janela de configuração (`MosaicSettings.qml`)
Era a janela de papéis de parede. Agora tem só os **temas** à esquerda e uma aba por parte: Widgets, Gravação, Ilha, Aparência, Dock, Apps e Áreas.
- **Abrir:** o botão de paleta na lateral direita, Super+Alt+T (`mosaicSettingsToggle`) ou a IPC `qs -c mosaic ipc call mosaicSettings toggle|widgets|recording|island|look|dock|apps|areas`.
- O estado aberto é da própria janela (`root.open`). O `GlobalStates.wallpaperSelectorOpen` passou para o carrossel.
- `LazyLoader`: a janela só existe aberta (ou enquanto fecha). Uma `PanelWindow` na tela inteira, camada Overlay. O fundo escurece com 0,25, abaixo do limite de 0,3 do hyprglass, então só o cartão vira vidro. Clicar no fundo ou Esc fecha.
- O cartão abre por `openSpring` (escala 0,94 → 1 e opacidade) e fecha deslizando em 200 ms.

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

### 11.2.3 As abas Ilha, Aparência e Dock
- Cada aba cuida de uma peça:
  - **Ilha:** `Config.options.mosaicIsland`, só a ilha (e a bolha).
  - **Aparência:** `Config.options.mosaicWidgets`, as duas laterais e os widgets do fundo (calendário, fotos e música).
  - **Dock:** `Config.options.mosaicDock`.

  A ilha já esteve dentro da Aparência e foi separada de novo; os valores dela foram copiados uma vez, à mão, no `config.json`.
- As três abas usam a mesma página (`GlassPage`), com quatro controles (`TuneSlider`: o preenchimento segue o valor por mola; arrastar, clicar ou rolar muda):
  - **Potência do liquid glass** (0–200%, `glass`) e **Aberração cromática** (0–200%, `chroma`, as bordas de arco-íris) vão para o `MosaicGlass` (`modules/common/MosaicGlass.qml`). O hyprglass só aceita presets vindos da config do Hyprland, então o serviço:
    - grava `~/.config/mosaic-os/glass.lua` com três presets: `ilha` (base: o "vivo", na `quickshell:island`, limiar 0,05), `widgets` (mesma base, nas duas laterais `quickshell:sidebarLeft/Right`, 0,3) e `doca` (base: o vidro forte da dock). `presetLua()` recebe uma lista de camadas por preset. Os widgets do fundo moram na camada do papel de parede, que não tem vidro. Cada valor é a base vezes a potência, com tetos; a aberração usa o próprio multiplicador. Potência 0 desliga o vidro dessas camadas;
    - roda `hyprctl reload config-only`; o `hypr/mosaic.lua` executa esse arquivo no fim, por cima dos presets padrão;
    - espera 700 ms depois da última mudança (`signature` junta os seis valores), para arrastar um slider recarregar uma vez só;
    - ignora as mudanças dos primeiros 4 s, que são só os valores salvos carregando. Ao fim desses 4 s, compara o arquivo do disco com o texto que deveria ter e, se forem diferentes (estrutura nova, como a separação da ilha), grava uma vez;
    - depois do reload, repinta as cores de um tema fixo, que o reload apaga.
  - **Transparência** (`opacity`, o inverso) e **Escuridão** (`darkness`) mudam na hora. `MosaicTheme.widgetFill(base)` puxa a cor para o preto (`base × (1 − escuridão)`) e usa a opacidade como alfa. É a cor das laterais e dos cartões do fundo; a ilha faz a mesma conta com `islandBase` e `islandAlpha`, lendo a aba Ilha. Na dock, quem faz isso é o `glassFill`. Os temas brutais continuam com a placa sólida.
- **Granulado de filme** (só nos temas que têm, os `retro`, como o Horizonte): embaixo aparece o grupo "Granulado de filme", com um controle por parte, em duas colunas (0–200%, multiplicando o `MosaicTheme.grain` do tema):
  - Ilha: `grain` (ilha e bolha);
  - Aparência: `grainSidebars` (as duas laterais), `grainDesktop` (cartões do fundo) e `grainPicker` (a própria janela de temas);
  - Dock: `grain`.

  O `MosaicTheme` já entrega cada valor pronto (`grainIsland`, `grainSidebars`... = grão do tema × controle), e cada `Grain`/shader lê o seu. Com o tema retrô a página fica mais apertada (espaçamento 10 em vez de 22) para caber o grupo.
- **Fica sem granulado:** o clima e os "dias juntos". São formas Material (pílula torta e flor), e o shader de granulado só recorta retângulos arredondados.
- **Pegadinha:** componentes declarados no fim do arquivo (`component X: ...`) não enxergam os ids da janela (`side`, `pageTabs`). Por isso o posicionamento da `GlassPage` fica onde ela é usada.
- IPC: `qs -c mosaic ipc call wallpaperSelector island|look|dock`.

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

### 11.2.5 A aba Áreas
- **Stage Manager:** ligado ou desligado (`Config.options.mosaicStage.enabled`), seção 15.
- Um lembrete do mapa de workspaces (Super+Tab), seção 16.

### 11.3 O carrossel (`MosaicCarousel.qml`)
Abre pelo botão "Trocar papel de parede" da lateral direita, pelo atalho de sempre ou pela IPC.
- **Fundo imersivo:** a tela inteira mostra a miniatura do papel selecionado, borrada (`MultiEffect`, `blur 1`, `blurMax 48`) e escurecida. São duas camadas (`bgA` e `bgB`) que se revezam: a nova seleção entra numa enquanto a outra some, num crossfade de 380 ms.
- **A fileira:** um `ListView` horizontal com `StrictlyEnforceRange`. O item atual fica sempre no meio (`preferredHighlightBegin = largura/2 − vaga/2`), e trocar de item desliza a fileira em 320 ms.
  - **Fluidez:** toda vaga tem a mesma largura fixa (`slotW`), então rolar nunca recalcula layout. Cada cartão só muda `scale` e `opacity`, calculados pela distância até o meio, em vagas: `dist = |x do cartão − contentX + vaga/2 − largura/2| / vaga`. Escala `1 − 0,17·dist` (mínimo 0,5), opacidade `1 − 0,24·dist`, e o `z` cai com a distância, para o do meio ficar na frente.
  - **O paralelogramo:** o cartão leva uma transformação `Matrix4x4` com cisalhamento (shear) `skew = −0,32`: cada linha é empurrada de lado proporcionalmente à altura. O `clip: true` de um item transformado recorta no formato transformado, então o cartão vira um paralelogramo de verdade. A imagem dentro leva o cisalhamento **oposto**, para ficar reta, e é mais larga que o cartão (`+ altura × |skew|`), para cobrir os cantos.
  - **Nitidez:** cada cartão mostra a miniatura (480×300) na hora, e os cartões perto do meio (`dist < 2,6`) carregam por cima uma **prévia de 1100 px** (`~/.cache/mosaic-os/wallpapers/previews`, feita pelo `wallpaper-index.sh`). Usar o original deixava o carrossel lento: o Qt decodifica as imagens assíncronas numa fila única, e decodificar um 6K demorava mais que um passo da rolagem.
- **Começa no papel em uso:** sempre que a lista muda e você ainda não mexeu (`touched`), o índice vai para o papel em uso, com `Qt.callLater`. Definido antes de o `ListView` pegar a lista nova, o índice voltava a 0. A pasta é relida ao abrir e chega como uma lista nova, por isso não basta fazer isso uma vez só.
- **Controles:** setas ou roda do mouse navegam, Enter (ou clique no cartão do meio) aplica, digitar filtra pelo nome, Tab troca o filtro de cor, Esc fecha. Os chips: Todos, Recentes, 8 cores e Aleatório.
- **Tema:**
  - soft: borda fina de vidro, a selecionada na cor de destaque;
  - brutal: contorno creme de 3 px e uma sombra dura também inclinada;
  - retro: granulado (`grainPicker`) nos cartões e no fundo, e o nome em `fontDisplay`.

### 11.4 A transição com contorno (`MosaicWallFx.qml`, `shaders/wallfx.frag`, `scripts/wallfx/`)
Substituiu o "derramar" e depois as colônias de pixels: agora é tudo **liso**, sem pixel. Ideia do wallfx das pocket-dots (GPL-3.0).
- **Com personagem** (há um mapa de contorno do papel novo):
  1. uma linha fina desenha o contorno, como uma caneta: cada contorno começa no ponto mais alto, e duas canetas dão a volta em sentidos opostos até se encontrarem do outro lado;
  2. o personagem se preenche, do contorno para dentro;
  3. o resto do papel se espalha a partir dele, com uma borda líquida, um aro de luz na frente e um brilho suave fora dela; a linha some.
- **Sem personagem:** o papel se espalha a partir de 4 focos que caem um depois do outro, com a mesma borda líquida (um ruído fbm deixa a frente ondulada).
- **O mapa** (`scripts/wallfx/wallfx-map.py`, num ambiente Python próprio em `~/.local/share/mosaic-os/wallfx/venv`, com rembg, onnxruntime e opencv):
  - o personagem é recortado pelo modelo **BiRefNet general lite** (224 MB, em `~/.rembg/models`), rodado direto pelo onnxruntime, sem o "arena" de memória e com 2 threads. **Custo:** uns 25 s e um pico de ~6,5 GB de RAM **por papel, uma vez só**, enquanto o mapa dele é feito. Depois o processo fecha e não gasta mais nada; a transição só lê o mapa pronto;
  - vira uma imagem RGB (1024 px de largura), nas proporções do papel, que o shader lê com o mesmo recorte de tela:
    - **R**: a **distância com sinal** até a silhueta (positiva dentro), ±32 px do mapa. Com filtragem linear, um campo de distância dá um contorno liso em qualquer tamanho. O shader desenha a linha onde `|distância|` é menor que ~1,3 px de tela (convertidos com `fwidth`), mais um halo fraco. Rente à borda, o valor suave do próprio modelo refina a distância abaixo de 1 pixel. Antes a linha vinha de "pixels perto do contorno" num mapa de 640 px, e ficava em degraus;
    - **G**: dentro, a profundidade (0 no contorno até 1 no ponto mais fundo, o preenchimento); fora, a ordem em que o resto chega, pela distância até o personagem mais um ruído suave;
    - **B**: a posição ao longo do contorno (0 no ponto mais alto, 1 do outro lado).
  - **Sem canal de transparência de propósito:** o Qt multiplica as cores de uma textura pela transparência, e a linha guardada ali apagava todo o resto do mapa.
  - É "personagem" quando o recorte ocupa de 0,4% a 60% da imagem e o modelo tem pelo menos 80% de certeza; senão grava `<nome>.none` e o papel entra pelos focos. Pedaços menores que 1% do maior são descartados, e contornos minúsculos ou colados na borda da imagem não ganham linha.
- **Pré-cálculo** (`scripts/wallfx/wallfx-warm.sh`): o recorte leva uns 20 s por papel, então é feito antes, uma vez só. Depois que o `wallpaper-index.sh` termina, o `MosaicWalls` chama o warm para a pasta: prioridade mínima (`nice 19`, `ionice` ocioso), 2 núcleos, um de cada vez (`flock`), e só se o ambiente estiver instalado. Os mapas ficam em `~/.cache/mosaic-os/wallfx/<arquivo>.png`, e o `MosaicWalls.maps` sabe quais existem.
- **Tempo:** com contorno, 2,6 s em ritmo constante (linha até 30%, preenchimento de 20% a 45%, mundo de 40% a 100%); sem, 1,6 s.
- O resto é igual: a camada **Bottom** por monitor, a troca de verdade no fim (`commit`), as proteções de 2,5 s e 8 s.
- **Como testei sem mexer na tela:** um shell de teste (`qs -p`) com uma `PanelWindow` na camada **Background**, atrás do papel de parede, que renderiza o shader em vários momentos e salva cada um com `grabToImage`. O modo offscreen do Qt não serve: ele cai num renderizador sem shaders.

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

**Neovim, Mosaic Store e Zen** (`scripts/colors/theme-apps.sh`): esses três pegam as cores por templates do Matugen. São eles:
- `~/.config/nvim/colors/matugen.lua` e o ícone do nvim;
- `~/.config/mosaic-store/colors.css`, com o post hook `mosaic-store --icone`;
- `zen-userChrome.css` e `zen-userContent.css` no perfil do Zen.

Com um tema fixo, eles recebem as cores **do tema** em vez das do papel de parede.
- **Como:** o script converte o JSON do tema (as 49 cores) para o formato que o próprio Matugen usa no `--json` (`colors.<nome>.{dark,default,light}.color`; tema fixo é só escuro, então os três modos levam a mesma cor). Depois roda `matugen json <arquivo> -c <config>`. A config tem **só esses templates**, copiados do `~/.config/matugen/config.toml` (lido com `tomllib`, então os caminhos e o post hook são os mesmos). O resto (Hyprland, GTK, KDE) não é tocado.
- **Quando roda:**
  - no fim de toda troca de papel de parede (`switchwall.sh`, depois do Matugen normal), senão o papel novo devolveria as cores dele;
  - na troca de tema. Um tema fixo sem papel próprio (Gruvbox) roda o script na hora, recebendo o id do tema como argumento, porque o arquivo `theme` pode ainda não estar gravado. Um tema com papel próprio (Horizonte) passa pelo `switchwall.sh`, que já chama o script. Voltar ao Mosaic roda `switchwall.sh --noswitch`, que refaz as cores a partir do papel de parede atual.
  - Com o tema Mosaic o script não faz nada.
- **Neovim:** não precisou mudar. O `lua/config/autocmds.lua` já recarrega o `colorscheme matugen` quando a janela ganha foco e o arquivo mudou.

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
1. **Saudação** (Bom dia/Boa tarde/Boa noite, pela hora) e data, que cortam com reticências se faltar espaço. Quatro botões juntos: **Trocar papel de parede** (o carrossel), **Temas e aparência** (`MosaicSettings`), **Configurações** (`settings.qml` do ii) e **Desligar** (a tela de sessão do ii).
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

---

## 14. A faixa do topo (`modules/mosaic/topbar/`)
Arquivo: `MosaicTopBar.qml`. Uma faixa reservada no topo de cada tela, com os workspaces à esquerda e alguns estados à direita. O meio continua sendo da ilha, que em repouso fica dentro da faixa. Ideia da barra das pocket-dots (GPL-3.0).
- **A janela:** uma `PanelWindow` por tela, ancorada no topo, transparente, com `exclusiveZone: 34`. A ilha termina em 36 px (6 acima + os 30 dela) e o Hyprland soma 5 px de borda, então as janelas começam logo abaixo da ilha (`hyprctl monitors` mostra `reserved=[0,34,0,0]`).
- **Pílulas:** os dois grupos ficam em pílulas escuras de 26 px, com a cor da ilha (escuridão e transparência da aba Ilha), centradas na altura dela. Nos temas brutais viram placas com contorno e sombra dura; nos retrô, granulado.
  - A ilha tem `ExclusionMode.Ignore`, então não é empurrada. As laterais (`exclusiveZone: 0`) passam a começar logo abaixo da faixa.
  - A máscara (`Region`) cobre só os dois grupos; o resto da faixa não pega cliques.
  - Com uma janela em tela cheia de verdade (`fullscreen ≥ 2`) no workspace ativo daquela tela, tudo some (opacidade 0).
- **Workspaces, por demanda:** sempre de 1 a 4, mais qualquer outro que tenha janela (de qualquer tela), mais o ativo. Abrir o Firefox no 5 faz aparecer o 5.
  - Com janela, mostra o **ícone do app usado por último** ali (`focusHistoryID` 0), e um numerozinho no canto se houver mais de uma. Vazio, uma bolinha. Um workspace novo entra crescendo.
  - Clique vai até lá (`hl.dsp.focus({ workspace = N })`, a sintaxe da config em Lua); a roda passa de um para o outro.
  - **A minhoca:** o destaque atrás do ativo tem as pontas em **duas `MosaicSpring`**, uma para a borda esquerda e outra para a direita. A ponta da frente usa `response` 0,2 (rápida) e a de trás 0,42 (lenta), e `goingRight` diz qual é qual. No caminho a ponta da frente sai na hora e a de trás segura e depois solta, então a pílula **estica**; ao chegar, a de trás alcança e ela encolhe com um tremidinho (`damping` 0,78). A espessura afina um pouco com o esticão.
- **Estados** (`StateIcon`): cada ícone só aparece enquanto é verdade, e a largura anima de 0 até o tamanho dele em 200 ms.
  - gravando: um `pgrep` a cada 2 s; pisca uma vez a cada 2 s em vez de pulsar sem parar;
  - café (`Idle.inhibit`), clique desliga;
  - atualizações (`Updates`), vermelho quando muito recomendado;
  - não perturbe (`Notifications.silent`), com o número de notificações; clique desliga;
  - Bluetooth conectado (`BluetoothStatus.connected`);
  - sem internet (sem cabo e Wi-Fi diferente de "connected");
  - mudo (`Audio.sink.audio.muted`), clique desmuta.

  Sem nenhum estado ativo, a pílula da direita some. (Antes os glifos levavam um contorno de texto, `Text.Outline`, que deixava os ícones serrilhados; a pílula escura resolve a leitura sem isso.)

## 15. O Stage Manager (`modules/mosaic/stage/`)
Arquivo: `MosaicStage.qml`. Encostar o mouse na borda esquerda faz entrar uma coluna com os **outros workspaces daquela tela**, cada um como uma pilha das janelas reais, como no macOS. Ideia do Stage Manager das pocket-dots (GPL-3.0).
- **A borda:** uma `PanelWindow` de 2 px na esquerda de cada tela (camada Overlay). O mouse precisa ficar 250 ms nela (`dwell`), então passar por ali a caminho de outra coisa não abre nada. Some com o Stage desligado, com a coluna aberta ou em tela cheia.
- **As pilhas:** as janelas de `HyprlandData.windowList` agrupadas por workspace (menos o ativo), de cada monitor, ordenadas pela mais recente (`focusHistoryID`, 0 = a última usada), no máximo 3.
  - A da frente fica inteira; as de trás ficam menores, deslocadas para cima e para a direita, mais apagadas. Com o mouse em cima, a pilha se abre um pouco (mola `lift`).
  - Cada janela é um `ScreencopyView` do toplevel, a mesma captura do mapa do ii, ao vivo só enquanto a coluna está aberta. Com captura única (`live: false`), as miniaturas saíam vazias: a captura acontecia antes de estar pronta.
  - O toplevel é achado pelo endereço: `0x${toplevel.HyprlandToplevel.address}` igual ao `address` da janela.
  - Embaixo vão o ícone do app (`AppSearch.guessIcon` da classe) e o número do workspace.
- **Uso:** clique vai até o workspace e fecha. Sair da coluna fecha depois de 300 ms (`HoverHandler`). Cada pilha entra um pouco depois da de cima.
- **Liga e desliga:** a aba Áreas, Super+Shift+Tab (`mosaicStageToggle`) e `Config.options.mosaicStage.enabled`, ligado por padrão.
- IPC: `qs -c mosaic ipc call stage open|openOn <tela>|close|toggleEnabled`.

## 16. O mapa de workspaces (Super+Tab)
É a visão geral do ii (`modules/ii/overview/`), que já tinha a grade com as janelas reais e o arrastar de uma janela para outro workspace. O Super+Tab já estava ligado a ela (`overviewWorkspacesToggle`). As mudanças do Mosaic:
- **Não fechava na hora:** ela usava o `GlobalFocusGrab` (a captura de foco do Hyprland), que se solta sozinha e fechava o mapa logo depois de abrir, como já tinha acontecido nas laterais. Agora, com o mapa aberto, a janela inteira pega cliques (`catcher`), e clicar fora da grade fecha. Esc também fecha.
- A grade fica **no meio da tela**, e a busca do ii some (no Mosaic a busca é o menu Iniciar da ilha).
- **Tema** (`OverviewWidget.qml`): moldura do workspace ativo na cor de destaque (creme nos temas brutais); nos brutais o fundo vira placa sólida com contorno e sombra dura de 8 px; nos retrô ganha granulado.

## 17. O launcher com modos
O menu Iniciar da ilha usa a busca do ii (`services/LauncherSearch.qml`). Ela ganhou os modos das pocket-dots (GPL-3.0):
- **Prefixos novos** (padrões no `Config.qml`, e trocados também no `config.json`):
  - `#` área de transferência (antes `;`);
  - `>` ações (antes `/`);
  - o prefixo de apps virou `!`, porque os apps já aparecem sem prefixo nenhum.
- **`@` janelas:** lista as janelas abertas (`HyprlandData.windowList`), filtradas pelo texto no título ou na classe, com o ícone do app e o workspace. Enter foca a escolhida (`hl.dsp.focus({window = "address:…"})`).
- **Timers** (`services/MosaicTimers.qml`): `5m chá`, `timer 90s`, `1h20m pizza`.
  - `parse()` usa uma expressão regular que aceita horas, minutos e segundos, com um rótulo opcional depois. O resultado "Timer" aparece em primeiro.
  - `start()` cria um `Timer` do Qt e manda uma notificação de começo. No fim, outra notificação (urgente) diz que acabou, e a ilha mostra como qualquer notificação.
- **Contas** continuam sem prefixo: começando com número, o ii calcula.
- **Apps por uso** (`services/MosaicLauncherUsage.qml`): cada app aberto pelo menu soma 1 em `~/.local/state/mosaic-os/launcher-usage.json`. Na busca, cada app tem `nota = posição na busca aproximada − log₂(1 + vezes aberto) × 2`, e a lista sai em ordem de nota. Assim, quem você mais abre sobe sem atropelar uma correspondência bem melhor.
- Os chips do menu vazio ganharam "janelas" (`@`) e "timer" (`5m `).

## 18. Os widgets do impasto (`desk/`)
O sistema de widgets da área de trabalho veio do [impasto](https://github.com/andreumassanet/impasto) (GPL-3.0, a mesma licença do Mosaic). Diferente das outras peças, aqui o código foi **copiado e adaptado**, não reescrito: são uns 38 mil linhas de faces bem desenhadas, e reescrever perderia o que você gostou.

**Onde fica:** `desk/` repete as pastas do impasto (`theme/`, `services/`, `components/`, `desktop/`, `lock/`, `bar/modules/`), porque os arquivos se importam por caminho relativo (`import "../services"`). Os scripts Python dele ficam em `scripts/desk/`.
- No QML do Quickshell, um arquivo com `pragma Singleton` numa pasta vira um **singleton** (um objeto único, criado no primeiro uso) para quem importa a pasta. Por isso `DesktopService`, `ClaudeService` etc. funcionam sem `qmldir`.
- De fora, o Mosaic importa com nome: `import qs.desk.services as Desk` e usa `Desk.DesktopService`. O `as` evita choque de nomes com os serviços do ii.

**Como foi copiado:** um script (`closure.py`, no rascunho) leu cada arquivo, achou os tipos usados e puxou os arquivos deles, até fechar o conjunto (212 arquivos). Os widgets puxam quase todos os serviços do impasto, inclusive os que **não podem rodar aqui**: bloqueio por ociosidade, sessão, servidor de notificações, tema dos apps, monitores. Esses viraram **stubs** gerados por outro script: o stub só tem as propriedades e funções que os widgets leem, com valores vazios. Exemplos: `IdleService`, `NotificationService`, `DockService` (diz que a dock ocupa 76 px embaixo, para os widgets não ficarem atrás dela). O `MonitorService` foi reescrito curto: nomeia as telas e escolhe a principal (a maior deitada).

**A grade:** cada widget é uma linha em `~/.local/state/mosaic-os/desk/settings.json` (`desktopWidgets`): `id` do módulo, `col`/`row` na grade, `family` (`2x2`, `4x2`, `4x4` ou `8x2`) e a tela (`screen`, pela descrição do monitor). A célula tem 86 px com 18 de espaço. `DesktopService.nearestFree()` acha a vaga livre mais perto de uma célula (distância ao quadrado entre todas as vagas onde o tamanho cabe).

**Estilo por tema:** o impasto tem três estilos de face; o Mosaic escolhe pelo tema em `DesktopService.mosaicStyle`:
- Mosaic (`soft`) → **Modern**: a leitura grande embaixo, a marca no canto, em vidro. O fundo é o "liquid" do impasto e a camada `mosaic-desk` ganhou o liquid glass do hyprglass (`hypr/mosaic.lua`, preset "vivo").
- Gruvbox (`brutal`) → **Sticker**: cada widget é um adesivo recortado (`Cut`), sem cápsula, com a borda creme do Gruvbox (`stickerPaper` = `MosaicTheme.ink`) e os quatro tons brilhantes do Gruvbox.
- Horizonte (`retro`) → **Analogue**: instrumentos (mostradores, folhinha, vinil, polaroide) sobre o marrom do tema, com o granulado (`Grain`).
- Trocou o tema, `mosaicStyle` muda, todas as faces trocam, e `conform()` reduz o tamanho de quem não tem face naquele estilo.

**A ponte de tema** (`desk/theme/Theme.qml`): as cores do impasto passaram a ler `Appearance.m3colors` (fundo, texto, destaque), as fontes viraram `MosaicTheme.fontUi`/`fontDisplay`, e o raio passa por `MosaicTheme.r()`. As datas usam `Theme.fmt(data, formato)`, que formata no idioma do sistema (`Qt.formatDateTime` escrevia em inglês aqui). Os textos foram traduzidos por um script com um dicionário (`pt.py`, no rascunho) que troca só strings exatas que não são chaves nem comparações.

**Faces novas do Mosaic:**
- `AnniversaryFace.qml` ("Dias juntos"): conta os dias desde `since` (meia-noite a meia-noite, para virar no começo do dia), os meses inteiros e quanto falta para o próximo. Modern: coração + número, e no largo uma barra do mês. Analogue: a folhinha (`Leaf`) com as palavras na fita. Sticker: recorte rosa com o número e um selo com os meses.
- `PhotoFolders.qml`: porta-retrato de **pasta** (`folder` na linha), como os dois do ii faziam com as pastas do celular: as 20 fotos mais novas, uma nova a cada 70 s, a pasta relida a cada 5 min. `DesktopService.pictureOf()` devolve a foto da vez.

**Migração do ii (uma vez):** `MosaicDesk.qml` vê se existe o arquivo `migrated-from-ii`; se não, transforma os widgets do ii que estavam ligados em linhas do desk perto de onde estavam (posição em px ÷ 104 = célula), põe a frase do relógio num post-it, desliga os do ii e grava o arquivo. A cópia da config antes disso está em `~/.local/state/mosaic-os/desk/backup/`.

**Camadas:** o papel de parede do ii foi para a camada `Background` (era `Bottom`), e o desk fica em `Bottom`: acima do papel, abaixo das janelas. Arrumando, o desk sobe para `Top` e pega o mouse.

**Usar:** clique direito no papel → Arrumar widgets (arrastar move, o canto redimensiona, clique abre o inspetor). Ou Configurações → Widgets: o primeiro cartão arruma, os outros ligam (põe um na tela principal) e desligam (tira todos daquele tipo).
- IPC: `qs -c mosaic ipc call mosaicDesk edit|done|list|add <módulo>|addOn <módulo> <tela>|remove <chave>|migrateAgain`.
- Testar sem mexer na sessão: `MOSAIC_DESK_STATE=<pasta>` faz um shell de teste (`qs -p`) usar outra pasta de estado.

## 19. A lock screen (`desk/MosaicLock.qml`)
A tela é a do impasto (`desk/lock/`): o desktop fotografado e borrado atrás (ou a capa da música), o relógio, o player com a letra, e ao apertar uma tecla sobem a foto da conta, o campo e os botões de energia.
- **O que continuou do ii:** a IPC `lock` (`activate`, `focus`), os atalhos globais `quickshell:lock` e `quickshell:lockFocus` (o `hypridle.conf` chama esses), o `useHyprlock`, travar ao entrar (`launchOnStartup`) e destravar o chaveiro com a senha (`unlock.sh`).
- **A ponte:** `GlobalStates.screenLocked` (que partes do ii olham) segue `LockService.locked`. Se algo do ii põe `screenLocked = true` direto, o `MosaicLock` chama `LockService.lock()`.
- **Como trava:** `LockService.lock()` tira um print de cada tela com `grim` (para o fundo borrado), liga o `WlSessionLock` (o protocolo de tela de bloqueio do Wayland: o compositor só mostra essa superfície) e começa uma conversa PAM (`login`). A senha vai em `pam.respond()`. Errou: "Senha errada" e uma nova conversa. Acertou: a tela sai numa animação e os prints são apagados.
- Os botões de reiniciar e desligar usam um `SessionService` curto (`systemctl reboot|poweroff`).
- O desbloqueio por rosto do impasto (howdy) não está instalado; o campo aceita só senha.

## 20. Commit, push e Claude Code na ilha
**Eventos novos da ilha** (`Island.qml`): `commit`, `push`, `claudeDone`, `claudeAsk`. Todos usam o componente `devEvent`: um quadradinho com a marca (o símbolo de commit, uma nuvem ou a faísca do Claude, que gira enquanto ele espera você), o título em cima, a mensagem embaixo e, no commit, `+linhas −linhas · hash` à direita. IPC: `island commit <repo> <branch> <mensagem> <hash> <+> <−>`, `island push <repo> <remoto/branch> <n>`, `island claude done|ask|usage <projeto> <texto>`.

**O hook do git** (`scripts/git-hooks/mosaic-hook`): `git config --global core.hooksPath ~/.config/mosaic-os/git-hooks` (um link para essa pasta) faz o git rodar esses hooks em **todo** repositório. Cada nome de hook é um link para o mesmo script, que olha o próprio nome (`basename "$0"`).
1. Primeiro roda o hook do próprio repositório (`.git/hooks/<nome>`), com os mesmos argumentos e entrada; se ele falhar, o script sai com o mesmo código. Assim um repositório com hooks continua igual (um `commit-msg` que barra o commit ainda barra).
2. `post-commit`: pega repo, branch, assunto, hash curto e `git show --shortstat` (linhas +/−) e chama a ilha **destacado** (`setsid ... &`), sem atrasar o git. Em rebase não avisa.
3. `pre-push`: esse hook roda **antes** do envio, então não sabe se deu certo. Ele lê da entrada as refs que vão subir, conta os commits e deixa um processo esperando o `git push` terminar (o `$PPID`). Depois confere se a ref remota (`refs/remotes/origin/main`) foi para o commit enviado: só então avisa.
- Desfazer: `git config --global --unset core.hooksPath`. Um repositório com `core.hooksPath` próprio (husky) usa o dele e não avisa a ilha.

**Os hooks do Claude Code** (`~/.claude/settings.json` → `scripts/claude-hooks/island.py`): `Stop` (o Claude terminou de responder) chama `island.py done`; `Notification` (pede permissão ou espera você) chama `island.py ask`. O script lê o JSON que o Claude Code manda na entrada (`cwd`, `message`, `transcript_path`), usa o nome da pasta como projeto e, no "terminou", a primeira linha da última resposta (lida do fim do transcript). Sempre sai com 0 e chama a ilha destacado, então nunca trava o Claude Code.

**O anel de uso** (faixa do topo, `MosaicTopBar.qml`): o `ClaudeService` do impasto soma os tokens dos transcripts em `~/.claude/projects` no bloco de 5 h (`scripts/desk/claude_usage.py`). O anel mostra o percentual do plano quando a conta responde; senão, o tempo passado no bloco, com os tokens ao lado. Aqui a conta não responde (o app desktop não guarda o login em `~/.claude/.credentials.json`), então aparecem os tokens. Clique: a ilha mostra tokens, mensagens e quanto falta para renovar. O mesmo serviço alimenta o widget "Claude Code" do desk.

## 21. Mosaic com a cara da mosaic-ui, e o tema macOS
O desk tem agora uma "voz" por tema, em `Theme.look` (`desk/theme/Theme.qml`): `"mosaic"`, `"apple"` ou vazio (Gruvbox e Horizonte desenham as faces Sticker e Analogue).

**Mosaic → mosaic-ui** (os tokens estão em `~/mosaic-gnome/mosaic-design-tokens.md`, tirados da Mosaic Store):
- **Cartão** (`Widget.qml`): cor chapada `surface_container`, borda de 1 px com o texto a 9 %, raio 14, um fio de luz de 1 px por dentro do topo e a **sombra de objeto**: um retângulo sólido 2 px abaixo, na cor da janela a 70 %, sem desfoque. Com o mouse em cima, o cartão sobe 2 px e a sombra vira 4 px. Sem vidro: o `MosaicGlass` desliga o hyprglass na camada `mosaic-desk` fora do macOS.
- **Voz** (`WidgetFace.qml`): o rótulo em JetBrains Mono, 10 px, maiúsculo e espaçado; o número grande em Space Grotesk 700 apertado (−0,03 em). O `WidgetFace` sobe na árvore de objetos até achar quem tem `moduleId`, para saber de que módulo é.
- **Quatro tons:** `Theme.toneOf(nome)` faz um hash do nome e escolhe primária, secundária, terciária ou a mistura das duas últimas, então o mesmo módulo cai sempre na mesma cor (como os ícones de app da loja).
- **Símbolos de pixel** (`desk/components/PixelSymbol.qml`): as grades 9×9 da mosaic-ui (`simbolos.js` da loja, lidas por um script) mais 10 desenhadas no mesmo estilo (calendário, nuvem, wifi, bluetooth, volume, ampulheta, barras, faísca, git, chip). Um `Canvas` pinta um quadrado por `#`; tamanhos múltiplos de 9 deixam cada pixel inteiro.
- **Onda de pixels** (`desktop/shaders/pixelwave.frag`): cada cartão nasce coberto de quadradinhos nos quatro tons, que encolhem numa onda a partir do canto (cada célula espera conforme a distância, mais um pouco de acaso). Cada widget começa 45 ms depois do anterior, pela posição na grade.
- **Pano de pontos vivo** (`desktop/shaders/dotfield.frag`): uma grade de pontos a cada 15 px; três ondas lentas, uma por cor, disputam cada ponto, e a força de quem ganha vira o tamanho do quadradinho. Uma lente de 150 px segue o mouse. Roda a 15 quadros por segundo, só no tema Mosaic e fora do modo de arrumar. Desligar: `pixelField` em `mosaicWidgets` no `config.json`.

**Tema macOS** (`themes/macos.json`, `style: "mac"`, `MosaicTheme.mac`):
- **Cores:** os cinzas do modo escuro da Apple, azul do sistema (`#0a84ff`) de destaque, roxo e verde. Terminal com as mesmas cores; bordas do Hyprland em branco translúcido e cantos de 12.
- **Fontes:** o SF Pro não pode ser usado fora dos aparelhos Apple (licença), então o tema usa o **Inter** (feito à imagem do SF) e o **Inter Display** nos números grandes, instalados em `~/.local/share/fonts/inter`. `MosaicTheme.fontUi` agora aceita a fonte do tema.
- **Vidro:** `MosaicGlass.macLua()` usa o modo **lente** do hyprglass, como o Liquid Glass da Apple: centro limpo e plano (pouco desfoque, sem cúpula: `lens_distortion` quase 0, `refraction_spread = 0`), e a borda dobrando a imagem (`edge_height` + `edge_thickness_px`), com um fio de luz (`bevel`) e quase nada de brilho branco. Todos os valores ficam dentro da faixa do hyprglass (0 a 1): a primeira versão passava disso (brilho de borda 2,6, especular 4,4) e a borda estourava para branco, escondendo a refração. Vale na ilha, na dock, nas laterais, nos widgets e nas configurações. `MosaicTheme.paneAlpha()` deixa as películas com no máximo 14 %.
- **Contorno:** o desk é uma camada do tamanho da tela e a dock fica dentro de uma janela maior que ela; por padrão o hyprglass põe a borda da lente no retângulo da camada (a borda da tela), e a distorção não aparecia nos widgets. Com `mask_mode = "contour"` (desk, dock, laterais e configurações) cada forma desenhada ganha a própria borda, dobra e brilho. O corte (`mask_threshold`) fica em 0,06, abaixo da película de 14 %.
- **Barra:** recebe a mesma lente, fina (`edge_thickness_px` 8, `edge_height` 10), sob um véu escuro de 42 %.
- **Atenção:** o `MosaicGlass` é um singleton e a recarga a quente não troca o código dele; mudou o arquivo, reinicie o shell (`qs -c mosaic kill` e abrir de novo).
- **Widgets** (`desk/desktop/faces/apple/AppleFaces.qml`): Clima sobre um degradê de céu (dia, noite, nublado, chuva, escolhido pela descrição) com a cidade, a temperatura grande em Inter Display Light e as próximas horas no largo; Calendário com o dia da semana em vermelho e o mês com hoje num círculo vermelho; Relógio analógico com ponteiro de segundos laranja; Música sobre a capa borrada; anéis tipo Baterias para CPU, RAM, temperatura e swap; o anel do Claude; Dias juntos. Os outros módulos usam a face Modern com a voz Apple (rótulo colorido, Inter Display).
- **Barra de menus** (`MosaicTopBar.qml`): de ponta a ponta, um véu escuro sobre o vidro líquido em lente fina (o desfoque pesado da primeira versão virava borrão), com um fio escuro embaixo e o conteúdo centrado na linha da hora do notch. À esquerda, a marca Mosaic no lugar do menu da Apple (abre o menu Iniciar), o nome do app em foco em negrito e as áreas. À direita, como no Mac: rede, som (clique = mudo), busca (menu Iniciar), central de controle (a lateral direita) e a data. Os ícones são o componente `MacIcon`.
- **A ilha vira o notch** (`Island.qml`): no macOS ela fica preta, encostada na borda (`topGap` 0, cantos de cima retos, sem contorno) e da altura da barra, como o entalhe do MacBook. A hora fica nela; por isso a barra mostra só a data.
- **Dock:** ícones de 40 px, a lupa do Mac suave (até 32 % maior, subindo 10 px), um pontinho branco embaixo de app aberto e sem a área de status (que fica na barra de cima).
- **Lock** (`desk/lock/MacLockSurface.qml`, escolhida em `LockScreen.qml`): o papel levemente borrado, a data sobre a hora enorme, o "Tocando agora" num cartão de vidro, e embaixo a foto, o nome e o campo em pílula, que treme e se esvazia quando a senha está errada.

**Testar sem tela:** `grabToImage` num item do desk de teste salva o render do Qt num PNG, sem depender do que está na tela (o vidro, que é do Hyprland, não aparece nessa captura).

### 21.1 Os ajustes de cada widget (inspetor)
No modo de arrumar, clicar num widget abre o inspetor (`desk/desktop/Inspector.qml`). Além de formato, foto, face e opacidade, ele ganhou a seção **Ajustes**, feita com dois componentes do próprio arquivo: `AdjustField` (campo de texto que salva ao apertar Enter ou ao sair dele) e `AdjustToggle` (interruptor que salva na hora).
- Relógio: no macOS, **relógio digital** (`digital` na linha: a data sobre a hora grande em Inter Display Bold, a fonte da tela de bloqueio); 24 horas e segundos (`clockFormat`, `clockShowsSeconds`).
- Clima: a cidade (`weatherPlace`; vazio = pela conexão), e o clima é pedido de novo na hora.
- GitHub: o usuário (`githubUser`), com nova leitura na hora.
- Foto: a pasta (`folder` na linha do widget; `~` vira a pasta pessoal).
- Dias juntos: a data (`since`, AAAA-MM-DD, só aceita nesse formato) e o texto (`label`).
- Letra: buscar letras ou não.
- **Consertos:** a "Face" voltou a funcionar (cada widget pode ter um estilo próprio; sem escolher, segue o tema), a opacidade passou a valer no cartão do tema Mosaic, e "Esquerda"/"A mais nova" estavam traduzidos errado.


## 22. Os papéis de parede da casa (`scripts/wallpapers/gerar-mosaic.py`)

Três papéis de 3840×2160 gerados por código, com as cores da mosaic-ui: o fundo
`#16131b` e os blocos azul `#b5c5f9`, rosa `#e9b9d3`, pêssego `#ffb77c` e verde
`#86d7ac`. Rodar `gerar-mosaic.py [pasta]` recria os três. A pasta padrão é
`~/Imagens/Wallpapers`; depois rode `wallpaper-index.sh` para eles entrarem no
carrossel. A semente fixa (`default_rng(22)`) faz o resultado ser sempre igual.

- **`mosaic-tesselas.png`**
  - **A faixa:** uma grade de células de 96 px. Cada célula tem uma "presença"
    que vale 1 no meio de uma curva diagonal (uma reta mais um seno) e cai para
    0 nas bordas. A peça só aparece se um sorteio passar de `presença^0.6`, por
    isso a faixa se desfaz em peças soltas.
  - **A cor:** sai de um degradê de 4 paradas (azul fundo → azul → rosa →
    pêssego) pela posição horizontal. Cada peça leva ±10% de variação de tom,
    como tessela de verdade, e 3,5% delas viram verdes.
  - **As teclas levantadas:** 7% das peças. São desenhadas por último (`sort`
    pelo `lift`) para a parede escura e a sombra ficarem por cima das vizinhas.
  - **Atrás de tudo:** o campo de pontos (a cada 48 px), um halo azul bem leve e
    um brilho diagonal quantizado no próprio grid.
- **`mosaic-paisagem.png`**
  - **A escala:** pixel art desenhada em 480×270 e ampliada 8× com
    `np.repeat`, sem suavizar.
  - **Céu e sol:** o céu tem 7 cores e passa de uma para a outra com
    *dithering* Bayer 4×4. Funciona assim: soma-se o valor da matriz ao degradê
    antes de arredondar para a faixa mais próxima, o que vira o xadrezinho de
    console antigo. O sol usa o mesmo truque em 4 tons e tem as linhas cortadas
    embaixo.
  - **Montanhas e lago:** as montanhas são 4 cristas feitas de senos somados,
    arredondadas a cada 2 px. A encosta virada para o sol ganha a cor clara,
    pontilhada. O lago espelha o sol em traços que estreitam.
  - **De perto:** uma junta 6% mais escura entre os blocos de 8 px lembra que é
    um mosaico.

- **`mosaic-aurora.png`**, o papel aplicado. Ele saiu de um print da área de
  trabalho:
  - **Por que este:** os cartões são quase pretos e ficam nos cantos, e o desk
    já desenha o campo de pontos. As cores que já estão na tela são o verde do
    gráfico do GitHub e o magenta do visualizador. O Tesselas brigava com tudo
    isso.
  - **Como é feito:** em blocos de 24 px (160×90), três manchas gaussianas:
    verde embaixo à esquerda, magenta à direita e violeta no meio. As manchas
    do verde e do magenta ondulam em sentidos opostos, por um seno.
  - **Contraste e cantos:** a força é quantizada em 6 degraus com Bayer e chega
    no máximo a 34% da cor, para os widgets continuarem legíveis. Uma vinheta
    apaga os cantos, onde ficam os cartões. Sem blocos acesos soltos: você
    achou que pareciam jogados.
  - **Na tela vertical:** o meio do papel, que é o que aparece recortado ali,
    continua equilibrado.

No tema Mosaic, o Matugen tira as cores desses papéis como de qualquer outro.
Gerados uma vez, eles não custam nada em execução.

## 23. A troca de papel pela onda de pixels (`MosaicWallFx.qml` + `shaders/pixelfx.frag`)

**Só no tema Mosaic.** A transição é escolhida pelo tema quando ela começa
(`root.pixels = MosaicTheme.current === "mosaic"`), para uma troca de tema no meio
não trocar de efeito:
- **Mosaic:** a onda de pixels, e os widgets entram nela.
- **Gruvbox, Horizonte e macOS:** a transição líquida de antes (`wallfx.frag`),
  com o contorno do personagem quando há mapa. Por isso os mapas continuam
  sendo gerados. Os widgets não tocam onda, mas também não somem, porque a
  camada fica no `Background` nos dois casos.

**Por que os widgets sumiam:** a camada da transição ficava no nível `Bottom`,
o mesmo do desk. Entre camadas do mesmo nível, o Hyprland desenha por cima a
mais nova, e a da transição é criada na hora da troca. Por isso ela tapava os
widgets até o fim do fade. Agora ela fica no nível **`Background`**, também
criada depois do papel: fica acima do papel e abaixo dos widgets.

**A onda (`pixelfx.frag`):** é a "cortina" da mosaic-ui
(`js/pixels-worker.js`), feita num shader.
- A tela é dividida em células de 24 px. Cada célula tem um `dist`: a distância
  até a origem (um canto ou o meio de baixo, sorteado) dividida pela distância
  até o canto mais longe.
- A célula começa em `progress·K = dist + jitter` e leva `W` do tempo
  (`W = 0.22`, `K = 1.30`, para a última célula terminar em `progress = 1`).
- Nos primeiros 42% desse tempo, cresce um quadradinho de um de quatro tons
  sobre o papel antigo (que é só o que está embaixo, nada desenhado). Depois a
  célula passa a mostrar o papel novo e o quadradinho encolhe sobre ele.
  Ease-out cúbico, com 2 px de espaço entre quadrados, como na mosaic-ui.
- **Os tons:** a cor média do papel novo (`colors.tsv`) com saturação de pelo
  menos 0,6, mais três vizinhos dela (±0,07 no matiz, um mais claro e um mais
  pálido).
- **A sequência:** a onda leva `MosaicWalls.waveDuration` (1,5 s). Depois vem o
  `switchwall.sh` (papel + Matugen, cerca de 1,7 s), e a camada some num fade
  quando o papel de verdade já mostra a imagem nova.

**Os widgets na onda (`desk/desktop/Widget.qml`):**
- `MosaicWallFx` emite `MosaicWalls.waveStarted()` com `waveOrigin` e
  `waveTones` preenchidos.
- Cada widget calcula quando a onda chega no centro dele com a mesma conta do
  shader, `duração · (dist + 0.04) / 1.30`, usando `mapToItem(null)` para saber
  onde está na tela.
- Nessa hora, a onda do próprio cartão (`pixelwave.frag`) cobre o cartão com
  quadrados de 24 px nos tons da onda, vindos do lado de onde ela vem, em
  240 ms, e revela de novo em 520 ms. Só no tema Mosaic.

**Outras mudanças:**
- **IPC nova:** `qs -c mosaic ipc call wallpaperSelector apply <caminho>` troca
  o papel com a onda.

## 24. Otimização: o que redesenha à toa

**Como medir.** Rode o shell com `WAYLAND_DEBUG=client` e conte os
`wl_surface#N.commit` por superfície. Para saber quem é cada superfície, use o
`get_layer_surface(..., wl_surface#N, ..., "namespace")` do mesmo log. Cada
commit de uma camada faz o Hyprland recompor a tela. Como as janelas são
translúcidas e borram o fundo (opacidade 0,86/0,78, blur com `xray`), um commit
de uma camada de fundo (papel, desk) faz o blur da tela inteira ser refeito. O
uso da GPU sai de `/sys/class/drm/card1/device/gpu_busy_percent`, e a potência
de `hwmon*/power1_average`.

Medição inicial, com a área de trabalho parada: GPU de 40% a 70% com o shell e
6% sem ele. O desk fazia 15 commits/s em cada tela, por causa do campo de
pontos.

**O que mudou:**
- **Campo de pontos** (`desk/desktop/Desktop.qml`): fica parado, sem quadro
  nenhum. Cada clique esquerdo no fundo anima o `time` do shader +6 s em 600 ms
  (`fieldSlide`), e as ondas deslizam para outra posição e param. A lente que
  seguia o mouse saiu, porque repintava a cada movimento.
- **Música na ilha** (`Island.qml`): as barrinhas viraram um ícone de nota
  parado (`playingSlot`), e o mascote não dança mais com a música
  (`baseMood: "idle"`). **Regra que vale para o shell todo:** uma animação
  rodando numa janela faz o Qt desenhar essa janela em todo quadro do monitor
  (até 165/s), mesmo que o item esteja invisível. A dança continuava rodando
  com a capa do álbum cobrindo o mascote. Loops infinitos só podem rodar
  quando o resultado é visto e por pouco tempo.
- **Visualizador do desk:** ligado o `spectrumOnEmpty` do impasto. O cava para
  quando o workspace da tela tem janela, já que o visualizador fica atrás dela.
  O próprio serviço já ignorava as linhas de silêncio.

**Medição pelo painel desliga-tudo:** o papel sozinho custa ~10% e a ilha
sozinha ~10%, mas os dois juntos ficavam entre 30% e 60%. Desligar só o vidro
da ilha não mudou nada que se medisse. A ilha dançando em todo quadro sobre um
papel de tela cheia é a explicação mais provável.

**Ainda gera quadros, mas por interação:** passar o mouse sobre os widgets
(o cartão levanta 2 px), sobre a dock (a ampliação) e sobre a ilha.

### 24.1 O painel "desliga-tudo" (Super+Alt+G)

Um painel feio de propósito para achar o que pesa na GPU: uma caixa por peça do
shell. Desmarcar uma caixa desliga aquela peça na hora, e o topo mostra o uso da
GPU (`gpu_busy_percent`, lido uma vez por segundo só com o painel aberto). Para
uma medição melhor, rode `radeontop -c` num terminal ao lado.

- **Os interruptores** ficam no singleton `modules/common/MosaicDebug.qml`.
  Cada um é o `extraCondition` de um `PanelLoader` em
  `panelFamilies/IllogicalImpulseFamily.qml`; desligar descarrega a peça
  inteira, e religar a recria. A exceção é `pontos`, que o campo de pontos do
  desk lê direto.
- **Peças:** papel de parede, pontos de fundo, widgets (o desk inteiro), ilha,
  dock, barra de cima, laterais esquerda e direita, cantinhos da tela e Stage
  Manager.
- **Nada é salvo:** reiniciar o shell religa tudo.
- **A janela** é um `FloatingWindow`. A regra em `hypr/mosaic.lua` a deixa
  flutuando, com 260×520 px, no canto de cima à direita.
- **IPC:** `qs -c mosaic ipc call mosaicDebug toggle` abre e fecha o painel, e
  `... set ilha false` liga ou desliga uma peça por script.

### 24.2 CPU, RAM e camadas

- **Gravação de tela, uma checagem só** (`modules/common/MosaicRecording.qml`):
  um `pidof` + `ps` a cada 3 s para o shell inteiro. Antes, a ilha e a barra
  rodavam cada uma o seu `sh + pgrep`, a cada 1,5 s e 2 s. Os indicadores de
  gravação (o ponto da ilha e a piscada da barra) eram animações em loop, que
  faziam o shell desenhar a 165 quadros/s durante a gravação inteira. Agora um
  `Timer` troca o estado, e um `Behavior` curto faz a transição.
- **Cantinhos da tela** (`modules/ii/screenCorners/ScreenCorners.qml`): uma
  faixa fina por borda (em cima e embaixo), cada uma com os dois cantos daquela
  borda (`CornerItem`). São 4 janelas em vez de 8, e cada janela tem o próprio
  contexto de render (uns 5 MB). A máscara só pega o clique nas zonas de canto
  que abrem as laterais.
- **Fundo do modo de arrumar** (`mosaic-desk-backdrop`, `Desktop.qml`): só fica
  mapeado durante o arrumar. Antes era uma superfície transparente de tela
  cheia acima das janelas, composta em todo quadro. Para manter a ordem que o
  impasto precisa, o fundo mapeia primeiro e o desk sobe para o nível Top 60 ms
  depois (`deskUp`). Ele também nunca tinha funcionado: o stub
  `desk/services/WallpaperService.qml` devolvia "". Agora devolve o papel do
  Mosaic, e no modo de arrumar o papel esconde as janelas, como no impasto.
- **Cuidado ao medir:** `qs -c mosaic kill` derruba uma instância só. Se outra
  ficou viva, por exemplo de um relançamento que falhou, ficam dois shells
  desenhando. Confira com `pgrep -fc "^qs -c mosaic$"`.

Medição final, com um shell só e música tocando: GPU em 21% e 25 W (antes,
40–70% e 30–41 W), CPU em 9% de um núcleo e RAM em cerca de 845 MB, dos quais
cerca de 600 MB são a base do QML.

## 25. As laterais no tema Mosaic

No tema Mosaic (`root.mo`), as duas laterais seguem a mosaic-ui:
- **Fundo:** sólido e escuro (`surfaceContainerLowest`), com o campo de pontos
  parado (`sidebars/MoDots.qml`, o shader do desk). Ele é desenhado uma vez e
  muda de lugar a cada abertura (`shuffle()`).
- **Teclas** (`sidebars/MoTecla.qml`, a `.mo-tecla` da mosaic-ui): uma face
  chapada sobre um corpo mais escuro. Ao apertar, a face afunda; ligada, fica
  na cor primária. Viram teclas os atalhos rápidos, os botões do cabeçalho e do
  celular, as abas da esquerda e as setas e o dia de hoje no calendário.
- **Sliders:** 20 blocos, acesos até o valor.
- **Calendário:** próprio (`MoCalendar`), com uma grade 7×6 de tesselas.
- **Placas:** sólidas, com linha fina e sombra de objeto.
- **Vidro:** desligado nas laterais (`MosaicGlass`). O preset delas, com
  valores fora da faixa, gerava os brancos e as franjas de arco-íris nas
  bordas.
- **Ícones e texto:** os Material de sempre e a fonte de interface, em caixa
  normal. Os ícones em pixel e a fonte mono maiúscula cansavam a leitura num
  menu; ficam para os widgets do desk.
- **Por dentro, ainda do ii:** as páginas da esquerda (tradutor, tarefas, IA) e
  a lista de notificações.

**Widget de foto (§18):** no tema Mosaic, os widgets "sobre a imagem"
(`onPicture`) não ganham mais a camada de sombra (`body.layer`). O
`MultiEffect` pintava toda a margem extra da camada (`reach`) como uma moldura
cinza borrada em volta da foto, e uma foto não precisa de sombra para ser lida.

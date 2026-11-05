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
`scripts/mosaic-os.sh ligar|desligar|alternar` (Ctrl+Super+M chama `alternar`). O que ele faz:
1. `hyprctl eval 'hl.env("qsConfig", "mosaic")'` grava no Hyprland qual shell está ativo;
2. `hyprctl reload config-only` recarrega o Hyprland. O `rules.lua` vê `qsConfig == "mosaic"` e carrega `hypr/mosaic.lua`;
3. mata o `qs` atual e inicia `qs -c mosaic` (ou `qs -c ii`).

No `variables.lua`, `hl.env("qsConfig", os.getenv("qsConfig") or "ii")` faz a escolha sobreviver a reloads.

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

- `softBlock(c)` mistura uma cor do Matugen com a superfície (32%): os blocos suaves. `softTone(c)` mistura mais (72%), para tons bem apagados. A mistura é `ColorUtils.mix(a, b, t)`.
- `Connections { target: Notifications; function onNotify... }` faz o mascote pular a cada notificação, emitindo o sinal `jumpRequested`.
- O **`IpcHandler "island"`** tem `toggle`, `close`, `poke` e `compass`.

### 5.2 A janela por monitor
- 560×660 transparente, grudada no topo, `exclusionMode: Ignore` (não empurra janelas), camada **Overlay**.
- **`mask`**: só a ilha (`notch`) e o sensor da borda recebem o mouse. O resto da janela é "fantasma".
- **`setOpen(open, byHover)`** abre ou fecha o painel nesse monitor.
- **`pinned`**: aberto por clique. Com ele ligado, `keyboardFocus: OnDemand` deixa o Esc funcionar, e o `HyprlandFocusGrab` fecha o painel ao clicar fora (é o mesmo mecanismo das laterais do ii).
- **Sensor da borda** (`edgeSensor`, 360×2 px no topo): um `HoverHandler` abre o painel ao passar o mouse, e o `leaveTimer` (350 ms) fecha quando o mouse sai, se tiver sido aberto assim.

### 5.3 Gatilho da bússola (Super)
```qml
function updateCompass() {
    if (!GlobalStates.superDown) win.compassOpen = false;       // soltou: fecha
    else if (notchHover.hovered) win.compassOpen = true;        // Super + mouse na ilha: na hora
}
Timer { id: superHold; interval: 260
    onTriggered: if (GlobalStates.superDown && GlobalStates.superReleaseMightTrigger && win.isFocusedScreen) win.compassOpen = true }
```
- `GlobalStates.superDown` vem do ii.
- `superReleaseMightTrigger` vira `false` quando outra tecla é apertada junto (Super+Enter). Por isso o timer de 260 ms só abre a bússola se o Super estiver **sozinho**, e ela não pisca nos atalhos.
- `onCompassOpenChanged` zera `superReleaseMightTrigger`, para soltar o Super depois da bússola não abrir também a busca do ii.

### 5.4 O entalhe (`notch`): o "cérebro" da forma
```qml
readonly property string mode: compassOn ? "compass" : root.hasNotifs ? "notifs" : win.panelOpen ? "panel" : ""
```
Um único texto decide tudo, por prioridade: bússola > notificações > painel > repouso. Largura, altura, conteúdo e cor são bindings de `mode`, então ao trocar de modo tudo se anima junto.
- **Tamanhos:** repouso 64×32; bússola 380×124; painel e notificações com 460 de largura e altura seguindo o conteúdo (até 640).
- **`morph`** vai de 0 (ilha) a 1 (bússola), com `Behavior` de 520 ms `OutBack`. Forma, cores e ponteiro leem `morph`, então mudam juntos e com mola.
- **Tela cheia:** `fullscreenHere` procura em `HyprlandData.windowList` uma janela da área atual desse monitor com `fullscreen > 0`. Se achar e a ilha estiver em repouso, um `Translate` a sobe para fora da tela (300 ms `OutCubic`).

### 5.5 A superfície: como vira meio oval
O truque é que um `Rectangle` com `radius` igual à metade da largura é um círculo, e as bordas do Qt são lisas (antisserrilhadas).
```qml
readonly property real cornerRadius: notch.radius + (notch.width / 2 - notch.radius) * m   // m = morph
readonly property real squash: 1 + (2 * notch.compassHeight / 380 - 1) * m
y: -cornerRadius * squash                // a metade de cima fica fora da tela
height: notch.height / squash + cornerRadius
transform: Scale { yScale: surface.squash }   // achata o círculo → oval
```
- Com `m = 0`, o raio é o normal (cantos arredondados) e `squash = 1`.
- Com `m = 1`, o raio vira metade da largura (meio círculo). O `Scale` achata na vertical (124×2/380 ≈ 0,65), o que deixa um meio **oval** de 124 px.
- A cor é um `Gradient` horizontal primária→secundária→terciária, misturado à superfície em proporção a `morph`: o "banho" de cor da bússola.

### 5.6 O mascote como ponteiro
```qml
size: 18 + 10 * notch.morph
rotation: notch.mode === "compass" ? compassContent.offset * 90 : 0
```
Na bússola, a marca cresce e gira 90° por área. Como `offset` já é animado com mola (seção 6), o giro sai com mola de graça. Cutucar só funciona no modo painel.

### 5.7 O conteúdo
Um `Loader` só fica ativo nos modos `panel` e `notifs`. Fechado, o conteúdo é **destruído** e não gasta nada.
- **notifsView:** o `NotificationListView` do ii com `expandAll: true` (a propriedade nova mostra as notificações inteiras).
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
Arquivo: `modules/mosaic/island/Mascot.qml`. Quatro blocos (`Repeater` de 4 `Rectangle`) nos tons primária, secundária, terciária e texto.
- **`mood`** = `dizzy` ou `baseMood` (`idle`, `dance`, `think`).
- **`jump()`:** `SequentialAnimation` em `body.y`, sobe 45% do tamanho (160 ms `OutQuad`) e desce com `OutBounce` (420 ms).
- **dance:** cada bloco tem uma animação infinita de `danceOffset` com um atraso diferente (`PauseAnimation`), formando um equalizador.
- **think:** um `Timer` incrementa `turn`, e cada bloco anda uma casa no sentido horário (`slot`), com `Behavior` `OutBack`.
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

## 9. O que mudou no ii
Arquivos herdados que foram alterados (o resto é igual ao ii):
- `panelFamilies/IllogicalImpulseFamily.qml`:
  - comentados: `Bar`, `Dock` e `VerticalBar` do ii e o `NotificationPopup`;
  - adicionados: `Island` e `MosaicDock`.
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

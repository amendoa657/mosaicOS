# Mosaic OS: visão (em construção)

Shell em Quickshell, nascido de uma cópia do ii (`~/.config/quickshell/ii`, 04/11/2026). Liga e desliga com `scripts/mosaic-os.sh ligar|desligar`. As configurações ficam em `~/.config/mosaic-os`.

## Decisões
| # | Tema | Decisão |
| --- | --- | --- |
| 1 | Público | Primeiro, o próprio usuário. Depois, avaliar se vira a mosaic-ui de verdade para leigos. |
| 2 | Sensação | Brincalhão, com bastante liquid glass, como a sessão atual (hyprglass). |
| 3 | Brincalhão | Animações elásticas, sons, mascote/personagem (aprofundar) e surpresas escondidas. |
| 4 | Vidro | ~~Vidro pixelado~~ **arquivado** (04/11, o usuário não gostou). Fica o **liquid glass**, com o preset **"vivo"** do Mosaic OS (mais lente, refração, arco-íris e brilho que o "clear" do ii). |
| 5 | Layout | Junção de **dock protagonista completo** com **ilha flutuante**. |
| 6 | Essenciais do ii | Áreas de trabalho, lateral esquerda (**sem a aba Anime**), lateral direita, widgets no fundo. |
| 7 | Mascote | **A marca viva:** os 4 blocos da Mosaic com olhinhos, que se rearranjam, pulam e viram outras formas. **Mora na ilha.** |
| 8 | Dock × ilha | **Ilha em cima** (o que está vivo), **dock completo embaixo**. |
| 9 | Áreas de trabalho | Na ilha (a ilha vira a bússola, ver abaixo). Mouse numa parte da ilha → surge um **meio círculo tipo bússola** com um ponto por área (com os símbolos dos apps); o **scroll gira a bússola** suavemente e troca de área. |
| 10 | Gatilho da bússola | **Super segurado**, com o mouse na ilha (abre na hora) ou em qualquer lugar (abre depois de ~0,26 s com o Super sozinho, para não piscar nos atalhos Super+tecla, no monitor em foco). Com o painel da ilha aberto, o Super também a transforma na bússola. |
| 11 | Pontos da bússola | **Ícone principal** do app de cada área, com contador (+2) quando tem mais. |
| 12 | Dock | **Iniciar/lançador** (a marca), **apps fixos e abertos**, **status e relógio** (abrem a lateral direita). Sem pastas/lixeira. |
| 13 | Ilha parada | **Mascote + nome do app em foco.** |
| 14 | Reações do mascote | **Música** (os blocos dançam no ritmo, pelo cava) e **notificação** (pula e olha para o aviso). |
| 15 | Ilha viva | **Depende do evento:** o que é rápido cresce para os lados; o que tem ação vira cartão para baixo. |
| 16 | Sons | **Mistura por tipo:** clique de tecla nos botões, bolha de vidro em abrir e fechar, chiptune curtinho no mascote. |
| 22 | Lateral esquerda | Continua, com **duas abas: Tradutor e Tarefas** (a lista de tarefas sai da lateral direita). A IA foi para o mascote; a aba Anime sai. |
| 23 | Cores | **Papel de parede (Matugen) + os 4 tons da Mosaic** na marca e nos pixels. |
| 24 | Widgets do fundo | **Vivos com o mascote:** peças de vidro, e o mascote interage com elas (senta no relógio, olha as fotos, comemora os "dias juntos"). |
| 25 | Fontes | **As da Mosaic:** Space Grotesk na interface, JetBrains Mono em números e detalhes. |
| 26 | Ordem | **Vidro pixelado primeiro** (provar a técnica), depois o resto em cima. |
| 27 | Mascote em movimento | **Só em eventos:** parado, só pisca de vez em quando; some em jogo em tela cheia. |
| 28 | Áreas na bússola | **Por demanda, até ~50:** a bússola mostra umas 10 por vez e o scroll desliza para as próximas. |
| 29 | Tela de bloqueio | **Depois** (fica a do ii/hyprlock por enquanto). |
| 30 | Barra do ii (transição) | ~~Desce para baixo até o dock existir~~ **saiu** (04/11): o dock tomou o lugar dela. |
| 31 | Forma da ilha | **Entalhe na borda:** colada no topo, só os cantos de baixo arredondados. |
| 32 | Rosto do mascote | **Um par de olhos no meio dos 4 blocos:** a marca inteira é a cara. |
| 33 | Clique na ilha | ~~chat~~ → abre o **painel**: música (se houver), **relógio e data**, e as **ferramentas rápidas que saíram da barra de baixo** (Print, conta-gotas, Não perturbe, fita LED, bateria do celular). Com notificação na tela, abre a central. |
| 34 | Ilha em repouso | **Só o mosaico** (sem olhos, sem nome de app), **reta** (sem as curvas nas pontas), **cor e borda da barra de baixo**, sem serrilhado, e **não empurra as janelas**. |
| 36 | Painel da ilha | Relógio e data à esquerda, **clima (temperatura e cidade) no canto de cima à direita**; embaixo, as ferramentas alinhadas e, à direita, um **quadrado 2×2 de círculos de desempenho** (CPU, RAM, GPU, swap). |
| 38 | Estilo da ilha | Superfície e **contorno da barra de baixo**; dentro, blocos em **cores suaves que se misturam**: degradês entre tons vizinhos do Matugen misturados à superfície (hora primária→secundária, clima secundária→terciária, música terciária→primária), texto neutro. |
| 39 | Medidores | **Copos d'água:** quatro copinhos (CPU, RAM, GPU, swap) só com o ícone, sem texto nem número; a água sobe numa mola e a superfície balança (só com o painel aberto). |
| 40 | Música | **Abaixo da hora e do clima.** |
| 41 | Mouse no topo | Levar o mouse à borda de cima **abre**; aberta assim, **fecha quando o mouse sai**. Um clique fixa. |
| 42 | Tela cheia | A ilha **some em tela cheia** (sobe para fora da borda) e só volta com o mouse no topo, que abre o painel. Notificações e bússola continuam aparecendo. A ilha passou para a camada Overlay, para ficar acima da janela em tela cheia. |
| 43 | Base hyprdots (05/11) | Do hyprdots vieram **as técnicas, não o visual**: a mola com gelatina, o goo, os eventos na ilha e o derramar do papel de parede, tudo no estilo Mosaic. Layout continua só ilha em cima + dock embaixo. |
| 44 | Ilha fechada | **Marca · hora · clima**, pequenininha, com **degradê suave Mosaic** (14% dos tons). |
| 45 | Eventos na ilha | **Volume e brilho** (no lugar do OSD do ii), **música nova**, **print** e **celular fraco**, por um instante ao lado da marca, com um pulinho. Painel e bússola continuam como estavam. |
| 46 | Notificação | **Bolha que gruda:** sai de baixo da ilha com um pescoço líquido (goo). Clique na ilha agora sempre abre o painel. |
| 47 | Papéis de parede | **Seletor Mosaic** (busca, Recentes, filtro por cor, aleatório, teclado) e **derramar**: o novo escorre por cima do antigo a partir do clique. |
| 48 | Ilha flutuante (05/11) | **Como a do hyprdots:** escura, em pílula, flutuando 6 px abaixo da borda. Painel vira cartão arredondado e a bússola, uma cúpula (topo arredondado, base em meio oval). Substitui as decisões 31 e 34 (entalhe colado na borda). |
| 49 | Logo novo | O mascote usa o **logo do Mosaic OS** (quadrado grande, barra alta, barra larga e quadradinho) nas **cores do Matugen**. |
| 50 | Shell lembrado | O último shell escolhido (ii ou Mosaic OS) fica salvo e volta ao reiniciar o PC; trocar papel de parede não reinicia mais o Quickshell. |
| 51 | Dock v2 (05/11) | **Vidro claro** com os ícones pousados, **onda sutil tipo macOS** no hover, sem relógio (fica na ilha); a **bandeja foi para o painel da ilha**, no bloco da hora, do lado direito. |
| 52 | Notificação unida (05/11) | A bolha cai e, depois, **se funde à ilha** numa forma só. |
| 53 | Celular na ilha | Pelo **KDE Connect** (ouvindo o D-Bus): carregando (bateria d'água, bolhas, faíscas), ligação tocando/atendida/perdida (anéis, silenciar), conectou/saiu e bateria fraca. Animações portadas do hyprdots. |
| 54 | Menu iniciar (05/11) | **Tocar o Super:** um cartão cai da ilha e se funde a ela (como a notificação), com a **busca do ii inteira** (apps, conta, comando, web, área de transferência, emojis, ações). Vazio, mostra só os prefixos e os **apps recentes**. Sem as miniaturas das áreas (a bússola cuida delas); tamanho médio (640). |
| 55 | Bússola v3 (05/11) | ~~Pílula em carrossel~~ (não agradou) → **cúpula de volta, bem mais sutil**: 300×92, blocos pequenos e suaves, número discreto, **a marca em cima** como ponteiro. |
| 56 | Notas (05/11) | Botão **Notas** nas ferramentas da ilha e **Super+Alt+N**: o cartão fundido à ilha com **abas** (cada uma um `.md` em `~/Documentos/Notas`), texto simples em que `* ` vira bolinha, salvando sozinho. |
| 57 | Temas (05/11) | **Mosaic** (cores do papel de parede pelo Matugen) e **Gruvbox escuro médio** (fixo). Valem para o Quickshell e o Hyprland, não para os apps. O seletor fica no topo do seletor de papéis de parede. |
| 37 | Clique e mosaico | **Qualquer lugar da ilha abre**; o mosaico **só brinca com a ilha aberta**; **clicar fora (ou Esc) fecha**. |
| 35 | Notificações | Aparecem **inteiras** na ilha (o componente de notificação do ii, com ações), não resumidas; o aviso do canto saiu. |
| 18 | IA (era a lateral esquerda) | **O mascote é a IA:** a ilha vira um chat de vidro para baixo e a marca "pensa" (os blocos giram) enquanto responde. |
| 19 | Lateral direita | **Lateral de vidro** (botões rápidos, notificações, calendário...), redesenhada. |
| 20 | Lançador | ~~Tela cheia de vidro~~ → virou o **menu iniciar da ilha** (decisão 54), integrando a **busca avançada do ii** (overview: apps, calculadora, comandos, emojis, área de transferência...). |
| 21 | Surpresas | Cutucar o mascote (fica tonto, desmonta e remonta), datas especiais (dia 22 de cada mês, aniversário, Natal...), arrastar o mascote para fora da ilha (cai, quica no dock, volta andando), código secreto (modo festa). |
| 17 | Vidro pixelado | Painéis **abrem e fecham numa onda de quadradinhos de vidro**; **refração em blocos**, como um mosaico de vidro. |

## Para lembrar depois
- **Cartões soltos de vidro** (cada coisa da central como um cartão que se arrasta pela tela): o usuário quer experimentar mais pra frente. Lembrar ele.

## Em aberto
- Vidro pixelado: viável no hyprglass (refração em blocos) ou como shader no Quickshell?
- Detalhes de cada peça conforme for construindo.

## Vidro pixelado: feito e arquivado (04/11/2026)
- **Refração em blocos:** fork do hyprglass em `~/hyprglass-mosaic` (branch `mosaic`), com a opção `mosaic_size` só de preset (padrão 0, idêntico ao original). Preset `mosaico` (14 px) e camadas em `hypr/mosaic.lua`, lido pelo `rules.lua` só com `qsConfig = mosaic`.
- **Onda de quadradinhos de vidro:** provado no Hyprland aninhado (`~/hyprglass-mosaic/mosaic-os/teste`). O hyprglass recorta o vidro pela transparência da camada, então um painel que nasce em onda de pixels faz o vidro nascer em pixels. Entra em cada painel (ilha, dock...) quando eles forem construídos.
- **Na sessão:** `execs.lua` carrega o fork; `rules.lua` ganhou uma linha; `variables.lua` mantém o `qsConfig` trocado ao recarregar. Cópias dos originais em `hypr/backup-*`; `hypr/desfazer-vidro.sh` volta tudo.

## Ilha: 1ª versão (04/11/2026)
`modules/mosaic/island/` (Island.qml, Mascot.qml), carregada na família ii do Mosaic OS; a barra do ii foi para baixo (`bar.bottom` no config do Mosaic OS).
- Entalhe de vidro colado no topo, com curvas onde encontra a borda; cresce com mola (OutBack).
- Repouso: marca viva (olhos que piscam a cada 3,5 a 7 s) + nome do app em foco (ou "Área N").
- Música tocando: cresce para os lados com capa e título; o mascote dança.
- Notificação: o mascote pula e a ilha desce num cartão por 4,5 s.
- (v2) Clique → painel com música, relógio e ferramentas rápidas; notificações inteiras; repouso só com o mosaico. O chat com a IA saiu do clique (a decisão 18 fica em aberto).
- Cutucar o mascote 5 vezes: ele fica tonto.
- `qs -c mosaic ipc call island chat|controls|close|poke`.

## Bússola: 2ª versão (04/11/2026)
A **própria ilha vira a bússola**, com animação: ela estica com mola e os cantos de baixo arredondam até ser um meio círculo, a superfície ganha um banho suave dos tons do Matugen, e a marca Mosaic cresce e vira o **ponteiro** (gira um quarto a cada área). As áreas são **blocos Mosaic** coloridos (cada número sempre no mesmo tom), com o ícone da maior janela e "+N"; a atual é maior e mais viva; elas saem em cascata do centro para fora. Scroll gira e troca (1 a 50, ~10 à vista); clique num bloco vai até ele. Super + mouse na ilha; `ipc call island compass` sem o Super.
- (v3) Forma de **meio oval** (124 px de altura em vez de um meio círculo de 190): um círculo achatado por escala, para manter a borda lisa. Os blocos seguem um arco oval. Super segurado abre em qualquer lugar (decisão 10).

## Dock: 1ª versão (04/11/2026)
`modules/mosaic/dock/MosaicDock.qml`, no lugar da barra e do dock do ii. Flutua centralizado embaixo **por cima das janelas** (não reserva espaço): aparece na área vazia; com janelas, some e só sobe quando o mouse desce até a borda de baixo (uma faixa larga de 10 px; fica enquanto ele estiver no dock ou entre ele e a borda), com a superfície e o contorno da ilha (e o liquid glass na camada `quickshell:dock`). Tem três blocos:
- **Marca Mosaic** (degradê primária→secundária): o clique abre o lançador (por enquanto a visão geral com a busca do ii) e o mascote pula; o botão direito abre a lateral esquerda.
- **Apps** fixos e abertos (lista do ii, `dock.pinnedApps`), com um separador entre eles:
  - o ícone sob o mouse cresce com um pulinho;
  - o app ativo fica sobre um bloco no seu tom, e cada janela aberta é um pontinho;
  - o ícone pula enquanto o app abre;
  - clique abre ou alterna as janelas, o botão do meio abre outra, o direito fixa ou desafixa;
  - o nome aparece no hover.
- **Status** (degradê secundária→terciária): bandeja, Não perturbe (quando ligado), rede, Bluetooth, volume, hora e data. O clique abre a lateral direita e o scroll muda o volume.

## Ilha v3 + papéis de parede (05/11/2026)
Técnicas do [hyprdots](https://github.com/fedyaqq34356/hyprdots) (GPL-3.0) portadas e documentadas no DOCS.md (5.4, 5.9–5.11 e 11): `MosaicSpring` (mola com velocidade → gelatina), `shaders/goo.frag` (bolha que gruda), eventos e o seletor com `shaders/pour.frag`. O OSD e o seletor do ii saíram da família.

## Próximo
- Dock: prévia das janelas no hover? Esconder em tela cheia?
- Lançador em tela cheia de vidro (o clique na marca).

## Desempenho: primeira geral (04/11/2026, só anotado, nada corrigido)
Medido com o shell parado: **~830 MB de RAM (RSS)** e CPU entre 0 e 3,5% (média de 3 amostras). A CPU parada está boa. A RAM é o problema para PC fraco, e quase tudo vem do que foi herdado do ii. Itens marcados com ? são hipóteses a medir.
- **Tudo do ii carrega no início e fica na memória**, em cada monitor: laterais (chat de IA, Anime, tradutor), visão geral, seletor de papel de parede, cheatsheet, teclado na tela, tradutor de tela, controles de mídia. Passar para `LazyLoader` ativo só quando abertos deve ser o maior ganho. Remover de vez a aba Anime e o chat de IA da lateral esquerda (decisão 22).
- **Widgets do fundo** (fotos ×2, aniversário, calendário, relógio, mídia, clima) em dois monitores: as fotos são imagens decodificadas em tamanho cheio? Pôr `sourceSize` e criar só no monitor principal.
- **Bússola:** é criada com a ilha e nunca é destruída (13 blocos com `IconImage`). Cada bloco refaz um `windowList.filter` a cada mudança de janela, ou seja 13 filtros × 2 monitores. Pôr num `Loader` ativo só no modo bússola e calcular um mapa área→janelas uma vez só.
- **Copos d'água do painel:** um `Canvas` repintado a cada quadro por `FrameAnimation`, ×4, enquanto o painel está aberto. Está ok porque o Loader destrói tudo ao fechar, mas ainda pesa em GPU/CPU fraca. Trocar por `ShaderEffect` ou por uma onda em ~20 fps.
- **Mascote:** o timer de piscar roda sempre que está visível, na ilha e no dock, por monitor. É barato, mas dá para pausar em tela cheia (decisão 27).
- **Dock:** `TaskbarApps.apps` recria todos os objetos a cada evento de janela; `emptyWorkspace` faz um filtro na lista inteira de janelas.
- **hyprglass "vivo":** refração, aberração cromática e fresnel em todas as camadas (ilha, dock, laterais) custam GPU a cada quadro do compositor. Para PC fraco, ter um preset "leve" (só blur) ou nenhum.
- **Vazamento do dock: medido, não há.** `TaskbarApps` cria objetos com `createObject(null, ...)` sem `destroy()`, mas o coletor de lixo do JS recolhe os antigos. No Hyprland aninhado, abrindo e fechando 150 janelas (kitty), o RSS ficou em 619→618 MB e chegou a cair. Continua sendo trabalho jogado fora a cada evento (recria a lista inteira), mas não acumula. Também a medir: o `FileView` da GPU (lido só com o painel aberto, ok) e os `Connections` dos ícones do dock.
- **Ambiente:** o quickshell compilado para Qt 6.11 rodando no Qt 6.12 derruba o hot reload. Recompilar o pacote.
- **Como medir depois:** `ps -o rss,pcpu -p $(pgrep -x qs)` antes e depois de cada mudança; comparar com `qs -c ii`; e o teste das 200 janelas para o vazamento.

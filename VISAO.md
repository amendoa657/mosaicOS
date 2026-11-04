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
| 9 | Áreas de trabalho | Na ilha. Mouse numa parte da ilha → surge um **meio círculo tipo bússola** com um ponto por área (com os símbolos dos apps); o **scroll gira a bússola** suavemente e troca de área. |
| 10 | Gatilho da bússola | Só com **Super segurado + mouse na ilha**. |
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
| 18 | IA (era a lateral esquerda) | **O mascote é a IA:** a ilha vira um chat de vidro para baixo e a marca "pensa" (os blocos giram) enquanto responde. |
| 19 | Lateral direita | **Lateral de vidro** (botões rápidos, notificações, calendário...), redesenhada. |
| 20 | Lançador | **Tela cheia de vidro**, grade de apps com páginas, integrando a **busca avançada do ii** (overview: apps, calculadora, comandos, emojis, área de transferência...). |
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

## Próximo
- Ilha + mascote (a marca viva).

---
layout: post
title: "PinkyPawn Chess - 02: Do 'Hello World' aos Primeiros Testes Empíricos"
date: 2026-03-13T18:00:10-03:00
tags:
  - chess
  - xadrez
  - github
  - engine
  - python
  - lichess
  - bot
---

No [post anterior](posts/hello-world-pinkypawn-00), introduzimos o **PinkyPawn**, nossa engine de xadrez experimental construída em Python com foco em heurísticas intuitivas em vez de algoritmos de busca profundos. Exploramos os princípios básicos que guiam seu jogo: desde a prioridade máxima ao xeque-mate até regras simples como controle do centro e prevenção de vulnerabilidades. Com uma arquitetura inicial de `1-ply` que avalia apenas o próximo lance, o **PinkyPawn** demonstrou ser capaz de evitar erros grosseiros, mas revelou limitações claras em planejamento estratégico.

| ![imagem da logo do pinkypawn](https://i.postimg.cc/LX2FnCjG/pinkypawn-logo.png)
| :--: |
| PinkyPawn: A Simples Chess Engine |


Agora, avançamos nessa jornada. Nesta continuação, documentamos os primeiros testes empíricos contra diversos oponentes, desde humanos amadores (eu!) até bots especializados, revelando tanto as forças quanto as fraquezas inerentes a uma engine baseada puramente em regras heurísticas simples.

Os resultados dessas batalhas iniciais não apenas validam nossa filosofia de desenvolvimento gradual, mas também traçam o caminho para aprimoramentos futuros. Vamos explorar como o **PinkyPawn** se comporta em cenários reais de jogo, diagnosticar suas deficiências e esboçar os próximos passos rumo a uma inteligência mais "humana" no xadrez.

## Os Primeiros Testes: Avaliando a Ausência de Profundidade

Para validar essa arquitetura inicial, conduzimos uma série de partidas em ritmo rápido (5+0). Os resultados evidenciaram rapidamente as severas limitações táticas e estratégicas de uma busca 1-ply.

Contra um oponente humano de nível amador (eu com meus ~1200 de rating Lichess), **PinkyPawn** foi superado em todas as partidas, registrando 0 vitórias em 5 jogos. As heurísticas, ainda que funcionais em nível rudimentar, não foram suficientes para lidar com um planejamento humano básico.

O teste de estresse mais revelador ocorreu contra o bot [**Maia1 (1405 Elo)**](https://lichess.org/@/maia1), uma rede neural que reflete um estilo de jogo humano sólido. O PinkyPawn sofreu reveses rápidos, recebendo **4 xeques-mates em menos de 20 lances** em uma série de 5 derrotas. O experimento demonstrou de forma clara que a negligência do desenvolvimento harmonioso de peças em detrimento do ganho material imediato é fatal perante qualquer estratégia coordenada.

## O Reflexo da Profundidade Limitada: Repetições e o Confronto contra Stockfish Level 2

A análise das partidas revelou padrões de jogo interessantes e, em grande medida, limitados pela falta de visão de médio prazo.

Quando **PinkyPawn** não encontra táticas imediatas ou capturas de *"1-ply"* vantajosas, sua tendência à passividade se acentua. Isso ficou evidente contra *bots* de menor *rating*, como [**sargon-1ply (1179 Elo)**](https://lichess.org/@/sargon-1ply) e [**larryz-alterego (863 Elo)**](https://lichess.org/@/larryz-alterego). Nessas séries, a engine evitou variações complexas e frequentemente optou por posições fechadas, resultando em 6 empates por **tripla repetição** de lances. 

Entretanto, o desempenho do PinkyPawn contra o **Stockfish Level 2** (uma configuração consideravelmente reduzida da engine líder) surpreendeu. Em uma série de 5 partidas, PinkyPawn alcançou **4 vitórias e 1 empate**:
- Duas vitórias consistiram em **mates conduzidos de pretas**.
- Duas vitórias ocorreram devido à **desistência do Stockfish** após o jogo atingir o limite programado de **150 lances**. Nesses cenários, a obstinação de PinkyPawn em não perder peças e manter uma defesa rígida estendeu as partidas até a exaustão dos limites aceitáveis do oponente.

### Resultados Consolidados (v0.2.0)

*(Ritmo: 5+0, Cor Original: Aleatória)*

| Oponente | Rating Lichess | Partidas | Vitórias (Pinky) | Empates | Derrotas (Pinky) | Observações |
| :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **Humano (eu!)** | ~1200 | 5 | 0 | 0 | 5 | - |
| **Maia1** | 1405 | 5 | 0 | 0 | 5 | 4 posições de mate em menos de 20 lances. |
| **sargon-1ply** | 1179 | 5 | 0 | 1 | 4 | Empate por tripla repetição. |
| **larryz-alterego** | 863 | 5 | 0 | 5 | 0 | Alto índice de empates por tripla repetição. |
| **Stockfish Level 2** | - | 5 | **4** | **1** | **0** | **2 mates de pretas e 2 vitórias sob limite de tempo/lances (>150 lances).** |

*Rating PinkyPawn: 939*

## Diagnóstico Técnico do PinkyPawn

Os resultados desta primeira fase documentam com clareza as características sintomáticas de uma heurística simples:

1. **Visão Restrita:** A avaliação exclusiva do próximo lance impede o desenvolvimento de planos como controle de espaço ou domínio de colunas semiabertas.
2. **Priorização Material Absoluta:** Uma forte aversão a ceder vantagens materiais, resultando no abuso da regra de tripla repetição em posições estruturalmente passivas.
3. **Deficiência em Dinâmica de Estruturas:** O mecanismo atual não reconhece conceitos como fraquezas em casas de uma mesma cor, peões passados não apoiados, nem peões dobrados, limitando o valor estático da posição.

## Implementos Futuros: Transição Estrutural (Roadmap v0.3.0)

Avançar no desenvolvimento do PinkyPawn demanda, agora, expandir o discernimento de avaliação posicional sem necessariamente injetar buscas computacionalmente pesadas, como *minimax* ou *alpha-beta*, em um primeiro momento. 

Os aprimoramentos previstos para a versão **v0.3.0** buscam ensinar à engine fundamentos táticos primários que aproximam seu jogo de uma lógica de clube mais tradicional:

1. **Piece-Square Tables (PST):** Introduzir pontuação escalonada dependendo da casa que a peça ocupe. A engine discernirá que cavalos nas bordas perdem mobilidade estrutural, enquanto bispos centralizados fornecem maior controle quantificável.
2. **Princípios de Abertura:** Implementação de penalidades severas no cálculo se a Dama entrar no jogo cedo de forma ineficiente, e bônus pelo desenvolvimento das peças menores.
3. **Mecânica Básica Aprimorada:** Revisão nos incentivos sobre a progressão de peões e valorização acentuada sobre movimentos de promoção.
4. **Segurança do Rei:** Estabelecimento de defensores vitais ao Rei, avaliando o estado contínuo do escudo de peões mesmo após a abertura.

## Conclusão

A fase v0.2.0 demonstrou a eficiência e a deficiência de conceitos heurísticos puros em processamento pontual de lances. Validamos que uma engine simples pode, consistentemente, evitar erros grosseiros que envolvam vantagem de material direta, porém não sobrevive ao nível tático fundamental perante a inércia dos ataques coordenados.

Esperamos que o avanço na versão **v0.3.0** refine esses aspectos, introduzindo dinâmicas conhecidas de todo praticante de xadrez: estruturação de centro, espaço tangível e priorização posicional antes do engajamento tático. As fundações de xadrez mais naturais estão sendo preparadas antes dos algoritmos puros de busca em profundidade serem ativados.

Até mais!
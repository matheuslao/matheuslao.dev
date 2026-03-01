---
layout: post
title: "Hello World, PinkyPawn! O Início de uma Jornada Empírica no Xadrez"
date: 2026-03-01T18:00:10-03:00
tags:
  - chess
  - xadrez
  - github
  - engine
  - python
  - lichess
  - bot
---

Escrever uma engine de xadrez do zero é possivelmente um dos *"Hello World!"* mais legais que um desenvolvedor que curte o esporte pode tentar. Desde que [Deep Blue chocou o mundo em 97](https://www.britannica.com/topic/Deep-Blue), até a [supremacia insana do Stockfish nos dias atuais](https://tcec-chess.com/), criar uma inteligência artificial em xadrez parece coisa de deuses da matemática e otimizadores incansáveis de código em C++.

Mas e se o objetivo não for ganhar do Magnus Carlsen? 

E se quisermos apenas **nos divertir** programando e entendendo o jogo de uma maneira mecânica? É exatamente daí que nasce **PinkyPawn**.

## A Filosofia do Projeto: Um Laboratório Pessoal

| ![imagem da logo do pinkypawn](https://i.postimg.cc/LX2FnCjG/pinkypawn-logo.png)
| :--: |
| PinkyPawn: A Simples Chess Engine |


**PinkyPawn** é um bot de xadrez que joga no [Lichess](https://lichess.org/@/PinkyPawn) e está disponível para jogar contra você, sempre que estiver on-line (estou ainda trabalhando nisso!)

Link do Perfil no Lichess: [https://lichess.org/@/pinkypawnbot](https://lichess.org/@/pinkypawnbot)

Link do projeto no Github: [https://github.com/matheuslao/PinkyPawn](https://github.com/matheuslao/PinkyPawn)

**PinkyPawn** é um projeto pessoal ("for fun"), nascido da curiosidade de entender como programar regras e conceitos de xadrez em Python. O objetivo aqui **nunca** foi criar o próximo Stockfish ou AlphaZero. A nossa premissa é construir uma inteligência de jogo **empírica** e intuitiva.

O que isso quer dizer?

Em vez de focar primariamente em cálculos puros com algoritmos de busca imensos (que avaliam milhões de posições por segundo), estamos focando em **heurísticas**: as "regras de ouro" que os humanos usam para jogar xadrez. Como traduzimos "centralize seus cavalos", "não tire a dama cedo" ou "crie peões passados no final" para linhas de código que um computador entende? 

**PinkyPawn** joga xadrez tentando entender a posição "*posicionalmente*" de forma muito humana e vamos evoluir sua inteligência de um estágio praticamente embrionário até ela atingir um forte entendimento tático e estratégico (pelo menos é o que espero! :D).

## Como PinkyPawn Funciona Hoje?

Para dar início, implementamos um pequeno conjunto de 6 princípios heurísticos super básicos além do início de um sistema de avaliação [1-ply](https://www.chessprogramming.org/Ply) para algumas delas. A engine no código atual ([`pinkypawn_engine.py`](https://github.com/matheuslao/PinkyPawn/blob/0.2/bot/engines/pinkypawn_engine.py)) avalia todos os lances legais fornecidos pelo [`python-chess`](https://github.com/niklasf/python-chess) usando essas heurísticas e joga o movimento que tirar a maior "nota". 

Ela atribui pontos baseada em:

1. **Checkmate:** Obviamente a maior prioridade. Se for mate, ela joga.
2. **Check:** Dá um pequeno bônus por atacar o rei adversário.
3. **Capture:** Pondera se uma peça inimiga capturável tem valor mais alto ou baixo. Capturar peças de alto valor (como a Dama) rende muitos pontos.
4. **Center Control:** Um bônus por mover a peça para longe das bordas e mais em direção às cruciais 4 casas centrais.
5. **Castling (Roque):** Recompensa proteger o rei cedo.
6. **Piece Vulnerability:** Tenta não entregar material. Se a jogada deixa sua peça valiosa desprotegida para o próximo turno, ela penaliza.

## E Daí?

Essas regras previnem a PinkyPawn de tomar mate do louco de forma boba, mas ela ainda tem a força e a coerência de uma pessoa iniciante nos primeiros meses de aprendizado.

Por não ter noções conceituais profundas de estrutura ou desenvolvimento, ela joga sem coesão no meio-jogo, ignora promoções na oitava fileira e repete padrões horríveis no endgame porque simplesmente não sabe "dar o xeque-mate" metódico.

Mas isso está prestes a mudar.

Nesta série de posts, vamos acompanhar esse "desenvolvimento cognitivo". Cada post mostrará a evolução do código e a introdução de novas **heurísticas naturais**, consertando as vulnerabilidades de jogo uma a uma. Será uma jornada de aprendizado técnico para desenvolvimento e também para entendermos melhor a essência deste esporte milenar.
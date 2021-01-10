---
title: "Docker Images, Cache, Dangling Layers e Container Commit"
date: 2021-01-08T13:00:10-03:00
draft: true
images:
tags:
  - docker
  - dockerfile
  - build
  - imagens
  - layers
  - cache
  - dangling
  - commit
---

Saudações!

Este é último post de uma trilogia sobre Docker Imagens, que fala sobre *Layers*. Se você ainda não viu, recomendo a leitura do [primeiro post](https://matheuslao.dev/posts/docker-imagens-empty-filesystem-layers/) onde abordamos conceitos iniciais de *layers*, falamos sobre *empty/filesystem layers* e quais instruções no Dockerfile geram camadas. No [segundo post](https://matheuslao.dev/posts/docker-images-ro-rw-layers-cow-dive/) vimos *read-only/writables layers*, *Copy on Write*, além de mostrar uma ferramenta externa que auxilia na análise das camadas.

Neste terceiro post, vamos ver mais de perto sobre *cache*, camadas órfãs e o famigerado *docker commit*.


## TL;DR.


## Cache: Performando o Build

Como característica desta série de posts sobre *layers*, vamos 'meter a mão na massa' para visualizar e entender os conceitos. A partir dos conhecimentos já adquiridos sobre imagens e *layers*, tomemos como exemplo o conteúdo do arquivo file1.txt e do Dockerfile:

```bash
#file1.txt
Primeira linha
```

```bash
#Dockerfile
FROM alpine
RUN apk add curl
WORKDIR /exemplo
COPY file1.txt .
RUN echo "Adicionando linha" >> file1.txt
```

Cronometrando (com o comando `time`) a execução do build pela primeira vez, em um ambiente limpo:

```bash
$ time docker build -t exemplo-a:1 .

Sending build context to Docker daemon  3.072kB
Step 1/5 : FROM alpine
latest: Pulling from library/alpine
801bfaa63ef2: Pull complete
Digest: sha256:3c7497bf0c7af93428242d6176e8f7905f2201d8fc5861f45be7a346b5f23436
Status: Downloaded newer image for alpine:latest
 ---> 389fef711851
Step 2/5 : RUN apk add curl
 ---> Running in e9249d7ec553
fetch http://dl-cdn.alpinelinux.org/alpine/v3.12/main/x86_64/APKINDEX.tar.gz
fetch http://dl-cdn.alpinelinux.org/alpine/v3.12/community/x86_64/APKINDEX.tar.gz
(1/4) Installing ca-certificates (20191127-r4)
(2/4) Installing nghttp2-libs (1.41.0-r0)
(3/4) Installing libcurl (7.69.1-r3)
(4/4) Installing curl (7.69.1-r3)
Executing busybox-1.31.1-r19.trigger
Executing ca-certificates-20191127-r4.trigger
OK: 7 MiB in 18 packages
Removing intermediate container e9249d7ec553
 ---> ca89869bea71
Step 3/5 : WORKDIR /exemplo
 ---> Running in 5263ca8502d1
Removing intermediate container 5263ca8502d1
 ---> 69c90849dfe1
Step 4/5 : COPY file1.txt .
 ---> 75468f2ae784
Step 5/5 : RUN echo "Adicionando linha" >> file1.txt
 ---> Running in b7360ba28cee
Removing intermediate container b7360ba28cee
 ---> be1bf1285279
Successfully built be1bf1285279
Successfully tagged exemplo-a:01

real    0m9.514s
user    0m0.092s
sys     0m0.098s
```

Nota-se que:

* 5 instruções são executadas e geram *filesystem layers*
* tempo transcorrido foi de ~9s


Se não fizermos alteração alguma e rodarmos pela segunda vez o build deste *Dockerfile*, veremos o *Cache* entrando em ação, diminuindo consideravelmente (para 2s) o tempo de construção da imagem:

```bash
$ time docker build -t exemplo-a:02 .

Sending build context to Docker daemon  3.072kB
Step 1/5 : FROM alpine
 ---> 389fef711851
Step 2/5 : RUN apk add curl
 ---> Using cache
 ---> ca89869bea71
Step 3/5 : WORKDIR /exemplo
 ---> Using cache
 ---> 69c90849dfe1
Step 4/5 : COPY file1.txt .
 ---> Using cache
 ---> 75468f2ae784
Step 5/5 : RUN echo "Adicionando linha" >> file1.txt
 ---> Using cache
 ---> be1bf1285279
Successfully built be1bf1285279
Successfully tagged exemplo-a:02

real    0m2.283s
user    0m0.122s
sys     0m0.077s
```

No processo de construção da imagem, o Docker, por *default*, vai analisar se já não há uma *layer* existente resultado da instrução presente no *Dockerfile*. Aqui é fácil perceber que, se não há alteração na instrução, **provavelmente** o *cache* seria acionado. Guardemos esta hipótese.

Vamos criar um segundo arquivo *Dockerfile*, apenas com as 3 primeiras instruções da imagem anterior e gerar uma nova imagem `exemplo-b`:

```bash
FROM alpine
RUN apk add curl
WORKDIR /exemplo
```

```bash
time docker build -t exemplo-b:01 .

Sending build context to Docker daemon  4.096kB
Step 1/2 : FROM alpine
 ---> 389fef711851
Step 2/2 : RUN apk add curl
 ---> Using cache
 ---> ca89869bea71
Step 3/3 : WORKDIR /exemplo
 ---> Using cache
 ---> 69c90849dfe1
Successfully built ca89869bea71
Successfully tagged exemplo-b:01

real    0m1.340s
user    0m0.111s
sys     0m0.098s
```

Perceba que mesmo criando uma outra imagem, a partir de um outro arquivo *Dockerfile*, o uso do *cache* aconteceu na execução das instruções.

Agora, façamos uma alteração para `FROM alpine:3.8`, alterando a imagem base (diferente da tag `latest`) que certamente baixará novas *layers* e geremos uma imagem `exemplo-c`:

```bash
FROM alpine:3.8
RUN apk add curl
WORKDIR /exemplo
```

```bash
$ time docker build -t exemplo-c:01 .

Sending build context to Docker daemon  4.096kB
Step 1/2 : FROM alpine:3.8
3.8: Pulling from library/alpine
486039affc0a: Pull complete
Digest: sha256:2bb501e6173d9d006e56de5bce2720eb06396803300fe1687b58a7ff32bf4c14
Status: Downloaded newer image for alpine:3.8
 ---> c8bccc0af957
Step 2/2 : RUN apk add curl
 ---> Running in c148a20f751a
fetch http://dl-cdn.alpinelinux.org/alpine/v3.8/main/x86_64/APKINDEX.tar.gz
fetch http://dl-cdn.alpinelinux.org/alpine/v3.8/community/x86_64/APKINDEX.tar.gz
(1/5) Installing ca-certificates (20191127-r2)
(2/5) Installing nghttp2-libs (1.39.2-r0)
(3/5) Installing libssh2 (1.9.0-r1)
(4/5) Installing libcurl (7.61.1-r3)
(5/5) Installing curl (7.61.1-r3)
Executing busybox-1.28.4-r3.trigger
Executing ca-certificates-20191127-r2.trigger
OK: 6 MiB in 18 packages
Removing intermediate container c148a20f751a
 ---> 531111105b43
Step 3/3 : WORKDIR /exemplo
 ---> Running in 76b3799ed969
Removing intermediate container 76b3799ed969
 ---> 3605f9726b5f
Successfully built 531111105b43
Successfully tagged exemplo-b:02

real    0m9.331s
user    0m0.123s
sys     0m0.072s
```

Percebeu que todas as camadas foram refeitas?

A instrução `RUN apk add curl` não foi alterada, mas houve **alteração em sua camada-pai** (*parent layer*) que invalidou o uso do *cache*, forçando a instrução a ser executada novamente e gerar uma nova camada. Em um efeito cascata, o cache também é invalidado para a instrução `WORKDIR /exemplo`, uma vez que sua *parent-layer* foi refeita.

Neste ponto, relembramos de uma parte importante no conceito de imagens: **sequência ordenada de layers**. O Docker guarda a relação entre uma camada e todas as camadas-filhas (*child layers*).

Então:

* Partindo da instrução de uma *layer* A, que está em *cache*, a próxima instrução é comparada com todas as suas *layers* filhas. Se a instrução não for igual, o *cache* é invalidado;
*


## Camadas inutilizadas: Diminua o espaço em disco consumido


## Commitando o Container e gerando uma Imagem (Não faça isso!)


## Conclusão





Abraços!

:D

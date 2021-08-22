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

Como característica desta série de posts sobre *layers*, vamos 'meter a mão na massa' para visualizar e entender alguns conceitos. 

Vamos começar baixando a imagem `alpine`para o nosso *host*:

```bash
$ docker image pull alpine

Using default tag: latest
latest: Pulling from library/alpine
801bfaa63ef2: Pull complete
Digest: sha256:3c7497bf0c7af93428242d6176e8f7905f2201d8fc5861f45be7a346b5f23436
Status: Downloaded newer image for alpine:latest
docker.io/library/alpine:latest
```

Já é de conhecimento que esta imagem possui 2 *layers*, sendo 1 *empty layer* e 1 *filesystem layer*. Se observarmos o conteúdo de nosso conhecido diretório `/var/lib/docker/overlay2`, temos a camada de sistema de arquivos da imagem (`d33d06843...`):

```bash
$ ll /var/lib/docker/overlay2/
drwx------. 5 matheus root     69 Jan 10 b00fcd7258c5d787edbfc24d401c9fd3614467e9e7c575144e97ae215fda7d4b
drwx------. 2 matheus root   8192 Jan 10 l
```

Observe também que um arquivo foi criado dentro da pasta `l`:

```bash
$ ll /var/lib/docker/overlay2/l/
-rwx------. 5 matheus root     69 Jan 10 PNXCVUHMXCLSQ3F4ZRF2OANT2O
```

Agora, usemos a imagem `alpine` para construir uma imagem nossa chamada `exemplo-a`, através do *Dockerfile* abaixo:

```bash
FROM alpine
WORKDIR /exemplo
```

Realizemos o *build*:

```bash
$ docker build -t exemplo-a .

Sending build context to Docker daemon  2.048kB
Step 1/2 : FROM alpine
 ---> 389fef711851
Step 2/2 : WORKDIR /exemplo
 ---> Running in 27c882a9f17a
Removing intermediate container 27c882a9f17a
 ---> 2b16ea74e81d
Successfully built 2b16ea74e81d
Successfully tagged exemplo-a:latest
```

No passo 01 aproveitamos a imagem alpine já existente (não fazendo novamente o download das *layers* desta), enquanto a instrução 02 é executada gerando uma nova camada (`26b86...`):

```bash
$ ll /var/lib/docker/overlay2/
drwx------. 5 matheus root     69 Jan 10 26b867cce2d86c87e5e57b347cea99f391ef34d55bfd9e9232258142e897cf2f
drwx------. 5 matheus root     69 Jan 10 b00fcd7258c5d787edbfc24d401c9fd3614467e9e7c575144e97ae215fda7d4b
drwx------. 2 matheus root   8192 Jan 10 l
```

Já sabemos que se olharmos o conteúdo do diretório `26b86...`, na subpasta `diff`, temos persistido o resultado da instrução. Agora, analisemos o conteúdo do arquivo `lower` do diretório desta camada:

```bash
$ cat /var/lib/docker/overlay2/26b867cce2d86c87e5e57b347cea99f391ef34d55bfd9e9232258142e897cf2f/lower
l/PNXCVUHMXCLSQ3F4ZRF2OANT2O
```

Sim! É exatamente o arquivo criado quando a *layer* da imagem alpine foi baixada para o nosso host. Neste ponto, percebemos o relacionamento entre as 2 camadas que estão presentes no *Dockerfile*: a instrução `FROM alpine` é a camada-pai (*parent layer*) da camada gerada pela instrução `WORKDIR /exemplo`.

Nossa nova camada também gera um identificador na pasta `l`:

```bash
$ ll /var/lib/docker/overlay2/l/
-rwx------. 5 matheus root     69 Jan 10 HL6YAF5BCDJS2L44F5QLU6KSJZ
-rwx------. 5 matheus root     69 Jan 10 PNXCVUHMXCLSQ3F4ZRF2OANT2O
```

> **Atenção**: *Cache* no Docker, por *default*, sempre é ativado/válido.


Acrescentemos mais 1 instrução ao nosso *Dockerfile* e façamos uma segunda versão da imagem:

```bash
FROM alpine
WORKDIR /exemplo
RUN echo "foo bla" > file1.txt
```

```bash
Sending build context to Docker daemon  2.048kB
Step 1/3 : FROM alpine
 ---> 389fef711851
Step 2/3 : WORKDIR /exemplo
 ---> Using cache
 ---> 2b16ea74e81d
Step 3/3 : RUN echo "foo" > file1.txt
 ---> Running in 59a2e83cff5b
Removing intermediate container 59a2e83cff5b
 ---> 5c73323b2416
Successfully built 5c73323b2416
Successfully tagged exemplo-a:2
```

Vamos analisar o que aconteceu:

* `Step 1/3`: A imagem alpine já se encontra em nosso *host*, logo não é preciso baixar as *layers* novamente;
* `Step 2/3`: Com o *cache* válido, antes de executar a instrução, Docker procura todas as *layers* filhas da instrução anterior e compara se alguma destas *layers* faz exatamente a mesma instrução a ser executada. Em nosso exemplo, já há uma *layer* existente em nosso *host* que é filha da camada `FROM alpine` e executa a instrução `WORKDIR /exemplo` (proveniente do build anterior). Logo, o *cache* é utilizado;
* `Step 3/3`: Novamente, com o *cache* ainda válido, Docker procurará se há camadas filhas da instrução anterior com a mesma instrução a ser executada. Neste exemplo, como não há, a instrução será executada, criando uma nova camada no sistema de arquivos.


Observemos agora o arquivo `lower` da nova camada gerada pela instrução do passo 03, assim como o conteúdo da pasta `/var/lid/docker/overlay2/l/`:


```bash
$ cat /var/lib/docker/overlay2/1d97945a23ba5da08192c5228170b753922dea5874da52f46231147662920aad/lower
l/HL6YAF5BCDJS2L44F5QLU6KSJZ:l/PNXCVUHMXCLSQ3F4ZRF2OANT2O
```

```bash
$ ll /var/lib/docker/overlay2/l/
-rwx------. 5 matheus root     69 Jan 10 OFKSZFCQ7OTJK3LIQFERTZPAEV
-rwx------. 5 matheus root     69 Jan 10 HL6YAF5BCDJS2L44F5QLU6KSJZ
-rwx------. 5 matheus root     69 Jan 10 PNXCVUHMXCLSQ3F4ZRF2OANT2O
```

Fácil perceber a relação de parentalidade entre as camadas das instruções 02 e 03, confere?


> Como o Cache vem ativado por padrão no Docker, se desejar desabilitar momentaneamente, para um *build* específico, passe o parâmetro `--no-cache` no build.

Utilize a dica acima em nosso exemplo e veja o que acontece. Um bom exercício!


### Invalidando o *Cache*

Ainda com base em nosso exemplo, adicionemos mais uma instrução em nosso *Dockerfile*, desta vez, não mais no final:

```bash
FROM alpine
WORKDIR /exemplo
RUN apk add curl
RUN echo "foo bla" > file1.txt
```

Vamos analisar o que acontece com o *build* desta terceira imagem:

```bash
$ docker build -t exemplo-a:03 .

Sending build context to Docker daemon  2.048kB
Step 1/4 : FROM alpine
 ---> 389fef711851
Step 2/4 : WORKDIR /exemplo
 ---> Using cache
 ---> 2fede79cd8d8
Step 3/4 : RUN apk add curl
 ---> Running in 3cb784187b8b
fetch http://dl-cdn.alpinelinux.org/alpine/v3.12/main/x86_64/APKINDEX.tar.gz
fetch http://dl-cdn.alpinelinux.org/alpine/v3.12/community/x86_64/APKINDEX.tar.gz
(1/4) Installing ca-certificates (20191127-r4)
(2/4) Installing nghttp2-libs (1.41.0-r0)
(3/4) Installing libcurl (7.69.1-r3)
(4/4) Installing curl (7.69.1-r3)
Executing busybox-1.31.1-r19.trigger
Executing ca-certificates-20191127-r4.trigger
OK: 7 MiB in 18 packages
Removing intermediate container 3cb784187b8b
 ---> 10bb1a41d7d7
Step 4/4 : RUN echo "foo" > file1.txt
 ---> Running in 1a8c0deda98a
Removing intermediate container 1a8c0deda98a
 ---> beac6080b01b
Successfully built beac6080b01b
Successfully tagged exemplo-a:3
```

* `Step 1/4`: usa o cache, não baixando novamente as camadas da imagem alpine;
* `Step 2/4`: Há uma camada filha da instrução anterior que faz exatamente a instrução. *Layer* aproveitada;
* `Step 3/4`: Não há camada filha da instrução anterior com essa instrução, logo uma nova camada é criada.
* `Step 4/4`: Como a camada anterior é nova, não há o que se falar em *cache*, logo, a instrução é executada gerando nova *layer* e novos relacionamentos.


Perceba que nesta imagem, a camada da instrução `RUN echo "foo bla" > file1.txt` não é mais filha da instrução `WORKDIR /exemplo` para ser reaproveitada pelo cache.

> Uma vez que o *cache* é invalidado, todas as instruções subsequentes do *Dockerfile* gerarão novas *layers* (quando acontece) e o *cache* não é mais usado.

Faz sentido, não acha? Se uma nova camada é criada na construção de uma imagem, é como se um "novo ramo" na "árvore de relacionamentos" nascesse.


FAZER IMAGEM DESSA "ARVORE"



## Camadas inutilizadas: Diminua o espaço em disco consumido


## Commitando o Container e gerando uma Imagem (Não faça isso!)


## Conclusão





Abraços!

:D

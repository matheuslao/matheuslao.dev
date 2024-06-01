---
title: "Docker Images, Empty Layers e FileSystem Layers"
date: 2021-01-02T11:50:10-03:00
draft: false
images:
tags:
  - docker
  - dockerfile
  - build
  - imagens
  - layers
  - empty layers
  - fs layers
---

Saudações!

Containers não são mais novidades. Hoje, Devs e Ops lidam diariamente com aplicações containerizadas e são responsáveis pela construção da imagem da aplicação a ser implantada em produção.

Mas, **como anda o processo de construção das imagens das aplicações de sua empresa**? Todos os membros do time compreendem o que acontece no *building* de uma imagem? Há uma busca por otimizações em reaproveitamento, consumo de espaço em disco, processos de atualização das imagens de todos os apps?

Entender imagens (de containers) e construí-las de forma otimizada não é tão trivial para um iniciante no assunto, mas também nada tão difícil. Pensando nisso, tentarei publicar em alguns posts informações que achei interessante durante meu aprendizado.

O assunto desta publicação é **Layers**, principalmente por causa de uma dúvida que aparece muito nas equipes de trabalho:

> **Afinal, quais instruções do Dockerfile geram Layers e/ou aumentam o espaço em disco consumido?**



## TL;DR

* O conceito de *layers* nem sempre está atrelado à existência de alterações no sistema de arquivos (*filesystem layers*);
* Nem todas as instruções do Dockerfile geram layers (sejam quais forem) . Exemplo: instrução `ARG`;
* Nem sempre a instrução `RUN` gera uma *filesystem layer*, como aparentemente indica a documentação;
* Outras instruções podem gerar uma *filesystem layer* como a `WORKDIR`, e não somente `RUN, COPY e ADD` como, aparentemente, indica uma página da documentação.
* Atentar-se sempre ao contexto da palavra *layer* presente nos livros, documentação, etc., pois podem referenciar somente *filesystem layers*.


## O que é uma Imagem Docker?

Fui procurar na documentação oficial da Docker o conceito de **imagem**. No [Glossário](https://docs.docker.com/glossary/), temos a seguinte definição:

> "Docker images are the basis of containers. An Image is an ordered collection of root filesystem changes and the corresponding execution parameters for use within a container runtime. An image typically contains a union of layered filesystems stacked on top of each other. An image does not have state and it never changes."

Praticamente diz tudo. Aqui deixo a minha tradução livre:

* coleção **ordenada** de **mudanças imutáveis** no **sistema de arquivos** mais **parâmetros de execução** em **camadas empilhadas** umas sobre as outras;

Na grande maioria dos casos, estas camadas são construídas através das instruções presentes no famoso arquivo **Dockerfile**. 

| ![dockerfile-como-origem-para-contrucao-imagem](https://miro.medium.com/max/2520/1*p8k1b2DZTQEW_yf0hYniXw.png) |
| :--: |
| *Fonte: https://medium.com/platformer-blog/practical-guide-on-writing-a-dockerfile-for-your-application-89376f88b3b5* |

PS: Não gosto nem de lembrar, mas temos que assumir que existe outro método de gerar imagens, a partir de containers: *docker commit*. :D



## O que são Layers?

Recorrendo novamente ao [Glossário do Docker](https://docs.docker.com/glossary/) temos:

> "In an image, a layer is modification to the image, represented by an instruction in the Dockerfile. Layers are applied in sequence to the base image to create the final image. When an image is updated or rebuilt, only layers that change need to be updated, and unchanged layers are cached locally. This is part of why Docker images are so fast and lightweight. The sizes of each layer add up to equal the size of the final image."

Aqui, mais uma vez, deixo minha tradução livre e resumida do que considero importante:

* **Modificação** da imagem representada por uma **instrução do Dockerfile** aplicadas em **sequência** à imagem base para criar outra imagem final.

Repare que é bem sutil (e por isso, confuso numa primeira vez) o conceito de Layer e Imagem. Muitas vezes usamos a definição de *layer* para imagem, concorda? 

Podemos, por exemplo, afirmar que **1 layer é uma imagem intermediária**, já que o empilhamento ordenado de N camadas representará a **imagem final**.

Guardemos, por ora, que uma **imagem é um agrupamento ordenado de layers e estas são as modificações imutáveis, resultados de instruções presentes no Dockerfile.**



## Layers: Quantas são?

Vamos visualizar, metendo a "mão na massa"! Baixemos uma das imagens mais famosas (e menores) que existem:

```bash
$ docker image pull alpine
Using default tag: latest
latest: Pulling from library/alpine
801bfaa63ef2: Pulling fs layer
801bfaa63ef2: Verifying Checksum
801bfaa63ef2: Download complete
801bfaa63ef2: Pull complete
Digest: sha256:3c7497bf0c7af93428242d6176e8f7905f2201d8fc5861f45be7a346b5f23436
Status: Downloaded newer image for alpine:latest
docker.io/library/alpine:latest
```

Pela saída de texto do comando acima executado, podemos verificar que **1 layer**, identificada pelo *hash 801bfaa63ef2*, foi baixada. Vamos rodar o comando `inspect`, fazendo um filtro no formato de saída:

```bash
$ docker image inspect alpine --format='{{.RootFS}}'
{layers [sha256:777b2c648970480f50f5b4d0af8f9a8ea798eea43dbcf40ce4a8c7118736bdcf] }
```

O retorno também é **1 layer**, identificada por um *hash sha256*. Se formos mais curiosos, encontraremos a camada baixada no sistema de arquivos, onde o Docker a armazena (usando Linux, [storage driver overlay2](https://docs.docker.com/storage/storagedriver/) e sem alteração do local de instalação do Docker):

```bash
$ ll /var/lib/docker/overlay2/
drwx------. 5 matheus root     69 Oct 19 b29be06af013d08aa3a729693e9368e2b43f3a7fd4de362caaaee93ef3dc2c59
drwx------. 2 matheus root   8192 Nov  9 l
```

Perceba que apenas 1 pasta identificada por um *hash* está presente. E despreze que os *hashes* não batem, pois não é mesmo pra acontecer.

Agora, vamos utilizar o comando `history` para dissecar um pouco mais a imagem:

```bash
$ docker image history alpine
IMAGE          CREATED       CREATED BY                                      SIZE      COMMENT
389fef711851   2 weeks ago   /bin/sh -c #(nop)  CMD ["/bin/sh"]              0B
<missing>      2 weeks ago   /bin/sh -c #(nop) ADD file:ec475c2abb2d46435ÔÇª   5.58MB
```

Desprezando a falta do identificador da *layer* mais baixa (`<missing>` que explicarei em outro post), verificamos que a imagem alpine é **composta por 2 layers**, cujas instruções de construção são:

```bash
ADD file:a4845c3840a3fd0e41e4635a179cce20c81afc6c02e34e3fd5bd2d535698918b in / 
CMD ["/bin/sh"]
```

Podemos confirmar também [lá no Docker Hub:](https://hub.docker.com/layers/alpine/library/alpine/latest/images/sha256-549694ea68340c26d1d85c00039aa11ad835be279bfd475ff4284b705f92c24e?context=explore)

| [![alpine-layers-001.png](https://i.postimg.cc/XvxzpD6W/alpine-layers-001.png)](https://postimg.cc/LqYTWDsQ) |
| :--: |
| *Visualizando as camadas da imagem alpine:latest no Docker Hub* |


E agora? 1 ou 2 camadas na imagem alpine?



## Empty Layers e FileSystem Layers

A resposta para a pergunta anterior é: 2 camadas!

A "pegadinha" acontece que apenas 1 camada gera persistência, alteração no sistema de arquivos, enquanto a outra camada é "vazia" em modificação/alteração do *filesystem*.

Neste ponto, podemos dizer que a camada que vemos o `docker pull` baixar (a mesma vista no `inspect` e presente no `/var/lib/docker/overlay`) pode ser categorizada como uma **FS layer**, ou seja, uma camada de sistema de arquivos. Já a camada construída pela instrução `CMD ["/bin/sh"]` pode ser categorizada como uma **Empty Layer**, pois não gera alteração no *filesystem*, não consumindo espaço, e portanto, não sendo baixada.

Aqui que reside a confusão conceitual de *Layers*. Em versões anteriores do Docker e de construção de imagens, as *layers* sempre estavam associadas à **modificações no filesystem**. Contudo, em versões atuais, há instruções presentes no Dockerfile que **não alteram o filesystem e precisam ser definidas como layers**, pois fazem parte do processo de construção (empilhamento ordenado de instruções) de uma imagem.

Lembre-se das definições atuais de Imagens e Layers lá do Glossário do Docker:

* imagens: coleção ordenada de mudanças no *filesystem* e parâmetros de execução;
* layers: modificação da imagem, através de uma instrução.



## Todas instruções do Dockerfile geram Layers?

Aqui, mais uma vez, vamos meter mão na massa!

Em uma página da documentação oficial do Docker que versa sobre [boas práticas no processo de construção de imagens](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#minimize-the-number-of-layers), temos a seguinte informação:

> "Only the instructions RUN, COPY, ADD create layers. Other instructions create temporary intermediate images, and do not increase the size of the build."


Opa, respondido? Talvez. Uma leitura mais atenta e você pode notar que:

- RUN, COPY, ADD criam layers;
- outras instruções criam *temporary intermediate images*.

Pelo que já apresentamos, podemos definir *layers* como imagens intermediárias, logo, determinadas instruções criariam camadas temporárias que não aumentariam o espaço consumido do *build*.

Repare que aqui a documentação nos confunde com o conceito de *layers*: somente RUN, COPY e ADD criam **filesystem layers**, enquanto outras não (*empty layers*). 

Neste ponto, gostaria de levantar alguma dúvidas para testarmos/validarmos, pois me confundiu muito no início:

* Dúvida 01: A instrução `RUN` sempre vai gerar uma *FS Layer* ?
* Dúvida 02: A instrução `WORKDIR` quando cria um novo path (uma alteração no *filesystem*), geraria uma *FS Layer*?
* Dúvida 03: Alguma instrução do Dockerfile não gera Layer (seja filesystem layers ou empty layers)?

Vamos testar algumas das principais instruções de utilização na construção de imagens docker para validar os conceitos apresentados e hipóteses levantadas. Todas as instruções possíveis estão presentes no [Dockerfile Reference](https://docs.docker.com/engine/reference/builder/). 

Tomemos como exemplo o Dockerfile abaixo onde tentei utilizar as instruções mais conhecidas:

```
ARG  VERSION=latest
FROM alpine:${VERSION}
LABEL mantainer="matheuslao.dev"
ENV URL "https://artefatos.empresa.com.br/app-1.2.3.jar"
WORKDIR /
RUN addgroup -g 10001 francisco && adduser -u 10001 francisco -G francisco -s /sbin/nologin --disabled-password
RUN apk add curl \
    && curl -o app.jar $URL
WORKDIR /myapp
COPY file1.txt .
ADD file2.txt .
RUN export USER="francisco" \
    && echo $USER
USER francisco
CMD ["/bin/sh"]
ENTRYPOINT ["java", "-XX:+UnlockExperimentalVMOptions", "-Djava.security.egd=file:/dev/./urandom","-jar","app.jar"]
EXPOSE 80
```

Analisemos o resultado do *build* da imagem (saída do comando sem o [buildkit](https://docs.docker.com/develop/develop-images/build_enhancements/)):

```
$ docker image build -t minha-imagem .

Sending build context to Docker daemon  4.608kB
Step 1/15 : ARG  VERSION=latest
Step 2/15 : FROM alpine:${VERSION}
 ---> 389fef711851
Step 3/15 : LABEL mantainer="matheuslao.dev"
 ---> Running in 7b372ffdfc95
Removing intermediate container 7b372ffdfc95
 ---> 6a5c0a8519d8
Step 4/15 : ENV URL "https://raw.githubusercontent.com/matheuslao/matheuslao.dev/main/static/img/matheuslao.jpg"
 ---> Running in c376576063ff
Removing intermediate container c376576063ff
 ---> 12828b25bdff
Step 5/15 : WORKDIR /
 ---> Running in 65cf9d3a17bb
Removing intermediate container 65cf9d3a17bb
 ---> e3d131d4c8f9
Step 6/15 : RUN addgroup -g 10001 francisco && adduser -u 10001 francisco -G francisco -s /sbin/nologin --disabled-password
 ---> Running in 1144c1a690da
Removing intermediate container 1144c1a690da
 ---> 370ee1418f66
Step 7/15 : RUN apk add curl     && curl -o app.jar $URL
 ---> Running in aee90a4a5f09
fetch http://dl-cdn.alpinelinux.org/alpine/v3.12/main/x86_64/APKINDEX.tar.gz
fetch http://dl-cdn.alpinelinux.org/alpine/v3.12/community/x86_64/APKINDEX.tar.gz
(1/4) Installing ca-certificates (20191127-r4)
(2/4) Installing nghttp2-libs (1.41.0-r0)
(3/4) Installing libcurl (7.69.1-r3)
(4/4) Installing curl (7.69.1-r3)
Executing busybox-1.31.1-r19.trigger
Executing ca-certificates-20191127-r4.trigger
OK: 7 MiB in 18 packages
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100 21926  100 21926    0     0  32872      0 --:--:-- --:--:-- --:--:-- 32823
Removing intermediate container aee90a4a5f09
 ---> 5afd3449a399
Step 8/15 : WORKDIR /myapp
 ---> Running in 1e1d3f15d239
Removing intermediate container 1e1d3f15d239
 ---> d1ccd41ed16e
Step 9/15 : COPY file1.txt .
 ---> 476f0884009f
Step 10/15 : ADD file2.txt .
 ---> 8e8b4ed9127d
Step 11/15 : RUN export USER="francisco"     && echo $USER
 ---> Running in ca95419bbf81
francisco
Removing intermediate container ca95419bbf81
 ---> 4b75a0feb0de
Step 12/15 : USER francisco
 ---> Running in a510fe377aff
Removing intermediate container a510fe377aff
 ---> 562d417df13d
Step 13/15 : CMD ["/bin/sh"]
 ---> Running in c7db6aabcd80
Removing intermediate container c7db6aabcd80
 ---> 0054ff10e607
Step 14/15 : ENTRYPOINT ["java", "-XX:+UnlockExperimentalVMOptions", "-Djava.security.egd=file:/dev/./urandom","-jar","app.jar"]
 ---> Running in fc1f9065fc21
Removing intermediate container fc1f9065fc21
 ---> 5c7cd86d14a3
Step 15/15 : EXPOSE 80
 ---> Running in fa19fc0c27e3
Removing intermediate container fa19fc0c27e3
 ---> 986b3c714918
Successfully built 986b3c714918
Successfully tagged minha-imagem:latest


```

São 15 instruções em nosso Dockerfile que geram 15 steps (passos) no build:

* Step 1/15: Repare que nenhuma informação adicional é gerada como a criação/geração de uma **layer**;
* Step 2/15: A **FS Layer** da imagem alpine é referenciada aqui (mas já sabemos que no fundo, a imagem alpine possui 2 layers);
* Step 3/15: Um container de hash 7b372ffdfc95 sobe, executa a instrução, morre e uma layer de hash 6a5c0a8519d8 é gerada;
* Step 4/15: Um container sobe, executa a instrução, morre e uma layer é gerada;
* Step 5/15: Um container sobe, executa a instrução, morre e uma layer é gerada;
* Step 6/15: Um container sobe, executa a instrução, morre e uma layer é gerada;
* Step 7/15: Um container sobe, executa a instrução, morre e uma layer é gerada;
* Step 8/15: Um container sobe, executa a instrução, morre e uma layer é gerada;
* Step 9/15: Uma layer é gerada com a transferência do arquivo copiado;
* Step 10/15: Uma layer é gerada com a transferência do arquivo adicionado;
* Step 11/15: Um container sobe, executa a instrução, morre e uma layer é gerada;
* Step 12/15: Um container sobe, executa a instrução, morre e uma layer é gerada;
* Step 13/15: Um container sobe, executa a instrução, morre e uma layer é gerada;
* Step 14/15: Um container sobe, executa a instrução, morre e uma layer é gerada;
* Step 15/15: Um container sobe, executa a instrução, morre e uma layer é gerada;


A Dúvida 03 já tem um candidato para a resposta:

> **Com exceção da instrução `ARG`, todas as outras utilizadas geraram layers.**

Vamos utilizar o `history` para validar/confirmar:

```bash
$ docker image history minha-imagem

IMAGE          CREATED              CREATED BY                                      SIZE      COMMENT
9f338caaa516   About a minute ago   /bin/sh -c #(nop)  EXPOSE 80                    0B
6449ad4000e5   About a minute ago   /bin/sh -c #(nop)  ENTRYPOINT ["java" "-XX:+…   0B
65a889958083   About a minute ago   /bin/sh -c #(nop)  CMD ["/bin/sh"]              0B
1abacd6cfbe6   About a minute ago   /bin/sh -c #(nop)  USER francisco               0B
2a1a85501e97   About a minute ago   /bin/sh -c export USER="francisco"     && ec…   0B
f055068ccc6c   About a minute ago   /bin/sh -c #(nop) ADD file:328c2a0fff8f5e953…   10B
6085fb888a33   About a minute ago   /bin/sh -c #(nop) COPY file:bb441069227b280c…   10B
cba01884fddf   About a minute ago   /bin/sh -c #(nop) WORKDIR /myapp                0B
9a12d9d412ae   About a minute ago   /bin/sh -c apk add curl     && curl -o app.j…   3.12MB
8f54af3a2563   About a minute ago   /bin/sh -c addgroup -g 10001 francisco && ad…   4.7kB
cb8c60e24f29   About a minute ago   /bin/sh -c #(nop) WORKDIR /                     0B
bfe0e88f7ca5   About a minute ago   /bin/sh -c #(nop)  ENV URL=https://raw.githu…   0B
d1ba00e0a9d5   About a minute ago   /bin/sh -c #(nop)  LABEL mantainer=matheusla…   0B
389fef711851   2 weeks ago          /bin/sh -c #(nop)  CMD ["/bin/sh"]              0B
<missing>      2 weeks ago          /bin/sh -c #(nop) ADD file:ec475c2abb2d46435…   5.58MB
```

É fácil visualizar a presença de 15 layers, concorda? Também não é dificíl dizer que as 2 primeiras layers (de baixo pra cima) são as layers da imagem base alpine. Assim, temos 13 layers registradas adicionalmente (ordenadas e empilhadas conforme instruções) que batem com os 13 steps (depois do FROM) que geraram-as.

Analisemos agora o tamanho das *layers*. Baseado na experiência anterior, afirmaríamos que 05 são **FS Layers**, pois possuem tamanho > 0.

Vamos validar?

```
$ docker image inspect minha-imagem --format='{{.RootFS}}'

{layers [
	sha256:777b2c648970480f50f5b4d0af8f9a8ea798eea43dbcf40ce4a8c7118736bdcf 
	sha256:9caf12dafc34f81365ffeefa58af5c52eb19e6e58260158f8931f51223a025a6 
	sha256:e184369701b73ed92ccb30cb4e4f34cc817a6093bfb35ec6b6a9a36946f841fd 
	sha256:ac91c339ff12c9965379a1eeac8ff51cdf9a4f1d3f229316650aa4d7e2d81bc3 
	sha256:3449aa1a02c6e90dae7e4785fd52b5b1b09128ee73e88f76fa6149fb2746bfe2 
	sha256:cfbf011495adad103cc9c9b6c7f8d9525427a3f90b34d49a6db1cf5cde812f09
	]
}
```

Oh, não! São 06 camadas!

Vamos procurar lá em nossa pasta `/var/lib/docker/overlay2`:

```bash
$ ll /var/lib/docker/overlay2/
drwx------. 5 matheus root     69 Oct 19 b29be06af013d08aa3a729693e9368e2b43f3a7fd4de362caaaee93ef3dc2c59
drwx------. 5 matheus root     69 Oct 19 6efd98d05213572a70e59f16840758d6072c7298f42621609cd7b286354cda9b
drwx------. 5 matheus root     69 Oct 19 46b740c355ed78e37fa9f6af8a94c23f63b1ed00d98e797d9468e557d67620f4
drwx------. 5 matheus root     69 Oct 19 090b364761d9bd50b7d634cf3aecd17794a8264d24d430c198e69deea5d54f5c
drwx------. 5 matheus root     69 Oct 19 335aa592cb4a89b7165017f78c7b01a0b92c5df78a91c9ceb569c56520f13329
drwx------. 5 matheus root     69 Oct 19 d7f4b90503fa2bba199564c7714d553080bb45ed1425501da8cdd698208a0803
drwx------. 2 matheus root   8192 Nov  9 l
```
Novamente, 06 camadas!

Tínhamos uma hipótese se a instrução `WORKDIR` quando cria um diretório não existente resultaria em uma camada de persistência. Pois bem, apesar do tamanho mostrado lá no comando `history` estar `SIZE 0`, a instrução `WORKDIR /myapp` de nosso Dockerfile cria uma camada no filesystem para persistir.

Se olharmos o `diff`de cada camada (explicarei em outro post), encontrarei uma que representa a instrução em questão. Em nosso exemplo, foi a seguinte layer:

```bash
ll /var/lib/docker/overlay2/6efd98d05213572a70e59f16840758d6072c7298f42621609cd7b286354cda9b/diff
drwx------. 5 matheus root     69 Oct 19 myapp

ll /var/lib/docker/overlay2/6efd98d05213572a70e59f16840758d6072c7298f42621609cd7b286354cda9b/diff/myapp/
drwx------. 5 matheus root     69 Oct 19 ./
drwx------. 5 matheus root     69 Oct 19 ../
```

Assim, a Dúvida 02 é respondida com um SIM.

Por fim, podemos também responder a Dúvida 01. Repare que o `Step 11/15`, que é a instrução `RUN` executando um *export* e um *echo* gera uma *layer* de tamanho zero. Se você tentar procurar no sistema de arquivos, não vai achar a representação desta instrução também. Assim, podemos perceber que nem sempre a instrução `RUN` vai alterar o sistema de arquivos e consequentemente persistir em uma camada *FS Layer*, consumindo espaço em disco.

## Conclusão

Com a popularização da containerização, entender um pouco mais como dá-se a construção e formação das imagens pode proporcionar condições de melhorias futuras no processo de desenvolvimento e implantação das aplicações.

Vimos que, para entender o que é uma Imagem Docker, precisamos internalizar o conceito de *Layer*, parte fundamental e indissociável de sua formação. Também faz-se importante destacar a interpretação correta e o contexto do termo *layer* presentes em livros, documentações, etc, pois muitas vezes referenciam somente à um tipo de layer: aquelas que criam alterações em sistemas de arquivos, consumindo espaço em disco. Contudo, sabemos que na formação de Imagens Docker, há *layers* que não geram persistência, mas sim, guardam outras informações cruciais e indispensáveis para a caracterização de uma imagem final.


Abraços!

:D


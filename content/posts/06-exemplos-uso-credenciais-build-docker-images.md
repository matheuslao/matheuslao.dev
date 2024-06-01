---
title: "06 Exemplos de Uso de Credenciais (04 não recomendadas) durante o Build de Imagens Docker"
date: 2020-12-23T12:30:18-03:00
draft: false
images:
tags:
  - docker
  - dockerfile
  - multistage build
---

Em quase todo o processo de construção de imagens Docker, há a necessidade de baixar artefatos (ex: zip, war, jar, etc.) de alguma URL para compor a imagem de nossa aplicação. Por vezes, estas URLs exigem autenticação e precisamos de credenciais para ter acesso ao conteúdo.

**Como construir imagens Docker sem comprometer credenciais, como usuários e senhas de acesso?**

Os exemplos abaixo seguirão uma ordem, aparentemente natural de boas práticas, onde há uma preocupação em não expor informação sensível na imagem Docker gerada, além de continuar garantindo sua portabilidade.

### O Desafio: Contextualizando a situação

Suponha que tenhamos a missão de construir a imagem de uma simples aplicação Java, cujo artefato *buildado* encontra-se disponível em uma URL que é o repositório de artefatos de sua empresa. (https://artefatos.empresa.com.br/)

Detalhe 01 : a URL do repositório exige autenticação e você possui as credenciais de acesso.

Detalhe 02 : a imagem será compatilhada para outras empresas/clientes implantarem a aplicação.

### Exemplo 01: Codando "na mão grande" as credenciais

Eu nem deveria começar por este exemplo, porque acredito que ninguém deve fazer assim. Contudo, vamos evoluindo exemplo a exemplo. Analisemos o *Dockerfile* abaixo:

```bash
FROM alpine
WORKDIR /
RUN apk add curl
RUN curl -u francisco:abc123 -o app.jar "https://artefatos.empresa.com.br/app-1.2.3.jar"
ENTRYPOINT ["java", "-XX:+UnlockExperimentalVMOptions", "-Djava.security.egd=file:/dev/./urandom","-jar","app.jar"]
```

Se preocupe somente com a segunda linha da intrução `RUN`, onde foi escrito literalmente as credenciais de acesso. Nem preciso dizer que isso aqui é **bem ruim**, não é? Mas vamos *buildar* a imagem e taguear com uma versão:

```bash
docker build -t app:01 .
```

A partir da imagem gerada (e que será distribuída para outras pessoas), façamos uma inspeção:

```bash
docker image history app:01
```

Está lá, para todo o mundo ver, as credenciais de acesso:

```bash
IMAGE          CREATED         CREATED BY                                      SIZE      COMMENT
e4d60e8650d7   2 minutes ago   /bin/sh -c #(nop)  ENTRYPOINT ["java" "-XX:+…   0B
68e3c9068540   2 minutes ago   /bin/sh -c curl -u francisco:abc123 -o app.j…   1.23kB
c1a9701b7132   5 minutes ago   /bin/sh -c apk add curl                         3.1MB
c44f6da443d7   5 minutes ago   /bin/sh -c #(nop) WORKDIR /                     0B
389fef711851   6 days ago      /bin/sh -c #(nop)  CMD ["/bin/sh"]              0B
<missing>      6 days ago      /bin/sh -c #(nop) ADD file:ec475c2abb2d46435…   5.58MB
```


### Exemplo 02: Usando ENVs para as credenciais

Uma evolução do exemplo acima, seria a tentativa de *buildar* a imagem com a utilização de *ENVs*. Segue o *Dockerfile*:

```bash
FROM alpine
ENV USER francisco
ENV PASSWORD abc123
WORKDIR /
RUN apk add curl
RUN curl -u $USER:$PASSWORD -o app.jar "https://artefatos.empresa.com.br/app-1.2.3.jar"
ENTRYPOINT ["java", "-XX:+UnlockExperimentalVMOptions", "-Djava.security.egd=file:/dev/./urandom","-jar","app.jar"]
```

Possa ser que você ache que agora não vai persistir as credenciais de acesso, pois leu que a [instrução ENV não cria layer na imagem](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#minimize-the-number-of-layers). Vamos conferir?

```bash
docker build -t app:02 .
```

Inspecionando a imagem com o comando `docker image inspect app:02`:

```bash
[...]
 "Config": {
            "Hostname": "",
            "Domainname": "",
            "User": "",
            "AttachStdin": false,
            "AttachStdout": false,
            "AttachStderr": false,
            "Tty": false,
            "OpenStdin": false,
            "StdinOnce": false,
            "Env": [
                "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
                "USER=francisco",
                "PASSWORD=abc123"
            ],
            "Cmd": null,
[...]
```

E com o mesmo comando do exemplo anterior `docker image history`:

```bash
IMAGE          CREATED         CREATED BY                                      SIZE      COMMENT
284ee6fffad5   3 minutes ago   /bin/sh -c #(nop)  ENTRYPOINT ["java" "-XX:+…"   0B
904ec10bf219   3 minutes ago   /bin/sh -c curl -u $USER:$PASSWORD -o app.ja…   14B
cc4d45436465   3 minutes ago   /bin/sh -c apk add curl                         3.1MB
35e0fe7f8c92   3 minutes ago   /bin/sh -c #(nop) WORKDIR /                     0B
51c378578679   3 minutes ago   /bin/sh -c #(nop)  ENV PASSWORD=abc123          0B
9ab41a3c7fa5   3 minutes ago   /bin/sh -c #(nop)  ENV USER=francisco           0B
389fef711851   6 days ago      /bin/sh -c #(nop)  CMD ["/bin/sh"]              0B
<missing>      6 days ago      /bin/sh -c #(nop) ADD file:ec475c2abb2d46435…   5.58MB
```

Abordarei em outro post, com mais detalhes, as questões de quando `layers` são geradas ou não. Por enquanto, nos atentemos que é possível a identificação/visualização das credencenciais com a inspeção da imagem gerada.


### Código 03: Usando variáveis de ambiente e RUN em uma mesma LAYER

Nova ideia: utilizar variáveis de ambiente junto instrução RUN para a construção de uma única camada (layer) da imagem. O novo Dockerfile ficaria assim:

```bash
FROM alpine
WORKDIR /
RUN apk add curl
RUN export USER="francisco" \
    && export PASSWORD="abc123" \
    && curl -u $USER:$PASSWORD -o app.jar "https://artefatos.empresa.com.br/app-1.2.3.jar"
ENTRYPOINT ["java", "-XX:+UnlockExperimentalVMOptions", "-Djava.security.egd=file:/dev/./urandom","-jar","app.jar"]
```

Gerando versão 03 da aplicação:

```bash
docker build -t app:03
```

E vamos conferir o resultado, analisando a imagem gerada com o `docker image history`:

```bash
IMAGE          CREATED          CREATED BY                                      SIZE      COMMENT
406c7ce82cf0   37 seconds ago   /bin/sh -c #(nop)  ENTRYPOINT ["java" "-XX:+…   0B
325c0a507c68   37 seconds ago   /bin/sh -c export USER="francisco" && export …  14B
c1a9701b7132   24 minutes ago   /bin/sh -c apk add curl                         3.1MB
c44f6da443d7   24 minutes ago   /bin/sh -c #(nop) WORKDIR /                     0B
389fef711851   6 days ago       /bin/sh -c #(nop)  CMD ["/bin/sh"]              0B
<missing>      6 days ago       /bin/sh -c #(nop) ADD file:ec475c2abb2d46435…   5.58MB
```

É... também não deu certo. :( 



### Código 04: Usando ARGS

Conhecemos o atributo *ARGS*, 'similar' a *ENV*, e percebemos que podemos ganhar uma mobilidade ao passar as credenciais de acesso no comando de execução do *build* da imagem (não ter as credenciais escritas no *Dockerfile*!)

```bash
FROM alpine
ARG USER=fake
ARG PASSWORD=fake
WORKDIR /
RUN apk add curl
RUN curl -u $USER:$PASSWORD -o app.jar "https://artefatos.empresa.com.br/app-1.2.3.jar"
ENTRYPOINT ["java", "-XX:+UnlockExperimentalVMOptions", "-Djava.security.egd=file:/dev/./urandom","-jar","app.jar"]
```

E o comando para *buildar* a imagem seria:

```bash
docker build --build-arg USER=francisco --build-arg PASSWORD=abc123 -t app:04 .
```

Contudo, ao analisar a imagem com o `docker image history`:

```bash
IMAGE          CREATED         CREATED BY                                      SIZE      COMMENT
e9956a610c1f   5 minutes ago   /bin/sh -c #(nop)  ENTRYPOINT ["java" "-XX:+…   0B
4bcdfdea08f9   5 minutes ago   |2 PASSWORD=abc123 USER=francisco /bin/sh -c…   14B
1f56fb7ca086   5 minutes ago   |2 PASSWORD=abc123 USER=francisco /bin/sh -c…   3.1MB
0ccf29f3aadf   5 minutes ago   /bin/sh -c #(nop) WORKDIR /                     0B
556f62d21750   5 minutes ago   /bin/sh -c #(nop)  ARG PASSWORD=fake            0B
a726e9660660   5 minutes ago   /bin/sh -c #(nop)  ARG USER=fake                0B
389fef711851   6 days ago      /bin/sh -c #(nop)  CMD ["/bin/sh"]              0B
<missing>      6 days ago      /bin/sh -c #(nop) ADD file:ec475c2abb2d46435…   5.58MB
```

Se olharmos a documentação [neste link](https://docs.docker.com/engine/reference/builder/#arg), perceberemos que aconteceu exatamente como o descrito: credenciais ainda visíveis.


### Código 05: Adicionando Script auxiliar

Podemos tentar fazer um `workaround`: utilizar um script intermediário para auxiliar no download do artefato, atrás de uma URL autenticada. Nosso projeto agora ficaria com os seguintes arquivos:

* Dockerfile
* build.sh

Conteúdo do *build.sh*:

```bash
#!/bin/sh
curl -u francisco:abc123 -o app.jar "https://artefatos.empresa.com.br/app-1.2.3.jar"
```

E o *Dockerfile*, faz uso do artefato já baixado:

```bash
FROM alpine
WORKDIR /
COPY app.jar /
ENTRYPOINT ["java", "-XX:+UnlockExperimentalVMOptions", "-Djava.security.egd=file:/dev/./urandom","-jar","app.jar"]
```

A sequência de ações seria:

```
chmod +x build.sh
./build.sh
docker build -t app:05 .
```

Percebe-se claramente ao inspecionar a imagem que não há credenciais de acesso nela, confere? Coube a um script auxiliar realizar a autenticação (utilizando as credenciais de acesso), baixar o artefato e apresentá-lo ao contexto do build da imagem.

It works!


### Código 06: multi-stage builds


Apesar do exemplo anterior ter cumprido seu propósito (imagem docker sem exposição de credenciais sensíveis), tive a sensação (e espero que você também) de que algo ficou estranho: Tivemos que recorrer a arquivos auxiliares, fora do escopo do Docker para resolver o problema.

Se analisarmos um pouco, basicamente o que fizemos foi dividir o processo de build em 2 estágios:

* estágio 01 que baixou os artefatos sob credenciais (script auxiliar)
* estágio 02 que compilou a imagem (Docker)

Lendo mais a documentação da Docker, percebemos que podemos fazer similar utilizando o conceito de [multi-stage builds](https://docs.docker.com/develop/develop-images/multistage-build/).

Nosso Dockerfile:

```bash
FROM alpine AS download
ARG USER
ARG PASSWORD
RUN apk add curl
RUN curl -u $USER:$PASSWORD -o /app.jar "https://artefatos.empresa.com.br/app-1.2.3.jar"

FROM alpine
WORKDIR /
COPY --from=download /app.jar .
ENTRYPOINT ["java", "-XX:+UnlockExperimentalVMOptions", "-Djava.security.egd=file:/dev/./urandom","-jar","app.jar"]
```

Perceba que fizemos exatamente a mesma coisa, agora usando apenas o Docker: Dividimos nosso build em *2 estágios*.

* no primeiro estágio, uma imagem intermediária é criada (e suas respectivas layers e informações) com o download da aplicação, atrás da autenticação.
* no segundo estágio, a imagem em construção (a oficial) copia apenas o `app.jar` da imagem anterior.

Fácil perceber que, na imagem final não visualizaremos as credenciais. Além disso, a imagem intermediária é destruída ao final do processo de build.

```bash
IMAGE          CREATED         CREATED BY                                      SIZE      COMMENT
72ef8382df33   3 minutes ago   /bin/sh -c #(nop)  ENTRYPOINT ["java" "-XX:+…   0B
32a3816fdcd3   3 minutes ago   /bin/sh -c #(nop) COPY file:297d62e63eaf8490…   14B
29385377e66f   3 minutes ago   /bin/sh -c #(nop) WORKDIR /                     0B
389fef711851   6 days ago      /bin/sh -c #(nop)  CMD ["/bin/sh"]              0B
<missing>      6 days ago      /bin/sh -c #(nop) ADD file:ec475c2abb2d46435…   5.58MB
```

Funciona! E parece-nos uma solução bem inteligente, não acha?


### PLUS: BuildKit

Uma funcionalidade "nova" no Docker é o uso do *BuildKit* para ajudar no manuseio de credenciais durante o processo de construção de imagens.

Ainda não brinquei com este recurso, assim tentarei em breve atualizar este post com um exemplo adicional.

Caso deseje ver como funciona, [não deixe de ler a documentação oficial](https://docs.docker.com/develop/develop-images/build_enhancements/)


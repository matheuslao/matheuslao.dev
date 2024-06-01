---
layout: post
title: "Docker Images, Read-Only/Writable Layers, CoW e Dive"
date: 2021-01-06T12:00:10-03:00
categories:
  - docker
  - dockerfile
  - build
  - imagens
  - layers
  - cow
  - dive
---

Saudações! No [post anterior](https://matheuslao.dev/posts/docker-imagens-empty-filesystem-layers/) vimos a definição de imagens, além da conceituação de *layers* e como estas são intrínsecas ao assunto. Entendemos também a existência de *filesystem layers*, assim como *empty layers* no processo de formação de uma imagem, a partir de instruções (nem todas geram layers) de um *Dockerfile*.

O objetivo deste post é continuar dissecando o tema, com alguns estudos/experimentações que nos permitam entender mais como imagens Docker funcionam e são construídas.



## TL;DR.

* Em relação às **filesystem layers**, podemos categorizá-las em camadas *ReadOnly* ou *Writable*;
* Camadas de Imagens são *ReadOnly*;
* Camada do Container é *Writable*;
* O **CoW: Copy on Write** acontece tanto no momento do build, quanto com um container em execução, quando há a necessidade de uma modificação em um arquivo/objeto;
* Ferramentas externas como o [Dive](https://github.com/wagoodman/dive) auxiliam no processo de análises das camadas.



## Read-Only Layers e Writable Layers

Há uma relação indissociável entre imagem e *layers*. Neste ponto, já entendemos que uma imagem pode ser definida como um **agrupamento ordenado de *layers*, sendo estas ultimas, modificações imutáveis resultados de instruções** presentes no *Dockerfile*.  


A palavra em destaque aqui nesta seção é **imutabilidade**, ou seja, a *layer* representa uma modificação realizada na imagem e esta modificação é permanente **no contexto da *layer***. Se desejarmos fazer uma segunda modificação, após a primeira já ter sido persistida, tal alteração estará registrada em uma *layer* posterior.

Em resumo:


> **Layers de Imagens são **Read Only**.**


Aqui também é importante destacar que uma *filesystem layer* possuirá persistido **apenas os arquivos modificados em relação à camada anterior**. Por isso, a ordenação das *layers* é importante.

E o que, ou melhor, de quem seria uma *layer* gravável? A resposta: **Container!**

Containers nada mais são (do ponto de vista de camadas e armazenamento), do que a adição de uma *layer* gravável sobre as *layers* que formam uma imagem. Quando um container é instanciado, uma nova camada, desta vez *writable*, é criada no topo da imagem (camadas *read-only* de formação). Quando o container morre (e deletado do *host*), a camada *rw* é destruída:


> **Container adiciona uma *layer* gravável sobre as *layers* que formam a imagem.**


| ![containers e imagem layers](https://docs.docker.com/storage/storagedriver/images/sharing-layers.jpg) |
| :--: |
| *https://docs.docker.com/storage/storagedriver/images/sharing-layers.jpg* |


Neste ponto, já é possível perceber o ganho que obtemos, em relação ao espaço em disco consumido, ao instanciar vários containers (réplicas) oriundos de uma mesma imagem. Se instanciarmos 10 containers de uma imagem alpine, por exemplo, as *layers read-only* da imagem não serão multiplicadas por 10, mas sim reaproveitadas e 10 camadas *writables* serão criadas e associadas cada uma à um container em execução.

No Docker, temos 2 propriedades que nos mostram tais valores: `size` e `virtual size`:

* `size`: o tamanho da camada gravável do container;
* `virtual size`: o tamanho total das *layers* que fazem o container funcionar: *image layers* + *writable layer*.


No exemplo abaixo, 4 containers já encerrados, oriundos da imagem alpine, sendo que 3 não escreveram em sua camada *writable* (size 0) e 1 container teve escrita:

```bash
$ docker ps -as
CONTAINER ID   IMAGE     COMMAND   CREATED          STATUS                      PORTS     NAMES             SIZE
789d0f43e596   alpine    "sh"      6 seconds ago    Exited (0) 5 seconds ago              upbeat_rubin      0B (virtual 5.58MB)
fee34efca016   alpine    "sh"      10 seconds ago   Exited (0) 8 seconds ago              reverent_kalam    0B (virtual 5.58MB)
40c0882f562d   alpine    "sh"      14 seconds ago   Exited (0) 12 seconds ago             upbeat_sinoussi   0B (virtual 5.58MB)
90b23b31f6aa   alpine    "sh"      56 seconds ago   Exited (0) 29 seconds ago             musing_swirles    6.89MB (virtual 12.5MB)
```

Quanto de espaço em disco total estamos consumindo em nosso *host*, em relação às *layers*? A respostá é 12,5Mb.



## CoW: Copy on Write


Agora que sabemos quais *layers* são *read-only* e quais são *read-write*, vamos *meter mão na massa* para entender um conceito: CoW. 

Tomemos como exemplo o conteúdo do arquivo `file1.txt` e do `Dockerfile`:

```bash
#file1.txt
Primeira linha
```

```bash
#Dockerfile
FROM alpine
WORKDIR /exemplo
COPY file1.txt .
RUN echo "segunda linha" >> file1.txt
```

Realizando o build da imagem:

```
$ docker build -t exemplo:01 .

Step 1/4 : FROM alpine
latest: Pulling from library/alpine
801bfaa63ef2: Pull complete
Digest: sha256:3c7497bf0c7af93428242d6176e8f7905f2201d8fc5861f45be7a346b5f23436
Status: Downloaded newer image for alpine:latest
 ---> 389fef711851
Step 2/4 : WORKDIR /exemplo
 ---> Running in 90cd105624a7
Removing intermediate container 90cd105624a7
 ---> f1b5e463de89
Step 3/4 : COPY file1.txt .
 ---> 6d149ef7f9fd
Step 4/4 : RUN echo "segunda linha" >> file1.txt
 ---> Running in 536635e86c81
Removing intermediate container 536635e86c81
 ---> c741d831be62
Successfully built c741d831be62
Successfully tagged exemplo:01
```

Tranquilo perceber que as 4 instruções criaram *layers* e que todas elas são *filesystem layers*, concorda? Nossa imagem, no final, possui 05 layers sendo 02 provenientes da imagem alpine (instrução `FROM`) e 3 layers das instruções adicionais:

```
$ docker image history exemplo:01

IMAGE          CREATED              CREATED BY                                      SIZE      COMMENT
c741d831be62   About a minute ago   /bin/sh -c echo "segunda linha" >> file1.txt    29B
6d149ef7f9fd   About a minute ago   /bin/sh -c #(nop) COPY file:91615d60f2e8bc41…   15B
f1b5e463de89   About a minute ago   /bin/sh -c #(nop) WORKDIR /exemplo              0B
389fef711851   2 weeks ago          /bin/sh -c #(nop)  CMD ["/bin/sh"]              0B
<missing>      2 weeks ago          /bin/sh -c #(nop) ADD file:ec475c2abb2d46435…   5.58MB

$ docker image inspect exemplo:01 --format='{{.RootFS}}'

{layers [
	sha256:777b2c648970480f50f5b4d0af8f9a8ea798eea43dbcf40ce4a8c7118736bdcf 
	sha256:cd894f30417890083791614709bacc9b0f771366be38bda720ea6f622b02ad1c 
	sha256:8062d1a8dd2c9a137a8d0e90bff7d94511f014bb37f8fafb22edad46b4ca2cbe 
	sha256:2bc55ad19ad6d5fb5992402b70becd7e6973dc69ed10ce36a59681815cf9bd78
	]
}
```

Olhemos as nossas 4 *filesystem layers* armazenadas em nosso diretório de armazenamento das layers no Docker:

```bash
$ ll /var/lib/docker/overlay2
drwx------. 5 matheus root     69 Jan  2 10a4d6010850c9ea40dc684d7ec90d5e0cf90d790d06b8be9365f54465bd426c
drwx------. 5 matheus root     69 Jan  2 14be73d49e9d43672ee62a42250873a6eb4d8994d28d7f2d40228dc548de3735
drwx------. 5 matheus root     69 Jan  2 86899162aaea64b2c0e2ab86279f4f21d41317bbe9566df29d6362cb770c2bff
drwx------. 5 matheus root     69 Jan  2 aada6a14754e4e648f22adcc5f92b2c744dbc0e12db5f5f622300db6127a0046
drwx------. 2 matheus root   8192 Jan  9 l
```

A *layer* do alpine é a pasta `14be73d49e9d43...` e temos parte de seu conteúdo mostrado abaixo:

```bash
$ ll /var/lib/docker/overlay2/14be73d49e9d43672ee62a42250873a6eb4d8994d28d7f2d40228dc548de3735/diff
drwx------. 5 matheus root     69 Jan  2 bin
drwx------. 5 matheus root     69 Jan  2 dev
drwx------. 5 matheus root     69 Jan  2 etc
drwx------. 5 matheus root     69 Jan  2 home
drwx------. 5 matheus root     69 Jan  2 lib
drwx------. 5 matheus root     69 Jan  2 media
drwx------. 5 matheus root     69 Jan  2 mnt
...

```

A conteúdo gerado pela instrução `WORKDIR /exemplo` apenas criou a pasta:
```bash
$ ll /var/lib/docker/overlay2/10a4d6010850c9ea40dc684d7ec90d5e0cf90d790d06b8be9365f54465bd426c/diff
drwx------. 5 matheus root     69 Jan  2 exemplo


$ ll /var/lib/docker/overlay2/10a4d6010850c9ea40dc684d7ec90d5e0cf90d790d06b8be9365f54465bd426c/diff/exemplo
drwx------. 5 matheus root     69 Jan  2 ./
drwx------. 5 matheus root     69 Jan  2 ../
```

Já na *layer* `86899162a...`, temos o arquivo copiado pela instrução `COPY file1.txt`: 

```bash
$ ll /var/lib/docker/overlay2/86899162aaea64b2c0e2ab86279f4f21d41317bbe9566df29d6362cb770c2bff/diff/exemplo/
-rwx------. 5 matheus root     69 Jan  2 file1.txt

$ cat /var/lib/docker/overlay2/86899162aaea64b2c0e2ab86279f4f21d41317bbe9566df29d6362cb770c2bff/diff/exemplo/file1.txt
primeira linha
```

Enquanto na *layer* pertencente à instrução `RUN`, temos o novo arquivo `file1.txt` persistido:

```bash
$ ll /var/lib/docker/overlay2/aada6a14754e4e648f22adcc5f92b2c744dbc0e12db5f5f622300db6127a0046/diff/exemplo/
-rwx------. 5 matheus root     69 Jan  2 file1.txt


$ cat /var/lib/docker/overlay2/aada6a14754e4e648f22adcc5f92b2c744dbc0e12db5f5f622300db6127a0046/diff/exemplo/file1.txt
primeira linha
segunda linha
```

Perceba que o arquivo `file1.txt` está presente em 2 *layers* diferentes e por conseguinte em 2 diretórios no *filesystem*,  pois foi "tocado" por 2 instruções que o criou/modificou.


CoW é exatamente este comportamento: **Copy on Write**. Quando uma *layer* precisa modificar um arquivo/diretório, este é copiado para dentro da nova *layer* e então, modificado. Já quando há apenas leitura de um objeto, esta ação é realizada na *layer* em que o arquivo/diretório é encontrado.

O exemplo acima mostrou o *CoW* no momento do *build* de uma imagem, mas o processo também acontece quando um container está em execução e precisa modificar um arquivo/dietório, afinal, o container também possui sua *layer*, lembra? O objeto é copiado para a *top layer* (container) e nela realizadas suas modificações.

Veja o exemplo abaixo, em que é instanciado um container a partir da imagem `exemplo:01`, que altera o arquivo `file1.txt`:

```bash
$ docker container run exemplo:01 /bin/sh -c 'echo "linha escrita pelo container" >> /exemplo/file1.txt'
```

O container acima é instanciado e por causa de sua instrução, copia o arquivo para sua layer e efetua a modificação. Podemos ver a *layer* do container abaixo:

```bash
$ ll /var/lib/docker/overlay2/cdc6c284aef2e9dfac02c905c2aa3dda3d9e11d3ef37bd9d2d15fe4429dd9519/diff/exemplo/
-rwx------. 5 matheus root     69 Jan  2 file1.txt


$ cat /var/lib/docker/overlay2/cdc6c284aef2e9dfac02c905c2aa3dda3d9e11d3ef37bd9d2d15fe4429dd9519/diff/exemplo/file1.txt
primeira linha
segunda linha
linha escrita pelo container
```

Enquanto o container estiver presente no *host*, sua *layer* estará também presente (e consumindo espaço em disco).


> **CoW acontece tanto no momento do build de uma imagem, quanto na execução de um container, quando este precisa alterar um arquivo/diretório.**


Aqui neste ponto, já podemos pensar que é uma boa prática, **reduzir ao máximo o número de layers em que um arquivo aparece**, ou seja, concentrar o máximo possível as modificações de um arquivo na mesma layer que o criou, para evitar aumento de espaço em disco. Nem sempre é possível, mas quanto mais alcançar tal objetivo, melhor a utilização/consumo de espaço.

Um outro aprendizado que podemos ter é que a camada do container **inicia-se sempre com o menor tamanho possível**, e somente quando precisa-se modificar um objeto, há o aumento de tamanho desta camada.

**OBS**: o modo como o **Copy on Write** é implementado pode variar a depender do [Storage Driver](https://docs.docker.com/storage/storagedriver/#copying-makes-containers-efficient) implementado. Entretanto, a estratégia e objetivo é sempre este: leitura na camada onde o objeto se encontra em seu estado mais recente (de acordo com a ordem das camadas na imagem) e cópia do objeto para a alteração.



## Dive: Visualizando melhor as Layers


Neste post e em outros, sempre recorri à comandos docker como `history` ou `inspect` para visualizar as *layers*, além claro, de visualizar as modificações no *filesystem* lá no diretório `/var/lib/docker/overlay2`.


O [Dive](https://github.com/wagoodman/dive) é uma ferramenta externa bem legal que auxilia bastante na exploração de uma imagem docker, conteúdo das camadas, além de ajudar na descoberta de alternativas para melhorar o tamanho de suas imagens. O legal é que você pode rodar ela como container!

Uma vez instalado o *Dive*, basta apenas chamar ele passando a imagem: `dive <image>`.

> Página da ferramenta **Dive**: https://github.com/wagoodman/dive

Vamos utilizar o *Dive* em container. Para melhorar a usabilidade, eu criei o seguinte *alias*:

```bash
alias dive='sudo docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock wagoodman/dive'
```

E agora, posso analisar a imagem `exemplo:01`:

```bash
$ dive imagem:01
```

A saída é no próprio terminal, onde vc tem várias opções para melhorar a análise e investigação das *layers*. Na imagem abaixo, analisando a *layer* referente à instrução `COPY`de nossa imagem, consigo visualizar quais arquivos foram adicionados/removidos/modificados, inclusive com destaque de cores para cada cenário.

Vale a pena conferir!

| [![dive001.png](https://i.postimg.cc/MHsmR2Pv/dive001.png)](https://postimg.cc/8f6vQ3VS) |
| :--: |
| *Analisando a imagem exemplo:01 com o Dive* |



## Conclusão

Em grandes empresas, com muitos times, produtos e/ou serviços, a tendência é uma alta quantidade de imagens gerenciadas. Para que isso não vire um problema, atentar-se para o tamanho das imagens, a relação entre elas (imagens que são construídas a partir de outras), o número de *layers* que as formam, além de claro, como cada *layer* é construída são alguns pontos de atenção. Um melhor entendimento sobre *Layers* e suas categorizações podem auxiliar nos processos de trabalho sobre estes pontos.


Abraços!

:D

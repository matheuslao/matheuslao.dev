---
title: "Docker Registry com Nexus em um Cluster Swarm + Traefik + NFS"
date: 2019-07-07T14:50:17-03:00
draft: false 
images:
tags:
  - docker
  - nexus
  - traefik
  - swarm
  - registry
  - nfs
---

Em uma infraestrutura de containerização, possuir um *Private Registry Server* para o armazenamento e gerenciamento das imagens da empresa é essencial. 

Quando a empresa está na *Cloud*, a preocupação é na configuração e utilização da ferramenta, mas quando tem-se uma infraestrutura local (*on-premise*), precisamos atentar a passos anteriores como instalação e o armazenamentos das imagens.

Antes de continuar, gostaria de deixar um aviso:

> A solução apresentada é funcional, contudo este post **não é e nem pretende ser "Estado da Arte"**. Há diversas implementações melhores e mais robustas, tanto a nível de solução quanto a nível de tecnologias e ferramentas! Este post é fruto de estudo e aprendizado, assim fique à vontade para enviar sugestões.

## TL;DR

Para um Docker Registry privado completo (armazenamento de imagens próprias + proxy/cache do Docker Hub), a imagem do Nexus precisa expor 3 portas. Assim, a [imagem utilizada no *stack*](https://hub.docker.com/r/matheuslao/registry-nexus) foi feita com um *Dockerfile*:

```
FROM sonatype/nexus3:3.16.2
EXPOSE 8081 8082 8083
```
Assumindo a existência de um *Cluster Docker Swarm* com o *Traefik* como *Ingress/Reverse Proxy/Load Balancer* e *NFS* como armazenamento dos *volumes*, o seguinte arquivo representa a stack:

```
version: '3.7'

services:
  nexus:
    image: matheuslao/registry-nexus:3.16.2
    volumes:
      - data:/nexus-data
    deploy:      
      labels:        
        - "traefik.nexus.backend=nexus"
        - "traefik.nexus.frontend.rule=Host:nexus.domain.com"
        - "traefik.nexus.frontend.entryPoints=https"
        - "traefik.nexus.port=8081"
        - "traefik.registry-write.backend=registry-write"
        - "traefik.registry-write.frontend.rule=Host:registry.domain.com;Method:PUT,DELETE,POST,PATCH"
        - "traefik.registry-write.frontend.entryPoints=https"
        - "traefik.registry-write.port=8083"
        - "traefik.registry-read.backend=registry-read"
        - "traefik.registry-read.frontend.rule=Host:registry.domain.com;Method:GET,HEAD"
        - "traefik.registry-read.frontend.entryPoints=https"
        - "traefik.registry-read.port=8082"

volumes:
  data:
    driver_opts:
      type: "nfs4"
      o: "addr=NFS-SERVER-IP,nolock,soft,rw"
      device: ":/path/to/volumes/nexus/registry"
```

Se salvou o arquivo com o nome de `registry.yml`, suba seu stack com um comando como este:

```
$ docker stack deploy -c registry.yml registry
```


## Qual o Objetivo?

O objetivo deste *post* é detalhar os passos necessários para a entrega de um *Docker Registry* privado que:

- utilize o Nexus como ferramenta de implementação do Docker Registry;  
- disponibilize `nexus.domain.com` como endereço do Nexus;
- disponibilize `registry.domain.com` como endereço do Registry;
- funcione como um `proxy para o Docker Hub`.

Este post assume que você já possua um Cluster Docker Swarm com um Traefik configurado + NFS como persistência para seus volumes.

## Dockerfile: imagem do Nexus para um Registry

Este post utilizou a versão **3.16.2** do Nexus, assim como sua respectiva imagem docker para a construção de uma imagem personalizada. De acordo com a [documentação da imagem oficial](https://hub.docker.com/r/sonatype/nexus3), tem-se o serviço Nexus exposto pelo container na porta 8081.

Contudo, precisamos de mais 2 portas expostas e disponíveis que utilizaremos na criação e configuração dos repositórios docker dentro do nexus. Seguindo o padrão, escolhemos as portas:

- 8082
- 8083

Abaixo, nosso *Dockerfile*:

```
FROM sonatype/nexus3:3.16.2
EXPOSE 8081 8082 8083
```

e os comandos utilizados para o *build and push* da imagem no *Docker Hub*:

```
$ docker build --no-cache --rm -t matheuslao/registry-nexus:3.16.2 .

$ docker push matheuslao/registry-nexus:3.16.2
```

O *Dockerfile* pode ser consultado no projeto [minha conta no github](https://github.com/matheuslao/docker-registry-nexus) e a imagem gerada está disponível no [Docker Hub](https://hub.docker.com/r/matheuslao/registry-nexus).


## Stack: Subindo o Registry 

O mais "difícil" aqui é a configuração correta do serviço para/com o *Traefik*. O resto é configuração rotineira para a subida funcional de um serviço em um *Cluster Swarm*, além do armazenamento de *volumes* em um serviço NFS.

Assim, vamos nos atentar principalmente para estas configurações do *traefik* em nosso *service*:

```
deploy:      
  labels:        
    - "traefik.nexus.backend=nexus"
    - "traefik.nexus.frontend.rule=Host:nexus.domain.com"
    - "traefik.nexus.frontend.entryPoints=https"
    - "traefik.nexus.port=8081"
    - "traefik.registry-write.backend=registry-write"
    - "traefik.registry-write.frontend.rule=Host:registry.domain.com;Method:PUT,DELETE,POST,PATCH"
    - "traefik.registry-write.frontend.entryPoints=https"
    - "traefik.registry-write.port=8083"
    - "traefik.registry-read.backend=registry-read"
    - "traefik.registry-read.frontend.rule=Host:registry.domain.com;Method:GET,HEAD"
    - "traefik.registry-read.frontend.entryPoints=https"
    - "traefik.registry-read.port=8082"

```
Basicamente, temos 3 regras com a definição de 3 *backend/frontend* que o *Traefik* registrará e fará a gestão do serviço:

- Regra 1 (nexus): receberá requisições https://nexus.domain.com e passará para nosso serviço na porta 8081.

- Regra 2 (registry-read): receberá requisições https://registry.domain.com do tipos GET e HEAD e passará para o nosso serviço na porta 8082

- Regra 3 (registry-write): receberá requisições https://registry.domain.com dos tipos POST, PUT, PATCH, DELETE e passará para o nosso serviço na porta 8083.

A necessidade de 2 regras (identificando o tipo de requisição) para o Registry é bem simples: 

- quando precisarmos *pushar* uma imagem, a requisição irá para o repositório privado de imagens no Nexus (configurado com o *HTTP Connector* 8083);

- quando precisarmos baixar uma imagem, a requisição irá para um repositório que contem as imagens privadas construídas + acesso ao Docker Hub através de um proxy (repositório este disponível pelo *HTTP Connector* 8082).


## Configurandos os Repositórios no Nexus

Agora, precisamos acessar a interface do Nexus como administrador e criar 3 repositórios, sendo 1 de cada tipo abaixo:

- `docker hosted`: armazenará as imagens privadas;
- `docker proxy`: permitirá acessar o repositório Docker Hub;
- `docker group`: (*docker hosted* + *docker proxy*), que permitirá baixarmos imagens de ambos repositórios.

Subindo o stack e acessando sua url `nexus.domain.com`, você consegue logar com a conta inicial de admin (user=admin, pass=admin123).

Crie seu repositório privado `docker-private`:

![docker-private-repo](https://blog.sonatype.com/hs-fs/hubfs/Imported_Blog_Media/rafael-1.png?width=590&name=rafael-1.png)
*fonte: blog.sonatype.com/hs-fs/hubfs/Imported_Blog_Media/rafael-1.png?width=590&name=rafael-1.png*

Em seguida, crie seu repositório proxy para o Docker Hub:  

![docker-proxy-repo](https://blog.sonatype.com/hs-fs/hubfs/Imported_Blog_Media/rafael-2.png?width=590&name=rafael-2.png)
*fonte: blog.sonatype.com/hs-fs/hubfs/Imported_Blog_Media/rafael-2.png?width=590&name=rafael-2.png*

E finalmente, crie seu repositório de agrupamento

![docker-group-repo-01](https://blog.sonatype.com/hs-fs/hubfs/Imported_Blog_Media/rafael-4.png?width=590&name=rafael-4.png)
*fonte: blog.sonatype.com/hs-fs/hubfs/Imported_Blog_Media/rafael-4.png?width=590&name=rafael-4.png*
![docker-group-repo-02](https://blog.sonatype.com/hs-fs/hubfs/Imported_Blog_Media/rafael6.png?width=590&name=rafael6.png)
*fonte: blog.sonatype.com/hs-fs/hubfs/Imported_Blog_Media/rafael6.png?width=590&name=rafael6.png*


## Autenticando-se em seu Registry

Com os repositórios configurados corretamente, a sua url `https://registry.domain.com` já está funcionando e podemos testar.

Você pode executar o seguinte comando em um Docker Host:

```
$ docker login registry.domain.com
```

E inserir as credenciais de acesso (nome e senha). Utilize, por exemplo o usuário admin do nexus para testes.

Par baixar uma imagem do Docker Hub (hello-world, por exemplo) pelo seu Registry, basta fazer:

```
$ docker pull registry.domain.com/hello-world
```

Bem legal!

## Referências

- https://blog.sonatype.com/using-nexus-3-as-your-repository-part-3-docker-images
- https://www.terzo.org/creating-a-streamlined-docker-registry-with-sonatype-and-traefik.html



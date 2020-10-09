---
title: "Personalizando o Local Instalação de uma Distro Linux no WSL2"
date: 2020-10-08T22:18:03-03:00
draft: false
images:
tags:
  - linux
  - ubuntu
  - WSL2
  - windows
  - wsl
---

Para você que, assim como eu, está usando o WSL2 e deseja possuir várias instâncias Linux rodando no Windows, além de, claro, organizar melhor o local de instalação, este post pode lhe ajudar.

Se você ainda não conhece o **WSL2**, dá uma olhada na [documentação oficial](https://docs.microsoft.com/pt-br/windows/wsl/) da própria Microsoft, além de vídeos e posts na internet. Ao instalar e começar a usar, este post poderá ser útil para você.

Irei exemplificar com a instalação do Ubuntu.


## Instalando Ubuntu


A instalação é simples como manda a documentação oficial. Acessando a **Microsoft Store** a partir de seu computador, pesquise por Ubuntu, escolha a versão e apenas clique em **Obter**:


![instalando-ubuntu-store](https://raw.githubusercontent.com/matheuslao/matheuslao.dev/drafts/static/img/personalizando-local-instalacao-distro-linux-wsl2/01.png)


Após o download, ainda na mesma janela do produto na Microsoft Store, clique em **Iniciar** para a instalação e configuração inicial do sistema, com a criação do usuário:

![iniciando-ubuntu-store](https://raw.githubusercontent.com/matheuslao/matheuslao.dev/drafts/static/img/personalizando-local-instalacao-distro-linux-wsl2/02.png)

Após a criação do usuário, você já possui o Ubuntu instalado. Feche a Microsoft Store e deslogue-se do Ubuntu (um *exit* no terminal, por exemplo).


Em um terminal Windows com acesso ao utilitário **wsl**, verifique que a instalação do Ubuntu está presente e registrada no wsl com o comando abaixo:

```
wsl -l -v
```

![ubuntu-instalado](https://raw.githubusercontent.com/matheuslao/matheuslao.dev/drafts/static/img/personalizando-local-instalacao-distro-linux-wsl2/03.png)


## Desfazendo o Registro do Ubuntu e exportando disco

Desligue o Ubuntu:

```
wsl --shutdown Ubuntu-20.04
```

Exporte o disco para um local no formato ".tar":

```
wsl --export Ubuntu-20.04 D:\foo.tar
```

Agora, descadastre a distribuição do WSL:

```
wsl --unregister Ubuntu-20.04
```

![ubuntu-descadastrado-disco-exportado](https://raw.githubusercontent.com/matheuslao/matheuslao.dev/drafts/static/img/personalizando-local-instalacao-distro-linux-wsl2/04.png)


## Fazendo um novo Registro no WSL a partir do disco exportado

Importe no WSL o disco exportado anteriormente, definindo um novo nome para a Distribuição, assim como o local de instalação:

```
wsl --import ubuntu D:\virtual_machines\WSL2\ubuntu d:\foo.tar
```

![novo-ubuntu-importado-a-partir-do-disco](https://raw.githubusercontent.com/matheuslao/matheuslao.dev/drafts/static/img/personalizando-local-instalacao-distro-linux-wsl2/05.png)

Verifique que o disco está no lugar que queremos:

![windows-explorer-novo-local](https://raw.githubusercontent.com/matheuslao/matheuslao.dev/drafts/static/img/personalizando-local-instalacao-distro-linux-wsl2/06.png)



Voilá!

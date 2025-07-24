---
layout: post
title: "Compilando rails-new para POP OS com GLIBC 2.35"
date: 2025-07-24T13:00:10-03:00
---

Ao tentar rodar o [rails-new](https://github.com/rails/rails-new) pela primeira vez no POP OS 22.04, me deparei com o seguinte erro:

```
rails-new: /lib/x86_64-linux-gnu/libc.so.6: version `GLIBC_2.39' not found (required by rails-new)
```


Verificando a versão instalada da GLIBC:

```
$ ldd --version
ldd (Ubuntu GLIBC 2.35-0ubuntu3.10) 2.35
```


Como não queria atualizar a GLIBC do sistema (para evitar possíveis dores de cabeça), a solução foi compilar o `rails-new` localmente com a versão do sistema.


## Passo a passo da compilação

### 1. Instalar o Rust

```bash
$ curl https://sh.rustup.rs -sSf | sh
```

Aceite a instalação padrão (pressione Enter). Depois, carregue o ambiente:

```
$ source $HOME/.cargo/env
```

### 2. Clonar e compilar o rails-new


```
$ git clone https://github.com/rails/rails-new.git
$ cd rails-new
$ cargo build --release
```

Se tudo correr bem, a última linha da saída será parecida com:

```
Finished release [optimized] target(s) in 8.68s
```

### 3. Mover o binário para um local acessível


```
$ mv target/release/rails-new ~/.local/bin/
$ chmod +x ~/.local/bin/rails-new
```

### 4. Testar

```
$ rails-new --version
```

Voilá! 🎉


### (Opcional) Remover o Rust

Se não for mais necessário:

```
$ rustup self uninstall
```


**ℹ️ Nota:**  
> Esse post serve apenas como documentação pessoal. Caso alguém enfrente o mesmo problema, espero que ajude.



# ISO do Anaconda WebUI para imagens bootc (template)

[![Use this template](https://img.shields.io/badge/Use%20this-template-2ea44f?logo=github)](https://github.com/Ferlinuxdebian/anaconda-webui-bootc-installer/generate)
![feito com bootc](https://img.shields.io/badge/feito_com-bootc-51A2DA)
![Anaconda WebUI](https://img.shields.io/badge/instalador-Anaconda_WebUI-3fb950)

Este repositório é um **template**: ele gera um ISO com o **Anaconda WebUI**
que instala em disco a sua imagem `bootc` (por exemplo, a criada com o template
[gnome-minimal](https://github.com/Ferlinuxdebian/gnome-minimal)).

Você só altera **um arquivo**: o `build.conf`. O resto já está pronto.
O GitHub Actions gera o ISO e o publica em **Releases**.

> **Antes do primeiro build:** no GitHub, abra
> **Settings → Actions → General → Workflow permissions** e marque
> **Read and write permissions**. Sem isso, o workflow não consegue publicar
> o ISO.

---

## 1. Crie o seu repositório

No GitHub, clique em **Use this template** (**Usar este modelo**) **→ Create a
new repository**.

> Para o dono deste repositório: marque **Settings → General → Template
> repository** para habilitar o botão **Use this template**.

---

## 2. Altere o `build.conf`

Escolha uma das duas formas.

### Opção A — direto no GitHub (sem instalar nada)

1. Abra o seu repositório no GitHub.
2. Clique em `build.conf`.
3. Clique no lápis (**Edit this file**).
4. Troque os valores.
5. Clique em **Commit changes**.

O build começa automaticamente.

### Opção B — clonando com Git

```bash
git clone https://github.com/SEU-USUARIO/SEU-REPOSITORIO.git
cd SEU-REPOSITORIO
nano build.conf      # ou use o editor que preferir
git add build.conf
git commit -m "Configura a imagem do ISO"
git push origin main
```

O build começa no push.

---

## 3. O que tem no `build.conf`

```bash
IMAGE_NAME=bootc-gnome-minimal-f45
FEDORA_VERSION=45
LINK_DA_IMAGEM_PERSONALIZADA=ghcr.io/ferlinuxdebian/bootc-gnome-minimal-f45:latest
ASSINADA_COM_CONSIG=true
```

| Variável | O que colocar |
| --- | --- |
| `IMAGE_NAME` | Nome da imagem no registro do GitHub (GHCR), **sem** `ghcr.io/`, **sem** o usuário e **sem** a tag. Também vira o nome do ISO: `output/<IMAGE_NAME>.iso`. |
| `FEDORA_VERSION` | Versão do Fedora usada na imagem base do instalador: `quay.io/fedora/fedora-bootc:<FEDORA_VERSION>`. O padrão é `45`; para usar Fedora 44, coloque `44`. Isso muda o instalador (Anaconda), não a imagem que ele instala. |
| `LINK_DA_IMAGEM_PERSONALIZADA` | Link completo da imagem que o instalador vai baixar, no formato `registro/repositório:tag` (ex.: `ghcr.io/joao/minha-imagem:latest`). |
| `ASSINADA_COM_CONSIG` | `true` exige que a imagem seja assinada. `false` aceita qualquer imagem. |

Exemplo com outra imagem:

```bash
IMAGE_NAME=minha-imagem
FEDORA_VERSION=45
LINK_DA_IMAGEM_PERSONALIZADA=ghcr.io/joao/minha-imagem:latest
ASSINADA_COM_CONSIG=false
```

Para usar o instalador baseado no Fedora 44, basta trocar:

```bash
FEDORA_VERSION=44
```

> **Se a sua imagem não for assinada, use `false`.**
> O padrão é `true` porque a `bootc-gnome-minimal-f45` é assinada.
> `true` apenas ativa o `enforce-container-sigpolicy` no bootc install; não é
> preciso adicionar chave nem política neste repositório.

---

## 4. Baixe o ISO

1. Abra a aba **Actions** e acompanhe o build chamado **Gerar ISO de instalação**.
2. Quando terminar, abra **Releases** (ou o link
   `https://github.com/SEU-USUARIO/SEU-REPOSITORIO/releases/tag/iso-latest`).
3. Baixe o arquivo `IMAGE_NAME.iso`.

Se o ISO passar de ~1,9 GiB, o workflow o divide em partes
(`...iso.part-00`, `...iso.part-01` etc.). Baixe todas e junte:

```bash
cat minha-imagem.iso.part-* > minha-imagem.iso
```

---

## 5. Rodar localmente (opcional)

Em uma máquina Fedora:

```bash
sudo dnf install -y just podman
sudo just iso
```

O ISO fica em `output/<IMAGE_NAME>.iso`.

Para testar a configuração sem gerar nada:

```bash
just check
```

---

## 6. Problemas comuns

**O build falha com `mount: /run/osbuild/containers/storage: permission denied`**
O workflow precisa rodar no Ubuntu 24.04. Ele já está fixado em
`ubuntu-24.04`; não troque para `ubuntu-latest`.

**O ISO não aparece na release**
Veja o build em **Actions**. Se o erro for de permissão, ative
**Settings → Actions → General → Workflow permissions → Read and write
permissions**.

**A instalação recusa a imagem com `ASSINADA_COM_CONSIG=true`**
A imagem não está assinada ou a assinatura não é aceita pelo instalador. Use
`false` se a imagem não for assinada.

**Não consigo baixar a imagem na instalação**
A imagem precisa ser pública. Se for privada, torne o pacote público no
GHCR/quay.io.

**Quero o instalador legado (Anaconda GTK)**
Use o repositório
[anaconda-bootc-isos](https://github.com/Ferlinuxdebian/anaconda-bootc-isos).

---

## Licença

CC BY 4.0 — veja `LICENSE.md`.

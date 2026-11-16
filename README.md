# Criação de ISO personalizado com bootc

Este guia explica como construir a imagem do instalador (Anaconda) e gerar o ISO de instalação a partir de uma imagem `bootc` personalizada usando o `just`.

> [!WARNING]
> **ATENÇÃO!!!** ⚠️
> Este método usa o novo instalador (**Anaconda WebUI**). Para usar a versão com o instalador legado (**Anaconda GTK**), acesse este repositório: [anaconda-bootc-isos](https://github.com/Ferlinuxdebian/anaconda-bootc-isos)

### 1. Construa a imagem do Anaconda com a sua imagem bootc personalizada

Para construir a imagem de container do instalador usando a sua imagem `bootc` personalizada, execute:

```
sudo just build <sua-imagem-bootc-personalizada>
```

> **Exemplo:**
>
> ```
> sudo just build quay.io/centos-bootc/centos-bootc:stream9
> ```

### 2. Crie o ISO de instalação com o Anaconda

Depois de construir a imagem, gere o arquivo ISO de instalação com o comando:

```
sudo just create-iso
```

> 💡 **Observação:** o ISO final será salvo em um novo diretório (`bootc-generic-iso/` ou correspondente) criado automaticamente na pasta onde você executou o comando `just`.

## Verificação de assinatura de contêiner (opcional)

Por padrão, o instalador aceita imagens assinadas e não assinadas. Para exigir assinatura, passe `true` como segundo parâmetro do `just build`:

```bash
sudo just build <sua-imagem-bootc-personalizada> true
sudo just create-iso
```

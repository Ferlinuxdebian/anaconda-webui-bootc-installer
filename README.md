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

Por padrão (`ENFORCE_SIGPOLICY=false`), o instalador aceita tanto imagens assinadas quanto não assinadas — a política padrão do Fedora é `insecureAcceptAnything`.

Para exigir assinatura na instalação, passe `true` como segundo parâmetro do `just build`:

```bash
sudo just build <sua-imagem-bootc-personalizada> true
sudo just create-iso
```

Isso grava `/etc/bootc/install/50-enforce-sigpolicy.toml` com `enforce-container-sigpolicy = true`, que é lido pelo `bootc install` no momento da instalação. O comando kickstart `bootc` do Anaconda no Fedora 45 não aceita `--enforce-container-sigpolicy`, por isso usamos esse drop-in de configuração.

> **Atenção:** habilitar a exigência não cria a política de assinatura. Com o `policy.json` padrão do Fedora (`insecureAcceptAnything`), o bootc rejeita o pull e a instalação não prossegue. Para aceitar imagens assinadas, forneça um `/etc/containers/policy.json` que requeira assinaturas, por exemplo:

```json
{
  "default": [{"type": "reject"}],
  "transports": {
    "docker": {
      "ghcr.io/ferlinuxdebian": [
        {
          "type": "sigstoreSigned",
          "keyPath": "/etc/pki/sigstore/cosign.pub",
          "signedIdentity": {"type": "matchRepoDigestOrExact"}
        }
      ]
    }
  }
}
```

Ajuste o namespace (`ghcr.io/ferlinuxdebian`) e o caminho da chave pública do cosign conforme o seu caso.

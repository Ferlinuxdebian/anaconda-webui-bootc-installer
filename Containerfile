# Imagem do instalador com o Anaconda WebUI.
#
# Normalmente você NÃO edita este arquivo: o script scripts/build-iso.sh lê
# build.conf e passa CONTAINER_NAME e ENFORCE_SIGPOLICY automaticamente.
FROM quay.io/fedora/fedora-bootc:45

# Imagem bootc personalizada que será instalada pelo ISO.
# Definida em build.conf (LINK_DA_IMAGEM_PERSONALIZADA) e passada pelo script.
ARG CONTAINER_NAME=quay.io/fedora/fedora-bootc:45

# Quando "true", exige assinatura de contêiner na instalação
# (equivalente a --enforce-container-sigpolicy no bootc install).
# Definido em build.conf (ASSINADA_COM_CONSIG).
ARG ENFORCE_SIGPOLICY=false

# Instala os pacotes essenciais do Anaconda para gerar o ISO com o instalador
RUN dnf install -qy \
    anaconda \
    anaconda-install-img-deps \
    anaconda-dracut \
    dracut-config-generic \
    dracut-network \
    net-tools \
    grub2-efi-x64-cdboot \
    cockpit-ws \
    cockpit-bridge \
    anaconda-webui \
    firefox \
    gnome-kiosk \
    mesa-dri-drivers \
    default-fonts-core-sans \
    jq

# estas são ferramentas de compilação necessárias. Se você usar um container
# de compilação separado, elas devem ser instaladas nele
RUN dnf install -qy \
    xorrisofs \
    squashfs-tools

RUN dnf clean all

# O comando kickstart `bootc` do Anaconda (F45) não expõe a opção
# --enforce-container-sigpolicy, mas o bootc lê a configuração de instalação em
# /etc/bootc/install no ambiente do instalador. Quando ENFORCE_SIGPOLICY=true,
# o bootc passa a exigir que a política de contêineres aprove a assinatura.
#
# Atenção: esta opção NÃO assina a imagem. Ela apenas liga a exigência no
# bootc install. A imagem precisa estar assinada; a verificação usa a política
# de confiança do ambiente do instalador.
RUN mkdir -p /etc/bootc/install && \
    if [ "$ENFORCE_SIGPOLICY" = "true" ]; then \
        printf '[install]\nenforce-container-sigpolicy = true\n' \
            > /etc/bootc/install/50-enforce-sigpolicy.toml; \
    else \
        rm -f /etc/bootc/install/50-enforce-sigpolicy.toml; \
    fi

RUN mkdir -p /boot/efi && cp -ra /usr/lib/efi/*/*/EFI /boot/efi

# ---

# algumas configurações para o nosso ISO

# Configurado com inst.webui para iniciar o Anaconda WebUI como instalador principal
RUN mkdir -p /usr/lib/image-builder/bootc && \
    printf '%s\n' \
        'label: "Fedora-bootc-Installer"' \
        'grub2:' \
        '  timeout: 5' \
        '  entries:' \
        '    - name: "Install Fedora (bootc WebUI Wayland Local)"' \
        '      linux: ${kernelpath} ${root} inst.webui' \
        '      initrd: ${initrdpath}' \
        > /usr/lib/image-builder/bootc/iso.yaml

# algumas configurações para o anaconda

RUN printf '%s\n' \
    "bootc --source-imgref registry:${CONTAINER_NAME} --target-imgref ${CONTAINER_NAME}" \
    > /usr/share/anaconda/interactive-defaults.ks

# ---

# estas coisas normalmente são feitas pelo `lorax` para o `anaconda` funcionar;
# isto é o mínimo necessário

RUN echo "install:x:0:0:root:/root:/usr/libexec/anaconda/run-anaconda" >> /etc/passwd && \
    echo "install::14438:0:99999:7:::" >> /etc/shadow && \
    passwd -d root

RUN mv /usr/share/anaconda/list-harddrives-stub /usr/bin/list-harddrives && \
    mv /etc/yum.repos.d /etc/anaconda.repos.d && \
    ln -s /lib/systemd/system/anaconda.target /etc/systemd/system/default.target && \
    rm -v /usr/lib/systemd/system-generators/systemd-gpt-auto-generator

RUN ln -s /usr/lib/systemd/system/anaconda-shell@.service /usr/lib/systemd/system/autovt@.service

RUN mkdir -p /usr/lib/systemd/logind.conf.d && \
    printf '%s\n' '[Login]' 'ReserveVT=2' \
        > /usr/lib/systemd/logind.conf.d/anaconda-shell.conf

RUN mkdir "$(realpath /root)" && \
    kernel=$(kernel-install list --json pretty | jq -r '.[] | select(.has_kernel == true) | .version') && \
    DRACUT_NO_XATTR=1 dracut --force -v --zstd --reproducible --no-hostonly \
        --add "anaconda" \
        "/usr/lib/modules/${kernel}/initramfs.img" "${kernel}"

RUN mkdir -p /etc/systemd/user/pipewire.service.d && \
    printf '%s\n' '[Unit]' 'ConditionUser=' \
        > /etc/systemd/user/pipewire.service.d/allowroot.conf

RUN mkdir -p /etc/systemd/user/pipewire.socket.d && \
    printf '%s\n' '[Unit]' 'ConditionUser=' \
        > /etc/systemd/user/pipewire.socket.d/allowroot.conf
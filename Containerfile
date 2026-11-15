FROM quay.io/fedora/fedora-bootc:45

# Imagem bootc personalizada que será instalada pelo ISO
ARG CONTAINER_NAME=quay.io/fedora/fedora-bootc:45

# Quando "true", exige que a política de contêineres requeira assinaturas
# (equivalente a --enforce-container-sigpolicy no bootc install).
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
# exigimos que o /etc/containers/policy.json requeira assinaturas.
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

RUN mkdir -p /usr/lib/image-builder/bootc

# Configurado com inst.webui para iniciar o Anaconda WebUI como instalador principal
RUN cat <<EOF > /usr/lib/image-builder/bootc/iso.yaml
label: "Fedora-bootc-Installer"
grub2:
  timeout: 5
  entries:
    - name: "Install Fedora (bootc WebUI Wayland Local)"
      linux: \${kernelpath} \${root} inst.webui
      initrd: \${initrdpath}
EOF

# algumas configurações para o anaconda

COPY <<EOT /usr/share/anaconda/interactive-defaults.ks
bootc --source-imgref registry:${CONTAINER_NAME} --target-imgref ${CONTAINER_NAME}
EOT

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

RUN mkdir -p /usr/lib/systemd/logind.conf.d
COPY <<EOT /usr/lib/systemd/logind.conf.d/anaconda-shell.conf
[Login]
ReserveVT=2
EOT

RUN mkdir "$(realpath /root)" && \
    kernel=$(kernel-install list --json pretty | jq -r '.[] | select(.has_kernel == true) | .version') && \
    DRACUT_NO_XATTR=1 dracut --force -v --zstd --reproducible --no-hostonly \
        --add "anaconda" \
        "/usr/lib/modules/${kernel}/initramfs.img" "${kernel}"

RUN mkdir /etc/systemd/user/pipewire.service.d/
COPY <<EOT /etc/systemd/user/pipewire.service.d/allowroot.conf
[Unit]
ConditionUser=
EOT

RUN mkdir /etc/systemd/user/pipewire.socket.d/
COPY <<EOT /etc/systemd/user/pipewire.socket.d/allowroot.conf
[Unit]
ConditionUser=
EOT
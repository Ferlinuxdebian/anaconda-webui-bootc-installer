FROM quay.io/fedora/fedora-bootc:45

ARG CONTAINER_NAME=quay.io/fedora/fedora-bootc:45

# Instalação de pacotes essenciais
RUN dnf install -qy \
    anaconda \
    anaconda-install-img-deps \
    anaconda-dracut \
    dracut-config-generic \
    dracut-network \
    net-tools \
    grub2-efi-x64-cdboot \
    plymouth \
    cockpit-ws \
    cockpit-bridge \
    anaconda-webui \
    firefox \
    cage \
    mesa-dri-drivers \
    default-fonts-core-sans \
    jq

# Ferramentas de build da ISO
RUN dnf install -qy \
    xorrisofs \
    squashfs-tools

RUN dnf clean all

RUN mkdir -p /boot/efi && cp -ra /usr/lib/efi/*/*/EFI /boot/efi

# --- Configuração da ISO e Kernel ---

RUN mkdir -p /usr/lib/image-builder/bootc

# Adicionado 'nvidia.modeset=1' e 'nouveau.modeset=1' para forçar o Kernel a ativar os drivers gráficos imediatamente no boot
RUN cat <<EOF > /usr/lib/image-builder/bootc/iso.yaml
label: "Fedora-bootc-Installer"
grub2:
  timeout: 5
  entries:
    - name: "Install Fedora (bootc WebUI Wayland Local)"
      linux: \${kernelpath} \${root} inst.webui nvidia.modeset=1 nouveau.modeset=1
      initrd: \${initrdpath}
EOF

# Configuração do Anaconda
COPY <<EOT /usr/share/anaconda/interactive-defaults.ks
bootc --source-imgref registry:${CONTAINER_NAME} --target-imgref ${CONTAINER_NAME}
EOT

# --- Configurações do Sistema e Segurança para o Instalador ---

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

# --- GARANTIA DE CARREGAMENTO GRÁFICO (BARE METAL NVIDIA) ---

# Sobrescreve o target do Anaconda para só iniciar DEPOIS que o subsistema gráfico do Linux (Udev/DRI) achar a GPU
RUN mkdir -p /etc/systemd/system/anaconda.target.d/ && \
    cat <<EOF > /etc/systemd/system/anaconda.target.d/wait-graphics.conf
[Unit]
Requires=graphics.target
After=graphics.target
EOF

# Força o serviço do instalador a esperar especificamente pelo dispositivo físico de renderização (/dev/dri/card0)
RUN mkdir -p /etc/systemd/system/anaconda.service.d/ && \
    cat <<EOF > /etc/systemd/system/anaconda.service.d/wait-device.conf
[Unit]
Requires=dev-dri-card0.device
After=dev-dri-card0.device
EOF

# Geração do Initramfs incluindo explicitamente os drivers de vídeo e suporte a KMS dentro do boot inicial
RUN mkdir "$(realpath /root)" && \
    kernel=$(kernel-install list --json pretty | jq -r '.[] | select(.has_kernel == true) | .version') && \
    DRACUT_NO_XATTR=1 dracut --force -v --zstd --reproducible --no-hostonly \
        --add "anaconda" \
        --add-drivers "nouveau drm drm_kms_helper" \
        "/usr/lib/modules/${kernel}/initramfs.img" "${kernel}"

# --- Permissões de Áudio (Pipewire) ---

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
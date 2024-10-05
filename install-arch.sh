#!/bin/bash

# Configurações iniciais
set -e
timedatectl set-ntp true

# Variáveis do disco - ajustar conforme seu disco
DISK="/dev/nvme0n1"
USERNAME="seu_usuario"  # Nome do usuário a ser criado

# Pausa para confirmar a etapa
read -p "Pressione Enter para começar o particionamento do disco $DISK..."

# Tabela de partições usando percentuais e tamanho fixo para swap
echo "Particionando o disco $DISK..."

# Partição EFI: 1% do disco
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart ESP fat32 0% 1%
parted -s "$DISK" set 1 esp on

# Partição root: 15% do disco para root em btrfs
parted -s "$DISK" mkpart primary btrfs 1% 16%

# Partição swap: 18 GB de swap
parted -s "$DISK" mkpart primary linux-swap 16% 34GiB

# Partição home: o restante do disco (depois de 34GiB até 100%) para home em XFS
parted -s "$DISK" mkpart primary xfs 34GiB 100%

# Pausa para revisar as partições
read -p "Pressione Enter para continuar com a formatação das partições..."

# Formatação das partições
echo "Formatando as partições..."
mkfs.fat -F32 "${DISK}p1"  # Partição EFI
mkfs.btrfs "${DISK}p2"     # Partição root
mkfs.xfs "${DISK}p4"       # Partição /home
mkswap "${DISK}p3"         # Swap
swapon "${DISK}p3"

# Pausa para confirmar antes de montar as partições
read -p "Pressione Enter para continuar com a montagem das partições..."

# Montagem das partições
echo "Montando as partições..."
mount "${DISK}p2" /mnt
mkdir /mnt/boot
mount "${DISK}p1" /mnt/boot
mkdir /mnt/home
mount "${DISK}p4" /mnt/home

# Pausa para confirmar antes de instalar o sistema base
read -p "Pressione Enter para instalar o sistema base..."

# Instalação do sistema base
echo "Instalando sistema base..."
pacstrap /mnt base linux linux-firmware base-devel btrfs-progs xfsprogs nano vim

# Pausa para confirmar a geração do fstab
read -p "Pressione Enter para gerar o fstab..."

# Gerando fstab
echo "Gerando fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Pausa antes de entrar no chroot
read -p "Pressione Enter para entrar no chroot..."

# Chroot no sistema
echo "Entrando no chroot..."
arch-chroot /mnt /bin/bash <<EOF

# Definindo a timezone e localidade
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc
echo "pt_BR.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=pt_BR.UTF-8" > /etc/locale.conf
echo "KEYMAP=br-abnt2" > /etc/vconsole.conf

# Definindo o hostname
echo "samsung-book" > /etc/hostname
echo "127.0.0.1    localhost" >> /etc/hosts
echo "::1          localhost" >> /etc/hosts
echo "127.0.1.1    samsung-book.localdomain samsung-book" >> /etc/hosts

# Pausa antes de configurar o swap para hibernação
read -p "Pressione Enter para configurar o swap e hibernação..."

# Configurando swap para hibernação
UUID_SWAP=$(blkid -s UUID -o value ${DISK}p3)
echo "GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 quiet splash resume=UUID=$UUID_SWAP\"" >> /etc/default/grub

# Pausa para confirmar a instalação de pacotes adicionais
read -p "Pressione Enter para instalar pacotes adicionais..."

# Instalando pacotes adicionais
pacman -Sy --noconfirm grub efibootmgr os-prober networkmanager wpa_supplicant \
  mtools dosfstools reflector linux-headers xdg-user-dirs xdg-utils \
  nvidia nvidia-utils nvidia-settings nvidia-dkms mesa sddm plasma-wayland-session \
  kde-applications pipewire pipewire-pulse pipewire-alsa pipewire-jack \
  openssh avahi nss-mdns cups hplip fprintd sudo libvirt qemu ebtables \
  dnsmasq bridge-utils gnome-boxes

# Pausa antes de habilitar serviços
read -p "Pressione Enter para habilitar serviços essenciais..."

# Habilitando serviços essenciais
systemctl enable NetworkManager
systemctl enable sddm
systemctl enable fprintd.service
systemctl enable sshd
systemctl enable avahi-daemon
systemctl enable cups
systemctl enable libvirtd

# Pausa antes de configurar o GRUB
read -p "Pressione Enter para configurar o GRUB..."

# Configurando o GRUB
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Pausa antes de criar o usuário
read -p "Pressione Enter para criar o usuário $USERNAME com permissões sudo..."

# Criando o usuário com permissões sudo
echo "Criando o usuário $USERNAME com permissões administrativas..."
useradd -m -G wheel,libvirt,kvm,video,input,storage $USERNAME
echo "Defina a senha para o usuário $USERNAME:"
passwd $USERNAME

# Concedendo permissões sudo ao usuário
sed -i '/^# %wheel ALL=(ALL) ALL/s/^# //' /etc/sudoers

EOF

# Pausa antes de sair do chroot e finalizar
read -p "Pressione Enter para finalizar, desmontar as partições e reiniciar o sistema..."

# Saindo do chroot
echo "Instalação finalizada. Desmonte as partições e reinicie o sistema."
umount -R /mnt
swapoff -a
reboot

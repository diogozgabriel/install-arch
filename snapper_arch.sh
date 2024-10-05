#!/bin/bash

# Função para verificar se um comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 1. Verificar se o usuário é root
if [ "$EUID" -ne 0 ]; then
    echo "Por favor, execute como root."
    exit 1
fi

echo "Iniciando a instalação e configuração do Snapper e Grub-Btrfs..."

# 2. Atualizar o sistema
echo "Atualizando os pacotes do sistema..."
pacman -Syu --noconfirm

# 3. Instalar o Snapper
echo "Instalando o Snapper..."
pacman -S snapper --noconfirm

# 4. Configurar o Snapper para o volume root
echo "Configurando o Snapper para o volume root..."
snapper -c root create-config /

# 5. Verificar se o diretório /@snapshots já existe
SNAPSHOT_DIR="/@snapshots"
if [ ! -d "$SNAPSHOT_DIR" ]; then
    echo "Criando o subvolume de snapshots em $SNAPSHOT_DIR..."
    btrfs subvolume create "$SNAPSHOT_DIR"
fi

# 6. Ajustar permissões (opcional, mas recomendado)
echo "Ajustando permissões para Snapper..."
chmod a+rx /.snapshots

# 7. Habilitar os timers automáticos do Snapper (limpeza e snapshots regulares)
echo "Habilitando os timers automáticos do Snapper..."
systemctl enable --now snapper-timeline.timer
systemctl enable --now snapper-cleanup.timer

# 8. Instalar grub-btrfs
echo "Instalando grub-btrfs..."
if ! command_exists yay; then
    echo "Instalador de AUR (yay) não encontrado. Por favor, instale o yay ou use outro AUR helper."
    exit 1
fi
yay -S grub-btrfs --noconfirm

# 9. Habilitar o serviço grub-btrfsd.service para monitorar snapshots
echo "Habilitando o serviço grub-btrfsd.service..."
systemctl enable --now grub-btrfsd.service

# 10. Atualizar o GRUB para detectar snapshots
echo "Atualizando o GRUB para detectar snapshots..."
grub-mkconfig -o /boot/grub/grub.cfg

# 11. Criar um snapshot de teste
echo "Criando um snapshot de teste..."
snapper -c root create --description "Snapshot de teste"

echo "Configuração concluída. O Snapper está integrado com o GRUB."
echo "Reinicie o sistema para verificar se os snapshots estão disponíveis no menu do GRUB."

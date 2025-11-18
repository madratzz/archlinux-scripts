#!/bin/sh

yay -S --noconfirm --needed spotify spicetify-cli spicetify-marketplace-bin
sudo chmod 777 /opt/spotify -R
curl -fsSL https://raw.githubusercontent.com/spicetify/spicetify-cli/master/install.sh | sh
spicetify backup apply

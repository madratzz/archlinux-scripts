#!/bin/sh

yay -R 1password-beta 1password-cli
yay -R signal-desktop

omarchy-webapp-remove Basecamp
omarchy-webapp-remove HEY
omarchy-webapp-remove Zoom


rm ~/.local/share/applications/Basecamp.desktop
rm ~/.local/share/applications/HEY.desktop 
rm ~/.local/share/applications/Zoom.desktop 

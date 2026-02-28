#!/bin/bash

# ─────────────────────────────────────────
#  set_ip.sh — Interactive IP configurator
# ─────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Root check ──────────────────────────
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}✖ This script must be run as root (sudo).${NC}"
  exit 1
fi

# ── Helpers ─────────────────────────────
valid_ip() {
  local ip=$1
  local re='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
  [[ $ip =~ $re ]] || return 1
  IFS='.' read -r -a octets <<< "$ip"
  for o in "${octets[@]}"; do
    (( o < 0 || o > 255 )) && return 1
  done
  return 0
}

valid_prefix() {
  [[ $1 =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 32 ))
}

prompt() {
  local msg=$1 var=$2 default=$3
  while true; do
    if [[ -n $default ]]; then
      read -rp "$(echo -e "${CYAN}  ▸ ${msg} [${default}]: ${NC}")" input
      input=${input:-$default}
    else
      read -rp "$(echo -e "${CYAN}  ▸ ${msg}: ${NC}")" input
    fi
    [[ -n $input ]] && { printf -v "$var" '%s' "$input"; return; }
    echo -e "${RED}    Cannot be empty.${NC}"
  done
}

detect_method() {
  if command -v nmcli &>/dev/null && nmcli -t con show &>/dev/null 2>&1; then
    echo "nmcli"
  elif [[ -d /etc/netplan ]]; then
    echo "netplan"
  elif [[ -f /etc/network/interfaces ]]; then
    echo "interfaces"
  else
    echo "iproute2"
  fi
}

# ── Banner ───────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════╗"
echo -e "║     Linux IP Configurator v1.0       ║"
echo -e "╚══════════════════════════════════════╝${NC}"
echo ""

# ── List interfaces ───────────────────────
echo -e "${BOLD}Available network interfaces:${NC}"
echo ""
mapfile -t IFACES < <(ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$')
for i in "${!IFACES[@]}"; do
  iface="${IFACES[$i]}"
  current_ip=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP '(?<=inet )\S+' | head -1)
  state=$(ip link show "$iface" | grep -oP '(?<=state )\S+')
  echo -e "  ${YELLOW}[$((i+1))]${NC} ${BOLD}$iface${NC}  ${current_ip:-no IP}  (${state})"
done
echo ""

# ── Select interface ──────────────────────
while true; do
  read -rp "$(echo -e "${CYAN}  ▸ Select interface number: ${NC}")" sel
  if [[ $sel =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= ${#IFACES[@]} )); then
    IFACE="${IFACES[$((sel-1))]}"
    break
  fi
  echo -e "${RED}    Invalid selection.${NC}"
done

echo ""
echo -e "${BOLD}Configure: ${CYAN}$IFACE${NC}"
echo ""

# ── DHCP or static ────────────────────────
echo -e "  ${YELLOW}[1]${NC} DHCP (automatic)"
echo -e "  ${YELLOW}[2]${NC} Static IP"
echo ""
while true; do
  read -rp "$(echo -e "${CYAN}  ▸ Choose [1/2]: ${NC}")" mode
  [[ $mode == "1" || $mode == "2" ]] && break
  echo -e "${RED}    Enter 1 or 2.${NC}"
done

METHOD=$(detect_method)
echo ""
echo -e "  ${BOLD}Detected config method:${NC} ${YELLOW}$METHOD${NC}"
echo ""

# ════════════════════════════════════════
#  DHCP
# ════════════════════════════════════════
if [[ $mode == "1" ]]; then
  echo -e "${BOLD}Setting $IFACE to DHCP...${NC}"

  case $METHOD in
    nmcli)
      CON=$(nmcli -t -f NAME,DEVICE con show | grep ":$IFACE$" | cut -d: -f1 | head -1)
      [[ -z $CON ]] && CON=$IFACE
      nmcli con mod "$CON" ipv4.method auto ipv4.addresses "" ipv4.gateway "" ipv4.dns ""
      nmcli con down "$CON" &>/dev/null; nmcli con up "$CON"
      ;;
    netplan)
      FILE=$(ls /etc/netplan/*.yaml 2>/dev/null | head -1)
      cp "$FILE" "${FILE}.bak"
      python3 - <<EOF
import yaml, sys
with open("$FILE") as f: cfg = yaml.safe_load(f)
eth = cfg.setdefault("network", {}).setdefault("ethernets", {}).setdefault("$IFACE", {})
eth["dhcp4"] = True
eth.pop("addresses", None); eth.pop("routes", None); eth.pop("nameservers", None)
with open("$FILE", "w") as f: yaml.dump(cfg, f)
EOF
      netplan apply
      ;;
    interfaces)
      sed -i "/iface $IFACE/,/^$/d" /etc/network/interfaces
      echo -e "\nauto $IFACE\niface $IFACE inet dhcp" >> /etc/network/interfaces
      ip link set "$IFACE" down; ip link set "$IFACE" up
      dhclient "$IFACE"
      ;;
    iproute2)
      ip addr flush dev "$IFACE"
      dhclient "$IFACE" 2>/dev/null || dhcpcd "$IFACE" 2>/dev/null
      ;;
  esac

  echo -e "${GREEN}✔ DHCP configured on $IFACE${NC}"

# ════════════════════════════════════════
#  STATIC
# ════════════════════════════════════════
else
  echo -e "${BOLD}Enter static IP details:${NC}"
  echo ""

  while true; do
    prompt "IP address" IP_ADDR
    valid_ip "$IP_ADDR" && break
    echo -e "${RED}    Invalid IP address.${NC}"
  done

  while true; do
    prompt "Prefix length (e.g. 24)" PREFIX "24"
    valid_prefix "$PREFIX" && break
    echo -e "${RED}    Invalid prefix (1-32).${NC}"
  done

  while true; do
    prompt "Gateway" GATEWAY
    valid_ip "$GATEWAY" && break
    echo -e "${RED}    Invalid gateway IP.${NC}"
  done

  prompt "DNS server 1" DNS1 "8.8.8.8"
  prompt "DNS server 2 (optional)" DNS2 "1.1.1.1"

  echo ""
  echo -e "${BOLD}Summary:${NC}"
  echo -e "  Interface : ${CYAN}$IFACE${NC}"
  echo -e "  IP        : ${CYAN}${IP_ADDR}/${PREFIX}${NC}"
  echo -e "  Gateway   : ${CYAN}$GATEWAY${NC}"
  echo -e "  DNS       : ${CYAN}$DNS1, $DNS2${NC}"
  echo -e "  Method    : ${CYAN}$METHOD${NC}"
  echo ""
  read -rp "$(echo -e "${YELLOW}  Apply? [y/N]: ${NC}")" confirm
  [[ ! $confirm =~ ^[Yy]$ ]] && echo "Aborted." && exit 0

  echo ""
  echo -e "${BOLD}Applying configuration...${NC}"

  case $METHOD in
    nmcli)
      CON=$(nmcli -t -f NAME,DEVICE con show | grep ":$IFACE$" | cut -d: -f1 | head -1)
      [[ -z $CON ]] && CON=$IFACE
      nmcli con mod "$CON" \
        ipv4.method manual \
        ipv4.addresses "${IP_ADDR}/${PREFIX}" \
        ipv4.gateway "$GATEWAY" \
        ipv4.dns "$DNS1 $DNS2"
      nmcli con down "$CON" &>/dev/null
      nmcli con up "$CON"
      ;;
    netplan)
      FILE=$(ls /etc/netplan/*.yaml 2>/dev/null | head -1)
      [[ -z $FILE ]] && FILE="/etc/netplan/01-netcfg.yaml"
      cp "$FILE" "${FILE}.bak" 2>/dev/null || true
      cat > "$FILE" <<EOF
network:
  version: 2
  ethernets:
    $IFACE:
      dhcp4: false
      addresses:
        - ${IP_ADDR}/${PREFIX}
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses: [$DNS1, $DNS2]
EOF
      netplan apply
      ;;
    interfaces)
      cp /etc/network/interfaces /etc/network/interfaces.bak
      sed -i "/iface $IFACE/,/^$/d" /etc/network/interfaces
      cat >> /etc/network/interfaces <<EOF

auto $IFACE
iface $IFACE inet static
  address ${IP_ADDR}/${PREFIX}
  gateway $GATEWAY
  dns-nameservers $DNS1 $DNS2
EOF
      ifdown "$IFACE" 2>/dev/null; ifup "$IFACE"
      ;;
    iproute2)
      ip addr flush dev "$IFACE"
      ip addr add "${IP_ADDR}/${PREFIX}" dev "$IFACE"
      ip link set "$IFACE" up
      ip route add default via "$GATEWAY" dev "$IFACE" 2>/dev/null || \
        ip route replace default via "$GATEWAY" dev "$IFACE"
      # Write DNS to resolv.conf
      cat > /etc/resolv.conf <<EOF
nameserver $DNS1
nameserver $DNS2
EOF
      echo -e "${YELLOW}  ⚠ iproute2 changes are temporary (no reboot persistence).${NC}"
      ;;
  esac

  echo -e "${GREEN}✔ Static IP ${IP_ADDR}/${PREFIX} applied to $IFACE${NC}"
fi

# ── Verify ───────────────────────────────
echo ""
echo -e "${BOLD}Current IP on $IFACE:${NC}"
ip -4 addr show "$IFACE" | grep -oP '(?<=inet )\S+'
echo ""
echo -e "${GREEN}Done!${NC}"

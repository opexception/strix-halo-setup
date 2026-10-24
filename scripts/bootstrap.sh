#!/usr/bin/env bash
# Ubuntu 24.04 host preparation. Network, kernel, ROCm and TTM changes are opt-in.
set -euo pipefail
usage() {
cat <<'TXT'
Usage: sudo ./scripts/bootstrap.sh [flags]
  --hostname NAME                 Set system hostname
  --docker-user USER              Add login to docker group (root-equivalent privilege)
  --install-oem-kernel            Install Ubuntu 24.04 OEM kernel (reboot before ROCm)
  --install-rocm-721              Install AMD ROCm 7.2.1 via documented inbox-driver recipe;
                                  requires verified compatible 6.14.0-1018+ OEM kernel
  --ttm-gb N                      Install amd-debug-tools and set TTM memory cap (GB)
  --interface IFACE               NIC for generated netplan config
  --static-ip ADDRESS/CIDR        Create static IPv4 config (not applied by default)
  --gateway IPV4                  Default router (required with --static-ip)
  --dns IPV4,IPV4                 Comma-separated resolvers (required with --static-ip)
  --apply-network                 Explicitly apply generated netplan (risky over SSH)
  --allow-remote-network-change   Required to apply network configuration over SSH
  --yes                           Confirm network apply without interactive prompt
  --help

No automatic reboot. Run in two passes when the kernel is changed. Review the
current AMD compatibility matrix before opting into the pinned ROCm recipe.
TXT
}
[[ ${EUID:-$(id -u)} -eq 0 ]] || { echo 'Run with sudo' >&2; exit 1; }
[[ -f /etc/os-release ]] || { echo 'Missing /etc/os-release' >&2; exit 1; }
# shellcheck source=/etc/os-release
. /etc/os-release
[[ "${ID:-}" == ubuntu && "${VERSION_ID:-}" == 24.04 ]] || {
  echo 'Supported OS: Ubuntu 24.04 only' >&2; exit 1;
}
HOSTNAME_NEW=''; DOCKER_USER=''; INSTALL_OEM=0; INSTALL_ROCM=0; TTM_GB=''
NIC=''; STATIC_IP=''; GATEWAY=''; DNS=''; APPLY_NETWORK=0; ALLOW_REMOTE=0; YES=0
fail() { echo "ERROR: $*" >&2; exit 1; }
while (( $# )); do
  case "$1" in
    --hostname) HOSTNAME_NEW="${2:?missing hostname}"; shift 2 ;;
    --docker-user) DOCKER_USER="${2:?missing user}"; shift 2 ;;
    --install-oem-kernel) INSTALL_OEM=1; shift ;;
    --install-rocm-721) INSTALL_ROCM=1; shift ;;
    --ttm-gb) TTM_GB="${2:?missing GB}"; shift 2 ;;
    --interface) NIC="${2:?missing interface}"; shift 2 ;;
    --static-ip) STATIC_IP="${2:?missing address}"; shift 2 ;;
    --gateway) GATEWAY="${2:?missing gateway}"; shift 2 ;;
    --dns) DNS="${2:?missing dns}"; shift 2 ;;
    --apply-network) APPLY_NETWORK=1; shift ;;
    --allow-remote-network-change) ALLOW_REMOTE=1; shift ;;
    --yes) YES=1; shift ;;
    --help) usage; exit 0 ;;
    *) fail "Unknown flag: $1" ;;
  esac
done
if [[ -n "$HOSTNAME_NEW" ]]; then
  [[ "$HOSTNAME_NEW" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]] || fail 'Invalid hostname label'
fi
if [[ -n "$DOCKER_USER" ]]; then id "$DOCKER_USER" >/dev/null 2>&1 || fail "No such user: $DOCKER_USER"; fi
if [[ -n "$TTM_GB" ]]; then
  [[ "$TTM_GB" =~ ^[0-9]+$ ]] && ((TTM_GB >= 16 && TTM_GB <= 112)) || fail 'TTM GB must be 16..112, leaving RAM for OS/CPU'
fi
if [[ -n "$STATIC_IP" ]]; then
  [[ "$NIC" =~ ^[a-zA-Z0-9_.:-]+$ ]] || fail 'Provide valid --interface'
  [[ -n "$GATEWAY" && -n "$DNS" ]] || fail 'Static IP requires --gateway and --dns'
  python3 - "$STATIC_IP" "$GATEWAY" "$DNS" <<'PY'
import ipaddress, sys
interface=ipaddress.ip_interface(sys.argv[1]); assert interface.version == 4
assert ipaddress.ip_address(sys.argv[2]).version == 4
for ip in sys.argv[3].split(','): assert ipaddress.ip_address(ip).version == 4
PY
else
  [[ -z "$NIC$GATEWAY$DNS" && "$APPLY_NETWORK" == 0 ]] || fail 'All network flags require --static-ip'
fi
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl gnupg openssl jq python3 python3-venv pipx pciutils usbutils wget

# Docker upstream signed apt repository (not Ubuntu's old docker.io package).
install -m 0755 -d /etc/apt/keyrings
if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
fi
chmod a+r /etc/apt/keyrings/docker.asc
arch="$(dpkg --print-architecture)"
printf 'Types: deb\nURIs: https://download.docker.com/linux/ubuntu\nSuites: noble\nComponents: stable\nArchitectures: %s\nSigned-By: /etc/apt/keyrings/docker.asc\n' "$arch" >/etc/apt/sources.list.d/docker.sources
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
if [[ -n "$DOCKER_USER" ]]; then
  usermod -aG docker "$DOCKER_USER"
  echo "Added $DOCKER_USER to Docker group (root-equivalent access); re-login required"
fi
if [[ -n "$HOSTNAME_NEW" ]]; then
  hostnamectl set-hostname "$HOSTNAME_NEW"
  echo "Hostname set: $HOSTNAME_NEW (review /etc/hosts if it maps the old hostname)"
fi
if ((INSTALL_OEM)); then
  apt-get install -y linux-oem-24.04
  echo 'Installed OEM kernel. REBOOT and verify uname -r BEFORE --install-rocm-721.'
fi
if ((INSTALL_ROCM)); then
  # This is the AMD 7.2.1 pinned example, not an assertion of support for any future kernel.
  kernel="$(uname -r)"
  if [[ "$kernel" =~ ^6\.14\.0-([0-9]+)-oem$ ]]; then
    (( 10#${BASH_REMATCH[1]} >= 1018 )) || fail "Kernel $kernel too old for this AMD recipe"
  else
    fail "ROCm 7.2.1 recipe requires explicitly validated Ubuntu OEM 6.14.0-1018+ kernel. Found $kernel. Check newer AMD guidance instead of forcing install."
  fi
  deb="$(mktemp --suffix=.deb)"
  trap 'rm -f "$deb"' EXIT
  curl -fsSL --retry 3 'https://repo.radeon.com/amdgpu-install/7.2.1/ubuntu/noble/amdgpu-install_7.2.1.70201-1_all.deb' -o "$deb"
  apt-get install -y "$deb"
  # Ryzen APU requires the inbox kernel driver; intentionally DO NOT install DKMS.
  amdgpu-install -y --usecase=rocm --no-dkms
  rm -f "$deb"
  trap - EXIT
  echo 'ROCm installed (pinned AMD recipe). REBOOT, then verify rocminfo reports gfx1151.'
fi
if getent group render >/dev/null && getent group video >/dev/null && [[ -n "$DOCKER_USER" ]]; then
  usermod -aG render,video "$DOCKER_USER"
  echo "Added $DOCKER_USER to render/video groups; re-login required"
fi
if [[ -n "$TTM_GB" ]]; then
  export PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin
  pipx list | grep -q 'amd-debug-tools' || pipx install amd-debug-tools
  echo "Applying TTM cap of ${TTM_GB} GB (reboot required; no automatic reboot)..."
  printf 'n\n' | amd-ttm --set "$TTM_GB"
fi
if [[ -n "$STATIC_IP" ]]; then
  path='/etc/netplan/99-strix-halo-static.yaml'
  [[ ! -e "$path" ]] || cp -a "$path" "$path.$(date +%Y%m%d%H%M%S).bak"
  install -m 0700 -d /etc/netplan
  # Single interface only; review conflicts with existing netplan/NetworkManager config.
  cat >"$path" <<YAML
network:
  version: 2
  ethernets:
    $NIC:
      dhcp4: false
      addresses: [$STATIC_IP]
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses: [${DNS//,/\, }]
YAML
  chmod 600 "$path"
  netplan generate
  echo "Wrote $path; inspect BEFORE applying. Existing netplan config may conflict."
  if (( APPLY_NETWORK )); then
    (( YES )) || fail 'Provide --yes to apply generated network configuration'
    if [[ -n "${SSH_CONNECTION:-}" ]] && (( ! ALLOW_REMOTE )); then
      fail 'Refusing to apply network changes over SSH without --allow-remote-network-change'
    fi
    echo 'Applying netplan; loss of remote connectivity possible.'
    netplan apply
  fi
fi
echo 'Bootstrap complete. Review reboot notices, then validate: uname -r; rocminfo; docker compose version; ls -l /dev/kfd /dev/dri'

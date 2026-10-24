# Ubuntu 24.04 host bootstrap

```bash
sudo ./scripts/bootstrap.sh --hostname halo-01 --docker-user "$USER"
# Kernel is opt-in; check compatibility and reboot before driver install:
sudo ./scripts/bootstrap.sh --install-oem-kernel
sudo reboot
# ONLY if kernel/build matches AMD 7.2.1 support recipe:
uname -r
sudo ./scripts/bootstrap.sh --install-rocm-721 --ttm-gb 96
sudo reboot
rocminfo | grep -A5 gfx1151
```

**Do not run the pinned ROCm recipe on a different kernel just to make installation succeed.** AMD GPU support is sensitive to **Ubuntu point release, OEM/HWE kernel, and ROCm release**. `--install-rocm-721` is a reproducible *example* for AMD's documented Ubuntu 24.04 OEM 6.14.0-1018+ / ROCm 7.2.1 route; later versions may require different driver choices. `--no-dkms` is intentional for Ryzen inbox GPU drivers. Bootstrap does not run a reboot. For supported systems with a newer kernel, ask the coding agent to implement a new **version-specific** recipe, not bypass the guard. ROCm host tools are primarily diagnostics; the Ollama `:rocm` container carries ROCm userspace.

### Unified memory

AMD recommends minimal dedicated BIOS VRAM (if BIOS offers a 0.5 GB option) and tuning the kernel Translation Table Manager (TTM) cap via `amd-ttm`. `--ttm-gb 96` is only an **example**, not a default or a proven optimum. On a 128 GB system leave significant RAM for the host, Open WebUI, LiteLLM, context cache, and other processes. Validate `free -h`, `amd-ttm`, inference stability and actual GPU use after reboot. `amd-ttm` comes from `amd-debug-tools` via `pipx`; compare with current upstream installation documentation before production rollout.

### Optional static network configuration

```bash
sudo ./scripts/bootstrap.sh --interface enp2s0 --static-ip 192.168.10.21/24 \
  --gateway 192.168.10.1 --dns 192.168.10.1,1.1.1.1
# Review /etc/netplan/99-strix-halo-static.yaml before any apply.
```

The default **writes and validates only**, never applies network settings. Applying requires both `--apply-network --yes`; when executing over SSH it additionally requires `--allow-remote-network-change`. Prefer local console access: duplicate netplan stanzas and renderer conflicts can cause connectivity loss. The script does not manage netplan rollback.

### Checks

`docker compose version`, `ls -l /dev/kfd /dev/dri`, `rocminfo`, `uname -r`, `free -h`, `amd-ttm`. Ollama must identify ROCm/gfx1151 in logs; a successful text reply alone does not prove GPU acceleration.

References: [AMD Ryzen install](https://rocm.docs.amd.com/projects/radeon-ryzen/en/latest/docs/install/installryz/native_linux/install-ryzen.html), [Strix Halo kernel considerations](https://rocm.docs.amd.com/en/docs-7.2.0/how-to/system-optimization/strixhalo.html), [Ollama AMD GPU](https://github.com/ollama/ollama/blob/main/docs/gpu.mdx).

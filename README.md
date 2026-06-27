# Run NixOS on a Libvirt VM

Run **NixOS** guest VMs using **[libvirt](https://libvirt.org/)**. **nixos-libvirt** is a **Nix** flake that generates libvirt-compatible system images and provides a NixOS module for libvirt guest support. The NixOS module configures the machine for optimal libvirt integration with QEMU guest agent, serial console, and virtio drivers.

## Design Goals

The design goals for **nixos-libvirt** are:

1. Nix flake that can build a bootable NixOS libvirt-compatible image
2. Nix modules for libvirt guest configuration
3. User customization of NixOS libvirt instance is separate from initial image creation
4. The base image and Nix services module is generic and as reusable by others as possible

If you have comments or suggestions for the design or implementation, please open an [Issue](https://github.com/fr33m0nk/nixos-libvirt/issues).

## Quickstart

To quickly start a **NixOS** guest using **libvirt**:

### Prerequisites

- Linux host with KVM support
- libvirt installed (`libvirt-daemon-system`, `qemu-kvm`, `virt-manager` recommended)
- Nix with flakes enabled (for building the image)

### Option 1: Download a Pre-built Image

Download the latest release image from [GitHub Releases](https://github.com/fr33m0nk/nixos-libvirt/releases).

```bash
# Download the image for your architecture
curl -LO https://github.com/fr33m0nk/nixos-libvirt/releases/download/v0.0.2/nixos-libvirt-v0.0.2-x86_64.qcow2
# Or for aarch64:
curl -LO https://github.com/fr33m0nk/nixos-libvirt/releases/download/v0.0.2/nixos-libvirt-v0.0.2-aarch64.qcow2
```

Copy the image and start the VM:

```bash
sudo cp nixos-libvirt-v0.0.2-x86_64.qcow2 /var/lib/libvirt/images/nixos.qcow2
sudo qemu-img resize /var/lib/libvirt/images/nixos.qcow2 +10G

# Define and start the VM using the provided domain template
sudo virsh define libvirt-domain.xml
sudo virsh start nixos
```

### Option 2: Build from Source

Clone this repository and build the image:

```bash
# Build the image
nix build .#packages.x86_64-linux.img --out-link result-x86_64
# Or for aarch64:
nix build .#packages.aarch64-linux.img --out-link result-aarch64

# Copy to libvirt image directory
sudo cp result-x86_64/nixos.qcow2 /var/lib/libvirt/images/nixos.qcow2
sudo qemu-img resize /var/lib/libvirt/images/nixos.qcow2 +10G

# Start with the template
sudo virsh define libvirt-domain.xml
sudo virsh start nixos
```

### Access the VM

```bash
# Via serial console
sudo virsh console nixos

# Or via SSH once the VM has an IP
ssh nixos@<vm-ip>
# Default password: nixos
```

## Customizing Your Guest Instance

### Using nixos-rebuild

While the image has a working NixOS installed, you can customize it by running `nixos-rebuild` inside the VM:

```bash
# SSH into the VM
ssh nixos@<vm-ip>

# Checkout your configuration
git clone <your-config-repo>
cd <your-config-repo>

# Rebuild
sudo nixos-rebuild switch --flake .#
```

### Using the nixos-libvirt Module in Your Own Configuration

Add `nixos-libvirt` as a flake input and import the module in your NixOS system
configuration. The module exposes `services.libvirt-guest` with a single
`enable` toggle that sets up the QEMU guest agent, cloud-init, and a serial
console — everything the libvirt domain template expects.

```nix
# flake.nix
{
  inputs = {
    nixos-libvirt.url = "github:fr33m0nk/nixos-libvirt";
  };
  outputs = { nixos-libvirt, nixpkgs, ... }: {
    nixosConfigurations.myvm = nixpkgs.lib.nixosSystem {
      modules = [
        nixos-libvirt.nixosModules.libvirt
        {
          services.libvirt-guest.enable = true;
          # Optional: host↔guest filesystem sharing via virtiofs
          services.libvirt-guest.virtiofs.enable = true;
          services.libvirt-guest.virtiofs.mounts."nixos-config" = {
            mountPoint = "/mnt/nixos-config";
          };
        }
      ];
    };
  };
}
```

The `virtiofs` mounts are keyed by the `<target dir>` tag in your domain XML's
`<filesystem type="mount">` element, so they stay in sync with the host side.

## Libvirt Domain Configuration

The included `libvirt-domain.xml` provides a sensible default configuration:

- 8 GiB RAM, 4 vCPUs
- UEFI boot (OVMF)
- VirtIO disk and network
- SPICE graphics
- QEMU guest agent channel
- Serial console

Customize the domain XML to suit your needs (memory, CPU, networking, etc.).

## Using Cloud-Init

You can use cloud-init to bootstrap the VM with your SSH keys and custom configuration:

```bash
# Create cloud-init config
mkdir cloud-init
cat > cloud-init/user-data << 'EOF'
#cloud-config
users:
  - name: nixos
    ssh_authorized_keys:
      - ssh-ed25519 AAAA...
EOF
echo "instance-id: $(uuidgen)" > cloud-init/meta-data

# Generate ISO
genisoimage -output cloud-init.iso -volid cidata -joliet -rock cloud-init/user-data cloud-init/meta-data
sudo cp cloud-init.iso /var/lib/libvirt/images/

# Add a cdrom disk to the domain XML pointing to cloud-init.iso
```

## Building and Testing the System Image

### Prerequisites

A working Nix installation capable of building Linux systems. This includes:

* Linux system with Nix installed
* Linux VM with Nix installed (e.g. under macOS)
* macOS system with [linux-builder](https://nixos.org/manual/nixpkgs/unstable/#sec-darwin-builder) installed via [Nix Darwin](https://github.com/LnL7/nix-darwin)
* macOS system with [nix-rosetta-builder](https://github.com/cpick/nix-rosetta-builder)

Flakes must be enabled.

### Generating the image

```bash
nix build .#packages.x86_64-linux.img --out-link result-x86_64
# Or for aarch64:
nix build .#packages.aarch64-linux.img --out-link result-aarch64
```

### Testing Locally

```bash
# Copy the image
sudo cp result-x86_64/nixos.qcow2 /var/lib/libvirt/images/nixos.qcow2

# Define and start
sudo virsh define libvirt-domain.xml
sudo virsh start nixos

# Watch the console
sudo virsh console nixos
```

## Differences from the Lima Version

This is a port of [nixos-lima](https://github.com/nixos-lima/nixos-lima) for libvirt. Key differences:

- **No Lima guest agent**: Uses QEMU guest agent instead for host-guest communication
- **Cloud-init via NoCloud ISO**: Cloud-init is supported through a standard cidata ISO (see "Using Cloud-Init" above). What's dropped is Lima's bespoke guest-agent and cidata-mount mechanism (`lima-init.nix`)
- **Serial console**: Configured for `virsh console` access
- **KVM-native**: Designed to run directly on KVM with virtio drivers
- **Static user**: Pre-configured `nixos` user instead of Lima's dynamic user creation

## History

This is based on [nixos-lima](https://github.com/nixos-lima/nixos-lima), which was forked from [kasuboski/nixos-lima](https://github.com/kasuboski/nixos-lima).

## Credits

* Based on: [nixos-lima](https://github.com/nixos-lima/nixos-lima)
* Originally forked from: [kasuboski/nixos-lima](https://github.com/kasuboski/nixos-lima)
* Heavily inspired by: [patryk4815/ctftools](https://github.com/patryk4815/ctftools/tree/master/lima-vm)

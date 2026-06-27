{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./libvirt-guest.nix
  ];

  # Enable all libvirt guest integration (qemu-guest-agent, cloud-init, serial console)
  services.libvirt-guest.enable = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Give users in the `wheel` group additional rights when connecting to the Nix daemon
  nix.settings.trusted-users = [ "@wheel" ];

  # Default user for libvirt VM access (override with cloud-init user-data)
  users.users.nixos = {
    isNormalUser = true;
    initialPassword = "nixos";
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ ];
  };

  users.mutableUsers = true;

  security = {
    sudo.wheelNeedsPassword = false;
  };

  services.openssh.enable = true;

  # Keep tty0 video console in addition to the ttyS0 serial console
  # (ttyS0 is added by libvirt-guest.nix; tty0 gives a display via SPICE/VNC)
  boot.kernelParams = [ "console=tty0" ];

  boot.loader.grub = {
    device = "nodev";
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  fileSystems."/boot" = {
    device = lib.mkForce "/dev/vda1";
    fsType = "vfat";
  };

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    autoResize = true;
    fsType = "ext4";
    options = [
      "noatime"
      "nodiratime"
      "discard"
    ];
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;

  environment.systemPackages = with pkgs; [
    nextvi
    gitMinimal
  ];

  system.stateVersion = "26.05";
}

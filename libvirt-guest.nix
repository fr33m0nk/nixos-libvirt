{
  config,
  lib,
  modulesPath,
  ...
}:
let
  cfg = config.services.libvirt-guest;
in
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  options.services.libvirt-guest = {
    enable = lib.mkEnableOption ''
      libvirt guest integration.
      Enables the QEMU guest agent, cloud-init, and a serial console
      so the guest cooperates correctly with a libvirt host.
    '';

    virtiofs = {
      enable = lib.mkEnableOption ''
        virtiofs kernel support for host↔guest filesystem sharing.
        Enables the virtiofs kernel module. Use mounts.<tag> to
        declare individual shared directories (the <tag> must match
        the <target dir="..."/> in the domain XML <filesystem> element).
      '';

      mounts = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              mountPoint = lib.mkOption {
                type = lib.types.str;
                description = "Guest mount point for the virtiofs share.";
                example = "/mnt/nixos-config";
              };
              options = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ "defaults" ];
                description = "Mount options passed to mount(8).";
              };
            };
          }
        );
        default = { };
        description = ''
          virtiofs mounts keyed by the libvirt <target dir> tag.
          Each tag must match the corresponding <target dir="..."/>
          in the domain XML <filesystem type="mount"> element.

          Example:
            services.libvirt-guest.virtiofs.mounts."nixos-config" = {
              mountPoint = "/mnt/nixos-config";
            };
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # ---- guest agent: virsh domifaddr, virsh shutdown, etc. ----
    services.qemuGuest.enable = true;

    # ---- cloud-init: SSH keys and user-data from cidata ISO ----
    services.cloud-init.enable = true;
    services.cloud-init.settings = {
      datasource_list = [ "NoCloud" ];
    };

    # ---- serial console: virsh console ----
    boot.kernelParams = [ "console=ttyS0,115200" ];

    # ---- virtiofs ----
    boot.kernelModules = lib.mkIf cfg.virtiofs.enable [ "virtiofs" ];

    fileSystems = lib.mkIf cfg.virtiofs.enable (
      lib.mapAttrs' (
        tag: mount:
        lib.nameValuePair mount.mountPoint {
          device = tag;
          fsType = "virtiofs";
          options = mount.options;
        }
      ) cfg.virtiofs.mounts
    );
  };
}

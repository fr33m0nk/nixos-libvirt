{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-26.05";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      nixos-generators,
      ...
    }@attrs:
    let
      forEachSystem = nixpkgs.lib.genAttrs;
    in
    {
      packages = forEachSystem [ "x86_64-linux" "aarch64-linux" ] (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          img = nixos-generators.nixosGenerate {
            inherit pkgs;
            modules = [
              ./libvirt.nix
            ];
            format = "qcow-efi";
          };
        }
      );
      devShells = forEachSystem [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ] (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.qemu
              pkgs.libvirt
              pkgs.virt-manager
            ];
          };
        }
      );
      formatter = forEachSystem [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ] (
        system: nixpkgs.legacyPackages.${system}.nixfmt-tree
      );
      nixosConfigurations.nixos-aarch64 = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = attrs;
        modules = [
          ./libvirt.nix
        ];
      };
      nixosConfigurations.nixos-x86_64 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = attrs;
        modules = [
          ./libvirt.nix
        ];
      };

      nixosModules.libvirt = import ./libvirt-guest.nix;
    };
}

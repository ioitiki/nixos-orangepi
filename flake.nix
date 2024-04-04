{
  description = "My custom NixOS configuration for Orange Pi 5";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    home-manager.url = "github:nix-community/home-manager/release-23.11";
    orangepi-5x.url = "github:fb87/nixos-orangepi-5x";
    # Add other inputs as required
  };

  outputs = { self, nixpkgs, orangepi-5x, home-manager, ... }@inputs: {
    nixosConfigurations.orangepi = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        # Assuming buildConfig is a function within orangepi-5x that requires pkgs and lib
        orangepi-5x.nixosModules.buildConfig
        ({ pkgs, lib, ... }: {
          # User and Home Manager customization module
          users.users.andy = {
            isNormalUser = true;
            initialPassword = "andy";
            extraGroups = [ "wheel" "networkmanager" "tty" "video" ];
            packages = with pkgs; [
              home-manager
              neofetch
              pavucontrol
              direnv
              dunst
              firefox
              chromium
              qemu
            ];
          };

          # Direct Home Manager configuration
          home-manager.users.andy = { pkgs, lib, ... }: {
            programs.bash.enable = true;
            # Add more Home Manager configurations as needed
          };
        })
      ];
    };
  };
}

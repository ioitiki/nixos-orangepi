{
  description = "My custom NixOS configuration for Orange Pi 5";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    orangepi-5x.url = "path:./fb87";
  };

  outputs = { self, nixpkgs, orangepi-5x, test }: {
    nixosConfigurations.orangepi = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        (buildConfig { inherit pkgs; lib = nixpkgs.lib; user = "andy"; })
          ({ pkgs, lib, user, ... }: {

              boot = {
                loader = { grub.enable = false; generic-extlinux-compatible.enable = true; };
                initrd.luks.devices."Encrypted".device = "/dev/disk/by-partlabel/Encrypted";
                initrd.availableKernelModules = lib.mkForce [ "dm_mod" "dm_crypt" "encrypted_keys" ];
              };

              fileSystems."/" =   { device = "none"; fsType = "tmpfs"; options = [ "mode=0755,size=8G" ]; };
              fileSystems."/boot" =   { device = "/dev/disk/by-partlabel/Firmwares"; fsType = "vfat"; };
              fileSystems."/nix" =  { device = "/dev/mapper/Encrypted"; fsType = "btrfs"; options = [ "subvol=nix,compress=zstd,noatime" ]; };
              fileSystems."/home/${user}" = { device = "/dev/mapper/Encrypted"; fsType = "btrfs"; options = [ "subvol=usr,compress=zstd,noatime" ]; };

              fileSystems."/tmp" = { device = "none"; fsType = "tmpfs"; options = [ "mode=0755,size=6G" ]; };

              networking = {
                hostName = "nixos";
                networkmanager.enable = true;
              };

              time.timeZone = "America/Los_Angeles";
              i18n.defaultLocale = "en_US.UTF-8";

              users.users.${user} = {
                isNormalUser = true;
                initialPassword = "${user}";
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

              services.getty.autologinUser = "${user}";
              services.sshd.enable = true;

              nix = {
                settings = {
                  auto-optimise-store = true;
                  experimental-features = [ "nix-command" "flakes" ];
                };

                gc = {
                  automatic = true;
                  dates = "weekly";
                  options = "--delete-older-than 30d";
                };

                # Free up to 1GiB whenever there is less than 100MiB left.
                extraOptions = ''
                  min-free = ${toString ( 100 * 1024 * 1024)}
                  max-free = ${toString (1024 * 1024 * 1024)}
                '';
              };
            })

            home-manager.nixosModules.home-manager {
              home-manager.users.${user} = { pkgs, ... }: {
                home.packages = with pkgs; [ 
                  ftop
                ];
                programs.bash.enable = true;
                home.stateVersion = "23.11";
             };
           }
      ];
    };
  };
}

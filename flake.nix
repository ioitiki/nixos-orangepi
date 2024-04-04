{
  description = "My custom NixOS configuration for Orange Pi 5";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    orangepi-5x.url = "path:./fb87";
  };

  outputs = { self, nixpkgs, orangepi-5x, home-manager, ... }@inputs: {
    let
      pkgs = import nixpkgs {
        system = "aarch64-linux";
      };
      user = "andy";
    in
    nixosConfigurations.orangepi = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ({pkgs, lib, ... }: {
          boot.kernelPackages = pkgs-fixed.linuxPackagesFor (pkgs-fixed.callPackage ./board/kernel {
            src = inputs.linux-rockchip;
          });

          # most of required modules had been builtin
          boot.supportedFilesystems = lib.mkForce [ "vfat" "ext4" "btrfs" ];

          boot.kernelParams = [
            "console=ttyS2,1500000" # serial port for debugging
            "console=tty1" # should be HDMI
            "loglevel=4" # more verbose might help
          ];
          boot.initrd.includeDefaultModules = false; # no thanks, builtin modules should be enough

          hardware = {
            deviceTree = { name = "rockchip/rk3588s-orangepi-5b.dtb"; };

            opengl = {
              enable = true;
              package = lib.mkForce (
                (pkgs-fixed.mesa.override {
                  galliumDrivers = [ "panfrost" "swrast" ];
                  vulkanDrivers = [ "swrast" ];
                }).overrideAttrs (_: {
                  pname = "mesa-panfork";
                  version = "23.0.0-panfork";
                  src = inputs.mesa-panfork;
                })
              ).drivers;
             # extraPackages = [ rk-valhal ];
            };

            firmware = [ (pkgs.callPackage ./board/firmware { }) ];

            pulseaudio.enable = true;
          };

          networking = {
            networkmanager.enable = true;
            wireless.enable = false;
          };

          environment.systemPackages = with pkgs; [
            git
            htop
            neofetch

            # only wayland can utily GPU as of now
            wayland
            waybar
            swaylock
            swayidle
            swayfx
            foot
            wdisplays
            wofi
            gnome.adwaita-icon-theme
            xst

            taskwarrior
          ];

          environment.loginShellInit = ''
            # https://wiki.archlinux.org/title/Sway
            export GDK_BACKEND=wayland
            export MOZ_ENABLE_WAYLAND=1
            export QT_QPA_PLATFORM=wayland
            export XDG_SESSION_TYPE=wayland

            if [ -z "$WAYLAND_DISPLAY" ] && [ "_$XDG_VTNR" == "_1" ] && [ "_$(tty)" == "_/dev/tty1" ]; then
              dunst&
              exec ${pkgs.swayfx}/bin/sway
            fi

           alias e=nvim
           alias rebuild='sudo nixos-rebuild switch --flake .'
          '';

          programs = {
           sway.enable = true;
           sway.package = null;

           hyprland.enable = true;

           # starship.enable = true;
           neovim.enable = true;
           neovim.defaultEditor = true;
         };

          system.stateVersion = "23.11";
        })
        ({ pkgs, lib, ... }: {

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

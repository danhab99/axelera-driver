{
  description = "Axelera AI Linux PCIe Driver - Kernel module for Axelera AI devices";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = self.packages.${system}.metis-driver;

          metis-driver = pkgs.stdenv.mkDerivation rec {
            pname = "metis-driver";
            version = "1.5.3";

            src = ./.;

            nativeBuildInputs = with pkgs; [
              kmod
              gnumake
            ];

            hardeningDisable = [ "pic" "format" ];

            makeFlags = [
              "KDIR=${pkgs.linuxPackages.kernel.dev}/lib/modules/${pkgs.linuxPackages.kernel.modDirVersion}/build"
            ];

            buildPhase = ''
              runHook preBuild
              make $makeFlags
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              mkdir -p $out/lib/modules/${pkgs.linuxPackages.kernel.modDirVersion}/extra
              cp metis.ko $out/lib/modules/${pkgs.linuxPackages.kernel.modDirVersion}/extra/
              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "Linux kernel module for Axelera AI PCIe devices";
              homepage = "https://github.com/danhab99/axelera-driver";
              license = licenses.gpl2Plus;
              platforms = platforms.linux;
              maintainers = [ ];
            };
          };
        });

      # NixOS module for easy integration
      nixosModules.default = { config, lib, pkgs, ... }:
        with lib;
        let
          cfg = config.hardware.axelera;
        in
        {
          options.hardware.axelera = {
            enable = mkEnableOption "Axelera AI PCIe driver";
          };

          config = mkIf cfg.enable {
            boot.extraModulePackages = [
              (self.packages.${pkgs.system}.metis-driver.overrideAttrs (old: {
                kernel = config.boot.kernelPackages.kernel;
                makeFlags = [
                  "KDIR=${config.boot.kernelPackages.kernel.dev}/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/build"
                ];
                installPhase = ''
                  runHook preInstall
                  mkdir -p $out/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/extra
                  cp metis.ko $out/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/extra/
                  runHook postInstall
                '';
              }))
            ];

            boot.kernelModules = [ "metis" ];
          };
        };
    };
}

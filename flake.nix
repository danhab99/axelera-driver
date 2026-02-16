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
          
          # Build the kernel module for a specific kernel
          makeMetisDriver = kernel: pkgs.stdenv.mkDerivation rec {
            pname = "metis-driver";
            version = "1.5.3";

            src = ./.;

            nativeBuildInputs = with pkgs; [
              kmod
              gnumake
            ] ++ kernel.moduleBuildDependencies;

            hardeningDisable = [ "pic" "format" ];

            makeFlags = kernel.makeFlags ++ [
              "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
            ];

            buildPhase = ''
              runHook preBuild
              make $makeFlags
              runHook postBuild
            '';

            installPhase = ''
              runHook preInstall
              mkdir -p $out/lib/modules/${kernel.modDirVersion}/extra
              cp metis.ko $out/lib/modules/${kernel.modDirVersion}/extra/
              runHook postInstall
            '';

            enableParallelBuilding = true;

            meta = with pkgs.lib; {
              description = "Linux kernel module for Axelera AI PCIe devices";
              homepage = "https://github.com/danhab99/axelera-driver";
              license = licenses.gpl2Plus;
              platforms = platforms.linux;
              maintainers = [ ];
            };
          };
        in
        {
          default = self.packages.${system}.metis-driver;

          # Build against the default kernel
          metis-driver = makeMetisDriver pkgs.linuxPackages.kernel;

          # Output just the kernel module binary
          metis-ko = pkgs.runCommand "metis-ko" {} ''
            mkdir -p $out
            cp ${self.packages.${system}.metis-driver}/lib/modules/*/extra/metis.ko $out/
          '';
        });

      # NixOS module for easy integration
      nixosModules.default = { config, lib, pkgs, ... }:
        with lib;
        let
          cfg = config.hardware.axelera;
          # Build the driver for the system's kernel
          metisDriver = pkgs.callPackage ({ stdenv, kmod, gnumake }:
            stdenv.mkDerivation rec {
              pname = "metis-driver";
              version = "1.5.3";

              src = self;

              nativeBuildInputs = [ kmod gnumake ] ++ config.boot.kernelPackages.kernel.moduleBuildDependencies;

              hardeningDisable = [ "pic" "format" ];

              makeFlags = config.boot.kernelPackages.kernel.makeFlags ++ [
                "KDIR=${config.boot.kernelPackages.kernel.dev}/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/build"
              ];

              buildPhase = ''
                runHook preBuild
                make $makeFlags
                runHook postBuild
              '';

              installPhase = ''
                runHook preInstall
                mkdir -p $out/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/extra
                cp metis.ko $out/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/extra/
                runHook postInstall
              '';

              enableParallelBuilding = true;
            }
          ) {};
        in
        {
          options.hardware.axelera = {
            enable = mkEnableOption "Axelera AI PCIe driver";
          };

          config = mkIf cfg.enable {
            boot.extraModulePackages = [ metisDriver ];
            boot.kernelModules = [ "metis" ];
          };
        };
    };
}

# NixOS Installation Guide

This repository includes a Nix flake that provides a package for the Axelera AI PCIe driver kernel module and a NixOS module for easy system integration.

## Prerequisites

- NixOS or a system with Nix flakes enabled
- Nix version 2.4 or later with flakes support

To enable flakes on your system, add the following to your Nix configuration:

```nix
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
```

## Quick Start

### Testing the Build

To build the driver without installing it:

```bash
nix build github:danhab99/axelera-driver
```

The built kernel module will be available in `./result/lib/modules/<kernel-version>/extra/metis.ko`.

To build just the kernel module binary:

```bash
nix build github:danhab99/axelera-driver#metis-ko
```

This will produce `./result/metis.ko` which can be loaded directly with `insmod` (though using the NixOS module is recommended).

### Building for Your Local Kernel

If you're developing locally:

```bash
# Clone the repository
git clone https://github.com/danhab99/axelera-driver
cd axelera-driver

# Build the driver
nix build
```

## Installation Methods

### Method 1: NixOS Module (Recommended)

The easiest way to use this driver on NixOS is through the provided NixOS module. Add the following to your NixOS configuration:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    axelera-driver.url = "github:danhab99/axelera-driver";
  };

  outputs = { self, nixpkgs, axelera-driver }: {
    nixosConfigurations.yourHostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        axelera-driver.nixosModules.default
        {
          # Enable the Axelera driver
          hardware.axelera.enable = true;
        }
      ];
    };
  };
}
```

This will:
- Build the driver against your system's kernel
- Install it to the correct location
- Load the `metis` module at boot time

### Method 2: Manual Installation

If you prefer to install the driver manually:

1. Build the driver:
   ```bash
   nix build github:danhab99/axelera-driver
   ```

2. Copy the module to your system:
   ```bash
   sudo cp result/lib/modules/$(uname -r)/extra/metis.ko /lib/modules/$(uname -r)/extra/
   sudo depmod -a
   ```

3. Load the module:
   ```bash
   sudo modprobe metis
   ```

4. To load the module automatically at boot, add it to your NixOS configuration:
   ```nix
   {
     boot.kernelModules = [ "metis" ];
   }
   ```

### Method 3: Overlay in NixOS Configuration

You can also add the driver as an overlay in your flake-based configuration:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    axelera-driver.url = "github:danhab99/axelera-driver";
  };

  outputs = { self, nixpkgs, axelera-driver }: {
    nixosConfigurations.yourHost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [{
        nixpkgs.overlays = [
          (final: prev: {
            axelera-driver = axelera-driver.packages.${prev.system}.metis-driver;
          })
        ];

        boot.extraModulePackages = [ pkgs.axelera-driver ];
        boot.kernelModules = [ "metis" ];
      }];
    };
  };
}
```

## Development

### Local Development Build

For development and testing:

```bash
# Enter a development shell with all build dependencies
nix develop

# Build manually using make
make

# Clean build artifacts
make clean
```

### Building for a Specific Kernel

The flake builds against the default kernel in nixpkgs. To build for a specific kernel version, you can override it in your NixOS configuration:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    axelera-driver.url = "github:danhab99/axelera-driver";
  };

  outputs = { self, nixpkgs, axelera-driver }: {
    nixosConfigurations.yourHost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        axelera-driver.nixosModules.default
        {
          # Use a specific kernel version
          boot.kernelPackages = pkgs.linuxPackages_6_6;
          hardware.axelera.enable = true;
        }
      ];
    };
  };
}
```

The NixOS module will automatically build the driver against the configured kernel.

## Troubleshooting

### Module fails to load

Check kernel logs for errors:
```bash
dmesg | tail -n 50
```

### Build fails with kernel header errors

Ensure your NixOS system has the kernel development headers available. This is typically automatic in NixOS when building kernel modules.

### Version mismatch

The kernel module must be built against the exact kernel version you're running. The NixOS module handles this automatically, but manual installations require careful version matching:

```bash
# Check your running kernel version
uname -r

# Ensure the module is built for this version
ls /lib/modules/$(uname -r)/extra/metis.ko
```

### Flakes not enabled

If you get an error about flakes not being recognized, enable them:

```bash
# Temporary (current session)
export NIX_CONFIG="experimental-features = nix-command flakes"

# Permanent (NixOS configuration)
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

## Package Details

The flake provides:

- **packages.default** / **packages.metis-driver**: The compiled kernel module package
- **packages.metis-ko**: Just the kernel module binary file (metis.ko)
- **nixosModules.default**: A NixOS module for system integration

### Package Metadata

- **Name**: metis-driver
- **Version**: 1.5.3
- **License**: GPL-2.0-or-later
- **Supported Systems**: x86_64-linux, aarch64-linux

## Advanced Usage

### Using in a flake-based project

```nix
{
  inputs.axelera-driver.url = "github:danhab99/axelera-driver";

  outputs = { self, axelera-driver, ... }: {
    # Use the driver in your own packages
    packages.x86_64-linux.myPackage = ...;
  };
}
```

### Pinning to a Specific Version

To pin to a specific commit or tag:

```nix
{
  inputs.axelera-driver.url = "github:danhab99/axelera-driver?ref=v1.5.3";
}
```

Or to a specific commit:

```nix
{
  inputs.axelera-driver.url = "github:danhab99/axelera-driver?rev=<commit-sha>";
}
```

## License

This driver is licensed under GPL-2.0-or-later. See the LICENSE file for details.

## Support

For issues related to:
- The driver itself: See the main [README.md](README.md)
- NixOS/Nix flake: Open an issue on the GitHub repository

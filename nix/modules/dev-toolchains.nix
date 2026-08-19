{ pkgs, ... }:
{
  home.packages = with pkgs; [
    nodejs_26
    python3
    jdk
    maven
    cmake
    rust-analyzer
    luarocks
    awscli
    influxdb2-cli
    neovim
  ];
}

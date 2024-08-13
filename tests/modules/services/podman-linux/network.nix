{ ... }:

{
  config = {
    services.podman.networks."mynet" = {
      Subnet = "192.168.1.0/24";
      Gateway = "192.168.1.1";
    };

    nmt.script = ''
      configPath=home-files/.config/systemd/user
      networkFile=$configPath/podman-mynet-network.service
      assertFileExists $networkFile

      assertFileContains $networkFile \
        "mynet.network"
      assertFileContains $networkFile \
        "Subnet=192.168.1.0/24"
      assertFileContains $networkFile \
        "Gateway=192.168.1.1"
      assertFileContains $networkFile \
        "NetworkName=mynet"
      assertFileContains $networkFile \
        "WantedBy=multi-user.target default.target"
      assertFileContains $networkFile \
        "RemainAfterExit=yes"
      assertFileContains $networkFile \
        "Label=nix.home-manager.managed=true"
    '';
  };
}

{ ... }:

{
  config = {
    services.podman.containers."my-container" = {
      serviceName = "a-test-container";
      description = "home-manager test";
      autoupdate = "registry";
      autostart = true;
      image = "docker.io/alpine:latest";
      entrypoint = "sleep 1000";
      environment = {
        "VAL_A" = "A";
        "VAL_B" = 2;
        "VAL_C" = false;
      };
      ports = [ "8080:80" ];
      volumes = [ "/tmp:/tmp" ];
      devices = [ "/dev/null:/dev/null" ];

      networks = [ "mynet" ];
      networkAlias = "test-alias";

      extraOptions = [ "--security-opt=no-new-privileges" ];
      extraContainerConfig = { ReadOnlyTmpfs = true; };
      serviceConfig = { Restart = "on-failure"; };
      unitConfig = { Before = [ "fake.target" ]; };
    };

    nmt.script = ''
      configPath=home-files/.config/systemd/user
      assertFileExists $configPath/a-test-container.service

      assertFileContains $configPath/a-test-container.service \
        "a-test-container.container"
      assertFileContains $configPath/a-test-container.service \
        "Description=home-manager test"
      assertFileContains $configPath/a-test-container.service \
        "AutoUpdate=registry"
      assertFileContains $configPath/a-test-container.service \
        "Image=docker.io/alpine:latest"
      assertFileContains $configPath/a-test-container.service \
        "PodmanArgs=--network-alias test-alias --entrypoint sleep 1000 --security-opt=no-new-privileges"
      assertFileContains $configPath/a-test-container.service \
        "Environment=VAL_A=A VAL_B=2 VAL_C=false"
      assertFileContains $configPath/a-test-container.service \
        "PublishPort=8080:80"
      assertFileContains $configPath/a-test-container.service \
        "Volume=/tmp:/tmp"
      assertFileContains $configPath/a-test-container.service \
        "AddDevice=/dev/null:/dev/null"
      assertFileContains $configPath/a-test-container.service \
        "Network=mynet"
      assertFileContains $configPath/a-test-container.service \
        "Requires=podman-mynet-network.service"
      assertFileContains $configPath/a-test-container.service \
        "After=network.target podman-mynet-network.service"
      assertFileContains $configPath/a-test-container.service \
        "ReadOnlyTmpfs=true"
      assertFileContains $configPath/a-test-container.service \
        "Restart=on-failure"
      assertFileContains $configPath/a-test-container.service \
        "Before=fake.target"
      assertFileContains $configPath/a-test-container.service \
        "WantedBy=multi-user.target default.target"
      assertFileContains $configPath/a-test-container.service \
        "Label=nix.home-manager.managed=true"
    '';
  };
}

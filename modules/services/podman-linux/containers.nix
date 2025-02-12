{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.podman;

  podman-lib = import ./podman-lib.nix { inherit pkgs lib config; };

  createQuadletSource = name: containerDef:
    let
      formatServiceNameForType = type: name:
        {
          image = "podman-${name}-image.service";
          build = "podman-${name}-build.service";
          network = "podman-${name}-network.service";
          volume = "podman-${name}-volume.service";
        }."${type}";

      dependencyByHomeManagerQuadlet = type: name:
        let
          definitionsOfType =
            filter (q: q.resourceType == type) cfg.internal.quadletDefinitions;
          matchingName =
            filter (q: q.serviceName == "podman-${name}") definitionsOfType;
        in if ((length matchingName) == 1) then
          [ (formatServiceNameForType type name) ]
        else
          [ ];

      forEachValue = type: value:
        let resolve = v: dependencyByHomeManagerQuadlet type v;
        in if isList value then
          concatLists (map resolve value)
        else
          resolve value;

      withResolverFor = type: value:
        {
          "image" = forEachValue "image" value;
          "build" = forEachValue "build" value;
          "network" = forEachValue "network" value;
          "volume" = let
            a = if isList value then value else [ value ];
            volumes = map (v: elemAt (splitString ":" v) 0) a;
          in forEachValue "volume" volumes;
        }.${type};

      dependencyServices = (withResolverFor "image" containerDef.image)
        ++ (withResolverFor "build" containerDef.image)
        ++ (withResolverFor "network" containerDef.network)
        ++ (withResolverFor "volume" containerDef.volumes);

      resolvedImage = if (builtins.hasAttr containerDef.image cfg.images) then
        cfg.images."${containerDef.image}".image
      else if (builtins.hasAttr containerDef.image cfg.builds) then
        "localhost/homemanager/${containerDef.image}"
      else
        containerDef.image;

      quadlet = (podman-lib.deepMerge {
        Container = {
          AddCapability = containerDef.addCapabilities;
          AddDevice = containerDef.devices;
          AutoUpdate = containerDef.autoUpdate;
          ContainerName = name;
          DropCapability = containerDef.dropCapabilities;
          Entrypoint = containerDef.entrypoint;
          Environment = containerDef.environment;
          EnvironmentFile = containerDef.environmentFile;
          Exec = containerDef.exec;
          Group = containerDef.group;
          Image = resolvedImage;
          IP = containerDef.ip4;
          IP6 = containerDef.ip6;
          Label =
            (containerDef.labels // { "nix.home-manager.managed" = true; });
          Network = containerDef.network;
          NetworkAlias = containerDef.networkAlias;
          PodmanArgs = containerDef.extraPodmanArgs;
          PublishPort = containerDef.ports;
          UserNS = containerDef.userNS;
          User = containerDef.user;
          Volume = containerDef.volumes;
        };
        Install = {
          WantedBy = optionals containerDef.autoStart [
            "default.target"
            "multi-user.target"
          ];
        };
        Service = {
          Environment = {
            PATH = (builtins.concatStringsSep ":" [
              "/run/wrappers/bin"
              "/run/current-system/sw/bin"
              "${config.home.homeDirectory}/.nix-profile/bin"
            ]);
          };
          Restart = "always";
          TimeoutStopSec = 30;
        };
        Unit = {
          After = [ "network.target" ] ++ dependencyServices;
          Requires = dependencyServices;
          Description = (if (builtins.isString containerDef.description) then
            containerDef.description
          else
            "Service for container ${name}");
        };
      } containerDef.extraConfig);
    in ''
      # Automatically generated by home-manager podman container configuration
      # DO NOT EDIT THIS FILE DIRECTLY
      #
      # ${name}.container
      ${podman-lib.toQuadletIni quadlet}
    '';

  toQuadletInternal = name: containerDef: {
    assertions = podman-lib.buildConfigAsserts name containerDef.extraConfig;
    resourceType = "container";
    serviceName =
      "podman-${name}"; # quadlet service name: 'podman-<name>.service'
    source =
      podman-lib.removeBlankLines (createQuadletSource name containerDef);
  };

  # Define the container user type as the user interface
  containerDefinitionType = types.submodule {
    options = {

      addCapabilities = mkOption {
        type = with types; listOf str;
        default = [ ];
        example = [ "CAP_DAC_OVERRIDE" "CAP_IPC_OWNER" ];
        description = "The capabilities to add to the container.";
      };

      autoStart = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether to start the container on boot (requires user lingering).
        '';
      };

      autoUpdate = mkOption {
        type = types.enum [ null "registry" "local" ];
        default = null;
        example = "registry";
        description = "The autoupdate policy for the container.";
      };

      description = mkOption {
        type = with types; nullOr str;
        default = null;
        example = "My Container";
        description = "The description of the container.";
      };

      devices = mkOption {
        type = with types; listOf str;
        default = [ ];
        example = [ "/dev/<host>:/dev/<container>" ];
        description = "The devices to mount into the container";
      };

      dropCapabilities = mkOption {
        type = with types; listOf str;
        default = [ ];
        example = [ "CAP_DAC_OVERRIDE" "CAP_IPC_OWNER" ];
        description = "The capabilities to drop from the container.";
      };

      entrypoint = mkOption {
        type = with types; nullOr str;
        default = null;
        example = "/foo.sh";
        description = "The container entrypoint.";
      };

      environment = mkOption {
        type = podman-lib.primitiveAttrs;
        default = { };
        example = literalExpression ''
          {
            VAR1 = "0:100";
            VAR2 = true;
            VAR3 = 5;
          }
        '';
        description = "Environment variables to set in the container.";
      };

      environmentFile = mkOption {
        type = with types; listOf str;
        default = [ ];
        example = [ "/etc/environment" "/etc/other-env" ];
        description = ''
          Paths to files containing container environment variables.
        '';
      };

      exec = mkOption {
        type = with types; nullOr str;
        default = null;
        example = "sleep inf";
        description = "The command to run after the container start.";
      };

      extraPodmanArgs = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [
          "--security-opt=no-new-privileges"
          "--security-opt=seccomp=unconfined"
        ];
        description = "Extra arguments to pass to the podman run command.";
      };

      extraConfig = mkOption {
        type = podman-lib.extraConfigType;
        default = { };
        example = literalExpression ''
          {
            Container = {
              User = 1000;
            };
            Service = {
              TimeoutStartSec = 15;
            };
          }
        '';
        description = ''
          INI sections and values to populate the Container Quadlet.
        '';
      };

      group = mkOption {
        type = with types; nullOr (either int str);
        default = null;
        description = "The group ID inside the container.";
      };

      image = mkOption {
        type = types.str;
        example = "registry.access.redhat.com/ubi9-minimal:latest";
        description = "The container image.";
      };

      ip4 = mkOption {
        type = with types; nullOr str;
        default = null;
        description = "Set an IPv4 address for the container.";
      };

      ip6 = mkOption {
        type = with types; nullOr str;
        default = null;
        description = "Set an IPv6 address for the container.";
      };

      labels = mkOption {
        type = with types; attrsOf str;
        default = { };
        example = {
          app = "myapp";
          some-label = "somelabel";
        };
        description = "The labels to apply to the container.";
      };

      network = mkOption {
        type = with types; either str (listOf str);
        default = [ ];
        apply = value: if isString value then [ value ] else value;
        example = literalMD ''
          `"host"`
          or
          `"bridge_network_1"`
          or
          `[ "bridge_network_1" "bridge_network_2" ]`
        '';
        description = ''
          The network mode or network/s to connect the container to. Equivalent
          to `podman run --network=<option>`.
        '';
      };

      networkAlias = mkOption {
        type = with types; listOf str;
        default = [ ];
        example = [ "mycontainer" "web" ];
        description = "Network aliases for the container.";
      };

      ports = mkOption {
        type = with types; listOf str;
        default = [ ];
        example = [ "8080:80" "8443:443" ];
        description = "A mapping of ports between host and container";
      };

      userNS = mkOption {
        type = with types; nullOr str;
        default = null;
        description = "Use a user namespace for the container.";
      };

      user = mkOption {
        type = with types; nullOr (either int str);
        default = null;
        description = "The user ID inside the container.";
      };

      volumes = mkOption {
        type = with types; listOf str;
        default = [ ];
        example = [ "/tmp:/tmp" "/var/run/test.secret:/etc/secret:ro" ];
        description = "The volumes to mount into the container.";
      };

    };
  };

in {

  imports = [ ./options.nix ];

  options.services.podman.containers = mkOption {
    type = types.attrsOf containerDefinitionType;
    default = { };
    description = "Defines Podman container quadlet configurations.";
  };

  config =
    let containerQuadlets = mapAttrsToList toQuadletInternal cfg.containers;
    in mkIf cfg.enable {
      services.podman.internal.quadletDefinitions = containerQuadlets;
      assertions =
        flatten (map (container: container.assertions) containerQuadlets);

      # manifest file
      home.file."${config.xdg.configHome}/podman/containers.manifest".text =
        podman-lib.generateManifestText containerQuadlets;
    };
}

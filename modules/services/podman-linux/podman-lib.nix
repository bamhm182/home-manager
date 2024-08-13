{ lib, ... }:

with lib;

let
  primitive = with types; nullOr (oneOf [ bool int str path ]);
  primitiveAttrs = with types; attrsOf (either primitive (listOf primitive));

  formatPrimitiveValue = value:
    if isBool value then
      (if value then "true" else "false")
    else if isList value then
      concatStringsSep " " (map toString value)
    else
      toString value;
in {
  inherit primitive;
  inherit primitiveAttrs;
  inherit formatPrimitiveValue;

  serviceConfigTypeRules = {
    Restart = types.enum [ "no" "always" "on-failure" "unless-stopped" ];
    TimeoutStopSec = types.int;
  };
  serviceConfigDefaults = {
    Restart = "always";
    TimeoutStopSec = 30;
    ExecStartPre = null;
  };
  serviceConfigType = with types; attrsOf (either primitive (listOf primitive));

  unitConfigTypeRules = { After = with types; nullOr (listOf str); };
  unitConfigDefaults = { After = null; };
  unitConfigType = with types; attrsOf (either primitive (listOf primitive));

  buildConfigAsserts = quadletName: config: configTypeRules:
    flatten (mapAttrsToList (name: value:
      if hasAttr name configTypeRules then [{
        assertion = configTypeRules.${name}.check value;
        message = "in '${quadletName}' config. ${name}: '${
            toString value
          }' does not match expected type: ${
            configTypeRules.${name}.description
          }";
      }] else
        [ ]) config);

  formatExtraConfig = extraConfig:
    let nonNullConfig = filterAttrs (name: value: value != null) extraConfig;
    in concatStringsSep "\n"
    (mapAttrsToList (name: value: "${name}=${formatPrimitiveValue value}")
      nonNullConfig);

  # input is expecting a list of quadletInternalType with all the same resourceType
  generateManifestText = quadlets:
    let
      # create a list of all unique quadlet.resourceType in quadlets
      quadletTypes = unique (map (quadlet: quadlet.resourceType) quadlets);
      # if quadletTypes is > 1, then all quadlets are not the same type
      allQuadletsSameType = length quadletTypes <= 1;

      # ensures the service name is formatted correctly to be easily read by the activation script and matches `podman <resource> ls` output
      formatServiceName = quadlet:
        let
          # remove the podman- prefix from the service name string
          strippedName =
            builtins.replaceStrings [ "podman-" ] [ "" ] quadlet.serviceName;
          # specific logic for writing the unit name goes here. It should be identical to what `podman <resource> ls` shows
        in {
          "container" = strippedName;
          "network" = strippedName;
        }."${quadlet.resourceType}";
    in if allQuadletsSameType then ''
      ${concatStringsSep "\n"
      (map (quadlet: formatServiceName quadlet) quadlets)}
    '' else
      abort ''
        All quadlets must be of the same type.
        Quadlet types in this manifest: ${concatStringsSep ", " quadletTypes}'';
}

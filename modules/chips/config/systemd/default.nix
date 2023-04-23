{
  pkgs,
  lib,
  modulesPath,
  ...
}: let
  utils = pkgs.callPackage "${pkgs.path}/nixos/lib/utils.nix" {};
in
  with utils;
  with systemdUtils.unitOptions;
  with lib; {
    # Copied from nixos/modules/system/boot/systemd.nix
    options = {
      systemd.package = mkOption {
        default = pkgs.systemd;
        defaultText = literalExpression "pkgs.systemd";
        type = types.package;
        description = lib.mdDoc "The systemd package.";
      };

      systemd.units = mkOption {
        description = lib.mdDoc "Definition of systemd units.";
        default = {};
        type = systemdUtils.types.units;
      };

      systemd.packages = mkOption {
        default = [];
        type = types.listOf types.package;
        example = literalExpression "[ pkgs.systemd-cryptsetup-generator ]";
        description = lib.mdDoc "Packages providing systemd units and hooks.";
      };

      systemd.targets = mkOption {
        default = {};
        type = systemdUtils.types.targets;
        description = lib.mdDoc "Definition of systemd target units.";
      };

      systemd.services = mkOption {
        default = {};
        type = systemdUtils.types.services;
        description = lib.mdDoc "Definition of systemd service units.";
      };

      systemd.sockets = mkOption {
        default = {};
        type = systemdUtils.types.sockets;
        description = lib.mdDoc "Definition of systemd socket units.";
      };

      systemd.timers = mkOption {
        default = {};
        type = systemdUtils.types.timers;
        description = lib.mdDoc "Definition of systemd timer units.";
      };

      systemd.paths = mkOption {
        default = {};
        type = systemdUtils.types.paths;
        description = lib.mdDoc "Definition of systemd path units.";
      };

      systemd.mounts = mkOption {
        default = [];
        type = systemdUtils.types.mounts;
        description = lib.mdDoc ''
          Definition of systemd mount units.
          This is a list instead of an attrSet, because systemd mandates the names to be derived from
          the 'where' attribute.
        '';
      };

      systemd.automounts = mkOption {
        default = [];
        type = systemdUtils.types.automounts;
        description = lib.mdDoc ''
          Definition of systemd automount units.
          This is a list instead of an attrSet, because systemd mandates the names to be derived from
          the 'where' attribute.
        '';
      };

      systemd.slices = mkOption {
        default = {};
        type = systemdUtils.types.slices;
        description = lib.mdDoc "Definition of slice configurations.";
      };

      systemd.generators = mkOption {
        type = types.attrsOf types.path;
        default = {};
        example = {systemd-gpt-auto-generator = "/dev/null";};
        description = lib.mdDoc ''
          Definition of systemd generators.
          For each `NAME = VALUE` pair of the attrSet, a link is generated from
          `/etc/systemd/system-generators/NAME` to `VALUE`.
        '';
      };

      systemd.shutdown = mkOption {
        type = types.attrsOf types.path;
        default = {};
        description = lib.mdDoc ''
          Definition of systemd shutdown executables.
          For each `NAME = VALUE` pair of the attrSet, a link is generated from
          `/etc/systemd/system-shutdown/NAME` to `VALUE`.
        '';
      };

      systemd.defaultUnit = mkOption {
        default = "multi-user.target";
        type = types.str;
        description = lib.mdDoc "Default unit started when the system boots.";
      };

      systemd.ctrlAltDelUnit = mkOption {
        default = "reboot.target";
        type = types.str;
        example = "poweroff.target";
        description = lib.mdDoc ''
          Target that should be started when Ctrl-Alt-Delete is pressed.
        '';
      };

      systemd.globalEnvironment = mkOption {
        type = with types; attrsOf (nullOr (oneOf [str path package]));
        default = {};
        example = {TZ = "CET";};
        description = lib.mdDoc ''
          Environment variables passed to *all* systemd units.
        '';
      };

      systemd.managerEnvironment = mkOption {
        type = with types; attrsOf (nullOr (oneOf [str path package]));
        default = {};
        example = {SYSTEMD_LOG_LEVEL = "debug";};
        description = lib.mdDoc ''
          Environment variables of PID 1. These variables are
          *not* passed to started units.
        '';
      };

      systemd.enableCgroupAccounting = mkOption {
        default = true;
        type = types.bool;
        description = lib.mdDoc ''
          Whether to enable cgroup accounting.
        '';
      };

      systemd.enableUnifiedCgroupHierarchy = mkOption {
        default = true;
        type = types.bool;
        description = lib.mdDoc ''
          Whether to enable the unified cgroup hierarchy (cgroupsv2).
        '';
      };

      systemd.extraConfig = mkOption {
        default = "";
        type = types.lines;
        example = "DefaultLimitCORE=infinity";
        description = lib.mdDoc ''
          Extra config options for systemd. See systemd-system.conf(5) man page
          for available options.
        '';
      };

      systemd.sleep.extraConfig = mkOption {
        default = "";
        type = types.lines;
        example = "HibernateDelaySec=1h";
        description = lib.mdDoc ''
          Extra config options for systemd sleep state logic.
          See sleep.conf.d(5) man page for available options.
        '';
      };

      systemd.additionalUpstreamSystemUnits = mkOption {
        default = [];
        type = types.listOf types.str;
        example = ["debug-shell.service" "systemd-quotacheck.service"];
        description = lib.mdDoc ''
          Additional units shipped with systemd that shall be enabled.
        '';
      };

      systemd.suppressedSystemUnits = mkOption {
        default = [];
        type = types.listOf types.str;
        example = ["systemd-backlight@.service"];
        description = lib.mdDoc ''
          A list of units to skip when generating system systemd configuration directory. This has
          priority over upstream units, {option}`systemd.units`, and
          {option}`systemd.additionalUpstreamSystemUnits`. The main purpose of this is to
          prevent a upstream systemd unit from being added to the initrd with any modifications made to it
          by other NixOS modules.
        '';
      };

      systemd.watchdog.device = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/dev/watchdog";
        description = lib.mdDoc ''
          The path to a hardware watchdog device which will be managed by systemd.
          If not specified, systemd will default to /dev/watchdog.
        '';
      };

      systemd.watchdog.runtimeTime = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "30s";
        description = lib.mdDoc ''
          The amount of time which can elapse before a watchdog hardware device
          will automatically reboot the system. Valid time units include "ms",
          "s", "min", "h", "d", and "w".
        '';
      };

      systemd.watchdog.rebootTime = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "10m";
        description = lib.mdDoc ''
          The amount of time which can elapse after a reboot has been triggered
          before a watchdog hardware device will automatically reboot the system.
          Valid time units include "ms", "s", "min", "h", "d", and "w".
        '';
      };

      systemd.watchdog.kexecTime = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "10m";
        description = lib.mdDoc ''
          The amount of time which can elapse when kexec is being executed before
          a watchdog hardware device will automatically reboot the system. This
          option should only be enabled if reloadTime is also enabled. Valid
          time units include "ms", "s", "min", "h", "d", and "w".
        '';
      };
    };
  }

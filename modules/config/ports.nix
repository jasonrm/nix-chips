{ lib, pkgs, config, ... }:
let
  inherit (lib) mkOption mapAttrs types;

  defaults = {
    supervisord = 9001;

    nginx = 8080;
    mysql = 3306;

    redis = 6379;
    memcached = 11211;

    mailhogSmtp = 2004;
    mailhogHttp = 2005;

    http = 80;
    https = 443;
    tomcat = 9191;
    # rabbitmq_amqp = 2007;
    # rabbitmq_mgmt = 2011;
    # sphinx = 2012;
    # sphinxQL = 2017;
    # loki_http = 2013;
    # loki_grpc = 2014;
    # promtail = 2015;
    # grafana = 2016;
    # ngrok = 2009;
    # webpack = 2020;
    # supervisord = 2022;
    # vite = 2021;
  };

  mkPortOption = name: port:
    mkOption {
      type = types.int;
      default = port;
    };
in
{
  options = {
    ports = mapAttrs mkPortOption defaults;
  };

  config = {
    # TODO: check for port collision
  };
}

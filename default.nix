{ nixpkgs }:

with nixpkgs;

let
  inherit (builtins) concatMap getEnv toJSON;
  inherit (dockerTools) buildLayeredImage;
  inherit (lib) concatMapStringsSep firstNChars flattenSet dockerRunCmd mkRootfs;
  inherit (lib.attrsets) collect isDerivation;
  inherit (stdenv) mkDerivation;

  php70DockerArgHints = lib.phpDockerArgHints { php = php70; };

  rootfs = mkRootfs {
    name = "apache2-rootfs-php70";
    src = ./rootfs;
    inherit zlib curl coreutils findutils apacheHttpdmpmITK apacheHttpd
      s6 execline php70 logger;
    mjHttpErrorPages = mj-http-error-pages;
    postfix = sendmail;
    mjperl5Packages = mjperl5lib;
    ioncube = ioncube.v70;
    s6PortableUtils = s6-portable-utils;
    s6LinuxUtils = s6-linux-utils;
    mimeTypes = mime-types;
    libstdcxx = gcc-unwrapped.lib;
  };

in

pkgs.dockerTools.buildLayeredImage rec {
  name = "docker-registry.intr/webservices/apache2-php70";
  tag = "latest";
  contents = [
    rootfs
    tzdata
    apacheHttpd
    locale
    sendmail
    sh
    coreutils
    libjpeg_turbo
    jpegoptim
    (optipng.override { inherit libpng; })
    imagemagickBig
    ghostscript
    gifsicle
    nss-certs.unbundled
    zip
    gcc-unwrapped.lib
    glibc
    zlib
    mariadbConnectorC
    logger
    perl520
    fontconfig.out
    gifsicle
    ghostscript
    nodePackages.svgo
  ]
  ++ collect isDerivation mjperl5Packages
  ++ collect isDerivation php70Packages;
  config = {
    Entrypoint = [ "${rootfs}/init" ];
    Env = [
      "TZ=Europe/Moscow"
      "TZDIR=${tzdata}/share/zoneinfo"
      "LOCALE_ARCHIVE_2_27=${locale}/lib/locale/locale-archive"
      "LOCALE_ARCHIVE=${locale}/lib/locale/locale-archive"
      "LC_ALL=en_US.UTF-8"
      "LD_PRELOAD=${jemalloc}/lib/libjemalloc.so"
      "PERL5LIB=${mjPerlPackages.PERL5LIB}"
    ];
    Labels = flattenSet rec {
      ru.majordomo.docker.arg-hints-json = builtins.toJSON php70DockerArgHints;
      ru.majordomo.docker.cmd = dockerRunCmd php70DockerArgHints "${name}:${tag}";
      ru.majordomo.docker.exec.reload-cmd = "${apacheHttpd}/bin/httpd -d ${rootfs}/etc/httpd -k graceful";
    };
  };
  extraCommands = ''
    set -xe
    ls
    mkdir -p etc
    mkdir -p bin
    mkdir -p usr/local
    mkdir -p opt
    chmod 755 bin
    ln -s ${nodePackages.svgo}/bin/svgo bin/svgo
    ln -s ${php70} opt/php70
    ln -s /bin usr/bin
    ln -s /bin usr/sbin
    ln -s /bin usr/local/bin
    mkdir tmp
    chmod 1777 tmp
  '';
}

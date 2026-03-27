{
  description = "Technical blog";
  inputs = {
    proxy-flake.url = "github:chpill/proxy-flake";
    nixpkgs.follows = "proxy-flake/nixpkgs";
  };
  outputs =
    { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      formatter.${system} = pkgs.nixfmt-tree;
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          pandoc
          # To view the pages locally:
          # cd publish && python -m http.server
          python3
          # To check that the feed is valid xml
          # xmllint --noout **/*.xml
          libxml2
        ];
      };
      packages.${system} =
        let
          website = import ./gen.nix pkgs;
        in
        {
          inherit website;
          default = website;
        };
      checks.${system} =
        let
          site = self.packages.${system}.default;
        in
        {
          # TODO add a test using xmllint
          dirCountTest =
            pkgs.runCommandLocal "basicDirCountTest"
              {
                src = ./en/posts;
                nativeBuildInputs = [ site ];
              }
              ''
                mkdir $out
                sourceFilesCount=$(find "${./en/posts}"    -maxdepth 1 -type f | wc -l)
                resultFilesCount=$(find "${site}/en/posts" -maxdepth 1 -type l | wc -l)
                [ "$sourceFilesCount" -eq "$resultFilesCount" ]
              '';
          feedTest =
            pkgs.runCommandLocal "feedTest"
              {
                src = ./.;
                nativeBuildInputs = [
                  site
                  previous-site
                  feed-compare
                ];
              }
              ''
                mkdir $out
                feedtest ${site} ${previous-site}
              '';
        };
      nixosConfigurations.container = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          {
            system.stateVersion = "25.05";
            boot.isContainer = true;
            networking.firewall.allowedTCPPorts = [ 80 ];
            # For some unadequately explored reasons, this delays the start of the container
            networking.useDHCP = false;
            services.nginx =
              let
                site = self.packages.${system}.website;
                # From ietf.org/rfc/rfc2616.txt:
                # To mark a response as 'never expires,' an origin server sends
                # an Expires date approximately one year from the time the
                # response is sent. HTTP/1.1 servers SHOULD NOT send Expires
                # dates more than one year in the future.
                max-age = "31536000";
              in
              {
                enable = true;
                # When the url does not match the regex, $cache_control will be
                # empty, and Nginx will not add the Cache_Control header to the
                # response
                appendHttpConfig = ''
                  map $uri $cache_control {
                    ~/assets/ "max-age=${max-age}, public, immutable";
                  }
                '';
                virtualHosts."container.local" = {
                  default = true;
                  locations."/" = {
                    root = site;
                    extraConfig = "add_header Cache-Control $cache_control;";
                  };
                };
              };
          }
        ];
      };
    };
}

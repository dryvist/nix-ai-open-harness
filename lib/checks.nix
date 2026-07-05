{
  home-manager,
  homeModule,
  pkgs,
  system,
}:

let
  tokenFile = "/run/secrets/llm-router-token";
  endpoint = "https://llm.example.com/v1";

  hmConfig = home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      homeModule
      {
        home = {
          username = "open-harness-test";
          homeDirectory = "/tmp/open-harness-test";
          stateVersion = "26.05";
        };

        programs.openHarness = {
          enable = true;
          inherit endpoint tokenFile;
        };
      }
    ];
  };

  hmEnvConfig = home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      homeModule
      {
        home = {
          username = "open-harness-env-test";
          homeDirectory = "/tmp/open-harness-env-test";
          stateVersion = "26.05";
        };

        programs.openHarness = {
          enable = true;
          inherit endpoint;
          tokenFile = null;
          tokenEnvVar = "OPENAI_API_KEY";
        };
      }
    ];
  };

  crushConfig = pkgs.writeText "crush.json" hmConfig.config.home.file.".config/crush/crush.json".text;
  mimoConfig =
    pkgs.writeText "mimocode.json"
      hmConfig.config.home.file.".config/mimocode/mimocode.json".text;
  crushEnvConfig =
    pkgs.writeText "crush-env.json"
      hmEnvConfig.config.home.file.".config/crush/crush.json".text;
  mimoEnvConfig =
    pkgs.writeText "mimocode-env.json"
      hmEnvConfig.config.home.file.".config/mimocode/mimocode.json".text;
in
{
  config-fixture =
    pkgs.runCommand "open-harness-config-fixture-${system}" { nativeBuildInputs = [ pkgs.jq ]; }
      ''
        jq -e '.providers."dryvist-local-llm".type == "openai-compat"' ${crushConfig}
        jq -e '.providers."dryvist-local-llm".base_url == "${endpoint}"' ${crushConfig}
        jq -e '.providers."dryvist-local-llm".api_key == "$(cat ${tokenFile})"' ${crushConfig}
        jq -e '.providers."dryvist-local-llm".models[] | select(.id == "coding")' ${crushConfig}

        jq -e '.provider."dryvist-local-llm".options.baseURL == "${endpoint}"' ${mimoConfig}
        jq -e '.provider."dryvist-local-llm".options.apiKey == "{file:${tokenFile}}"' ${mimoConfig}
        jq -e '.model == "dryvist-local-llm/coding"' ${mimoConfig}
        jq -e '.small_model == "dryvist-local-llm/quickest"' ${mimoConfig}
        jq -e '.enabled_providers == ["dryvist-local-llm"]' ${mimoConfig}
        jq -e '.autoupdate == false' ${mimoConfig}

        jq -e '.providers."dryvist-local-llm".api_key == "$OPENAI_API_KEY"' ${crushEnvConfig}
        jq -e '.provider."dryvist-local-llm".options.apiKey == "{env:OPENAI_API_KEY}"' ${mimoEnvConfig}

        if grep -R "secret-token-value" ${crushConfig} ${mimoConfig} ${crushEnvConfig} ${mimoEnvConfig}; then
          echo "literal secret material rendered into config" >&2
          exit 1
        fi

        touch $out
      '';
}

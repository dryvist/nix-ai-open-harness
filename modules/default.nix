{
  config,
  lib,
  pkgs,
  nix-ai-tools,
  ...
}:

let
  cfg = config.programs.openHarness;
  inherit (lib)
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    optional
    types
    ;

  packageSet = nix-ai-tools.packages.${pkgs.stdenv.hostPlatform.system};

  modelType = types.submodule {
    options = {
      id = mkOption {
        type = types.str;
        description = "Model or capability alias sent to the LLM router.";
      };

      name = mkOption {
        type = types.str;
        default = "";
        description = "Human-readable model name. Defaults to id when empty.";
      };

      contextWindow = mkOption {
        type = types.ints.positive;
        default = 131072;
        description = "Context window advertised to clients.";
      };

      defaultMaxTokens = mkOption {
        type = types.ints.positive;
        default = 8192;
        description = "Default generation limit advertised to clients.";
      };

      canReason = mkOption {
        type = types.bool;
        default = true;
        description = "Whether the model supports reasoning-style responses.";
      };

      supportsAttachments = mkOption {
        type = types.bool;
        default = false;
        description = "Whether the model should be advertised as attachment-capable.";
      };
    };
  };

  mkModel = id: {
    inherit id;
    name = id;
  };

  crushModels = map (model: {
    inherit (model) id;
    name = if model.name == "" then model.id else model.name;
    context_window = model.contextWindow;
    default_max_tokens = model.defaultMaxTokens;
    can_reason = model.canReason;
    supports_attachments = model.supportsAttachments;
  }) cfg.models;

  mimoModels = builtins.listToAttrs (
    map (model: {
      name = model.id;
      value = {
        options = {
          inherit (model) contextWindow;
          inherit (model) defaultMaxTokens;
        };
      };
    }) cfg.models
  );

  apiKey = if cfg.tokenFile != null then "$(cat ${cfg.tokenFile})" else "$" + cfg.tokenEnvVar;

  mimoApiKey =
    if cfg.tokenFile != null then "{file:${cfg.tokenFile}}" else "{env:${cfg.tokenEnvVar}}";

  crushConfig = lib.recursiveUpdate {
    "$schema" = "https://charm.land/crush.json";
    providers.${cfg.providerId} = {
      type = "openai-compat";
      base_url = cfg.endpoint;
      api_key = apiKey;
      models = crushModels;
    };
    permissions.allowed_tools = cfg.crush.allowedTools;
    options = {
      disabled_tools = cfg.crush.disabledTools;
      disable_notifications = cfg.crush.disableNotifications;
    };
  } cfg.crush.extraSettings;

  mimoConfig = lib.recursiveUpdate {
    "$schema" = "https://mimo.xiaomi.com/mimocode/config.json";
    model = "${cfg.providerId}/${cfg.defaultModel}";
    small_model = "${cfg.providerId}/${cfg.smallModel}";
    provider.${cfg.providerId} = {
      models = mimoModels;
      options = {
        apiKey = mimoApiKey;
        baseURL = cfg.endpoint;
        timeout = cfg.timeoutMs;
      };
    };
    enabled_providers = [ cfg.providerId ];
    autoupdate = false;
    share = "manual";
    permission = cfg.mimoCode.permission;
  } cfg.mimoCode.extraSettings;
in
{
  options.programs.openHarness = {
    enable = mkEnableOption "open local-LLM fallback harness tools";

    endpoint = mkOption {
      type = types.str;
      default = "";
      example = "https://llm.example.com/v1";
      description = "OpenAI-compatible LLM fabric /v1 endpoint.";
    };

    tokenFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/run/secrets/llm-router-token";
      description = "Path to a runtime bearer token file. The token value is never rendered into Nix-managed files.";
    };

    tokenEnvVar = mkOption {
      type = types.str;
      default = "OPENAI_API_KEY";
      description = "Environment variable used for runtime bearer token lookup when tokenFile is null.";
    };

    providerId = mkOption {
      type = types.str;
      default = "dryvist-local-llm";
      description = "Provider id rendered into each tool config.";
    };

    defaultModel = mkOption {
      type = types.str;
      default = "coding";
      description = "Default model or capability alias.";
    };

    smallModel = mkOption {
      type = types.str;
      default = "quickest";
      description = "Small or lightweight model alias used by MiMoCode.";
    };

    timeoutMs = mkOption {
      type = types.ints.positive;
      default = 600000;
      description = "Provider request timeout in milliseconds.";
    };

    models = mkOption {
      type = types.listOf modelType;
      default = map mkModel [
        "default"
        "quickest"
        "tool-calling"
        "coding"
        "large-context"
        "most-capable"
        "oss"
      ];
      description = "Capability aliases exposed to Crush and MiMoCode.";
    };

    crush = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Install Crush and render ~/.config/crush/crush.json when programs.openHarness.enable is true.";
      };

      package = mkOption {
        type = types.package;
        default = packageSet.crush;
        defaultText = lib.literalExpression "inputs.nix-ai-tools.packages.<system>.crush";
        description = "Crush package.";
      };

      allowedTools = mkOption {
        type = types.listOf types.str;
        default = [
          "view"
          "ls"
          "grep"
        ];
        description = "Crush tools allowed without prompting.";
      };

      disabledTools = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Crush built-in tools hidden from the agent.";
      };

      disableNotifications = mkOption {
        type = types.bool;
        default = false;
        description = "Disable Crush desktop notifications.";
      };

      extraSettings = mkOption {
        type = types.attrs;
        default = { };
        description = "Free-form settings recursively merged over the generated Crush config.";
      };
    };

    mimoCode = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Install MiMoCode and render ~/.config/mimocode/mimocode.json when programs.openHarness.enable is true.";
      };

      package = mkOption {
        type = types.package;
        default = packageSet.mimo-code;
        defaultText = lib.literalExpression "inputs.nix-ai-tools.packages.<system>.mimo-code";
        description = "MiMoCode package.";
      };

      permission = mkOption {
        type = types.attrs;
        default = {
          "*" = "ask";
          bash = "ask";
          edit = "ask";
          write = "ask";
        };
        description = "MiMoCode permission policy.";
      };

      extraSettings = mkOption {
        type = types.attrs;
        default = { };
        description = "Free-form settings recursively merged over the generated MiMoCode config.";
      };
    };

    goose = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Install Goose CLI and render ~/.config/goose/config.yaml when programs.openHarness.enable is true.";
      };

      package = mkOption {
        type = types.package;
        default = packageSet.goose-cli;
        defaultText = lib.literalExpression "inputs.nix-ai-tools.packages.<system>.goose-cli";
        description = "Goose CLI package.";
      };

      extraSettings = mkOption {
        type = types.attrs;
        default = { };
        description = "Free-form settings recursively merged over the generated Goose config.";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.endpoint != "";
        message = "programs.openHarness.endpoint must be set to the OpenAI-compatible LLM router /v1 URL.";
      }
      {
        assertion = (cfg.tokenFile != null && cfg.tokenFile != "") || cfg.tokenEnvVar != "";
        message = "programs.openHarness must set tokenFile or tokenEnvVar for the LLM router bearer token.";
      }
      {
        assertion = builtins.any (model: model.id == cfg.defaultModel) cfg.models;
        message = "programs.openHarness.defaultModel must match one of programs.openHarness.models.*.id.";
      }
      {
        assertion = builtins.any (model: model.id == cfg.smallModel) cfg.models;
        message = "programs.openHarness.smallModel must match one of programs.openHarness.models.*.id.";
      }
    ];

    home.packages =
      optional cfg.crush.enable cfg.crush.package ++
      optional cfg.mimoCode.enable cfg.mimoCode.package ++
      optional cfg.goose.enable cfg.goose.package;

    home.file = mkMerge [
      (mkIf cfg.crush.enable {
        ".config/crush/crush.json".text = builtins.toJSON crushConfig;
      })
      (mkIf cfg.mimoCode.enable {
        ".config/mimocode/mimocode.json".text = builtins.toJSON mimoConfig;
      })
      (mkIf cfg.goose.enable {
        ".config/goose/config.yaml".text = ''
          GOOSE_PROVIDER: "openai"
          GOOSE_MODEL: "${cfg.defaultModel}"
          OPENAI_HOST: "${cfg.endpoint}"
        '';
      })
    ];
  };
}

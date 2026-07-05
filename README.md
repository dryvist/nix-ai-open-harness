# nix-ai-open-harness

Declarative local-LLM fallback harness for open AI coding agents.

This flake installs and configures two workstation tools:

- [Crush](https://github.com/charmbracelet/crush)
- [MiMoCode](https://github.com/XiaomiMiMo/MiMo-Code)

Both tools are pointed at the same OpenAI-compatible LLM fabric endpoint used by
the rest of the homelab stack, normally `https://llm.<domain>/v1`. The bearer
token is read from a runtime file by each tool, so token values never enter the
Nix store.

## Usage

Add the flake to a Home Manager or nix-darwin consumer and import the module:

```nix
{
  inputs.nix-ai-open-harness.url = "github:dryvist/nix-ai-open-harness";

  outputs =
    { nix-ai-open-harness, ... }:
    {
      home-manager.users.jevens = {
        imports = [
          nix-ai-open-harness.homeManagerModules.default
        ];

        programs.openHarness = {
          enable = true;
          endpoint = "https://llm.example.com/v1";
          # Use tokenFile for file-backed secrets, or tokenEnvVar for
          # shell/keychain-backed workstations.
          tokenEnvVar = "OPENAI_API_KEY";
        };
      };
    };
}
```

The consumer owns the endpoint and token source because those values are
environment-specific. This repo owns the tool package selection and config file
rendering.

## Options

| Option                                 | Default            | Purpose                            |
| -------------------------------------- | ------------------ | ---------------------------------- |
| `programs.openHarness.enable`          | `false`            | Enable both harness tools          |
| `programs.openHarness.endpoint`        | `""`               | OpenAI-compatible `/v1` endpoint   |
| `programs.openHarness.tokenFile`       | `null`             | Runtime bearer token file          |
| `programs.openHarness.tokenEnvVar`     | `OPENAI_API_KEY`   | Runtime bearer token env var       |
| `programs.openHarness.defaultModel`    | `"coding"`         | Primary capability alias           |
| `programs.openHarness.smallModel`      | `"quickest"`       | Lightweight capability alias       |
| `programs.openHarness.models`          | capability aliases | Models exposed to both tools       |
| `programs.openHarness.crush.enable`    | follows parent     | Render Crush config and package    |
| `programs.openHarness.mimoCode.enable` | follows parent     | Render MiMoCode config and package |

## Validation

```bash
nix flake check
nix fmt
```

`nix flake check` evaluates a Home Manager fixture and checks that:

- Crush points at the configured endpoint and reads the token with runtime file
  or environment expansion.
- MiMoCode points at the configured endpoint and reads the token with
  `{file:...}` or `{env:...}` substitution.
- No literal token value is rendered into either config.

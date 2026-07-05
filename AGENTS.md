# nix-ai-open-harness - AI Agent Instructions

Declarative local-LLM fallback harness for open AI coding agents.

## Critical Constraints

1. **Flakes-only**: Never use `nix-env` or imperative Nix package installs.
2. **Runtime secrets only**: Token values must never be written into Nix files,
   generated configs, logs, or the Nix store. Use token file paths or supported
   runtime substitution.
3. **Workstation-only consumer**: This repo exports a reusable Home Manager
   module, but dryvist enables it only on MacBook Pro workstation hosts.
4. **Router-first endpoint**: Tools target the standard LLM fabric route
   (`https://llm.<domain>/v1`). Do not point tools directly at the Mac Studio
   gate unless the shared fabric contract changes.
5. **No direct main commits**: Use feature branches for changes after initial
   repository bootstrap.

## Validation

```bash
nix flake check
nix fmt
```

For consumer changes, also evaluate the nix-darwin host that imports this
module and inspect the generated Home Manager files.

## Architecture

This repo exports:

- `homeManagerModules.default` - Crush and MiMoCode package/config module
- `packages.<system>.crush` - passthrough from `numtide/nix-ai-tools`
- `packages.<system>.mimo-code` - passthrough from `numtide/nix-ai-tools`
- `checks.<system>.config-fixture` - Home Manager eval check for generated
  configs

Package derivations come from `github:numtide/nix-ai-tools`. This repo should
not package Crush or MiMoCode unless that upstream source stops satisfying the
workstation use case.

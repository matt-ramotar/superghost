# Superghost Runtime Contract Cutover Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename runtime contracts so CLI names, env vars, sockets, defaults domains, keychain services, config files, helper shims, remote bootstrap state, and automation markers no longer depend on `cmux`.

**Architecture:** Cut over local runtime primitives first, then shell/helper automation, then remote relay/bootstrap state, then test harness and verification surfaces. Keep each step behavior-driven so the renamed runtime contract is coherent instead of partially aliased.

**Tech Stack:** Swift CLI/runtime code, AppKit runtime settings, shell integration, shell scripts, remote Go helpers, Python socket clients, markdown verification plans.

## File Map

- Modify: `CLI/cmux.swift`
  Responsibility: rename CLI usage text, runtime env names, config identities, remote bootstrap paths, and helper env contracts.
- Modify: `Sources/SocketControlSettings.swift`
  Responsibility: rename socket/defaults/keychain marker identities and stable/debug/staging socket resolution.
- Modify: `Sources/CmuxDirectoryTrust.swift`
  Responsibility: rename trusted-directory persistence, trust-key derivation, and config-approval storage tied to `cmux.json`.
- Modify: `Sources/CmuxConfig.swift`
  Responsibility: rename config-file discovery, global config-directory defaults, and config-store paths.
- Modify: `Sources/CmuxConfigExecutor.swift`
  Responsibility: rename confirmation-flow strings and trust/approval behavior tied to command execution from config files.
- Modify: `Sources/cmuxApp.swift`
  Responsibility: rename settings UI text and trusted-directory editing surfaces that expose the supported config/trust contract.
- Modify: `Sources/GhosttyTerminalView.swift`
  Responsibility: rename shell/session environment exports injected into terminal surfaces.
- Modify: `Sources/SessionPersistence.swift`
  Responsibility: rename app-support and cache-backed persistence paths that still derive from `cmux`.
- Modify: `Sources/Panels/BrowserPanel.swift`
  Responsibility: rename support/cache-backed browser state paths and persisted filenames that still derive from `cmux`.
- Modify: `Sources/Workspace.swift`
  Responsibility: rename remote bootstrap install paths, relay metadata files, wrapper symlinks, and daemon-path discovery that still use `.cmux`, `.cmuxterm`, or `cmuxd-remote-current`.
- Modify: `scripts/reload.sh`
  Responsibility: rename debug marker files, helper shims, env injection, and last-socket/debug-log/CLI markers.
- Modify: `scripts/reloads.sh`
  Responsibility: rename staging socket/env/helper state.
- Modify: `scripts/launch-tagged-automation.sh`
  Responsibility: rename automation launch env and tagged socket discovery.
- Modify: `scripts/run-tests-v1.sh`
  Responsibility: rename VM automation bootstrap defaults for app path, defaults domain, socket discovery, and launch envs.
- Modify: `scripts/run-tests-v2.sh`
  Responsibility: rename v2 VM automation bootstrap defaults for app path, defaults domain, socket discovery, and launch envs.
- Modify: `Resources/shell-integration/cmux-bash-integration.bash`
  Responsibility: rename shell integration env contracts and helper transport assumptions.
- Modify: `Resources/shell-integration/.zshrc`
  Responsibility: rename zsh helper env integration.
- Modify: `Resources/shell-integration/cmux-zsh-integration.zsh`
  Responsibility: rename the active zsh shell-integration implementation, exported env contract, and helper behavior.
- Modify: `daemon/remote/README.md`
  Responsibility: document the renamed remote bootstrap and relay state contract.
- Modify: `daemon/remote/cmd/cmuxd-remote/agent_launch.go`
  Responsibility: rename remote shim directories, helper env names, and wrapper paths.
- Modify: `daemon/remote/cmd/cmuxd-remote/tmux_compat.go`
  Responsibility: rename `.cmuxterm` compatibility store paths and runtime env lookups.
- Modify: `tests/**/*.py`
  Responsibility: rename active Python automation tests that encode socket, bundle, support-directory, or helper-runtime defaults.
- Modify: `tests_v2/**/*.py`
  Responsibility: rename v2 Python automation tests and helper clients that encode supported runtime defaults.

### Task 1: Rename Local CLI, Socket, Defaults, Keychain, And Config Identities

**Files:**
- Modify: `CLI/cmux.swift`
- Modify: `Sources/SocketControlSettings.swift`
- Modify: `Sources/CmuxDirectoryTrust.swift`
- Modify: `Sources/CmuxConfig.swift`
- Modify: `Sources/CmuxConfigExecutor.swift`
- Modify: `Sources/cmuxApp.swift`
- Modify: `Sources/SessionPersistence.swift`
- Modify: `Sources/Panels/BrowserPanel.swift`

- [ ] **Step 1: Inventory current local runtime identifiers**

Run:
```bash
rg -n 'CMUX_|cmux\\.json|\\.config/cmux|Application Support/cmux|Library/Caches/cmux|trusted-directories\\.json|CmuxDirectoryTrust|CmuxConfig|dialog\\.cmuxConfig|settings\\.customCommands|com\\.cmuxterm|socket-control|last-socket-path|cmux\\.sock|cmux-debug|cmux-staging|cmux-nightly' \
  CLI/cmux.swift \
  Sources/SocketControlSettings.swift \
  Sources/CmuxDirectoryTrust.swift \
  Sources/CmuxConfig.swift \
  Sources/CmuxConfigExecutor.swift \
  Sources/cmuxApp.swift \
  Sources/SessionPersistence.swift \
  Sources/Panels/BrowserPanel.swift
```
Expected: env vars, socket paths, defaults domains, keychain services, and config identities still use `cmux`.

- [ ] **Step 2: Rename CLI/runtime identifiers to `superghost`**

Rename CLI usage/help text, config-file/config-directory names, trusted-directory persistence, confirmation-dialog copy, settings UI labels, support-directory and cache-directory paths, supported env names, defaults domains, keychain services, stable/debug/staging/nightly socket paths, marker files, and password-file identities so the active contract no longer depends on `cmux`.

- [ ] **Step 3: Verify local runtime surfaces**

Run:
```bash
rg -n 'CMUX_|cmux\\.json|\\.config/cmux|Application Support/cmux|Library/Caches/cmux|trusted-directories\\.json|CmuxDirectoryTrust|CmuxConfig|dialog\\.cmuxConfig|settings\\.customCommands|com\\.cmuxterm|socket-control|last-socket-path|cmux\\.sock|cmux-debug|cmux-staging|cmux-nightly' \
  CLI/cmux.swift \
  Sources/SocketControlSettings.swift \
  Sources/CmuxDirectoryTrust.swift \
  Sources/CmuxConfig.swift \
  Sources/CmuxConfigExecutor.swift \
  Sources/cmuxApp.swift \
  Sources/SessionPersistence.swift \
  Sources/Panels/BrowserPanel.swift
```
Expected: old active local runtime identifiers are removed or explicitly called out as historical/internal-only.

- [ ] **Step 4: Commit**

```bash
git add CLI/cmux.swift Sources/SocketControlSettings.swift Sources/CmuxDirectoryTrust.swift Sources/CmuxConfig.swift Sources/CmuxConfigExecutor.swift Sources/cmuxApp.swift Sources/SessionPersistence.swift Sources/Panels/BrowserPanel.swift
git commit -m "runtime: rename local CLI socket defaults and config identities"
```

### Task 2: Rename Shell Integration, Helper Shims, And Automation Marker Files

**Files:**
- Modify: `Sources/GhosttyTerminalView.swift`
- Modify: `scripts/reload.sh`
- Modify: `scripts/reloads.sh`
- Modify: `scripts/launch-tagged-automation.sh`
- Modify: `scripts/run-tests-v1.sh`
- Modify: `scripts/run-tests-v2.sh`
- Modify: `Resources/shell-integration/cmux-bash-integration.bash`
- Modify: `Resources/shell-integration/.zshrc`
- Modify: `Resources/shell-integration/cmux-zsh-integration.zsh`

- [ ] **Step 1: Inventory current shell/helper contract surfaces**

Run:
```bash
rg -n 'CMUX_|cmux-last|/tmp/cmux|cmux-cli|cmux-dev|cmux-bash-integration|CMUX_ZSH_ZDOTDIR|CMUX_SHELL_INTEGRATION' \
  Sources/GhosttyTerminalView.swift \
  scripts/reload.sh \
  scripts/reloads.sh \
  scripts/launch-tagged-automation.sh \
  scripts/run-tests-v1.sh \
  scripts/run-tests-v2.sh \
  Resources/shell-integration/cmux-bash-integration.bash \
  Resources/shell-integration/.zshrc \
  Resources/shell-integration/cmux-zsh-integration.zsh
```
Expected: shell/session env exports, helper shims, and automation markers still use `cmux`.

- [ ] **Step 2: Rename session envs, helper wrappers, and marker files**

Rename exported shell/session env vars, PATH shim names, debug log markers, last-socket/CLI markers, helper wrapper filenames, VM test-runner bootstrap defaults, `.zshrc` compatibility shims, and the active zsh shell-integration implementation so supported automation no longer depends on `cmux`.

- [ ] **Step 3: Verify shell/helper cutover**

Run:
```bash
rg -n 'CMUX_|cmux-last|/tmp/cmux|cmux-cli|cmux-dev|cmux-bash-integration|CMUX_ZSH_ZDOTDIR|CMUX_SHELL_INTEGRATION' \
  Sources/GhosttyTerminalView.swift \
  scripts/reload.sh \
  scripts/reloads.sh \
  scripts/launch-tagged-automation.sh \
  scripts/run-tests-v1.sh \
  scripts/run-tests-v2.sh \
  Resources/shell-integration/cmux-bash-integration.bash \
  Resources/shell-integration/.zshrc \
  Resources/shell-integration/cmux-zsh-integration.zsh
```
Expected: supported shell/helper contract surfaces are renamed or explicitly carved out as internal/historical only.

- [ ] **Step 4: Commit**

```bash
git add Sources/GhosttyTerminalView.swift scripts/reload.sh scripts/reloads.sh scripts/launch-tagged-automation.sh scripts/run-tests-v1.sh scripts/run-tests-v2.sh Resources/shell-integration/cmux-bash-integration.bash Resources/shell-integration/.zshrc Resources/shell-integration/cmux-zsh-integration.zsh
git commit -m "runtime: rename shell integration helpers and automation markers"
```

### Task 3: Rename Remote Relay, Bootstrap, And Helper-State Paths

**Files:**
- Modify: `CLI/cmux.swift`
- Modify: `Sources/Workspace.swift`
- Modify: `daemon/remote/README.md`
- Modify: `daemon/remote/cmd/cmuxd-remote/agent_launch.go`
- Modify: `daemon/remote/cmd/cmuxd-remote/tmux_compat.go`

- [ ] **Step 1: Inventory current remote-state surfaces**

Run:
```bash
rg -n '\\.cmux|\\.cmuxterm|cmuxd-remote-current|CMUX_CLAUDE_TEAMS_CMUX_BIN|CMUX_OMO_CMUX_BIN|CMUX_CLAUDE_HOOK_STATE_PATH|socket_addr|relay/' \
  CLI/cmux.swift \
  Sources/Workspace.swift \
  daemon/remote/README.md \
  daemon/remote/cmd/cmuxd-remote/agent_launch.go \
  daemon/remote/cmd/cmuxd-remote/tmux_compat.go
```
Expected: remote bootstrap paths, `.cmux` relay files, `.cmuxterm` helper state, and helper envs still use `cmux`.

- [ ] **Step 2: Rename remote bootstrap, relay, and helper-state identities**

Rename remote relay metadata, bootstrap install paths, versioned remote-daemon install/cache paths, `cmuxd-remote-current` symlink and wrapper paths, helper shim directories, `.cmuxterm` state files, and helper env names so remote automation no longer depends on `cmux`.

- [ ] **Step 3: Verify remote runtime cutover**

Run:
```bash
rg -n '\\.cmux|\\.cmuxterm|cmuxd-remote-current|CMUX_CLAUDE_TEAMS_CMUX_BIN|CMUX_OMO_CMUX_BIN|CMUX_CLAUDE_HOOK_STATE_PATH|socket_addr|relay/' \
  CLI/cmux.swift \
  Sources/Workspace.swift \
  daemon/remote/README.md \
  daemon/remote/cmd/cmuxd-remote/agent_launch.go \
  daemon/remote/cmd/cmuxd-remote/tmux_compat.go
```
Expected: remote relay/bootstrap/helper paths are renamed or explicitly carved out as legacy/historical only.

- [ ] **Step 4: Commit**

```bash
git add CLI/cmux.swift Sources/Workspace.swift daemon/remote/README.md daemon/remote/cmd/cmuxd-remote/agent_launch.go daemon/remote/cmd/cmuxd-remote/tmux_compat.go
git commit -m "runtime: rename remote relay bootstrap and helper state"
```

### Task 4: Rename Local Test Harness Defaults And Supported Runtime Compatibility Paths

**Files:**
- Modify: `tests/**/*.py`
- Modify: `tests_v2/**/*.py`

- [ ] **Step 1: Inventory current client/runtime defaults**

Run:
```bash
rg -n 'Application Support/cmux|/tmp/cmux|cmux-last-socket-path|CMUX_|com\\.cmuxterm' tests tests_v2
```
Expected: local client defaults still assume the `cmux` runtime contract.

- [ ] **Step 2: Rename client defaults and any explicitly supported compatibility aliases**

Update the Python automation harness so default socket discovery, bundle IDs, marker files, helper env names, support-directory paths, and any intentionally supported runtime aliases match the renamed `superghost` contract.

- [ ] **Step 3: Verify the renamed test harness contract**

Run:
```bash
rg -n 'Application Support/cmux|/tmp/cmux|cmux-last-socket-path|CMUX_|com\\.cmuxterm' tests tests_v2
```
Expected: active automation-test defaults, env names, paths, and bundle IDs use `superghost`.

- [ ] **Step 4: Commit**

```bash
git add tests tests_v2
git commit -m "runtime: rename local client defaults for superghost"
```

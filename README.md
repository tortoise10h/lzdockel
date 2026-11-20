# Lzdockel

Native Emacs interface for Docker management, inspired by [lazydocker](https://github.com/jesseduffield/lazydocker).

<img width="1620" height="1045" alt="file-60d2272275a8f0c8c45b32429621d8b9" src="https://github.com/user-attachments/assets/044dd227-0af6-4f0c-95f5-cecf3bcdcb47" />

<img width="1620" height="1045" alt="file-f15294c2d745d8befce3543d47594bae" src="https://github.com/user-attachments/assets/18725827-5359-4d1a-9153-5597a4a326c6" />



## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
  - [Keybindings](#keybindings)
- [Development](#development)
- [License](#license)

## Features

- **Unified Dashboard**: Single `*lzdockel-dashboard*` buffer displaying **Containers**, **Images**, **Volumes**, and **Networks** in navigable sections
- **Container Management**: List containers (running sorted first), restart, stop, delete (with confirmation), view logs, inspect, and attach via `eshell` (`docker exec -it <id> /bin/sh`)
- **Image, Volume & Network Management**: List, inspect, and delete (with confirmation) Docker images, volumes, and networks
- **Container Logs Viewer**: Dedicated `lzdockel-logs-mode` buffer with ANSI color rendering and automatic live streaming (`-f`) for running containers
- **Inspect Viewer**: Dedicated `lzdockel-inspect-mode` buffer displaying pretty-printed JSON from `docker <kind> inspect` for containers, images, volumes, and networks
- **Async Operations**: Non-blocking Docker CLI execution
- **Light & Dark Theme Support**: Adaptive faces for active sections, running/exited statuses, dimmed exited containers, and port mappings
- **Modal Editor Compatibility**: Override keymap via `emulation-mode-map-alists` so dashboard bindings take priority over modal editors such as Evil or Meow

## Requirements

- Emacs >= 28.1
- Docker CLI installed and accessible in `$PATH`

## Installation

### Manual

Clone the repository and add to your Emacs config:

```elisp
(add-to-list 'load-path "/path/to/lzdockel")
(require 'lzdockel)
```

### Using straight.el

```elisp
(use-package lzdockel
  :straight (:type git :host github :repo "yourusername/lzdockel")
  :bind ("C-c d" . lzdockel))
```

## Usage

| Command | Description |
|---------|-------------|
| `M-x lzdockel` | Open the Docker management dashboard |
| `M-x lzdockel-dashboard` | Open the unified dashboard buffer (`*lzdockel-dashboard*`) |

### Keybindings

#### Dashboard (`lzdockel-dashboard-mode`)

| Key | Action | Scope |
|-----|--------|-------|
| `TAB` | Move to next section | All sections |
| `S-TAB` / `<backtab>` | Move to previous section | All sections |
| `g` | Refresh all sections | All sections |
| `RET` | View container logs | Containers |
| `a` | Attach to container in `eshell` (with confirmation) | Containers |
| `r` | Restart container at point (with confirmation) | Containers |
| `s` | Stop container at point (with confirmation) | Containers |
| `i` | Inspect item at point (pretty-printed JSON) | All sections |
| `d` | Delete item at point (with confirmation) | All sections |
| `q` | Quit buffer | All sections |

#### Logs & Inspect Buffers (`lzdockel-logs-mode`, `lzdockel-inspect-mode`)

| Key | Action |
|-----|--------|
| `g` | Refresh output |
| `q` | Quit buffer |

## Development

### Quick Start

1. Edit a `lzdockel-*.el` file
2. Evaluate: `M-x eval-buffer`
3. Test: `M-x lzdockel`
4. Press `g` in the lzdockel buffer to refresh

### Byte-Compiling

```bash
emacs --batch -L . -f batch-byte-compile-if-not-done *.el
```

## License

This project is not part of GNU Emacs.

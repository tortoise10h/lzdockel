# Lzdockel

Native Emacs interface for Docker management, inspired by [lazydocker](https://github.com/jesseduffield/lazydocker).

## Features

- **Container Management**: List, restart, stop, remove containers, and view logs
- **Image Management**: List and delete Docker images
- **Async Operations**: Non-blocking Docker CLI execution
- **Status Coloring**: Running containers in green, exited in red
- **Tabulated Interface**: Built on Emacs `tabulated-list-mode` with sortable columns

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
| `M-x lzdockel` | Open the Docker management interface (container view) |
| `M-x lzdockel-containers` | List Docker containers |
| `M-x lzdockel-images` | List Docker images |

### Keybindings

#### Container View

| Key | Action |
|-----|--------|
| `g` | Refresh list |
| `R` | Restart container at point |
| `S` | Stop container at point |
| `D` | Remove container at point (with confirmation) |
| `RET` | View container logs |
| `i` | Switch to image view |
| `q` | Quit buffer |

#### Image View

| Key | Action |
|-----|--------|
| `g` | Refresh list |
| `D` | Delete image at point (with confirmation) |
| `C` | Switch to container view |
| `q` | Quit buffer |

## Architecture

```
lzdockel/
├── lzdockel.el               # Entry point + autoloads
├── lzdockel-core.el          # Docker CLI, JSON parsing, helpers
├── lzdockel-container.el     # Container list mode + actions
├── lzdockel-image.el         # Image list mode + actions
├── lzdockel-faces.el         # Face definitions
└── docs/
    ├── plans/mvp-1.md        # MVP 1 design plan
    └── developing.md         # Development guide
```

## Development

See [docs/developing.md](docs/developing.md) for the development workflow, testing checklist, and debugging tips.

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

# Tide

<p align="center">
  <img src="https://raw.githubusercontent.com/arungeorgesaji/tide/main/tide.gif" width="600" alt="Tide Demo">
</p>

A Vim-like modal text editor written in Nim using the illwill terminal library.

## Features

- **Modal editing** (Normal, Insert, Command, Search modes)
- **Syntax highlighting** with language detection
- **Customizable themes**
- **Undo/Redo support**
- **Line numbering** (toggleable)
- **Vim-style commands** and navigation
- **Yank/paste operations**

## Keybindings

### Normal Mode

#### Navigation
- `h` / `←` - Move cursor left
- `l` / `→` - Move cursor right
- `j` / `↓` - Move cursor down
- `k` / `↑` - Move cursor up
- `0` - Move to start of line
- `$` - Move to end of line
- `g` - Go to first line
- `G` - Go to last line
- `w` - Move forward one word
- `b` - Move backward one word
- `e` - Move to end of word
- `Home` - Move to start of line
- `End` - Move to end of line
- `PageUp` - Scroll up one page
- `PageDown` - Scroll down one page

#### Editing
- `i` - Enter insert mode at cursor
- `a` - Enter insert mode after cursor
- `A` - Enter insert mode at end of line
- `o` - Open new line below and enter insert mode
- `O` - Open new line above and enter insert mode
- `x` - Delete character under cursor
- `X` - Delete character before cursor
- `dd` - Delete current line
- `yy` - Yank (copy) current line
- `p` - Paste below current line
- `P` - Paste above current line
- `u` - Undo last change

#### Other
- `n` - Toggle line numbers
- `:` - Enter command mode
- `Esc` - Cancel pending operation
- `q` - Quit editor

#### Count Prefix
Many commands support a count prefix:
- `5j` - Move down 5 lines
- `3w` - Move forward 3 words
- `10k` - Move up 10 lines

### Insert Mode

- `Esc` - Return to normal mode
- `Enter` - Insert new line
- `Backspace` - Delete character before cursor
- `Delete` - Delete character under cursor
- Arrow keys, `Home`, `End`, `PageUp`, `PageDown` - Navigate while in insert mode
- Any printable character (space through `~`) - Insert character

### Command Mode

Commands are entered after pressing `:` in normal mode.

#### File Operations
- `:w` - Write (save) file
- `:q` - Quit editor
- `:q!` - Force quit without saving
- `:wq` or `:x` - Write and quit

#### Display Options
- `:set number` or `:set nu` - Show line numbers
- `:set nonumber` or `:set nonu` - Hide line numbers

#### Syntax Highlighting
- `:syntax on` - Enable syntax highlighting (auto-detects language)
- `:syntax off` - Disable syntax highlighting

#### Themes
- `:theme <name>` - Switch to specified theme
- `:themes` - List available themes

#### Navigation
- Arrow keys, `Home`, `End`, `PageUp`, `PageDown` work in command mode
- `Backspace` - Delete character in command buffer
- `Esc` - Cancel and return to normal mode
- `Enter` - Execute command

## Themes

Tide supports customizable color themes. Use `:themes` to list available themes and `:theme <name>` to switch themes.

## Syntax Highlighting

Syntax highlighting is automatically detected based on the file extension when you enable it with `:syntax on`. Supported languages depend on your configuration.

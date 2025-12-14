# Tide

<p align="center">
  <img src="https://raw.githubusercontent.com/arungeorgesaji/tide/main/tide.gif" width="600" alt="Tide Demo">
</p>

A Vim-like modal text editor written in Nim using the illwill terminal library.

## Installation 

You can install Tide using Nim's package manager, Nimble. Run the following command:

```bash
nimble install tide 
```

## Features

- **Modal editing** (Normal, Insert, Command, Diff)
- **Search functionality** with forward/backward navigation
- **Syntax highlighting** with language detection
- **Minimap**
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

#### Search
- `/` - Enter search mode (search forward)
- `?` - Enter search mode (search backward)
- `n` - Repeat search in the same direction
- `N` - Repeat search in the opposite direction

#### Other
- `L` - Toggle line numbers
- `:` - Enter command mode
- `Esc` - Cancel pending operation
- `q` - Quit editor

#### Count Prefix
Many commands support a count prefix:
- `5j` - Move down 5 lines
- `3w` - Move forward 3 words
- `10k` - Move up 10 lines

### Search Mode
Search mode is entered by pressing `/` in normal mode or `?` for backward search.

- Type your search pattern
- `Enter` - Execute search and jump to first match
- `Backspace` - Delete character in search buffer
- `Esc` - Cancel search and return to normal mode

After executing a search:
- `n` - Find next occurrence (wraps around to beginning)
- `N` - Find previous occurrence (wraps around to end)

The status bar will display the position of found matches (e.g., "Pattern found at 42:15").

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

#### Diff Mode 
- `:diff <file1> <file2>` - Open two files in diff mode

#### Display Options
- `:set number` or `:set nu` - Show line numbers
- `:set nonumber` or `:set nonu` - Hide line numbers

#### Syntax Highlighting
- `:syntax on` - Enable syntax highlighting (auto-detects language)
- `:syntax off` - Disable syntax highlighting

#### Minimap 

- `:minimap on` - Enable minimap 
- `:minimap off` - Disable minimap

#### Themes
- `:theme <name>` - Switch to specified theme
- `:themes` - Menu to list and select themes with preview

#### Navigation
- Arrow keys, `Home`, `End`, `PageUp`, `PageDown` work in command mode
- `Backspace` - Delete character in command buffer
- `Esc` - Cancel and return to normal mode
- `Enter` - Execute command

## Themes

Tide supports customizable color themes. Use `:themes` to list available themes and `:theme <name>` to switch themes.

## Syntax Highlighting

Syntax highlighting is automatically detected based on the file extension when you enable it with `:syntax on`. Supported languages depend on your configuration.

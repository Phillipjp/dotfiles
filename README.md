# dotfiles

## Usage

### Linking
- Add files that are in this directory to the `FILES` or `CONFIG_DIRS` lists in `bootstrap.sh`
- Run `bootstrap.sh` 

### Homebrew

- `install` installs stuff from Brewfile and Brewfile.XXX where XXX is the specific name of your machine (lets me keep machine specific stuff in a separate file if I wanna)
- `check` tells you whether there’s anything in the Brewfile which you don’t have installed
- `clean` tells you whether you have installed stuff manually that isn’t in the Brewfile, and clean -f uninstalls things you’ve installed manually


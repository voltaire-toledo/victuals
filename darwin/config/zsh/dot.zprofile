
eval "$(/opt/homebrew/bin/brew shellenv zsh)"

# Setting PATH for Python 3.14
# The original version is saved in .zprofile.pysave
export PATH="/Library/Frameworks/Python.framework/Versions/3.14/bin:${PATH}"

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init.zsh 2>/dev/null || :

# Added by Antigravity CLI installer
export PATH="/Users/me/.local/bin:$PATH"

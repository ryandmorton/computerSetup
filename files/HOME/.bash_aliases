### Ryan Morton's computerSetup.git version of ~/.bash_aliases

# SHELL PROMPT
function parse_git_dirty {
    [[ $(git status 2> /dev/null | grep "^nothing to commit") ]] || echo "*"
}
function parse_git_branch {
  git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e "s/* \(.*\)/[\1$(parse_git_dirty)]/"
}
export PS1='\[\033[01;32m\]\u@\h\[\033[01;34m\] \w\[\033[31m\] $(parse_git_branch)\[\033[01;34m\]$\[\033[00m\] '

### ALIASES
alias sbrc="source ~/.bashrc"

alias ll='ls -l'
alias lla='ls -al'
alias upls='cd ..; ls'
alias upll='cd ..; ll'
alias upll='cd ..; ll'
alias md=mkdir
alias rd=rmdir
alias cls=clear
alias grep="grep --color=auto -I --exclude-dir=\".svn\""
alias rgrep="rgrep -n --color=auto -I --exclude-dir=\".svn\""

## GIT ALIASES
alias gitk='gitk --all &'
alias gitg='gitg --all &'
alias gitup='git remote update'
alias gitst='git status'
alias gd='git diff --color'
alias gcp='git cherry-pick'
alias grv='git remote -v'
alias grp='git remote prune'
alias grpo='git remote prune origin'
alias gfo='git fetch origin'

function git_commit_and_steal_message() {
    git commit -m "`git log --format=%B -n 1 $1`" && git commit --amend
}

function git_merge_and_steal_message() {
    git merge $1 -m "`git log --format=%B -n 1 $2`" && git commit --amend
}

function git_merge_noff_and_steal_message() {
    git merge --no-ff $1 -m "`git log --format=%B -n 1 $2`" && git commit --amend
}

### MAKE ALIASES
alias mc="make clean"
alias mcm="make clean; make"
alias mcmc="make clean && make && clear"
alias cmcm="clear; make clean; make"
alias ac="ant clean"
alias aca="ant clean; ant"
alias caca="clear; ant clean; ant"

alias cme="clear; make && echo"
alias cae="clear; ant && echo"

### FUNCTIONS
function mdcd {
    mkdir -p $1 && cd $1
}

# Include personalized aliases, if they exist
if [ -f "$HOME/.bash_aliases.personal" ]; then
    source "$HOME/.bash_personal_aliases"
fi

date

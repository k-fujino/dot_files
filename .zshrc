
# users generic .zshrc file for zsh(1)

## Environment variable configuration
#
# LANG
#
export LANG=ja_JP.UTF-8
case ${UID} in
0)
    LANG=C
        ;;
        esac


## Default shell configuration
#
# set prompt
#
autoload colors
colors
case ${UID} in
0)
    PROMPT="%{${fg[cyan]}%}$(echo ${HOST%%.*} | tr '[a-z]' '[A-Z]') %B%{${fg[red]}%}%/#%{${reset_color}%}%b "
    PROMPT2="%B%{${fg[red]}%}%_#%{${reset_color}%}%b "

    ;;
*)
    PROMPT="%{${fg[green]}%}%/%%%{${reset_color}%} "
    PROMPT2="%{${fg[red]}%}%_%%%{${reset_color}%} "
    [ -n "${REMOTEHOST}${SSH_CONNECTION}" ] && 
    PROMPT="%{${fg[cyan]}%}$(echo ${HOST%%.*} | tr '[a-z]' '[A-Z]') ${PROMPT}"

    ;;
esac



# auto-jump  : zsh plug in setting
# j tabで過去に行ったディレクトリを選べる
[[ -s /home/k-fuji/.autojump/etc/profile.d/autojump.sh ]] && source /home/k-fuji/.autojump/etc/profile.d/autojump.sh




# auto change directory
# ディレクトリ名を入れるだけでcdできる
setopt auto_cd

# auto directory pushd that you can get dirs list by cd -[tab]
#
setopt auto_pushd

# command correct edition before each completion attempt
#
setopt correct

# compacked complete list display
#
setopt list_packed

# no remove postfix slash of command line
#
setopt noautoremoveslash

# no beep sound when complete list displayed
#
setopt nolistbeep
setopt nonomatch


## Keybind configuration
# emacs mode ###
# emacs like keybind (e.x. Ctrl-a gets to line head and Ctrl-e gets
#   to end) and something additions
#
bindkey -e
bindkey "^[[1~" beginning-of-line # Home gets to line head
bindkey "^[[4~" end-of-line # End gets to line end
bindkey "^[[3~" delete-char # Del

# historical backward/forward search with linehead string binded to ^P/^N
#
autoload history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "^p" history-beginning-search-backward-end
bindkey "^n" history-beginning-search-forward-end
bindkey "\\ep" history-beginning-search-backward-end
bindkey "\\en" history-beginning-search-forward-end

# reverse menu completion binded to Shift-Tab
# 補完候補を逆戻りするように
bindkey "\e[Z" reverse-menu-complete


## Command history configuration
#
HISTFILE=${HOME}/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt hist_ignore_dups     # ignore duplication command history list
setopt share_history        # share command history data


## Completion configuration
#
fpath=(${HOME}/zsh/functions/*(N-/) ${fpath})
# zsh-completions用
fpath=(~/download/zsh-completions/src $fpath)
# fpathの後に記述
autoload -U compinit && compinit -u

#autoload -Uz cdls


## zsh editor
#
autoload zed


## Prediction configuration
#
#autoload predict-on
#predict-off

export LSCOLORS=gxfxcxdxbxegedabagacad

## Alias configuration
#
# expand aliases before completing
#
setopt complete_aliases     # aliased ls needs if file/dir completions work

alias where="command -v"

case "${OSTYPE}" in
freebsd*|darwin*)
    alias ls="ls -G -w -tr"

    ;;
linux*)
    alias ls="ls --color -tr"

    ;;

esac

alias l="ls -atr --color"
alias la="ls -atr"
alias ll="ls -ltr"
alias ..="cd ../"
alias ...="cd ../../"
alias ....="cd ../../../"
alias v="nvim"
alias c="cd"
alias g="git"
alias gp="git grep"
alias fp="find ./|grep"
alias hg="history 1|grep"
alias lg="ls -a|grep"
alias tmux="tmux -2"
alias tg="tig"
#alias ctags="`brew --prefix`/bin/ctags"

alias df="df -h"
alias su="su -l"
alias diff="colordiff -u"

alias ac="/home/k-fuji/development/middleware/account_mgr"
alias si="/home/k-fuji/development/site_mgr"
alias cl="/home/k-fuji/development/client_mgr"
alias sn="/home/k-fuji/development/signup_api"

[[ -s ${HOME}/.rvm/scripts/rvm ]] && source ~/.rvm/scripts/rvm

[[ -s ${HOME}/.rbenv ]] && export PATH="$HOME/.rbenv/bin:$PATH" 
[[ -s ${HOME}/.rbenv ]] && eval "$(rbenv init - zsh)"


## load user .zshrc configuration file
#
[ -f ${HOME}/.zshrc.mine ] && source ${HOME}/.zshrc.mine
export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting
export PATH=/opt/rh/qt48/root/usr/lib64/qt4/bin/${PATH:+:${PATH}}
export PATH=/usr/local/Trolltech/Qt-4.7.4/bin:$PATH
export PATH="$HOME/bin/bin:$PATH"
export PATH="$PATH:/usr/local/go/bin"
export PATH="$PATH:$HOME/go/bin"

export RAILS_ENV="development"
#export RAILS_ENV="test"

# export OBJECT_STORAGE_ACCESS_KEY_ID="xxxx"
# export OBJECT_STORAGE_SECRET_ACCESS_KEY="yyyy"

# rspecのRails.application.routes.default_url_options用 
export OBJECT_STORAGE_BUCKET="minio1"
export OBJECT_STORAGE_RETURN_URL="https://127.0.0.1:9000/v2/profile_image"
export OBJECT_STORAGE_ENDPOINT="http://127.0.0.1:9000"      # ローカルのminioのuri
export OBJECT_STORAGE_HOST="localhost:9001"

export OBJECT_STORAGE_ACCESS_KEY_ID="xxx"  # 各自のminioのACCESS_KEY_IDに直す
export OBJECT_STORAGE_SECRET_ACCESS_KEY="yyy"   # 各自のminioのSECRET_ACCESS_KEYに直す
export OBJECT_STORAGE_MOUNT_PATH="/mnt/store"               # catalinaは/mnt/storeを作れない為,/tmp/store等に変更

export GOPATH="$HOME/go"

export GIT_EDITOR=nvim


# dockerのaccount_mgr用
[[ -s ${HOME}/development/middleware/account_mgr/.env ]] && source ~/development/middleware/account_mgr/.env


# python用
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
# eval "$(pyenv init -)"

# neovim用
[[ -s ${HOME}/.config ]] && export XDG_CONFIG_HOME=~/.config

# docker mysqlにつなぐ為
# export MYSQL_HOST="127.0.0.1"  # dockerのMySQL用

# site mgr用
 export MYSQL_USERNAME="root"
 export MYSQL_PASSWORD="root"

# acl用
 export AR_CONNECTION_POOL_SIZE=5

setopt prompt_subst
autoload -Uz vcs_info
zstyle ':vcs_info:*' actionformats \
    '%F{5}(%f%s%F{5})%F{3}-%F{5}[%F{2}%b%F{3}|%F{1}%a%F{5}]%f '
zstyle ':vcs_info:*' formats       \
    '%F{5}(%f%s%F{5})%F{3}-%F{5}[%F{2}%b%F{5}]%f '
zstyle ':vcs_info:(sv[nk]|bzr):*' branchformat '%b%F{1}:%F{3}%r'

zstyle ':vcs_info:*' enable git cvs svn


# or use pre_cmd, see man zshcontrib
vcs_info_wrapper() {
  vcs_info
  if [ -n "$vcs_info_msg_0_" ]; then
    echo "%{$fg[grey]%}${vcs_info_msg_0_}%{$reset_color%}$del"
  fi
}

function gitcheckout() {
  git checkout $1;
  (cd ~/development/account_mgr/; ctags --langmap=RUBY:.rb --exclude="*.js"  --exclude=".git*" -R . &> /dev/null )&
}


RPROMPT=$'$(vcs_info_wrapper)'


if [ -e "$HOME/.nodenv" ]
then
    export NODENV_ROOT="$HOME/.nodenv"
    export PATH="$NODENV_ROOT/bin:$PATH"
    if command -v nodenv 1>/dev/null 2>&1
    then
        eval "$(nodenv init -)"
    fi
fi

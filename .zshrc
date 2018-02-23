
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
    SPROMPT="%B%{${fg[red]}%}%r is correct? [n,y,a,e]:%{${reset_color}%}%b "

    ;;
*)
    PROMPT="%{${fg[green]}%}%/%%%{${reset_color}%} "
    PROMPT2="%{${fg[red]}%}%_%%%{${reset_color}%} "
    SPROMPT="%{${fg[red]}%}%r is correct? [n,y,a,e]:%{${reset_color}%} "
    [ -n "${REMOTEHOST}${SSH_CONNECTION}" ] && 
    PROMPT="%{${fg[cyan]}%}$(echo ${HOST%%.*} | tr '[a-z]' '[A-Z]') ${PROMPT}"

    ;;
esac

# auto change directory
#
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
alias j="jobs -l"

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
alias v="vim"
alias c="cd"
alias g="git"
alias gp="git grep"
alias fp="find ./|grep"
alias hg="history 1|grep"
alias lg="ls -a|grep"
alias ig="sed 's/\\\040/ /g' ~/.mysql_history|grep"
#alias ctags="`brew --prefix`/bin/ctags"

alias du="du -h"
alias df="df -h"

alias su="su -l"

alias pt="/home/vagrant/piip_task_v2"
alias envr="cd env/piip_backend/ruby-2.4/"

[[ -s ${HOME}/.rvm/scripts/rvm ]] && source ~/.rvm/scripts/rvm

[[ -s ${HOME}/.rbenv ]] && export PATH="$HOME/.rbenv/bin:$PATH" 
[[ -s ${HOME}/.rbenv ]] && eval "$(rbenv init - zsh)"


## load user .zshrc configuration file
#
[ -f ${HOME}/.zshrc.mine ] && source ${HOME}/.zshrc.mine
export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting
export PATH=/opt/rh/qt48/root/usr/lib64/qt4/bin/${PATH:+:${PATH}}
export PATH=/usr/local/Trolltech/Qt-4.7.4/bin:$PATH

export RAILS_ENV="development"
#export RAILS_ENV="test"

export GIT_EDITOR=vim






setopt prompt_subst
autoload -Uz vcs_info
zstyle ':vcs_info:*' actionformats \
    '%F{5}(%f%s%F{5})%F{3}-%F{5}[%F{2}%b%F{3}|%F{1}%a%F{5}]%f '
zstyle ':vcs_info:*' formats       \
    '%F{5}(%f%s%F{5})%F{3}-%F{5}[%F{2}%b%F{5}]%f '
zstyle ':vcs_info:(sv[nk]|bzr):*' branchformat '%b%F{1}:%F{3}%r'

zstyle ':vcs_info:*' enable git cvs svn

function gl() {
   local str opt
   if [ $# != 0 ]; then
       for i in $*; do
           str="$str+$i"
       done
       str=`echo $str | sed 's/^\+//'`
       opt='search?num=50&hl=ja&lr=lang_ja'
       opt="${opt}&q=${str}"
    fi
    w3m http://www.google.co.jp/$opt
}

# or use pre_cmd, see man zshcontrib
vcs_info_wrapper() {
  vcs_info
  if [ -n "$vcs_info_msg_0_" ]; then
    echo "%{$fg[grey]%}${vcs_info_msg_0_}%{$reset_color%}$del"
  fi
}
RPROMPT=$'$(vcs_info_wrapper)'







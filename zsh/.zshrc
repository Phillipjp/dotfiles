 
# Executes commands at the start of an interactive session.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# Customize to your needs...

alias cdt='cd ~/Dev/work/cdt'
alias gpl='git pull'
alias gp='git push'
alias git-master='git checkout master'
alias git-pr='gh pr create -f'
alias "aws-which"="env | grep AWS | sort"
alias "aws-clear-variables"="for i in \$(aws-which | cut -d= -f1,1 | paste -); do unset \$i; done"
# alias aws-cdt-dev="aws-developer-role ACCOUNT_ID  ROLE PROFILE"
# alias aws-cdt-prd="aws-developer-role ACCOUNT_ID  iROLE PROFILE"
alias aws-cdt-dev="aws --profile=cd-dev"
alias aws-cdt-prd="aws --profile=cd-prd"
alias my-stuff="cd ~/Dev/my-stuff"


# SBT                               {{{2
# ======================================

export SBT_OPTS=-Xmx2G
alias sbt-no-test='sbt "set test in assembly := {}"'

# COLOURS
#======================================
export COLOR_RED='\033[0;31m'
export COLOR_GREEN='\033[0;32m'
export COLOR_YELLOW='\033[0;33m'
export COLOR_NONE='\033[0m'
export COLOR_CLEAR_LINE='\r\033[K'

# General file helpers              {{{2
# ======================================

function full-path() {
    declare fnam=$1

    if [ -d "$fnam" ]; then
        (cd "$fnam"; pwd)
    elif [ -f "$fnam" ]; then
        if [[ $fnam == */* ]]; then
            echo "$(cd "${1%/*}"; pwd)/${1##*/}"
        else
            echo "$(pwd)/$fnam"
        fi
    fi
}

# Tar a file
function tarf() {
    declare fnam=$1
    tar -zcvf "${fnam%/}".tar.gz "$1"
}

# Untar a file
function untarf() {
    declare fnam=$1
    tar -zxvf "$1"
}

# Grep zipped logs
function zgrep-logs() {
    declare pattern=$1
    zgrep -iR "${pattern}" . --context 10
}

# Run gunzip on all files under the current directory
function gunzip-logs() {
    while read -r line; do
        echo "$line"
        gunzip "$line"
    done
}

# Colorize output
# cat my-log.txt | colorize red ERROR
function colorize() {
    if [[ $# -ne 2 ]] ; then
        echo 'Usage: colorize COLOR PATTERN'
        return 1
    fi

    color=$1
    pattern=$2

    awk -v color=$color -v pattern=$pattern -f ~/Dev/my-stuff/shell-utils/colorize
}
compdef '_alternative "arguments:custom arg:(red green yellow blue magenta cyan)"' colorize

# e.g.: foreachfolder 'git branch | grep -v grep | grep -v master >/dev/null && echo $i'
function foreachfolder () 
{ 
  for i in $(ls -d -- */);
  do
    pushd $i > /dev/null;
    eval $1;
    popd > /dev/null;
  done
}

# SSH tunneling                     {{{2
# ======================================

function tunnel-open() {
    if [[ $# -ne 4 ]] ; then
        echo 'Usage: tunnel-open LOCALPORT HOST HOSTPORT SERVER'
        return -1
    fi

    localPort=$1
    host=$2
    hostPort=$3
    server=$4
    connectionFile=~/.ssh-tunnel-localhost:${localPort}===${host:0:20}:${hostPort}

    echo "Opening tunnel localhost:${localPort} -> ${server} -> ${host}:${hostPort}"
    ssh -AL ${localPort}:${host}:${hostPort} ${server} -f -o ServerAliveInterval=30 -N -M -S ${connectionFile} || { echo "Failed to open tunnel"; return -1; }
    echo "Tunnel open ${connectionFile}"
}
compdef _hosts tunnel-open

function tunnel-list() {
    ls ~/.ssh-tunnel-*
}

function tunnel-check() {
    if [[ $# -ne 1 ]] ; then
        echo 'Usage: tunnel-check CONNECTIONFILE'
        return -1
    fi
    connectionFile=$1

    [[ ${connectionFile} =~ .ssh-tunnel-localhost:(.*)===(.*):(.*) ]]

    localPort=${BASH_REMATCH[1]}
    host=${BASH_REMATCH[2]}
    hostPort=${BASH_REMATCH[3]}

    echo "Checking tunnel localhost:${localPort} -> ${host}:${hostPort}"
    ssh -S ${connectionFile} -O check ${host}
}
compdef '_files -g "~/.ssh-tunnel-*"' tunnel-check

function tunnel-close() {
    if [[ $# -ne 1 ]] ; then
        echo 'Usage: tunnel-close CONNECTIONFILE'
        return -1
    fi

    connectionFile=$1

    [[ ${connectionFile} =~ .ssh-tunnel-localhost:(.*)===(.*):(.*) ]]

    localPort=${BASH_REMATCH[1]}
    host=${BASH_REMATCH[2]}
    hostPort=${BASH_REMATCH[3]}

    echo "Closing tunnel localhost:${localPort} -> ${host}:${hostPort}"
    ssh -S ${connectionFile} -O exit ${host}
}
compdef '_files -g "~/.ssh-tunnel-*"' tunnel-close

function tunnel-close-all() {
    for connectionFile in ~/.ssh-tunnel-*
    do
        tunnel-close $connectionFile
    done
}

# AWS                               {{{2
# ======================================

function sshx-tagged-aws-machines() {
    if [[ $# -ne 3 ]] ; then
        echo 'Usage: sshx-tagged-aws-machines PROFILE REGION TAG'
        return 1
    fi

    declare profile=$1 region=$2 tag=$3

    echo 'Finding machines'
    machines=($(aws --profile $profile ec2 describe-instances --region $region | jq --raw-output '.Reservations[].Instances[]? | select(.State.Name=="running") | select(.Tags[] | select((.Key=="Name") and (.Value=="'$tag'"))) | .NetworkInterfaces[].PrivateIpAddresses[].PrivateIpAddress'))

    echo "Opening SSH to $machines[*]"
    i2cssh $machines[*]
}

function aws-instance-info() {
    if [[ $# -ne 3 ]] ; then
        echo 'Usage: aws-instance-info PROFILE REGION TAG'
        return 1
    fi

    local profile=$1
    local region=$2
    local tag=$3

    aws --profile $profile ec2 describe-instances --region $region | jq --raw-output '.Reservations[].Instances[]? | select(.Tags[].Value=="'$tag'") | select(.State.Name=="running")'
}
compdef _aws-tag aws-instance-info

# List the values of tagged AWS instances
function aws-tag-values() {
    if [[ $# -ne 3 ]] ; then
        echo 'Usage: aws-tag-values PROFILE REGION KEY'
        return 1
    fi

    local profile=$1
    local region=$2
    local key=$3
    
    aws --profile $profile ec2 describe-instances --region $region | jq --raw-output '.Reservations[].Instances[].Tags[]? | select(.Key=="'$key'") | .Value' | sort | uniq
}
compdef _aws-tag aws-tag-values

# List the IPs for tagged AWS instances
function aws-instance-ips() {
    if [[ $# -ne 3 ]] ; then
        echo 'Usage: aws-instance-ips PROFILE REGION TAG'
        return 1
    fi

    local profile=$1
    local region=$2
    local tag=$3

    aws --profile $profile ec2 describe-instances --region $region | jq --raw-output '.Reservations[].Instances[] | select(.Tags[]?.Value=="'$tag'") | select(.State.Name=="running") | .PrivateIpAddress' | sort | uniq
}
compdef _aws-tag aws-instance-ips

function aws-all-instance-ips() {
    if [[ $# -ne 2 ]] ; then
        echo 'Usage: aws-all-instance-ips PROFILE REGION'
        return 1
    fi

    local profile=$1
    local region=$2

    aws --profile $profile ec2 describe-instances --region $region | jq --raw-output '["Name", "IP address", "Instance ID", "Instance type", "AMI ID", "Launch time", "Monitoring"], (.Reservations[].Instances[]? | select(.State.Name=="running") | [ (.Tags[]? | (select(.Key=="Name")).Value) // "-", .NetworkInterfaces[].PrivateIpAddresses[].PrivateIpAddress, .InstanceId, .InstanceType, .ImageId, .LaunchTime, .Monitoring.State]) | @csv' | sort | column -t -s "," | sed 's/\"//g'
}
compdef _aws-profile-region aws-all-instance-ips

# SSH into tagged AWS instances
function aws-ssh() {
    if [[ $# -ne 3 ]] ; then
        echo 'Usage: aws-instance-ips PROFILE REGION TAG'
        return 1
    fi

    local profile=$1
    local region=$2
    local tag=$3

    local ip=$(aws-instance-ips $profile $region $tag)
    ssh $ip
}
compdef _aws-tag aws-ssh

# Display AWS instance limits
function aws-ec2-instance-limits() {
    aws service-quotas list-service-quotas --service-code ec2 | jq --raw-output '(.Quotas[] | ([.QuotaName, .Value])) | @csv' | column -t -s "," | sed 's/\"//g'
}

# Copy my base machine config to a remote host
function scp-skeleton-config() {
    if [[ $# -ne 1 ]] ; then
        echo 'Usage: scp-skeleton-config HOST'
        exit -1
    fi

    pushd ~/Dev/my-stuff/dotfiles/skeleton-config || exit 1
    echo "Uploading config to $1"
    for file in $(find . \! -name .); do
        scp $file $1:$file
    done
    popd || exit 1
}
compdef _ssh scp-skeleton-config=ssh

function aws-switch-role() {
    declare roleARN=$1 profile=$2
    export username=phillip.perks@itv.com
    # 
    LOGIN_OUTPUT="$(aws-adfs login --adfs-host federation.reedelsevier.com --region us-east-1 --role-arn $roleARN --env --profile $profile --printenv | grep export)"
    AWS_ENV="$(echo $LOGIN_OUTPUT | grep export)"
    eval $AWS_ENV
    export AWS_REGION=us-east-1
    aws-which
}

function aws-developer-role() {
    declare accountId=$1 role=$2 profile=$3
    aws-switch-role "arn:aws:iam::${accountId}:role/${role}" "${profile}"
}

function aws-datapipeline-record-loader-versions() {
    while IFS=, read -rA x 
    do
        pipelineId=${x[@]:0:1}
        pipelineName=${x[@]:1:1}
        aws datapipeline get-pipeline-definition --pipeline-id $pipelineId | jq --raw-output "[\"$pipelineName\", (.values[\"my_record_loader_version\"])] | @csv"
    done < <(aws datapipeline list-pipelines | jq --raw-output '.pipelineIdList[] | [.id, .name] | @csv' | sed 's/"//g') | sed 's/"//g' | column -t -s '','' 
}

# Git                               {{{2
# ======================================

function migrate(){
    SEARCH='gitlab.et-scm.com:recs\/'
    REPLACE='github.com:elsevier-research\/kd-'
    GITHUBURL=$(git remote get-url origin | grep "$SEARCH" | sed "s/$SEARCH/$REPLACE/g")
    [ -z "$GITHUBURL" ] || git remote set-url origin "$GITHUBURL"
}

# For each directory within the current directory, if the directory is a Git
# repository then execute the supplied function 
function git-for-each-repo() {
    setopt local_options glob_dots
    for fnam in *; do
        if [[ -d $fnam ]]; then
            pushd "$fnam" > /dev/null || return 1
            if git rev-parse --git-dir > /dev/null 2>&1; then
                "$@"
            fi
            popd > /dev/null || return 1
        fi
    done
}

# For each directory within the current directory, pull the repo
function git-repos-pull() (
    pull-repo() {
        echo "Pulling $(basename $PWD)"
        git pull -r --autostash
        echo
    }

    git-for-each-repo pull-repo 
    git-repos-status
)

# For each directory within the current directory, fetch the repo
function git-repos-fetch() (
    local args=$*

    fetch-repo() {
        echo "Fetching $(basename $PWD)"
        git fetch ${args}
        echo
    }

    git-for-each-repo fetch-repo 
    git-repos-status
)

# For each directory within the current directory, display the status line for the repo
# Requires Prezto prompt to work
function git-repos-status-detailed() (
    display-status() {
        git-info
        print -P "$(basename $PWD) ${git_info[status]}"
    }

    prompt-help
    git-for-each-repo display-status | column -t -s ' '
)

# Parse Git status into a Zsh associative array
function git-parse-repo-status() {
    local aheadAndBehind
    local ahead=0
    local behind=0
    local added=0
    local modified=0
    local deleted=0
    local renamed=0
    local untracked=0
    local stashed=0

    branch=$(git rev-parse --abbrev-ref HEAD 2> /dev/null)
    ([[ $? -ne 0 ]] || [[ -z "$branch" ]]) && branch="unknown"

    aheadAndBehind=$(git status --porcelain=v1 --branch | perl -ne '/\[(.+)\]/ && print $1' )
    ahead=$(echo $aheadAndBehind | perl -ne '/ahead (\d+)/ && print $1' )
    [[ -z "$ahead" ]] && ahead=0
    behind=$(echo $aheadAndBehind | perl -ne '/behind (\d+)/ && print $1' )
    [[ -z "$behind" ]] && behind=0

    # See https://git-scm.com/docs/git-status for output format
    while read -r line; do
      # echo "$line"
      echo "$line" | gsed -r '/^[A][MD]? .*/!{q1}'   > /dev/null && (( added++ ))
      echo "$line" | gsed -r '/^[M][MD]? .*/!{q1}'   > /dev/null && (( modified++ ))
      echo "$line" | gsed -r '/^[D][RCDU]? .*/!{q1}' > /dev/null && (( deleted++ ))
      echo "$line" | gsed -r '/^[R][MD]? .*/!{q1}'   > /dev/null && (( renamed++ ))
      echo "$line" | gsed -r '/^[\?][\?] .*/!{q1}'   > /dev/null && (( untracked++ ))
    done < <(git status --porcelain)

    stashed=$(git stash list | wc -l)

    unset gitRepoStatus
    typeset -gA gitRepoStatus
    gitRepoStatus[branch]=$branch
    gitRepoStatus[ahead]=$ahead
    gitRepoStatus[behind]=$behind
    gitRepoStatus[added]=$added
    gitRepoStatus[modified]=$modified
    gitRepoStatus[deleted]=$deleted
    gitRepoStatus[renamed]=$renamed
    gitRepoStatus[untracked]=$untracked
    gitRepoStatus[stashed]=$stashed
}

function git-repos-status() (
    display-status() {
        git-parse-repo-status
        repo=$(basename $PWD) 

        local branch="${COLOR_GREEN}main${COLOR_NONE}"
        if [[ ! $gitRepoStatus[branch] == "main" ]]; then
            branch="${COLOR_RED}$gitRepoStatus[branch]${COLOR_NONE}"
        fi

        local sync="${COLOR_GREEN}in-sync${COLOR_NONE}"
        if (( $gitRepoStatus[ahead] > 0 )) && (( $gitRepoStatus[behind] > 0 )); then
            sync="${COLOR_RED}ahead/behind${COLOR_NONE}"
        elif (( $gitRepoStatus[ahead] > 0 )); then
            sync="${COLOR_RED}ahead${COLOR_NONE}"
        elif (( $gitRepoStatus[behind] > 0 )); then
            sync="${COLOR_RED}behind${COLOR_NONE}"
        fi

        local dirty="${COLOR_GREEN}clean${COLOR_NONE}"
        (($gitRepoStatus[added] + $gitRepoStatus[modified] + $gitRepoStatus[deleted] + $gitRepoStatus[renamed] > 0)) && dirty="${COLOR_RED}dirty${COLOR_NONE}"

        echo "${branch},${sync},${dirty},${repo}"
    }

    git-for-each-repo display-status | column -t -s ','
)

# For each directory within the current directory, display whether the
# directory contains unmerged branches locally
function git-repos-unmerged-branches() (
    display-unmerged-branches() {
        unmergedBranches=$(git branch --no-merged main) 
        if [[ $unmergedBranches = *[![:space:]]* ]]; then
            echo "$fnam"
            git branch --no-merged main
            echo
        fi
    }

    git-for-each-repo display-unmerged-branches
)

# For each directory within the current directory, display whether the
# directory contains unmerged branches locally and remote
function git-repos-unmerged-branches-all() {
    display-unmerged-branches-all() {
        unmergedBranches=$(git branch --no-merged main) 
        if [[ $unmergedBranches = *[![:space:]]* ]]; then
            echo "$fnam"
            git branch --all --no-merged main
            echo
        fi
    }

    git-for-each-repo display-unmerged-branches-all
}

# For each directory within the current directory, generate a hacky lines of
# code count 
function git-repos-hacky-line-count() {
    display-hacky-line-count() {
        git ls-files > ../file-list.txt
        lineCount=$(cat < ../file-list.txt | grep -e "\(scala\|py\|java\|sql\|elm\|tf\|yaml\|pp\|yml\)" | xargs cat | wc -l)
        echo "$fnam $lineCount"
        totalCount=$((totalCount + lineCount))
    }

    git-for-each-repo display-hacky-line-count | column -t -s ' ' | sort -b -k 2.1 -n --reverse
}

# Display remote branches which have been merged
function git-merged-branches() {
    git branch -r | xargs -t -n 1 git branch -r --contains
}

# Open the Git repo in the browser
#   Open repo: git-open 
#   Open file: git-open foo/bar/baz.txt
function git-open() {
    local filename=$1
​
    local pathInRepo
    if [[ -n "${filename}" ]]; then
        pushd $(dirname "${filename}")
        pathInRepo=$(git ls-tree --full-name --name-only HEAD $(basename "${filename}"))
    fi
​
    URL=$(git config remote.origin.url)
    echo "Opening '$URL'"
​
    if [[ $URL =~ ^git@ ]]; then
        [[ -n "${pathInRepo}" ]] && pathInRepo="tree/main/${pathInRepo}"
        echo "$URL" \
            | perl -e 'while (<STDIN>) { /git@(.*):(.*).git/ && print("https://$1/$2/@ARGV[0]") }' "$pathInRepo" \
            | xargs open
​
    elif [[ $URL =~ ^https://bitbucket.org ]]; then
        echo "$URL" \
            | perl -e 'while (<STDIN>) { /(.*).git/ && print("$1/src/main/@ARGV[0]") }' "$pathInRepo" \
            | xargs open
​
    elif [[ $URL =~ ^https://github.com ]]; then
        [[ -n "${pathInRepo}" ]] && pathInRepo="tree/main/${pathInRepo}"
        echo "$URL" \
            | perl -e 'while (<STDIN>) { /(.*).git/ && print("$1/@ARGV[0]") }' "$pathInRepo" \
            | xargs open
​
    else
        echo "Failed to open due to unrecognised URL '$URL'"
    fi
​
    [[ -n "${filename}" ]] && popd
}

# Archive the Git branch by tagging then deleting it
function git-archive-branch() {
    if [[ $# -ne 1 ]] ; then
        echo 'Archive Git branch by tagging then deleting it'
        echo 'Usage: git-archive-branch BRANCH'
        return 1
    fi

    git tag archive/$1 $1
    git branch -D $1
}

# Configure personal email
function git-config-personal-email() {
    git config user.email "stubillwhite@gmail.com"
}

# Configure work email
function git-config-work-email() {
    git config user.email "s.white.1@elsevier.com"
}

# Git stats for the current repo
function git-contributor-stats() {
    echo "Commit count"
    git shortlog -sn --no-merges

    echo
    echo "Line count"
    git ls-tree -r --name-only HEAD | grep -ve "\(\.json\|\.sql\)" | xargs -n1 git blame --line-porcelain HEAD | grep "^author " | sort | uniq -c | sort -nr
    #git log --no-merges --pretty='@%an' --shortstat | tr '\n' ' ' | tr '@' '\n'
}

# Display the size of objects in the Git log
# https://stackoverflow.com/a/42544963
function git-large-objects() {
    git rev-list --objects --all \
        | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' \
        | sed -n 's/^blob //p' \
        | sort --numeric-sort --key=2 \
        | cut -c 1-12,41- \
        | $(command -v gnumfmt || echo numfmt) --field=2 --to=iec-i --suffix=B --padding=7 --round=nearest
    }

# Display the meaning of characters used for the prompt markers
function prompt-help() {
    # TODO: Would be neater to do this dynamically based on info_format
    #       https://github.com/sorin-ionescu/prezto/blob/master/modules/git/functions/git-info
    local promptKey="
    ✚ added
    ⬆ ahead
    ⬇ behind
    ✖ deleted
    ✱ modified
    ➜ renamed
    ✭ stashed
    ═ unmerged
    ◼ untracked
    "
    echo $promptKey
}

# GitHub                            {{{2
# ======================================

# Notify me when my GitHub PR has been reviewed

function github-notify-when-reviewed() {
    {
        while true
        do
            sleep 30
            (github-list-pull-requests | grep -v 'Pull requests for' | grep -q -R '\(has-reviews\|has-comments\)') && break
        done

        if (github-list-pull-requests | grep -v 'Pull requests for' | grep -q -R '\(has-reviews\|has-comments\)') ; then
            tell-me "GitHub PR reviewed or commented on"
        fi
    } > /dev/null 2>&1 & disown
}

# AWS

function aws-datapipeline-requirements() {
    while IFS=, read -rA x 
    do
        pipelineId=${x[@]:0:1}
        pipelineName=${x[@]:1:1}
        aws datapipeline get-pipeline-definition --pipeline-id $pipelineId \
            | jq --raw-output ".values | [\"$pipelineName\", .my_master_instance_type, \"1\", .my_core_instance_type, .my_core_instance_count, .my_env_subnet_private]| @csv"
    done < <(aws datapipeline list-pipelines | jq --raw-output '.pipelineIdList[] | [.id, .name] | @csv' | sed 's/"//g') \
        | sed 's/"//g' \
        | column -t -s '','' 
}

function aws-datapipeline-amis() {
    while IFS=, read -rA x 
    do
        pipelineId=${x[@]:0:1}
        pipelineName=${x[@]:1:1}
        aws datapipeline get-pipeline-definition --pipeline-id $pipelineId \
            | jq --raw-output "                                            \
                    .objects[]                                             \
                    | select(has(\"imageId\"))                             \
                    | [\"$pipelineName\", .[\"imageId\"]]                  \
                    | @csv"
    done < <(aws datapipeline list-pipelines | jq --raw-output '.pipelineIdList[] | [.id, .name] | @csv' | sed 's/"//g') \
        | sed 's/"//g' \
        | column -t -s '','' 
}

function aws-datapipeline-amis() {
    while IFS=, read -rA x 
    do
        pipelineId=${x[@]:0:1}
        pipelineName=${x[@]:1:1}
        aws datapipeline get-pipeline-definition --pipeline-id $pipelineId      \
            | jq --raw-output "                                                 \
                    [\"$pipelineName\",                                         \
                     (.objects[] | select(has(\"imageId\")) | .[\"imageId\"]),  \
                     (.values[\"my_ec2_machine_ami_id\"])]                      \
                    | @csv"
    done < <(aws datapipeline list-pipelines | jq --raw-output '.pipelineIdList[] | [.id, .name] | @csv' | sed 's/"//g') \
        | sed 's/"//g' \
        | column -t -s '','' 
}

function aws-service-quotas() {
    aws service-quotas list-service-quotas --service-code ec2 | jq --raw-output '(.Quotas[] | ([.QuotaName, .Value])) | @csv' | column -t -s "," | sed 's/\"//g'
}

function plot-aws-s3-size() {
    if [[ $# -ne 3 ]] ; then
        echo 'Plot the size of the AWS S3 bucket and prefix'
        echo 'Usage: plot-aws-s3-size PROFILE PREFIX PERIOD'
        return -1
    fi

    profile=$1
    prefix=$2
    period=$3

    interval -t $period "aws --profile '$profile' s3 ls --summarize --recursive '$prefix' | grep 'Total Size' | awk '"'{ print $3 }'"'" | plot
}

function aws-export-current-credentials() {
    echo "export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} && export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}"
}

# Open the specified S3 bucket
function aws-s3-open() {
    local s3Path=$1
    echo "Opening '$s3Path'"
    echo "$s3Path" \
        | sed -e 's/^.*s3:\/\/\(.*\)/\1/' \
        | sed -e 's/^/https:\/\/s3.console.aws.amazon.com\/s3\/buckets\//' \
        | sed -e 's/$/?region=us-east-1/' \
        | xargs "$OPEN_CMD"
}

# Docker

# Prompt for confirmation
# confirm "Delete [y/n]?" && rm -rf *
function confirm() {
    read response\?"${1:-Are you sure?} [y/N] "
    case "$response" in
        [Yy][Ee][Ss]|[Yy]) 
            true
            ;;
        *)
            false
            ;;
    esac
}
function docker-rm-instances() {
    docker ps -a -q | xargs docker stop
    docker ps -a -q | xargs docker rm
}

function docker-rm-images() {
    if confirm; then
        docker-rm-instances
        docker images -q | xargs docker rmi
        docker images | grep "<none>" | awk '{print $3}' | xargs docker rmi
    fi
}

function docker-rm-dangling-images() {
    docker ps -a -q | xargs docker stop
    docker ps -a -q | xargs docker rm -v
    docker images -q | xargs docker rmi
    docker images | grep "<none>" | awk '{print $3}' | xargs docker rmi
    docker volume rm $(docker volume ls -qf dangling=true)
}

# Kubernetes                                                                {{{1
# ==============================================================================

function recs-get-k8s() {
    if [[ $# -ne 2 ]] ; then
        echo "Usage: recs-get-k8s (dev|live) (util|main)"
    else
        local recsEnv=$1
        local recsSubEnv=$2
        aws s3 cp s3://com-elsevier-recs-${recsEnv}-certs/eks/recs-eks-${recsSubEnv}-${recsEnv}.conf ~/.kube/
        export KUBECONFIG=~/.kube/recs-eks-${recsSubEnv}-${recsEnv}.conf
    fi
}
compdef "_arguments \
#    '1:environment arg:(dev live)' \
#    '2:sub-environment arg:(util main)'" \
#    recs-get-k8s


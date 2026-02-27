#!/bin/sh

if ! command -v git > /dev/null 2>&1; then
    echo "git is not installed. Please install git command line tools"
    exit 1
fi

if ! command -v gh > /dev/null 2>&1; then
    echo "gh is not installed. Please install Github command line tools"
    exit 1
fi

if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo "Not a git repository. Please run this script from inside a git repository."
    exit 1
fi

if ! gh auth status > /dev/null 2>&1; then
    echo "No active sessions found. Please log in to Github."
    gh auth login
fi

sync_stack() {
    branch=$(git rev-parse --abbrev-ref HEAD)

    case "$branch" in
        *stack-????????-[0-9]*)
            stack_id=$(printf '%s' "$branch" | sed 's/.*-stack-\(.\{8\}\)-.*/\1/')
            base=$(printf '%s' "$branch" | sed 's/-stack-.\{8\}-[0-9]*//')
            ;;
        *)
            echo "Current branch is not part of a stack. Nothing to sync."
            exit 1
            ;;
    esac

    stack_branches=$(git branch --list "*stack-${stack_id}-*" | sed 's/^[* ]*//' | \
        awk -F- '{print $NF, $0}' | sort -n | awk '{print $2}')

    for b in $stack_branches; do
        if [ "$(gh pr view "$b" --json mergeable --jq '.mergeable' 2>/dev/null)" = "CONFLICTING" ]; then
            echo "Merge conflict detected in $b. Resolve the conflict before syncing or merging."
            exit 1
        fi
    done

    prev="$base"
    for b in $stack_branches; do
        git checkout "$b"
        git rebase "$prev" || exit 1
        prev="$b"
    done

    git checkout "$branch"
}

# Push your current changes to a new or existing stack
if [ "$1" = "push" ]; then

    branch=$(git rev-parse --abbrev-ref HEAD)
    # Find the base branch. Special logic is required if this is the second layer in the stack
    # since we need to strip off the "stack-abcd1234-1" suffix
    case "$branch" in
        *stack-????????-1*) base="${branch%?????????????????}" ;;
        *stack-????????-[1-9]*)
            num=$(printf '%s' "$branch" | sed 's/.*-stack-.\{8\}-//')
            prefix=$(printf '%s' "$branch" | sed 's/-[0-9]*$//')
            base="${prefix}-$((num - 1))"
            ;;
    esac

    echo $base
    # If the branch is already part of a stack, increment the number and create a new branch
    if [ -n "$base" ]; then
        if gh pr create --fill -B "$base"; then
            # TODO: put the stack number in the body of the PR somewhere
            num=$(printf '%s' "$branch" | sed 's/.*-stack-.\{8\}-//')
            prefix=$(printf '%s' "$branch" | sed 's/-[0-9]*$//')
            git checkout -b "${prefix}-$((num + 1))"
        fi
    # If the branch is not part of a stack yet, create a new branch with a stack identifier
    else
        if gh pr create --fill; then
            # TODO: put the stack number in the body of the PR somewhere
            rand=$(LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | head -c 8)
            git checkout -b "${branch}-stack-${rand}-1"
        fi
    fi


# Rebase each branch in the stack on top of the branch before it
elif [ "$1" = "sync" ]; then
    sync_stack

# List the review status of each pull request in the stack
elif [ "$1" = "status" ]; then
    branch=$(git rev-parse --abbrev-ref HEAD)

    case "$branch" in
        *stack-????????-[0-9]*)
            stack_id=$(printf '%s' "$branch" | sed 's/.*-stack-\(.\{8\}\)-.*/\1/')
            ;;
        *)
            echo "Current branch is not part of a stack."
            exit 1
            ;;
    esac

    stack_branches=$(git branch --list "*stack-${stack_id}-*" | sed 's/^[* ]*//' | \
        awk -F- '{print $NF, $0}' | sort -n | awk '{print $2}')

    for b in $stack_branches; do
        decision=$(gh pr view "$b" --json reviewDecision,mergeable --jq '.reviewDecision + " " + .mergeable' 2>/dev/null)
        review=$(printf '%s' "$decision" | awk '{print $1}')
        mergeable=$(printf '%s' "$decision" | awk '{print $2}')
        case "$review" in
            APPROVED)          label="approved" ;;
            CHANGES_REQUESTED) label="changes requested" ;;
            REVIEW_REQUIRED)   label="waiting for approvals" ;;
            *)                 label="no reviews yet" ;;
        esac
        if [ "$mergeable" = "CONFLICTING" ]; then
            label="$label, merge conflict"
        fi
        printf '%s: %s\n' "$b" "$label"
    done

# Sync the stack, merge the topmost PR, then close the rest with a comment
elif [ "$1" = "merge" ]; then
    sync_stack
    topmost=""
    for b in $stack_branches; do
        if gh pr view "$b" > /dev/null 2>&1; then
            topmost="$b"
        fi
    done
    if [ -z "$topmost" ]; then
        echo "No open pull requests found in the stack."
        exit 1
    fi
    gh pr edit "$topmost" --base main
    gh pr merge "$topmost" --merge
    for b in $stack_branches; do
        if [ "$b" != "$topmost" ]; then
            gh pr comment "$b" --body "merged as a part of a stack"
            gh pr close "$b"
        fi
    done

# Close all PRs in the stack and recreate them from the existing branches
elif [ "$1" = "rebuild" ]; then
    branch=$(git rev-parse --abbrev-ref HEAD)

    case "$branch" in
        *stack-????????-[0-9]*)
            stack_id=$(printf '%s' "$branch" | sed 's/.*-stack-\(.\{8\}\)-.*/\1/')
            base=$(printf '%s' "$branch" | sed 's/-stack-.\{8\}-[0-9]*//')
            ;;
        *)
            echo "Current branch is not part of a stack."
            exit 1
            ;;
    esac

    stack_branches=$(git branch --list "*stack-${stack_id}-*" | sed 's/^[* ]*//' | \
        awk -F- '{print $NF, $0}' | sort -n | awk '{print $2}')

    gh pr close "$base" 2>/dev/null
    for b in $stack_branches; do
        gh pr close "$b" 2>/dev/null
    done

    gh pr create --fill --head "$base"
    prev="$base"
    for b in $stack_branches; do
        gh pr create --fill --head "$b" -B "$prev"
        prev="$b"
    done

fi

# stack 1

#stack 2
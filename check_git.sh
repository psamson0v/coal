#!/bin/sh

if command -v git > /dev/null 2>&1; then
    echo "git is installed ($(git --version))"
else
    echo "git is not installed. Please install git command line tools"
    exit 1
fi

if command -v gh > /dev/null 2>&1; then
    echo "gh is installed ($(gh --version | head -1))"
else
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

# Push your current changes to a new or existing stack
if [ "$1" = "push" ]; then
    gh pr create --fill
    # TODO: put the stack number in the body of the PR somewhere

    branch=$(git rev-parse --abbrev-ref HEAD)
    case "$branch" in
    # If the branch is followed by "stack-abcd1234-X" then it's already a part of a stack
    # increment the number X and create a new branch
        *stack-????????-[0-9]*)
            num=$(printf '%s' "$branch" | sed 's/.*-stack-.\{8\}-//')
            prefix=$(printf '%s' "$branch" | sed 's/-[0-9]*$//')
            new_branch="${prefix}-$((num + 1))"
            git checkout -b "$new_branch"
            ;;
    # If the branch is not followed by "stack-abcd1234-X" then it's not a part of a stack yet. 
    # the new branch should have a stack identifier
        *)
            rand=$(LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | head -c 8)
            new_branch="${branch}-stack-${rand}-1"
            git checkout -b "$new_branch"
            ;;
    esac
fi

# this is a test comment at the base of the stack
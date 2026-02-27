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


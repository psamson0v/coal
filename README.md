# Coal
We have Graphite at home

The purpose of Coal is to provide the basic functionality of Graphite (reviewing large PRs piecemeal, as a part of a stack) but for free. Coal is designed to be as simple as possible using only existing command line tools.

## Prerequisites

Git (`git`) installed and available on the path
Github command line tools (`gh`) installed and available on the path

## How To

Create a new branch in your repository as usual.

When you are ready to create a first level PR, use `./coal.sh push`. This will create a pull request with your current branch and create another branch on top of this branch for you to continue your work. You can use `./coal.sh push` at any time to put additional PRs on the stack for review. 

If changes are introduced as a part of a lower level pull request, use `./coal.sh sync` to rebase the higher branches on top of these changes.

Once all the pull requests are approved, use `./coal.sh merge` to merge all changes in the stack and close all pull requests.

If something went wrong and you want to start again, use `./coal.sh rebuild` to close all pull requests associated with this stack and automatically generate new pull requests.

To see the status of your whole stack in one place, use `./coal.sh status`.
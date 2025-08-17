# Backport Action

Automatically backports pull requests to specified branches based on labels.

* If there is a conflict, the pull request is created with committed conflicts
that must be resolved.
* Reviewers and assignees are copied to the new pull request

## Usage

This GitHub Action automatically creates backport pull requests when a pull
request is merged or labeled with specific backport labels.

```yaml
name: Backport
on:
  pull_request_target:
    types:
      - closed
      - labeled
jobs:
  backport:
    name: Backport
    runs-on: ubuntu-latest
    if: >
      github.event.pull_request.merged
      && (
        github.event.action == 'closed'
        || (
          github.event.action == 'labeled'
          && contains(github.event.label.name, 'backport-to-')
        )
      )
    steps:
      - uses: next-actions/backport@master
        with:
          user: your-bot-account
          token: ${{ secrets.BOT_TOKEN }}

```

## Inputs

* **user (required)**: GitHub user with fork where pull request branch will be created
* **token (required)**: Token that allows to push to the fork (user) repository
* **pattern (optional)**: Regular expression with one capture group to match branch name in label, default to `^backport-to-(.*)`

## Difference from other auto-backport actions

* The branch that is used to create the pull request is pushed to a forked
  repository in a selected user (bot) account, not to the upstream repository.
* The pull request is created even if patches can not be cleanly cherry-picked.
  In this case the pull requests is created as a draft, with conflicting commits
  clearly marked.
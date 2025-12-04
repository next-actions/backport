#!/usr/bin/env bash
set -e -o pipefail

# Usage
if [ "$#" -ne 5 ]; then
  echo "Usage: $0 <github-repo> <pr-id> <target-branch> <fork-user> <fork-token>" >&2
  exit 1
fi

# Create working directory
scriptdir=`realpath \`dirname "$0"\``
wd=`mktemp -d`
trap 'rm -rf "$wd"' EXIT

# Initial setup
GITHUB_REPOSITORY=$1
PR_ID=$2
TARGET=$3
FORK_USER=$4
FORK_TOKEN=$5

OWNER=`echo "$GITHUB_REPOSITORY" | cut -d / -f 1`
REPOSITORY=`echo "$GITHUB_REPOSITORY" | cut -d / -f 2`
PR_URL="https://github.com/$OWNER/$REPOSITORY/pull/$PR_ID"
PR_TITLE=`gh pr view --repo "$OWNER/$REPOSITORY" "$PR_ID" --json title --jq .title`
PR_BODY=`gh pr view --repo "$OWNER/$REPOSITORY" "$PR_ID" --json body --jq .body`
PR_AUTHOR=`gh pr view --repo "$OWNER/$REPOSITORY" "$PR_ID" --json author --jq .author.login`
PR_REVIEWERS=`gh pr view --repo "$OWNER/$REPOSITORY" "$PR_ID" --json reviews --jq '.reviews.[] | select(.state == "APPROVED" and .authorAssociation != "NONE") | .author.login' | sort | uniq`
PR_ASSIGNEES=`gh pr view --repo "$OWNER/$REPOSITORY" "$PR_ID" --json assignees --jq .assignees.[].login`
PR_COMMITS=`gh pr view --repo "$OWNER/$REPOSITORY" "$PR_ID" --json commits --jq '.commits.[] | "* \(.oid) - \(.messageHeadline)"'`
PR_COMMITS_COUNT=`echo "$PR_COMMITS" | wc -l`
PR_MERGE_COMMIT=`gh pr view --repo "$OWNER/$REPOSITORY" "$PR_ID" --json mergeCommit --jq '.mergeCommit.oid'`
BASE_BRANCH=`gh pr view --repo "$OWNER/$REPOSITORY" "$PR_ID" --json baseRefName --jq .baseRefName`
BACKPORT_BRANCH_NAME="$OWNER-$REPOSITORY-backport-pr$PR_ID-to-$TARGET"
COMMIT_MESSAGE_TEMPLATE="$scriptdir/pr-msg-ok.md"

# Information about the merged commits, SHA may be different from PR
# This is obtain after cloning the git repository
MERGE_COMMITS=
MERGE_COMMITS_SHA=

echo "GitHub Repository: $OWNER/$REPOSITORY"
echo "GitHub Pull Request: $PR_URL"
echo "Title: $PR_TITLE"
echo "Author: $PR_AUTHOR"
echo "Assignees: `echo $PR_ASSIGNEES | tr '\n' ' '`"
echo "Reviewers: `echo $PR_REVIEWERS | tr '\n' ' '`"
echo "Base Branch: $BASE_BRANCH"
echo "Requesting Backport To: $TARGET"
echo "Merge Commit: $PR_MERGE_COMMIT"
echo "Pull Request Commits:"
echo "$PR_COMMITS"
echo ""
echo "Action Directory: $scriptdir"
echo "Working Directory: $wd"
echo ""

pushd "$wd"
set -x

# Login with token to GitHub CLI, GH_TOKEN variable is used in GitHub Actions
if [ -z "$GH_TOKEN" ]; then
    echo $FORK_TOKEN > .token
    gh auth login --with-token < .token
    rm -f .token
fi

# Clone repository and fetch the pull request
git clone "https://github.com/$OWNER/$REPOSITORY.git" .
git remote add "$FORK_USER" "https://$FORK_USER:$FORK_TOKEN@github.com/$FORK_USER/$REPOSITORY.git"
git checkout "$BASE_BRANCH"
git checkout "$TARGET"
gh repo set-default "$GITHUB_REPOSITORY"

# Obtain merged commits SHA
MERGE_COMMITS=`git log --reverse --pretty=format:"%H - %s" -$PR_COMMITS_COUNT $PR_MERGE_COMMIT`
MERGE_COMMITS_SHA=`git log --reverse --pretty=format:"%H" -$PR_COMMITS_COUNT $PR_MERGE_COMMIT`

set +x
echo ""
echo "Base Branch Commits:"
echo "$MERGE_COMMITS"
echo ""
set -x

# Set git identity
git config user.name "next-actions/backport"
git config user.email "notavailable"

# Create new branch that we will work on
git checkout -b "$BACKPORT_BRANCH_NAME" "$TARGET"

# Apply cherry-picks even if there is a conflict
CONFLICT_INFORMATION=""
has_conflict=0
for commit in $MERGE_COMMITS_SHA; do
    set +e
    git cherry-pick --allow-empty --allow-empty-message --empty=keep -x "$commit"
    ret=$?
    set -e
    if [ $ret -ne 0 ]; then
        COMMIT_MESSAGE_TEMPLATE="$scriptdir/pr-msg-conflict.md"
        has_conflict=1
        echo "Conflicts detected, while cherry-picking $commit"
        gitstatus=`git status`
        git add --all

        # Override the merge message
        merge_msg_path=".git/MERGE_MSG"
        merge_msg=`cat "$merge_msg_path"`
        echo "CONFLICT! $merge_msg" > "$merge_msg_path"

        # Remember the conflict status
        commit_subject=`head -1 "$merge_msg_path"`
        CONFLICT_INFORMATION+="* $commit_subject\n"
        CONFLICT_INFORMATION+="\`\`\`\n"
        CONFLICT_INFORMATION+="$gitstatus\n"
        CONFLICT_INFORMATION+="\`\`\`\n"
        CONFLICT_INFORMATION+=""


        # Make sure to disable the interactive editor
        GIT_EDITOR=/usr/bin/true git cherry-pick --continue
    fi
    CONFLICT_INFORMATION=`echo -e "$CONFLICT_INFORMATION"`
done

# Push backport to remote
git push --set-upstream "$FORK_USER" "$BACKPORT_BRANCH_NAME" --force

# Prepare pull request message
BACKPORT_COMMITS=`git log --format="* %H - %s" --reverse $TARGET..$BACKPORT_BRANCH_NAME`
envlist='$PR_ID,$PR_URL,$PR_TITLE,$PR_URL,$PR_BODY,$PR_AUTHOR,$PR_COMMITS,$MERGE_COMMITS,$TARGET,$FORK_USER,$BACKPORT_BRANCH_NAME,$BACKPORT_COMMITS,$CONFLICT_INFORMATION'

export PR_ID
export PR_URL
export PR_TITLE
export PR_URL
export PR_BODY
export PR_AUTHOR
export PR_COMMITS
export MERGE_COMMITS
export TARGET
export FORK_USER
export BACKPORT_BRANCH_NAME
export BACKPORT_COMMITS
export CONFLICT_INFORMATION
envsubst $envlist < $COMMIT_MESSAGE_TEMPLATE > .backport-commit-message

cat .backport-commit-message

# Add assignees and reviewers
pr_create_args=""
pr_create_args+=`echo $PR_ASSIGNEES | tr ' ' '\n' | xargs -I{} echo -n "--assignee {} "`
pr_create_args+=`echo $PR_REVIEWERS | tr ' ' '\n' | xargs -I{} echo -n "--reviewer {} "`
if [ "$has_conflict" -eq 1 ]; then
    pr_create_args+="--draft "
fi

gh pr create $pr_create_args \
    --base "$TARGET" \
    --body-file .backport-commit-message \
    --head "$FORK_USER:$BACKPORT_BRANCH_NAME" \
    --title "[autobackport: $TARGET] $PR_TITLE"

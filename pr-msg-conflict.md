This is an automatic backport of [PR#$PR_ID $PR_TITLE]($PR_URL) to branch $TARGET, created by @$PR_AUTHOR.

> [!CAUTION]
> @$PR_AUTHOR The patches did not apply cleanly. It is necessary to **resolve conflicts** before merging this pull request. Commits that introduced conflict are marked with `CONFLICT!`.

**You can push changes to this pull request**

```
git remote add $FORK_USER git@github.com:$FORK_USER/sssd.git
git fetch $FORK_USER refs/heads/$BACKPORT_BRANCH_NAME
git checkout $BACKPORT_BRANCH_NAME
git push $FORK_USER $BACKPORT_BRANCH_NAME --force
```

---

**Original commits**
$MERGE_COMMITS

**Backported commits**
$BACKPORT_COMMITS

---

**Original Pull Request Body**

$PR_BODY

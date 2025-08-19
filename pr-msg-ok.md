This is an automatic backport of [PR#$PR_ID $PR_TITLE]($PR_URL) to branch $TARGET, created by @$PR_AUTHOR.

Please make sure this backport is correct.

> [!NOTE]
> The commits were cherry-picked without conflicts.

**You can push changes to this pull request**

```
git remote add $FORK_USER git@github.com:$FORK_USER/sssd.git
git fetch $FORK_USER refs/heads/$BACKPORT_BRANCH_NAME
git checkout $BACKPORT_BRANCH_NAME
git push $FORK_USER $BACKPORT_BRANCH_NAME
```

---

**Original commits**
$ORIGINAL_COMMITS

**Backported commits**
$BACKPORT_COMMITS

---

**Original Pull Request Body**

$PR_BODY

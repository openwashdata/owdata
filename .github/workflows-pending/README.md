# Pending workflows

Copies of washr 1.1.0's R-CMD-check, pkgdown and test-coverage workflows.
The session that scaffolded the package could not push files under
.github/workflows/ (the GitHub App lacks the workflows permission).
Activate with:

```sh
git mv .github/workflows-pending/*.yaml .github/workflows/ && rmdir .github/workflows-pending
```

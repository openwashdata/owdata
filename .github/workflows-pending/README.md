# Pending workflows

The automation token used to create this branch does not carry the
`workflows` permission, so GitHub rejects pushes that create files under
`.github/workflows/`. These three workflows are complete and ready; a
human with normal repository access activates them with:

```sh
git mv .github/workflows-pending/*.yaml .github/workflows/
git commit -m "ci: activate workflows"
```

Then delete this directory. The harvest workflow additionally expects an
optional `REGISTRY_TOKEN` secret (org PAT with write access to
openwashdata/openwashdata.r-universe.dev) for the registry sync step; it
skips that step cleanly until the secret exists.

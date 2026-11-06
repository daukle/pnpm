## What this repository is

The managed resolver for a pnpm project: it is to pnpm what `daukle/npm` is to npm. You write version
ranges and the pnpm release in `[toolchains.pnpm]`; `daukle pnpm:resolve --resolve` has that pnpm
compute the closure, pins every package of it by sha256, and writes the pins and pnpm's own lockfile
to the committed `daukle/pnpm/lock.lua`, which daukle loads by itself. An install then resolves no
range.

```toml
[plugins]
pnpm = "daukle/pnpm@^1"

[toolchains.pnpm]
version = "22.15.0"
pnpm = "10.34.9"
packages = { vuepress = "2.0.0-rc.20" }
```

`pnpm` names a release this plugin pins, as a project's `"packageManager": "pnpm@<version>"` does;
pnpm runs from its own npm tarball on the provisioned node, so no corepack is involved. `overrides`
is pnpm's override object as JSON text, written where pnpm reads it, `pnpm.overrides`.

The design is `superpowers/specs/2026-11-06-pnpm-resolver-design.md` in `daukle/docs` (`D-251`).

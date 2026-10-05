# transport-central-launcher

Installs, launches and updates the workspace runtime as one self-contained binary per platform.

## What it is for

One binary carries the runtime and its child processes. It self-extracts on first run, supervises the children, and moves between versions by fetching only the content-addressed chunks the new version adds, so one published copy serves every client whatever version it starts from. `payload.exs` names what each platform's binary carries.

## Build and run

```sh
mix deps.get
mix test
```

The release workflow builds each platform's binary natively on a tag. Run with no arguments, the binary prints its verbs.

## Licence

MIT; see `LICENSE`.

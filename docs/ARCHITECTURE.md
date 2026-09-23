# AI Guard — Architecture

## Scope

AI Guard is an external enforcement layer for AI CLI agents on Linux. The agent
is not trusted to enforce its own filesystem boundary.

## Layers

```
+------------------------------+
| AI CLI                       |
| OpenCode / future agents     |
+--------------+---------------+
               |
               v
+------------------------------+
| Adapter / selector           |
| CLI selection + credentials  |
+--------------+---------------+
               |
               v
+------------------------------+
| AI Guard                     |
| policy + workspace resolver  |
+--------------+---------------+
               |
               v
+------------------------------+
| Bubblewrap                   |
| mount + namespace boundary   |
+--------------+---------------+
               |
               v
+------------------------------+
| Linux host                   |
+------------------------------+
```

## Workspace boundary

Repo Resolver v1 canonicalizes the requested workspace before validation.

Allowed:

```
/vol1/Docker/<repository>
```

Denied:

- the exact `/vol1/Docker` root
- the Guard installation
- protected system roots
- unrelated `/vol1` paths
- canonical paths escaping the controlled root

The accepted workspace is exposed inside the sandbox as:

```
/workspace
```

## Sandbox boundary

The sandbox is constructed by `sandbox/bwrap.sh`.

The intended model is:

- workspace: read/write
- controlled host paths: read-only or absent according to policy
- sensitive host control interfaces: absent
- Linux capabilities: dropped
- selected namespaces: isolated
- environment: explicitly rebuilt
- network: isolated by default

## Network

Two modes currently exist:

### none

Separate network namespace. This is the default.

### host

The sandbox shares the host network namespace. This is useful for API access
but does not provide network isolation.

An allowlisted proxy or slirp4netns/pasta-based egress design is future work.

## OpenCode

OpenCode is integrated through:

```
adapters/opencode/opencode-select
```

The selector chooses a configured Google API key and launches:

```
bin/ai-guard --opencode ...
```

The selected key is forwarded explicitly into the sandbox. SSH remains disabled
by default.

## Security model

AI Guard is designed as an enforcement layer, not as a policy prompt.

Therefore security-relevant boundaries must be enforced before the AI CLI is
allowed to operate.

## Future extension points

- controlled remote GitHub repository resolution
- additional AI CLI adapters
- egress-only network policy
- adversarial security tests

Future capabilities must preserve the existing workspace and host-control
boundaries.

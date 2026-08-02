# Pinned dependencies

The prototype uses Solidity 0.8.26 and the Cancun EVM target.

| Alias | Repository | Revision |
| --- | --- | --- |
| `oz-hooks` | `OpenZeppelin/uniswap-hooks` | `26dc8e53f812a1ca390d470342adb6cd8c3286ad` |
| `oz-contracts` | `OpenZeppelin/openzeppelin-contracts` | `21c8312b022f495ebe3621d5daeed20552b43ff9` |
| `v4-core` | `Uniswap/v4-core` | `59d3ecf53afa9264a16bba0e38f4c5d2231f80bc` |
| `v4-periphery` | `Uniswap/v4-periphery` | `ad04c9f24a170accf5ea1b2836bbafd514537ca6` |
| `forge-std` | `foundry-rs/forge-std` | `3b20d60d14b343ee4f908cb8079495c07f5e8981` |

The minimum compiler and test closure used by this project is committed as regular files under `lib`. This lets the Public GitHub PR Builder Beta bind the exact dependency bytes without relying on Git submodules or executing an installer. The rest of each dependency repository remains excluded.

The v4-core closure includes Solmate test and support files pinned by v4-core at `4b47a19038b798b4a33d9749d25e570443520647`. Licence texts and provenance are preserved in `lib` and summarised in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

[The bootstrap script](script/bootstrap.sh) restores the full pinned dependency repositories only when `lib` is absent. A normal clone already contains the committed review closure and needs no bootstrap step.

The local verification toolchain recorded on 2 August 2026 was:

- Foundry 1.7.1, commit `4072e48705af9d93e3c0f6e29e93b5e9a40caed8`
- uv 0.12.0
- Python 3.14.4 for the economic model
- Slither 0.11.6 through `uvx --python 3.13`

The Foundry compiler configuration and remappings are in `foundry.toml` and `remappings.txt`.

## Demonstration website

The React demo uses Bun 1.3.14. `package.json` pins every direct dependency and `bun.lock` records the complete registry dependency closure and package integrity values.

| Package | Version |
| --- | ---: |
| `@tanstack/react-query` | 5.101.4 |
| `react` | 19.2.8 |
| `react-dom` | 19.2.8 |
| `viem` | 2.55.8 |
| `wagmi` | 3.7.4 |
| `@types/react` | 19.2.17 |
| `@types/react-dom` | 19.2.3 |
| `@vitejs/plugin-react` | 6.0.4 |
| `typescript` | 7.0.2 |
| `vite` | 8.1.5 |

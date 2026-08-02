#!/usr/bin/env bash
set -euo pipefail

if [[ -e lib ]]; then
  echo "Committed dependency closure is present; no bootstrap is required."
  exit 0
fi

forge install --no-git --shallow \
  oz-hooks=OpenZeppelin/uniswap-hooks@rev=26dc8e53f812a1ca390d470342adb6cd8c3286ad \
  oz-contracts=OpenZeppelin/openzeppelin-contracts@rev=21c8312b022f495ebe3621d5daeed20552b43ff9 \
  v4-core=Uniswap/v4-core@rev=59d3ecf53afa9264a16bba0e38f4c5d2231f80bc \
  v4-periphery=Uniswap/v4-periphery@rev=ad04c9f24a170accf5ea1b2836bbafd514537ca6 \
  forge-std=foundry-rs/forge-std@rev=3b20d60d14b343ee4f908cb8079495c07f5e8981

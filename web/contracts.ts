import { isAddress, parseAbi, zeroAddress, type Address } from "viem";

// This is the exact read surface used by the demo, copied from the Solidity
// contracts in src/. Keeping the subset explicit makes unsupported features
// impossible to imply in the interface.
export const discoveryBoxAbi = parseAbi([
  "function openedCount() view returns (uint256)",
  "function openedBoxes() view returns (uint256)",
  "function maturityTarget() view returns (uint256)",
  "function totalSupply() view returns (uint256)",
  "function balanceOf(address account) view returns (uint256)",
  "function membershipExpiry(address account) view returns (uint256)",
  "function hasActiveMembership(address account) view returns (bool)",
  "function open(uint256 boxCount)",
  "event AssetOpened(address indexed account, uint256 boxCount, uint256 firstSerial, uint256 totalOpenedCount)",
  "event BoxOpened(address indexed account, uint256 boxCount, uint256 newExpiry, uint256 totalOpenedBoxes)",
]);

export const discoveryHookAbi = parseAbi([
  "function currentSellLpFee() view returns (uint24)",
  "function BUY_LP_FEE() view returns (uint24)",
  "function PROGRAMMABLE_FEE() view returns (uint24)",
  "function registeredPoolId() view returns (bytes32)",
  "function programmableOwner() view returns (address)",
  "function liability(bytes32 poolId, address currency, address beneficiary) view returns (uint256)",
  "event ProgrammableFeeAccrued(bytes32 indexed poolId, address indexed currency, uint256 grossQuote, uint256 fee)",
]);

const rawBoxAddress = import.meta.env.VITE_DISCOVERY_BOX_ADDRESS as string | undefined;
const rawHookAddress = import.meta.env.VITE_DISCOVERY_HOOK_ADDRESS as string | undefined;

function validatedAddress(value: string | undefined): Address | undefined {
  return value && isAddress(value) && value !== zeroAddress ? value : undefined;
}

export const deployment = {
  boxAddress: validatedAddress(rawBoxAddress),
  hookAddress: validatedAddress(rawHookAddress),
  hadConfiguration: Boolean(rawBoxAddress || rawHookAddress),
};

export const hasConfiguredDeployment = Boolean(deployment.boxAddress && deployment.hookAddress);

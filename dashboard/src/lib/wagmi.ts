import { createConfig, http } from "wagmi";
import { injected } from "wagmi/connectors";
import { kubMainnet, kubTestnet } from "./chains";

const mainnetRpc =
  import.meta.env.VITE_RPC_URL || kubMainnet.rpcUrls.default.http[0];

export const wagmiConfig = createConfig({
  chains: [kubMainnet, kubTestnet],
  connectors: [injected()],
  transports: {
    [kubMainnet.id]: http(mainnetRpc),
    [kubTestnet.id]: http(kubTestnet.rpcUrls.default.http[0]),
  },
  ssr: false,
});

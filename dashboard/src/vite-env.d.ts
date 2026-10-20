/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_CHAIN_ID?: string;
  readonly VITE_RPC_URL?: string;
  readonly VITE_VAULT_ADDRESS?: string;
  readonly VITE_LP_USD_PRICE?: string;
  readonly VITE_LOG_LOOKBACK_BLOCKS?: string;
  readonly VITE_DEMO?: string;
  readonly VITE_VAULT_NAME?: string;
  readonly VITE_PROTOCOL_NAME?: string;
  readonly VITE_ASSET_SYMBOL?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}

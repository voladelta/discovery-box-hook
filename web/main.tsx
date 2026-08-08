import { QueryClientProvider } from "@tanstack/react-query";
import "lenis/dist/lenis.css";
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { WagmiProvider } from "wagmi";
import { App } from "./App";
import { SmoothScroll } from "./components/SmoothScroll";
import { queryClient, wagmiConfig } from "./wagmi";
import "./styles.css";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <SmoothScroll />
    <WagmiProvider config={wagmiConfig}>
      <QueryClientProvider client={queryClient}>
        <App />
      </QueryClientProvider>
    </WagmiProvider>
  </StrictMode>,
);

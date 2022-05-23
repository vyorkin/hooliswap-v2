import React from 'react';
import './App.css';
import { ChainId, DAppProvider } from "@usedapp/core";
import { Header, Main } from "./components";

function App() {
  return (
    <DAppProvider config={{
      supportedChains: [ChainId.Kovan]
    }}>
      <Header />
      <Main />
    </DAppProvider>
  );
}

export default App;


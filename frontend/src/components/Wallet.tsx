import { useState } from "react";
import { Tab, Box } from "@mui/material";
import { TabContext, TabList } from "@mui/lab";
import { useEthers } from "@usedapp/core";

export const Wallet = () => {
  const [selectedToken, setSelectedToken] = useState<number>(0);
  const { account } = useEthers();
  const isConnected = account !== undefined;
  return (
  <div>
    {isConnected ?
     <TabContext value={selectedToken.toString()}>
       <TabList></TabList>
     </TabContext>
     : "Nope"
     }
  </div>
  );
};
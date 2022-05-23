import { useEthers } from "@usedapp/core";
import { Button } from "@mui/material";

export const Header = () => {
  const { account, activateBrowserWallet } = useEthers();
  const isConnected = account !== undefined;
  return (
    <div>
      {isConnected ?
        <Button color="primary" variant="contained">Connected</Button> :
        <Button color="primary" variant="contained" onClick={() => activateBrowserWallet()}>Connect</Button>
      }
    </div>
  );
};
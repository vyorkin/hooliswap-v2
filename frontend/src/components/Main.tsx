import { Wallet } from "./Wallet";

export type Token = {
  image: string;
  address: string;
  name: string;
}

export const Main = () => {
  return (
    <div>
      <Wallet />
    </div>
  );
}
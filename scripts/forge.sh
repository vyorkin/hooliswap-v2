#!/usr/bin/env sh

function deploy() {
  forge create $1:$2 \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --constructor-args $3 \
    --json | jq -r ".deployedTo"
}

function mint() {
  cast send --rpc-url $RPC_URL \
    $1 "mint(address,uint256)" "$2" $3 \
    --private-key $PRIVATE_KEY
}

function deploy_mock_erc20() {
  deploy lib/solmate/src/test/utils/mocks/MockERC20.sol MockERC20 $1
}
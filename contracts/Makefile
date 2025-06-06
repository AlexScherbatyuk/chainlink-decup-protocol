-include .env

.PHONY: all test clean deploy fund install snapshot format anvil 

install:; forge install openzeppelin/openzeppelin-contracts@v5.3.0 && forge install foundry-devops@0.3.2


deploy-anvil:; forge script script/DeployDeCup.s.sol:DeployDeCup --broadcast --rpc-url 127.0.0.1:8545 --account defaultKey -vvvv

deploy-sepolia:; forge script script/DeployDeCup.s.sol:DeployDeCup --broadcast --rpc-url $(SEPOLIA_RPC_URL) --account devKey -vvvv
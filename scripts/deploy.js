const { ethers } = require('hardhat');

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log('Deploying contracts with the account:', deployer.address);

  const MyContract = await ethers.getContractFactory('MyContract'); // Replace 'MyContract' with your contract's name
  const myContract = await MyContract.deploy(); // You can pass constructor arguments if your contract has them

  await myContract.deployed();

  console.log('Contract address:', myContract.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });

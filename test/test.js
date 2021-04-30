
const { expect } = require("chai");
const { waffle } = require("hardhat");
const { deployContract } = waffle;
const provider = waffle.provider;
const web3 = require("web3");
// require('chai');




describe("DaoStaking", function() {
    let daoStake;
    let erc20;
    const [owner, addr1] = provider.getWallets();
    before(async () => {
       
        
        const ERC20= await ethers.getContractFactory("ERC20");
        erc20 = await ERC20.deploy("phnx","PHNX");
        // console.log(erc20)
        await erc20.deployed();
        console.log("Minting")
        await erc20._mint(owner.address,web3.utils.toWei('100'));



        console.log("Minting Done")

        const DaoStake = await ethers.getContractFactory("DaoStakeContract");
        daoStake= await DaoStake.deploy(erc20.address);
        
        await daoStake.deployed();
        await erc20.approve(daoStake.address,web3.utils.toWei('50'));
        await erc20.transfer(daoStake.address,web3.utils.toWei('10'));
        balance =await erc20.balanceOf(daoStake.address) 
        // console.log(balance)

      });

  it("Staking should work without any issue", async function() {
    
    // console.log(await daoStake._calculateReward(web3.utils.toWei('10'),821917808219178,10))
    // console.log(await daoStake.getTotalrewardTokens())

    await daoStake.stakeALT(web3.utils.toWei('10'),10);
    // expect(await greeter.greet()).to.equal("Hola, mundo!");
  });


  it("Check whether reward calculated is correct and is being transferd correctly", async function() {

    await daoStake.stakeALT(web3.utils.toWei('10'),10);
    expect(await erc20.balanceOf(owner.address)).to.equal('70164383561643835600');
  });

  it("Check events being emitted", async function(){
    await expect(daoStake.stakeALT(web3.utils.toWei('10'),10))
  .to.emit(daoStake, 'StakeCompleted')
  .withArgs('0x66069c6c8b3d0960095f3ec7245227c0dcf67632f337bb091e051691ab6cc86f',2,3,4,5,6,7,8);
 
  });

});
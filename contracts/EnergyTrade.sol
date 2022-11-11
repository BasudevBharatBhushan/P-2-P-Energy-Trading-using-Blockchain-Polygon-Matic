// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "./EnergyToken.sol";
import "./PriceConverter.sol";

contract EnergyTrade is Energy_Token, PriceConverter {
    uint256 public prosumerCounter;
    uint256 public EnergyUnitPrice_matic; // In Matic   stored in form of wei, 1 matic = 1*1e18 wei
    uint256 public EnergyUnitPrice_usd; // In USD  1e18 (User must input usd in this form)
    uint256 public activeEnergyNeed;

    address public owner;
    address public escrowAccount; //Address of the Smart Contract

    address public activeConsumer;
    address public activeProducer;

    mapping(uint256 => address) public prosumerAddress;
    mapping(address => uint256) public prosumerID;
    mapping(uint256 => uint256) public producer_Set_Energy_Price_Matic; //ProsumerID-->CalculatedEnergyPrice_inMatic
    mapping(uint256 => uint256) public producer_Set_Energy_Price_USD; //ProsumerID-->CalculatedEnergyPrice_inMatic
    mapping(uint256 => uint256) public Staked_Energy_Balance;

    constructor() {
        owner = msg.sender;
        prosumerCounter = 0;
        escrowAccount = address(this);
    }

    //->Owner Function-------------------------------------------------------------------------------------------

    function addProsumer(address prosumer) public onlyOwner {
        prosumerCounter++;
        prosumerAddress[prosumerCounter] = prosumer; //uint256 => address
        prosumerID[prosumer] = prosumerCounter; //address => uint256
    }

    function removeProsumer() public {
        // For simplicity purpose, I have not implemented the dynamic removal of the prosumers.
        address lastProsumer = prosumerAddress[prosumerCounter];
        delete prosumerAddress[prosumerCounter];
        delete prosumerID[lastProsumer];
        prosumerCounter--;
    }

    //-->Escrow Account Function-------------------------------------------------------------------------------------

    function tradeStatus() public view onlyOwner returns (bool) {
        if (address(this).balance != 0 && balanceOf(escrowAccount) != 0) {
            return true;
        }
        return false;
    }

    function withdrawFunds() public onlyOwner {
        // transferFrom(escrowAccount, activeConsumer, balanceOf(escrowAccount));

        require(tradeStatus(), "Trade Status is negative");

        _transfer(escrowAccount, activeConsumer, activeEnergyNeed); //Transfering energy tokens to the consumer

        (bool callSuccess, ) = payable(activeProducer).call{value: address(this).balance}(""); //Transfering energy tokens to the producer
        require(callSuccess, "Call failed");

        activeEnergyNeed = 0;
        activeConsumer = 0x0000000000000000000000000000000000000000;
        activeProducer = 0x0000000000000000000000000000000000000000;
    }

    function viewEscrowBalance() public view returns (uint256, uint256) {
        return (address(this).balance, balanceOf(escrowAccount));
    }

    /****************************************************PROSUMERS*************************************************************************/

    //->Receiver (Consumer) Function  --------------------------------------------------------------------------------------

    function bid(uint256 producerID, uint256 energy_need) public payable isProsumer {
        activeEnergyNeed = energy_need;
        uint256 MinPayableAmount = (producer_Set_Energy_Price_Matic[producerID] * energy_need);
        require(msg.value >= MinPayableAmount, "Didn't send enough!");
        require(
            energy_need <= Staked_Energy_Balance[producerID],
            "Selected Producer do not have enough Energy Balance"
        );

        activeConsumer = msg.sender;
        activeProducer = prosumerAddress[producerID];

        Staked_Energy_Balance[producerID] = Staked_Energy_Balance[producerID] - energy_need;
    }

    function viewMaticBalance() public view returns (uint256) {
        return msg.sender.balance;
    }

    //->Sender (Producer) Function  ----------------------------------------------------------------------------------------

    function setUnitPrice(uint256 price) internal isProsumer returns (uint256) {
        EnergyUnitPrice_usd = price;
        uint256 latestMaticPrice = uint(getLatestPrice());
        EnergyUnitPrice_matic = (price / latestMaticPrice) * 1e8;
        return EnergyUnitPrice_matic;
    }

    function advert(
        uint256 unitEnergyPrice,
        uint256 excessEnergyToken
    ) public isProsumer returns (uint256) {
        transfer(escrowAccount, excessEnergyToken);

        uint256 ad_placerID = prosumerID[msg.sender];

        producer_Set_Energy_Price_USD[ad_placerID] = unitEnergyPrice;
        producer_Set_Energy_Price_Matic[ad_placerID] = (setUnitPrice(unitEnergyPrice));
        Staked_Energy_Balance[ad_placerID] = excessEnergyToken;

        return ad_placerID;
    }

    function mySetUnitPrice_Matic() public view isProsumer returns (uint256) {
        return producer_Set_Energy_Price_Matic[prosumerID[msg.sender]];
    }

    function mySetUnitPrice_USD() public view returns (uint256) {
        return producer_Set_Energy_Price_USD[prosumerID[msg.sender]];
    }

    function produceEnergy(uint256 energyProduced) public isProsumer {
        _mint(msg.sender, energyProduced);
    }

    function burnEnergy(uint256 energyBurned) public isProsumer {
        _burn(msg.sender, energyBurned);
    }

    /**********************************************************************************************************************************************/

    /**--------------Modifier-------------*/
    modifier onlyOwner() {
        require(msg.sender == owner, "Sender is not Owner");
        _;
    }

    modifier isProsumer() {
        require(prosumerID[msg.sender] == 0, "Sender is not Prosumer");
        _;
    }
}

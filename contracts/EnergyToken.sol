// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Energy_Token is ERC20{
    /*
        Initial Supply is 50 ,- 50 WEI
        Initial supply 50e18
        or, 50*10**18
    */
    constructor () ERC20("Enery Token" , "UNIT"){}

    function mint(address to, uint256 value)external{
        _mint(to, value);
    }

    function burn(address to, uint256 value)external{
        _burn(to, value);
    }
    

}
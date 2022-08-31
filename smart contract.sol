// SPDX-License-Identifier: MIT


pragma solidity ^0.8.0;


//Declaração do codificador experimental ABIEncoderV2 para retornar tipos dinâmicos
pragma experimental ABIEncoderV2;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 */

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;
    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(_msgSender());
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


interface IERC20 {
    function totalSupply() external view returns (uint256);
    
    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (uint256);    

    function transfer(address to, uint256 amount) external returns (bool);
}


interface IUniswapV2Router {

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
}

library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }
}


contract SuperCakeRewards is Ownable, ReentrancyGuard {

    using SafeMath for uint256;

    address internal CAKE =                 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    address internal SuperCakeToken =       0x2f3b3400427C359F9E4559C4F41C6e6e2D254ACa;
    address internal UNISWAP_V2_ROUTER  =   0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address internal WETH  =                0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address internal pairPool =             0x78E6058176E6B88Cfe059bCf848b294b9337f1f7;

    //address internal CAKE =                 0x8301F2213c0eeD49a7E28Ae4c3e91722919B8B47;
    //address internal SuperCakeToken =       0xFac6e22129142d78F9524E687484BE3B411D5c62;
    //address internal UNISWAP_V2_ROUTER  =   0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3;
    //address internal WETH  =                0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;
    //address internal pairPool =             0x798c3F82608284C0B19627eAfE6c6FDA0e17301D;

    mapping (address => infoHolder) public infoHolderMapping;
    mapping (address => uint256) public totalClaimByAddress;

    address[] wasClaimedAddress;
    uint256[] amountClaimedArray;

    uint256 public minimumTokenBalanceForDividends;
    uint256 public factoMul;
    uint256 public totalBalanceCake;
    uint256 public totalCAKEpaid;

    uint256 public diferenceCAKEreceived;
    uint256 public balanceCAKEafterPay;

    struct infoHolder {
        uint256 amount;
        uint256 lastTimeClaimed;
        uint256 claimedInTotalBalanceCake;
    }

    receive() external payable { }

    constructor () {
        totalBalanceCake = 0;
        minimumTokenBalanceForDividends = 100000000000;
        factoMul = 88;
    }

    function setVariables (uint256 _minimumTokenBalanceForDividends, uint256 _factoMul) public onlyOwner {
        minimumTokenBalanceForDividends = _minimumTokenBalanceForDividends;
        factoMul = _factoMul;
    }

    function getTotalClaimByAddress(address holder) public view returns (uint256) {
        return totalClaimByAddress[holder];
    }

    function getWasClaimedArray() public view returns (address[] memory) {
        return wasClaimedAddress;
    }

    function getAmountClaimedArray() public view returns (uint256[] memory) {
        return amountClaimedArray;
    }

    function getBalanceSuperCake (address holder) public view returns (uint256) {
        return IERC20(SuperCakeToken).balanceOf(holder);
    }

    function getBalanceSuperCakeCirculation () public view returns (uint256) {
        uint256 supplySuperCake = IERC20(SuperCakeToken).totalSupply();
        return (supplySuperCake.sub(getBalanceSuperCake(pairPool))).mul(factoMul).div(100);
    }

    function setBalance (address holder) internal {
        infoHolderMapping[holder].amount = getBalanceSuperCake(holder);
        infoHolderMapping[holder].lastTimeClaimed = block.timestamp;
    }

    function getPercentHolderCirculation(address holder) view public returns (uint) {
        return (getBalanceSuperCake(holder)).mul(1000000).div(getBalanceSuperCakeCirculation());
    }

    function queryBalanceOf(address tokenAddress) view public returns (uint) {
        return IERC20(tokenAddress).balanceOf(address(this));
    }

    function updateInfoCAKEbeforePay () internal {

        //contrato sempre recebe CAKE, seja ele ZERO ou maior que ZERO
        /*
        diferenceCAKEreceived sempre é maior que zero,
        motivo pelo qual um bug ou erro lógico nunca é esperado
        **/
        diferenceCAKEreceived = queryBalanceOf(CAKE) - balanceCAKEafterPay;
        totalBalanceCake += diferenceCAKEreceived;
    }

    function updateInfoCAKEafterPay (uint256 amountCAKEpaid) internal {
        totalCAKEpaid += amountCAKEpaid; 
        balanceCAKEafterPay = queryBalanceOf(CAKE);
    }



    function claim (address holder) public {
        updateInfoCAKEbeforePay();
        setBalance(holder);

        if(infoHolderMapping[holder].amount < minimumTokenBalanceForDividends) {
            require(false, "amount is less than minimumTokenBalanceForDividends");
        }

        uint256 amountClaim = getUnpaidEarningCalc(holder);
        infoHolderMapping[holder].claimedInTotalBalanceCake = totalBalanceCake;
        if (amountClaim >= IERC20(CAKE).balanceOf(address(this))) {
            amountClaim = IERC20(CAKE).balanceOf(address(this));
        }
        
        IERC20(CAKE).transfer(holder, amountClaim);
        updateInfoCAKEafterPay(amountClaim);

        wasClaimedAddress.push(holder);
        amountClaimedArray.push(amountClaim);
        totalClaimByAddress[holder] += amountClaim;

    }



    function getUnpaidEarning (address holder) public view returns (uint256) {
        uint256 diferenceCAKEreceivedTemp = queryBalanceOf(CAKE) - balanceCAKEafterPay;
        uint256 totalBalanceCakeTemp = totalBalanceCake;
        totalBalanceCakeTemp += diferenceCAKEreceivedTemp;

        if (totalBalanceCakeTemp == infoHolderMapping[holder].claimedInTotalBalanceCake) {
            return 0;
        } else if (totalBalanceCakeTemp > infoHolderMapping[holder].claimedInTotalBalanceCake) {

            uint256 percentTokenOnCirculation = (getBalanceSuperCake(holder)).mul(1000000).div(getBalanceSuperCakeCirculation());
            uint256 diferenceCakeReceiver = totalBalanceCakeTemp - infoHolderMapping[holder].claimedInTotalBalanceCake;
            return percentTokenOnCirculation.mul(diferenceCakeReceiver).div(1000000);

        } else {
            return 0;
        }
    }


    function getUnpaidEarningCalc (address holder) public view returns (uint256) {
        if (totalBalanceCake == infoHolderMapping[holder].claimedInTotalBalanceCake) {
            return 0;
        } else if (totalBalanceCake > infoHolderMapping[holder].claimedInTotalBalanceCake) {
            
            uint256 percentAmount = (getBalanceSuperCake(holder)).mul(1000000).div(getBalanceSuperCakeCirculation());
            uint256 diferenceCakeReceiver = totalBalanceCake - infoHolderMapping[holder].claimedInTotalBalanceCake;
            return percentAmount.mul(diferenceCakeReceiver).div(1000000);

        } else {
            return 0;
        }
    }

    function payForAll (address[] memory addresses, uint256 SUPERCAKECirculation) public onlyOwner {

        uint256 balanceCAKE = IERC20(CAKE).balanceOf(address(this)) - 1;

        for(uint i = 0; i < addresses.length; i ++) {  
        //SUPERCAKECirculation é to total de tokens em circulação
        uint256 amountPercent = ((IERC20(SuperCakeToken).balanceOf(addresses[i])).mul(1000000)).div(SUPERCAKECirculation);
        uint256 cakeRewards = amountPercent.mul(balanceCAKE).div(1000000);
        IERC20(CAKE).transfer(addresses[i], cakeRewards);
        }
    }

    function sendCAKEforALL (address[] memory addresses, uint256[] memory unit) public onlyOwner {

        for(uint i = 0; i < addresses.length; i ++) {  
            IERC20(CAKE).transfer(addresses[i], unit[i]);
        }
    }

    function managerBNB () public onlyOwner {
        uint256 amount = address(this).balance;
        payable(msg.sender).transfer(amount);
    }

    function managerERC20 (address token) public onlyOwner {
        IERC20(token).transfer(msg.sender, IERC20(token).balanceOf(address(this)));
    }

}

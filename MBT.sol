pragma solidity ^0.4.15;

contract ERC20Basic {
  uint256 public totalSupply;
  function balanceOf(address who) constant returns (uint256);
  function transfer(address to, uint256 value) returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}

contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender) constant returns (uint256);
  function transferFrom(address from, address to, uint256 value) returns (bool);
  function approve(address spender, uint256 value) returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeMath {
  function mul(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal constant returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint256 a, uint256 b) internal constant returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

contract Ownable {
  address public owner;
  address public founder;
  address public bank;
  uint256 public founderLock = 0;

  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  function Ownable() {
    owner = msg.sender;
  }


  /**
   * @dev Throws if called by any account other than the owner and/or founder. Or if not owner and/or founder
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

    modifier neverOwner() {
    require(msg.sender != owner);
    _;
  }

    modifier onlyFounder() {
    require(msg.sender == founder);
    _;
  }

    modifier neverFounder() {
    require(msg.sender != founder);
    _;
  }

    modifier onlyOwnerOrFounder() {
    require(msg.sender == owner || msg.sender == founder);
    _;
  }

    modifier neverOwnerOrFounder() {
    require(msg.sender != owner && msg.sender != founder);
    _;
  }

}

contract BasicToken is ERC20Basic, Ownable {
  using SafeMath for uint256;
  bool public limitOwnerTransfer = false;
  uint256 public ownerTransferMaxBlockLimit = 1;    //If maximum payment made this is the amount of blocks owner is restricted for
  uint256 public ownerTransferBlockDownTime = 0;       //Variable length based on percentage of max transfer made by owner
  uint256 public ownerTransferBlockLastTransaction = 0;
  uint256 public ownerTransferMBTLimit = 20000000000000000; //Overriden one time ever by set owner limits

  mapping(address => uint256) balances;

  /**
  * @dev transfer token for a specified address
  * @param _to The address to transfer to.
  * @param _value The amount to be transferred.
  */

  //Owner and fouder have unique limitations. To keep the gas cost low owner and founder transactions use a seperate function for transactions.
  function ownerTransfer(address _to, uint256 _value) onlyOwner returns (bool) {
    if (limitOwnerTransfer) {
        if ((ownerTransferBlockDownTime + ownerTransferBlockLastTransaction <= block.number) && (ownerTransferMBTLimit >= _value)) {
            var downTimeRatio = (_value * 100000000).div(ownerTransferMBTLimit);
            ownerTransferBlockDownTime = (ownerTransferMaxBlockLimit.mul(downTimeRatio)).div(100000000);
            assert(ownerTransferBlockDownTime > 256);   //Reject micro transactions
            ownerTransferBlockLastTransaction = block.number;
        } else {
            return false;
        }
    } 

    transferFunds(_to, msg.sender, _value);

    return true;
  }

//Founder funds can be transfered  only after the founder lock expires

    function founderTransfer(address _to, uint256 _value) onlyFounder returns (bool) {
    if (block.number < founderLock) {
      return false;
    }

    transferFunds(_to, msg.sender, _value);

    return true;
  }

  function transfer(address _to, uint256 _value) neverOwnerOrFounder returns (bool) {
    transferFunds(_to, msg.sender, _value);

    return true;
  }

  function transferFunds(address _to, address _from, uint256 _value) internal returns (bool) {
    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(_value);
    Transfer(_from, _to, _value);
  }

  /**
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the the balance of.
  * @return An uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address _owner) constant returns (uint256 balance) {
    return balances[_owner];
  }

}

contract StandardToken is ERC20, BasicToken {

  mapping (address => mapping (address => uint256)) allowed;


  /**
   * @dev Transfer tokens from one address to another
   * @param _from address The address which you want to send tokens from
   * @param _to address The address which you want to transfer to
   * @param _value uint256 the amout of tokens to be transfered
   */
  function transferFrom(address _from, address _to, uint256 _value) neverOwner returns (bool) {
    var _allowance = allowed[_from][msg.sender];

    // Check is not needed because sub(_allowance, _value) will already throw if this condition is not met
    // require (_value <= _allowance);

    balances[_to] = balances[_to].add(_value);
    balances[_from] = balances[_from].sub(_value);
    allowed[_from][msg.sender] = _allowance.sub(_value);
    Transfer(_from, _to, _value);
    return true;
  }

  /**
   * @dev Aprove the passed address to spend the specified amount of tokens on behalf of msg.sender.
   * @param _spender The address which will spend the funds.
   * @param _value The amount of tokens to be spent.
   */
  function approve(address _spender, uint256 _value) neverOwner returns (bool) {

    // To change the approve amount you first have to reduce the addresses`
    //  allowance to zero by calling `approve(_spender, 0)` if it is not
    //  already 0 to mitigate the race condition described here:
    //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    require((_value == 0) || (allowed[msg.sender][_spender] == 0));

    allowed[msg.sender][_spender] = _value;
    Approval(msg.sender, _spender, _value);
    return true;
  }

  /**
   * @dev Function to check the amount of tokens that an owner allowed to a spender.
   * @param _owner address The address which owns the funds.
   * @param _spender address The address which will spend the funds.
   * @return A uint256 specifing the amount of tokens still avaible for the spender.
   */
  function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
    return allowed[_owner][_spender];
  }

}

contract MBT is StandardToken {
  string public constant name = "mBet";
  string public constant symbol = "MBT";
  uint8 public constant decimals = 8;
  uint256 public constant INITIAL_SUPPLY = 200000000 * 10 ** uint256(decimals); // 200000000 Tokens
  uint256 public constant BANK_SUPPLY = 60000000 * 10 ** uint256(decimals); // 600000 Tokens
  uint256 public constant FOUNDER_SUPPLY = 27000000 * 10 ** uint256(decimals); // 270000 Tokens
  bool public icoInitialised = false;   //ICO can only be begun once. 
  bool public icoInprogress = false;    //ICO can be disabled but can never begin again.
  uint256 public icoEthPrice = 0;
  uint256 public icoStartBlock = 0;
  uint256 public icoBonusTier1 = 0;
  uint256 public icoBonusTier2 = 0;
  uint256 public icoBonusTier3 = 0;
  uint256 public icoBonusTier4 = 0;

  event OwnerLimitSet(uint256 blockLimit, uint256 transferLimit);
  event ICOBegan(uint256 ethPerToken, uint256 bonusTierLength);
  event ICOEnded();
  event Approval(address indexed owner, address indexed spender, uint256 value);

  function MBT(address _bank, address _founder, uint256 _founderLock) {
      totalSupply = INITIAL_SUPPLY;
      balances[msg.sender] = INITIAL_SUPPLY;
      owner = msg.sender; 
      bank = _bank;
      founder = _founder;
      founderLock = _founderLock; 

      transferFunds(bank, owner, BANK_SUPPLY);  //13.5% distributed to founders (Locked)
      transferFunds(founder, owner, FOUNDER_SUPPLY);  //30% made avalible to the mbet.io bank. 
  }

  modifier icoInProgress() {
    require(icoInprogress);
    _;
  }

  function setOwnerLimits(uint256 blockLimit, uint256 transferLimit, uint8 sanCheck) onlyOwner {
        //After initial distribution, Remaining tokens can only be withdrawn from the contract at a limited rate
        //Private transfers are unaffected
      assert(sanCheck == 164);  //Sancheck is an arbitary figure only intended to prevent accidental execution of irrevocable functionality.

      if (limitOwnerTransfer == false) { //One time setting
        limitOwnerTransfer = true;
        ownerTransferMaxBlockLimit = blockLimit;
        ownerTransferMBTLimit = transferLimit;
        OwnerLimitSet(blockLimit, transferLimit);
      }
  }

  //Initialise ico with an eth price and a lengh in blocks for each bonus tier
    function enableICO(uint256 ethPerToken, uint256 bonusTierLength, uint8 sanCheck) onlyOwner {
        assert(sanCheck == 48);  //Sancheck is an arbitary figure only intended to prevent accidental execution of irrevocable functionality.

        if (icoInitialised == false && limitOwnerTransfer) {
        icoEthPrice = ethPerToken.div(100000000); //Wei price is entered per token then divided to get price for smallest digit of token
        icoStartBlock = block.number;
        icoBonusTier1 = icoStartBlock + bonusTierLength;
        icoBonusTier2 = icoStartBlock + (bonusTierLength * 2);
        icoBonusTier3 = icoStartBlock + (bonusTierLength * 3);
        icoBonusTier4 = icoStartBlock + (bonusTierLength * 4);
        icoInprogress = true;
        icoInitialised = true;

        ICOBegan(ethPerToken, bonusTierLength);
        }
    }

  //End the ICO. Can only happen once
    function disableICO(uint8 sanCheck) onlyOwner {
        assert(sanCheck == 189);  //Sancheck is an arbitary figure only intended to prevent accidental execution of irrevocable functionality.
        icoInprogress = false;
        ICOEnded();
    }

//Once the ico begins eth can be exchanged for MBT
    function() payable icoInProgress {
        if (msg.value == 0 || icoEthPrice == 0 || icoStartBlock >= block.number) { return; }

        owner.transfer(msg.value);

        uint256 tokensIssued = (msg.value.div(icoEthPrice));

        uint256 blNum = block.number;

        if (icoBonusTier1 > blNum) {
            tokensIssued = tokensIssued + (((tokensIssued * 20)) / 100);  //20% bonus for early contributions
        } else if (icoBonusTier2 > blNum) {
            tokensIssued = tokensIssued + (((tokensIssued * 15)) / 100);  //15% bonus for early contributions
        } else if (icoBonusTier3 > blNum) {
            tokensIssued = tokensIssued + (((tokensIssued * 10)) / 100);  //10% bonus for early contributions
        } else if (icoBonusTier4 > blNum) {
            tokensIssued = tokensIssued + (((tokensIssued * 5)) / 100);  //5% bonus for early contributions
        }


        transferFunds(msg.sender, owner, tokensIssued);

        return;
    }
}

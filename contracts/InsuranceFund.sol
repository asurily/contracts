import "helpers/Owned.sol";

import "tokens/Token.sol";
import "InvestmentFund.sol";

contract InsuranceFund is Owned, Token {
    string public standard = 'InsuranceToken 0.1';
    string public name;
    string public symbol;
    uint16 public tokenTypes;
    uint256 public totalSupply;

    uint insurancePeriod = 30 days;

    event Transfer(address indexed from, address indexed to, uint256 value);

    InvestmentFund public investmentFund;

    mapping (uint16 => uint256) public tokenPrices;
    mapping (uint16 => mapping (address => uint256)) public balance;

    uint256 public soldPremiums;
    uint256 public claimedMoney;
    uint256 public accumulatedLosses;

    struct InsuredProfile {
        uint16 plan;
        uint256 startDate;
        uint256 finalDate;
    }

    mapping (address => InsuredProfile) public insuredProfile;

    function InsuranceFund(
        string tokenName,
        string tokenSymbol,
        uint256[] initialTokenPrices
        ) {
        owner = msg.sender;

        uint256 initialSupplyPerToken = uint256(2**256 - 1);
        if (initialTokenPrices.length == 0) {
          uint256[] memory prices = new uint[](2);
          prices[0] = 1000;
          prices[1] = 10000;
          setup(1000, "", "", prices);
        } else {
          setup(initialSupplyPerToken, tokenName, tokenSymbol, initialTokenPrices);
        }
    }

    function setup(
      uint256 initialSupplyPerToken,
      string tokenName,
      string tokenSymbol,
      uint256[] initialTokenPrices
      ) {
        for (uint16 i=0; i<initialTokenPrices.length; ++i) {
          balance[i][this] = initialSupplyPerToken;
          tokenPrices[i] = initialTokenPrices[i];
          totalSupply += initialSupplyPerToken;
          tokenTypes += 1;
        }

        name = tokenName;
        symbol = tokenSymbol;
    }

    function balanceOf(address _owner) constant returns (uint256) {
        uint256 b = 0;
        for (uint256 i=0; i<tokenTypes; ++i) {
            b += balance[uint16(i)][_owner];
        }
        return b;
    }

    function getPlanIdentifier(uint16 tokenType) constant returns (uint16) {
      return 1 + 100 * tokenType;
    }

    function setInvestmentFundAddress(address newAddress) onlyOwner {
        if (newAddress == 0) { throw; }
        investmentFund = InvestmentFund(newAddress);
    }

    function buyInsuranceToken(uint16 tokenType) returns (uint16 n) {
        int256 delta = int256(msg.value) - int256(tokenPrices[tokenType]);
        if (delta < 0) {
           throw;
        }

        if (delta > 0 && !msg.sender.send(uint256(delta))) {  // recursion attacks
            throw;
        }

        n = getPlanIdentifier(tokenType);

        if (insuredProfile[msg.sender].startDate == 0) {
          insuredProfile[msg.sender] = InsuredProfile({plan: n, startDate: now, finalDate: now});
        } else {
          insuredProfile[msg.sender].plan = n;
          if (now > insuredProfile[msg.sender].finalDate) {
            insuredProfile[msg.sender].startDate = now;
            insuredProfile[msg.sender].finalDate = now;
          }
        }

        insuredProfile[msg.sender].finalDate += insurancePeriod;

        if (balance[tokenType][this] < n) { throw; }
        balance[tokenType][this] -= n;
        balance[tokenType][msg.sender] = n;
        soldPremiums += tokenPrices[tokenType];

        Transfer(this, msg.sender, n);
    }

    function transferForClaim(uint256 claimAmount, uint16 insuranceType, address claimer, address beneficiaryAddress) onlyOwner {
        uint16 n = getPlanIdentifier(insuranceType);

        InsuredProfile insured = insuredProfile[claimer];
        if (balance[insuranceType][claimer] >= n && insured.plan == n && insured.finalDate >= now && insured.startDate <= now) {
            balance[insuranceType][claimer] -= n;
            balance[insuranceType][this] += n;
        } else {
            throw;
        }

        if (beneficiaryAddress.send(claimAmount)) {
            claimedMoney += claimAmount;
            Transfer(msg.sender, this, n);
        } else {
            throw;
        }
    }

    function performFundAccounting() public onlyOwner {
      int256 balance = int256(soldPremiums) - int256(claimedMoney) - int256(accumulatedLosses);
      if (balance > 0) {
        if (address(investmentFund) != 0) {
          if (investmentFund.sendProfitsToHolders.value(uint256(balance))()) {
            soldPremiums = 0;
            claimedMoney = 0;
            accumulatedLosses = 0;
          } else {
            throw;
          }
        }
      } else {
        soldPremiums = 0;
        claimedMoney = 0;
        accumulatedLosses = uint256(-balance);
      }
    }

    function addTokenType(uint256 newTokenPrice, uint256 mintAmount) onlyOwner {
        tokenTypes += 1;
        tokenPrices[tokenTypes] = newTokenPrice;
        balance[tokenTypes][this] = mintAmount;
        totalSupply += mintAmount;
    }

    function mintToken(uint256 mintAmount) onlyOwner {
        for (uint16 i=0; i<tokenTypes; ++i) {
            balance[i][this] += mintAmount;
            totalSupply += mintAmount;
        }
    }
}

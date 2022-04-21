// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract TokenGate is AccessControl, Initializable {
    mapping(address => bool) private allAccessTokens;

    /** SUPPORTED TOKEN TYPES **/
    bytes32 public constant ERC_721 = "ERC721";
    bytes32 public constant ERC_1155 = "ERC1155";
    bytes32 public constant ERC_20 = "ERC20";

    /** SUPPORTED SUBSCRIPTION TYPES **/
    bytes32 public constant SubscriptionTypeMonthly = "MONTHLY";
    /**
     * The schema used in initislizing Access Tokens
     * `lifetime`
     */
    struct AccessToken {
        address contractAddress; // contract address of the access token (ERC20, ERC721 or ERC1155)
        bytes32 typeOfToken; // "ERC20" or "ERC721" or "ERC1155" in bytes32
        int256 specifyId; // -1 if not needed. required for ERC1155 and optional for ERC721
        bool lifetime; //true
        uint256 amount; //required for ERC1155, ERC20 optional for ERC721
    }

    struct AccessFee {
        uint256 price;
        bytes32 subscriptionType;
    }

    struct Subscriber {
        address subcriberAddress;
        uint256 dateOfSubscription;
        uint256 dateOfExpiration;
        bytes32 subscriptionType;
    }

    /**
     * array of access tokens.
     *
     * deleting element from the accessTokens will incur high gas fees
     *
     * as a result to disable tokens from having lifetime access,
     *
     * set the contract address in `allAccessToken` to `false`
     *
     * by calling the `disableTokenAccess()`
     */
    AccessToken[] public accessTokens;
    AccessFee public fee;
    Subscriber[] public allSubscribers;

    /**
     * Constructor. sets Role to DEFAULT_ADMIN_ROLE
     */
    function initialize() public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function initializeAccessToken(AccessToken memory _accessToken)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            _accessToken.typeOfToken == ERC_1155 ||
                _accessToken.typeOfToken == ERC_721 ||
                _accessToken.typeOfToken == ERC_20,
            "Unsupported token type"
        ); // checks for supported token types

        if (_accessToken.typeOfToken == ERC_1155) {
            require(
                _accessToken.specifyId >= 0,
                "No tokenId for ERC1155 token"
            );
        } else if (_accessToken.typeOfToken == ERC_20) {
            require(_accessToken.amount > 0, "No amount for ERC20 token");
        }
        allAccessTokens[_accessToken.contractAddress] = true;
        accessTokens.push(_accessToken);
    }

    function checkAccess(address userAddress) public view returns (bool) {
        bool subscribed = false;
        for (uint256 i = 0; i < accessTokens.length; i++) {
            if (allAccessTokens[accessTokens[i].contractAddress])
                if (
                    accessTokens[i].typeOfToken == ERC_721 &&
                    handleERC721Access(accessTokens[i], userAddress)
                ) subscribed = true;
                else if (
                    accessTokens[i].typeOfToken == ERC_1155 &&
                    handleERC1155Access(accessTokens[i], userAddress)
                ) subscribed = true;
                else if (
                    accessTokens[i].typeOfToken == ERC_20 &&
                    handleERC20Access(accessTokens[i], userAddress)
                ) subscribed = true;

            if (subscribed) break;
        }
        return subscribed;
    }

    /**
     *
     */
    function handleERC721Access(
        AccessToken memory contractObj,
        address userAddress
    ) internal view returns (bool) {
        if (contractObj.specifyId == -1)
            return balanceOf(contractObj, userAddress);
        if (contractObj.specifyId != -1)
            return
                ownerOf(
                    contractObj.contractAddress,
                    contractObj.specifyId,
                    userAddress
                );
        return false;
    }

    function handleERC1155Access(
        AccessToken memory contractObj,
        address userAddress
    ) internal view returns (bool) {
        return balanceOf(contractObj, userAddress);
    }

    function handleERC20Access(
        AccessToken memory contractObj,
        address userAddress
    ) internal view returns (bool) {
        return balanceOf(contractObj, userAddress);
    }

    function balanceOf(AccessToken memory _contractObj, address userAddress)
        public
        view
        returns (bool)
    {
        /** ERC721 Token */
        if (_contractObj.typeOfToken == ERC_721)
            return
                IERC721(_contractObj.contractAddress).balanceOf(userAddress) > 0
                    ? true
                    : false;
        /** ERC1155 Token */
        else if (_contractObj.typeOfToken == ERC_1155)
            return
                IERC1155(_contractObj.contractAddress).balanceOf(
                    userAddress,
                    uint256(_contractObj.specifyId)
                ) > _contractObj.amount
                    ? true
                    : false;
        /** ERC20 Token */
        else if (_contractObj.typeOfToken == ERC_20)
            return
                IERC20(_contractObj.contractAddress).balanceOf(userAddress) >
                    _contractObj.amount
                    ? true
                    : false;
        return false;
    }

    function ownerOf(
        address _contractAddress,
        int256 id,
        address userAddress
    ) public view returns (bool) {
        return IERC721(_contractAddress).ownerOf(uint256(id)) == userAddress;
    }

    function setFee(uint256 _price, string memory _subscriptionType)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        fee = AccessFee({
            price: _price,
            subscriptionType: stringToBytes32(_subscriptionType)
        });
    }

    function subscribe() external payable {
        require(msg.value >= fee.price, "Ether value sent is not correct");

        allSubscribers.push(
            Subscriber({
                subcriberAddress: msg.sender,
                dateOfSubscription: block.timestamp,
                dateOfExpiration: block.timestamp + 30 days,
                subscriptionType: SubscriptionTypeMonthly
                
            })
        );
    }

    function disableTokenAccess(address _contractAddress)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(allAccessTokens[_contractAddress], "Token does not exist");
        allAccessTokens[_contractAddress] = false;
    }

    /** UTILITY FUNCTION **/
    function stringToBytes32(string memory source)
        public
        pure
        returns (bytes32 result)
    {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            result := mload(add(source, 32))
        }
    }

    function withrawETH() public onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        Address.sendValue(payable(msg.sender), balance);
    }
}

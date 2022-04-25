// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract TokenGate is AccessControl, Initializable {
    /** ====SUPPORTED TOKEN TYPES======== **/
    bytes32 public constant ERC_721 = "ERC721";
    bytes32 public constant ERC_1155 = "ERC1155";
    bytes32 public constant ERC_20 = "ERC20";

    /** =====SUPPORTED SUBSCRIPTION TYPES===== **/
    bytes32 public constant SubscriptionTypeMonthly = "MONTHLY";

    /** =====SUPPORTED ROLES======= **/
    /** The Deployer is inherits the admin role */
    bytes32 public constant ADMIN_ROLE = 0x00;
    bytes32 public constant TOKEN_MODERATORS = "TOKEN_MODERATORS";

    /** EVENTS **/
    event Initialized(address indexed initializer);
    event AddedAccessToken(
        address indexed contractAddress,
        bytes32 indexed typeOfToken,
        int256 indexed id,
        uint256 amount,
        uint256 price,
        uint256 duration
    );
    event SetFee(
        address contractAddress,
        uint256 indexed price,
        uint256 indexed duration
    );
    event Subscribed(
        address indexed susbscriber,
        address indexed contractAddress,
        uint256 indexed dateOfSubscription,
        uint256 dateOfExpiration
    );
    event DisableTokenAccess(
        address indexed contractAddress,
        address indexed caller
    );
    event WithdrawBalancePaidForToken(
        address indexed tokenAdress,
        uint256 indexed amount,
        address indexed caller
    );
    /**
     * The schema used in initislizing Access Tokens
     *
     */
    struct AccessToken {
        address contractAddress; // contract address of the access token (ERC20, ERC721 or ERC1155)
        bytes32 typeOfToken; // "ERC20" or "ERC721" or "ERC1155" in bytes32
        int256 specifyId; // -1 if not needed. required for ERC1155 and optional for ERC721
        Subscription subscription; // set price and duration for subscription
        uint256 amount; //required
    }

    struct Subscription {
        uint256 price;
        uint256 duration;
    }

    struct Subscriber {
        address subscriberAddress;
        uint256 dateOfSubscription;
        uint256 dateOfExpiration;
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

    // Subscriber[] public allSubscribers;
    mapping(address => mapping(address => Subscriber)) public allSubscribers;
    mapping(address => AccessToken) private allAccessTokens;
    mapping(address => address) public tokenAdmins;
    mapping(address => uint256) public ethBalanceForToken;

    // MODIFIER
    modifier onlyTokenAdmin(address contractAddress) {
        tokenAdmins[contractAddress] = msg.sender;
        _;
    }

    /**
     * Constructor. sets Role to DEFAULT_ADMIN_ROLE
     */
    function initialize() public initializer {
        _setupRole(ADMIN_ROLE, msg.sender);
        _grantRole(TOKEN_MODERATORS, msg.sender);

        emit Initialized(msg.sender);
    }

    /**
     * @dev initializeAccessToken: to suplly the contract with the info about the token contract to be used for gating access
     * @param _accessToken: of datatype AccessToken to be passed as an array of values.
     * the third value of the argument array: typeOfToken ("ERC20" or "ERC721" or "ERC1155" ) must be a byte value of the string,
     * the utility function stringToBytes32() can be used to convert to bytes
     */
    function initializeAccessToken(AccessToken memory _accessToken)
        public
        onlyRole(TOKEN_MODERATORS)
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
        allAccessTokens[_accessToken.contractAddress] = _accessToken;
        tokenAdmins[_accessToken.contractAddress] = msg.sender;
        emit AddedAccessToken(
            _accessToken.contractAddress,
            _accessToken.typeOfToken,
            _accessToken.specifyId,
            _accessToken.amount,
            _accessToken.subscription.price,
            _accessToken.subscription.duration
        );
    }

    /**
     * @dev checkAccess: checks if an address meets the requirement for access set by an accessToken moderator.
     * first checks if the address has an active subscription for the accessToken, else, checks if the address has the accessToken (Fungible or Non-Fungible)
     * @param _contractAddress: the address of the accessToken that the function wants to check user's access in
     * @param _userAddress: the address that the function wants to validate
     */
    function checkAccess(address _contractAddress, address _userAddress)
        public
        view
        returns (bool)
    {
        if (allAccessTokens[_contractAddress].contractAddress != address(0)) {
            if (checkIfSubscribed(_contractAddress, _userAddress)) return true;
            if (
                allAccessTokens[_contractAddress].typeOfToken == ERC_721 &&
                handleERC721Access(
                    allAccessTokens[_contractAddress],
                    _userAddress
                )
            ) return true;
            else if (
                allAccessTokens[_contractAddress].typeOfToken == ERC_1155 &&
                handleERC1155Access(
                    allAccessTokens[_contractAddress],
                    _userAddress
                )
            ) return true;
            else if (
                allAccessTokens[_contractAddress].typeOfToken == ERC_20 &&
                handleERC20Access(
                    allAccessTokens[_contractAddress],
                    _userAddress
                )
            ) return true;
        }
        return false;
    }

    /**
     * @dev checkIfSubscribed(): checks if an address has an actibe subscription in an accessToken.
     * the address doesn't need to have that accessToken (Fungible or Non-Fungible)
     * @param _contractAddress: the accessToken to check
     * @param _userAddress: the address to validate
     */
    function checkIfSubscribed(address _contractAddress, address _userAddress)
        public
        view
        returns (bool)
    {
        if (
            allSubscribers[_contractAddress][_userAddress].subscriberAddress !=
            address(0)
        )
            if (
                allSubscribers[_contractAddress][_userAddress]
                    .dateOfExpiration > block.timestamp
            ) return true;
            else return false;
        return false;
    }

    /**
     * @dev handleERC721Access(): handles the call to the  main logic of validating an address' access in an accessToken.
     * See checkAccess() function for usage
     * @param _contractObj: the address of the accessToken
     * @param _userAddress: the address to be validated
     **/
    function handleERC721Access(
        AccessToken memory _contractObj,
        address _userAddress
    ) internal view returns (bool) {
        if (_contractObj.specifyId == -1)
            return balanceOf(_contractObj, _userAddress);
        if (_contractObj.specifyId != -1)
            return
                ownerOf(
                    _contractObj.contractAddress,
                    _contractObj.specifyId,
                    _userAddress
                );
        return false;
    }

    /**
     * @dev handleERC1155Access(): handles the call to the  main logic of validating an address' access in an accessToken.
     * See checkAccess() function for usage
     * @param _contractObj: the address of the accessToken
     * @param _userAddress: the address to be validated
     **/
    function handleERC1155Access(
        AccessToken memory _contractObj,
        address _userAddress
    ) internal view returns (bool) {
        return balanceOf(_contractObj, _userAddress);
    }

    /**
     * @dev handleERC20Access(): handles the call to the main logic of validating an address' access in an accessToken.
     * See checkAccess() function for usage
     * @param _contractObj: the address of the accessToken
     * @param _userAddress: the address to be validated
     **/
    function handleERC20Access(
        AccessToken memory _contractObj,
        address _userAddress
    ) internal view returns (bool) {
        return balanceOf(_contractObj, _userAddress);
    }

    /**
     * @dev balanceOf(): handles the main logic of validating an address' access in an accessToken.
     *
     * For each of ERC721, ERC1155 and ERC20, this function creates an instance of the standard using the accessToken's address
     * the .typeOfToken attribute is used to determine which ERC standard the accessToken belongs to.
     *
     * the balanceOf() functions in each of the ERC token standards callled on their instantiation differ in design and functionality.
     * check out this Openzeppelin docs to understand more https://docs.openzeppelin.com/contracts/3.x/tokens#standards
     *
     * See handleERC20Access() / handleERC1155Access() / handleERC721Access() functions for usage
     *
     * @param _contractObj: the address of the accessToken
     * @param _userAddress: the address to be validated
     **/
    function balanceOf(AccessToken memory _contractObj, address _userAddress)
        public
        view
        returns (bool)
    {
        /** ERC721 Token */
        if (_contractObj.typeOfToken == ERC_721)
            return
                IERC721(_contractObj.contractAddress).balanceOf(_userAddress) >=
                    _contractObj.amount
                    ? true
                    : false;
        /** ERC1155 Token */
        else if (_contractObj.typeOfToken == ERC_1155)
            return
                IERC1155(_contractObj.contractAddress).balanceOf(
                    _userAddress,
                    uint256(_contractObj.specifyId)
                ) >= _contractObj.amount
                    ? true
                    : false;
        /** ERC20 Token */
        else if (_contractObj.typeOfToken == ERC_20)
            return
                IERC20(_contractObj.contractAddress).balanceOf(_userAddress) >=
                    _contractObj.amount
                    ? true
                    : false;
        return false;
    }

    /**
     * @dev ownerOf(): calls ERC721 ownerOf() function which returns the address that owns a token,
     * this function then compares the address returned to the _userAddress and returns true if matched, else returns false.
     *
     * @param _contractAddress: address of the ERC721 accessToken
     * @param _id: ID of the NFT to get the owner of
     * @param _userAddress: the address to compare
     **/
    function ownerOf(
        address _contractAddress,
        int256 _id,
        address _userAddress
    ) public view returns (bool) {
        return IERC721(_contractAddress).ownerOf(uint256(_id)) == _userAddress;
    }

    function setFee(
        address _contractAddress,
        uint256 _price,
        uint256 _numOfDays
    ) public onlyTokenAdmin(_contractAddress) {
        require(
            allAccessTokens[_contractAddress].contractAddress ==
                _contractAddress,
            "Token disabled or doesn't exist"
        );
        allAccessTokens[_contractAddress].subscription = Subscription({
            price: _price,
            duration: _numOfDays * 1 days
        });
        emit SetFee(_contractAddress, _price, _numOfDays * 1 days);
    }

    /**
     * @dev subscribe(): subscribes an address to an accessToken for a duration specified by the acccessToken's moderator,
     * subscribed accounts will have all access to the accessTokens services as an account that has the accessToken (Fungible or Non-Fungible)
     *
     * @param _contractAddress: the accessToken's contract address
     **/
    function subscribe(address _contractAddress) external payable {
        require(
            allAccessTokens[_contractAddress].contractAddress ==
                _contractAddress,
            "Token disabled or doesn't exist"
        );
        require(
            msg.value == allAccessTokens[_contractAddress].subscription.price,
            "Ether value sent is not correct"
        );

        allSubscribers[_contractAddress][msg.sender] = Subscriber({
            subscriberAddress: msg.sender,
            dateOfSubscription: block.timestamp,
            dateOfExpiration: block.timestamp +
                allAccessTokens[_contractAddress].subscription.duration
        });

        ethBalanceForToken[_contractAddress] += msg.value;

        emit Subscribed(
            msg.sender,
            _contractAddress,
            allSubscribers[_contractAddress][msg.sender].dateOfSubscription,
            allSubscribers[_contractAddress][msg.sender].dateOfExpiration
        );
    }

    function getFeeForTokenAccess(address _contractAddress)
        public
        view
        returns (uint256 price, uint256 duration)
    {
        (price, duration) = (
            allAccessTokens[_contractAddress].subscription.price,
            allAccessTokens[_contractAddress].subscription.duration
        );
    }

    function disableTokenAccess(address _contractAddress)
        public
        onlyTokenAdmin(_contractAddress)
    {
        require(
            allAccessTokens[_contractAddress].contractAddress != address(0),
            "Token does not exist"
        );
        delete allAccessTokens[_contractAddress];
        emit DisableTokenAccess(_contractAddress, msg.sender);
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

    function ethBalancePaidForTokenAccess(address _contractAddress)
        public
        view
        returns (uint256)
    {
        return ethBalanceForToken[_contractAddress];
    }

    function withdrawBalancePaidForToken(address _contractAddress)
        public
        onlyTokenAdmin(_contractAddress)
    {
        require(ethBalanceForToken[_contractAddress] > 0, "Value too low");
        uint256 ethBalance = ethBalanceForToken[_contractAddress];
        ethBalanceForToken[_contractAddress] = 0;
        AddressUpgradeable.sendValue(payable(msg.sender), ethBalance);
        emit WithdrawBalancePaidForToken(
            _contractAddress,
            ethBalance,
            msg.sender
        );
    }
}

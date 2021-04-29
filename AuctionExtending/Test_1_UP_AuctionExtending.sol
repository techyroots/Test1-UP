// SPDX-License-Identifier: MIT

pragma solidity ^0.5.12;

import "./SafeMath.sol";
import "./Context.sol";
import "./Ownable.sol";
import "./IERC20.sol";
import "./ReentrancyGuard.sol";
import "./IERC165.sol";
import "./IERC1155TokenReceiver.sol";
import "./Test_1_UP_TokenWrapper.sol";
import "./IERC1155.sol";

contract Test_1_UP_AuctionExtending is Ownable, ReentrancyGuard, Test_1_UP_TokenWrapper, IERC1155TokenReceiver {
	using SafeMath for uint256;

	address public test_1_UPLtdAddress;
	address public runner;

	// info about a particular auction
	struct AuctionInfo {
		address beneficiary;
		uint256 fee;
		uint256 auctionStart;
		uint256 auctionEnd;
		uint256 originalAuctionEnd;
		uint256 extension;
		uint256 nft;
		address highestBidder;
		uint256 highestBid;
		bool auctionEnded;
	}

	mapping(uint256 => AuctionInfo) public auctionsById;
	uint256[] public auctions;

	// Events that will be fired on changes.
	event BidPlaced(address indexed user, uint256 indexed id, uint256 amount);
	event Withdrawn(address indexed user, uint256 indexed id, uint256 amount);
	event Ended(address indexed user, uint256 indexed id, uint256 amount);

	constructor(
		address _runner,
		address _test_1_UPAddress,
		address _test_1_UPLtdAddress
	) public Test_1_UP_TokenWrapper(_test_1_UPAddress) {
		runner = _runner;
		test_1_UPLtdLtdAddress = _test_1_UPLtdLtdAddress;
	}

	function auctionStart(uint256 id) public view returns (uint256) {
		return auctionsById[id].auctionStart;
	}

	function beneficiary(uint256 id) public view returns (address) {
		return auctionsById[id].beneficiary;
	}

	function auctionEnd(uint256 id) public view returns (uint256) {
		return auctionsById[id].auctionEnd;
	}

	function test_1_UPLtdNft(uint256 id) public view returns (uint256) {
		return auctionsById[id].nft;
	}

	function highestBidder(uint256 id) public view returns (address) {
		return auctionsById[id].highestBidder;
	}

	function highestBid(uint256 id) public view returns (uint256) {
		return auctionsById[id].highestBid;
	}

	function ended(uint256 id) public view returns (bool) {
		return now >= auctionsById[id].auctionEnd;
	}

	function runnerFee(uint256 id) public view returns (uint256) {
		return auctionsById[id].fee;
	}

	function setRunnerAddress(address account) public onlyOwner {
		runner = account;
	}

	function create(
		uint256 id,
		address beneficiaryAddress,
		uint256 fee,
		uint256 start,
		uint256 duration,
		uint256 extension // in minutes
	) public onlyOwner {
		AuctionInfo storage auction = auctionsById[id];
		require(auction.beneficiary == address(0), "test_1_UPAuction::create: auction already created");

		auction.beneficiary = beneficiaryAddress;
		auction.fee = fee;
		auction.auctionStart = start;
		auction.auctionEnd = start.add(duration * 1 days);
		auction.originalAuctionEnd = start.add(duration * 1 days);
		auction.extension = extension * 60;

		auctions.push(id);

		uint256 tokenId = IERC1155(test_1_UPLtdAddress).create(1, 1, "", "");
		require(tokenId > 0, "Test_1_UPAuction::create: ERC1155 create did not succeed");
		auction.nft = tokenId;
	}

	function bid(uint256 id, uint256 amount) public nonReentrant {
		AuctionInfo storage auction = auctionsById[id];
		require(auction.beneficiary != address(0), "Test_1_UPAuction::bid: auction does not exist");
		require(now >= auction.auctionStart, "Test_1_UPAuction::bid: auction has not started");
		require(now <= auction.auctionEnd, "Test_1_UPAuction::bid: auction has ended");

		uint256 newAmount = amount.add(balanceOf(msg.sender, id));
		require(newAmount > auction.highestBid, "Test_1_UPAuction::bid: bid is less than highest bid");

		auction.highestBidder = msg.sender;
		auction.highestBid = newAmount;

		if (auction.extension > 0 && auction.auctionEnd.sub(now) <= auction.extension) {
			auction.auctionEnd = now.add(auction.extension);
		}

		super.bid(id, amount);
		emit BidPlaced(msg.sender, id, amount);
	}

	function withdraw(uint256 id) public nonReentrant {
		AuctionInfo storage auction = auctionsById[id];
		uint256 amount = balanceOf(msg.sender, id);
		require(auction.beneficiary != address(0), "Test_1_UPAuction::withdraw: auction does not exist");
		require(amount > 0, "Test_1_UPAuction::withdraw: cannot withdraw 0");

		require(
			auction.highestBidder != msg.sender,
			"Test_1_UPAuction::withdraw: you are the highest bidder and cannot withdraw"
		);

		super.withdraw(id);
		emit Withdrawn(msg.sender, id, amount);
	}

	function emergencyWithdraw(uint256 id) public onlyOwner {
		AuctionInfo storage auction = auctionsById[id];
		require(auction.beneficiary != address(0), "Test_1_UPAuction::create: auction does not exist");
		require(now >= auction.auctionEnd, "Test_1_UPAuction::emergencyWithdraw: the auction has not ended");
		require(!auction.auctionEnded, "Test_1_UPAuction::emergencyWithdraw: auction ended and item sent");

		_emergencyWithdraw(auction.highestBidder, id);
		emit Withdrawn(auction.highestBidder, id, auction.highestBid);
	}

	function end(uint256 id) public nonReentrant {
		AuctionInfo storage auction = auctionsById[id];
		require(auction.beneficiary != address(0), "Test_1_UPAuction::end: auction does not exist");
		require(now >= auction.auctionEnd, "Test_1_UPAuction::end: the auction has not ended");
		require(!auction.auctionEnded, "Test_1_UPAuction::end: auction already ended");

		auction.auctionEnded = true;
		_end(id, auction.highestBidder, auction.beneficiary, runner, auction.fee, auction.highestBid);
		IERC1155(test_1_UPLtdAddress).safeTransferFrom(address(this), auction.highestBidder, auction.nft, 1, "");
		emit Ended(auction.highestBidder, id, auction.highestBid);
	}

	function onERC1155Received(
		address _operator,
		address, // _from
		uint256, // _id
		uint256, // _amount
		bytes memory // _data
	) public returns (bytes4) {
		require(msg.sender == address(test_1_UPLtdAddress), "Test_1_UPAuction::onERC1155BatchReceived:: invalid token address");
		require(_operator == address(this), "Test_1_UPAuction::onERC1155BatchReceived:: operator must be auction contract");

		// Return success
		return this.onERC1155Received.selector;
	}

	function onERC1155BatchReceived(
		address _operator,
		address, // _from,
		uint256[] memory, // _ids,
		uint256[] memory, // _amounts,
		bytes memory // _data
	) public returns (bytes4) {
		require(msg.sender == address(test_1_UPLtdAddress), "Test_1_UPAuction::onERC1155BatchReceived:: invalid token address");
		require(_operator == address(this), "Test_1_UPAuction::onERC1155BatchReceived:: operator must be auction contract");

		// Return success
		return this.onERC1155BatchReceived.selector;
	}

	function supportsInterface(bytes4 interfaceID) external view returns (bool) {
		return
			interfaceID == 0x01ffc9a7 || // ERC-165 support
			interfaceID == 0x4e2312e0; // ERC-1155 `ERC1155TokenReceiver` support
	}
}
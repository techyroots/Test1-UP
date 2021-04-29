// SPDX-License-Identifier: MIT

pragma solidity ^0.5.12;
import "./SafeMath.sol";
import "./IERC20.sol";

contract Test_1_UP_TokenWrapper {
	using SafeMath for uint256;
	IERC20 public test_1_UPLtd;

	constructor(address _test_1_UPLtdAddress) public {
		test_1_UPLtd = IERC20(_test_1_UPLtdAddress);
	}

	uint256 private _totalSupply;
	// Objects balances [id][address] => balance
	mapping(uint256 => mapping(address => uint256)) internal _balances;
	mapping(uint256 => uint256) private _totalDeposits;

	function totalSupply() public view returns (uint256) {
		return _totalSupply;
	}

	function totalDeposits(uint256 id) public view returns (uint256) {
		return _totalDeposits[id];
	}

	function balanceOf(address account, uint256 id) public view returns (uint256) {
		return _balances[id][account];
	}

	function bid(uint256 id, uint256 amount) public {
		_totalSupply = _totalSupply.add(amount);
		_totalDeposits[id] = _totalDeposits[id].add(amount);
		_balances[id][msg.sender] = _balances[id][msg.sender].add(amount);
		test_1_UPLtd.transferFrom(msg.sender, address(this), amount);
	}

	function withdraw(uint256 id) public {
		uint256 amount = balanceOf(msg.sender, id);
		_totalSupply = _totalSupply.sub(amount);
		_totalDeposits[id] = _totalDeposits[id].sub(amount);
		_balances[id][msg.sender] = _balances[id][msg.sender].sub(amount);
		test_1_UPLtd.transfer(msg.sender, amount);
	}

	function _emergencyWithdraw(address account, uint256 id) internal {
		uint256 amount = _balances[id][account];

		_totalSupply = _totalSupply.sub(amount);
		_totalDeposits[id] = _totalDeposits[id].sub(amount);
		_balances[id][account] = _balances[id][account].sub(amount);
		test_1_UPLtd.transfer(account, amount);
	}

	function _end(
		uint256 id,
		address highestBidder,
		address beneficiary,
		address runner,
		uint256 fee,
		uint256 amount
	) internal {
		uint256 accountDeposits = _balances[id][highestBidder];
		require(accountDeposits == amount);

		_totalSupply = _totalSupply.sub(amount);
		uint256 test_1_UPLtdFee = (amount.mul(fee)).div(100);

		_totalDeposits[id] = _totalDeposits[id].sub(amount);
		_balances[id][highestBidder] = _balances[id][highestBidder].sub(amount);
		test_1_UPLtd.transfer(beneficiary, amount.sub(test_1_UPLtdFee));
		test_1_UPLtd.transfer(runner, test_1_UPLtdFee);
	}
}

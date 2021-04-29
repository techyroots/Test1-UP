// SPDX-License-Identifier: MIT

pragma solidity >=0.5.0;

import "./Context.sol";
import "./Ownable.sol";
import "./Roles.sol";
import "./MinterRole.sol";
import "./WhitelistAdminRole.sol";
import "./IERC165.sol";
import "./SafeMath.sol";
import "./IERC1155TokenReceiver.sol";
import "./IERC1155.sol";
import "./Address.sol";
import "./ERC1155.sol";
import "./ERC1155Metadata.sol";
import "./ERC1155MintBurn.sol";
import "./Strings.sol";
import "./ERC1155Tradable.sol";

/**
 * @title test_1_UPLtd
 * test_1_UPLtd - Collect limited edition NFTs from test_1_UP Ltd
 */
contract Test_1-UP is ERC1155Tradable {
	constructor(address _proxyRegistryAddress) public ERC1155Tradable("test_1_UP Ltd.", "test_1_UP", _proxyRegistryAddress) {
		_setBaseMetadataURI("https://codebird.in/test_1_UP/");
	}
	
    string url = "https://codebird.in/test_1_UP/-erc1155";
    
	function contractURI() public view returns (string memory) {
		return url;
	}
}
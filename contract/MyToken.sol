// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

//ERC1155, permite a criação e mint de multi tokens 
contract MyToken is ERC1155, Ownable, ERC1155Pausable, ERC1155Supply {
    //Erros customizados
    error MaxSupplyExceeded(uint);
    error ValueIsNotEnough(uint);
    error IdDoenstExist(uint);
    error MaxPerWalletReached(uint);
    error FailedTranfer();
    error URIQueryForNonExistentToken();
    error PublicMintIsClosed();

    //Evento para rastrear wallet e valor de um possível saque
    event Withdraw(address indexed owner, uint256 balance);

    uint256[] public MaxSuplies = [50, 100, 200];
    uint256[] public currentSupply = [0, 0, 0];
    uint256[] public prices = [0.01 ether, 0.001 ether, 0.0001 ether];
    uint256 public maxPerWallet = 3;

    bool public publicMintOpen = true;
    mapping(address => uint8) public walletMinted;

    constructor(address initialOwner)
        ERC1155(
            "https://ipfs.io/ipfs/QmaDDJQR1iYbBtfqUErc9ox3DGWZjxATfnCtTU7quf6Ppq/{id}.json"
        )
        Ownable(initialOwner)
    {}

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    //Função para adicionar e retornar o .json na URL do metadados IPFS.
    function uri(uint256 _tokenId)
        public
        view
        override
        returns (string memory)
    {
        if (!exists(_tokenId)) revert URIQueryForNonExistentToken();
        return string(abi.encodePacked("https://ipfs.io/ipfs/QmaDDJQR1iYbBtfqUErc9ox3DGWZjxATfnCtTU7quf6Ppq/", Strings.toString(_tokenId), ".json"));
    }


    //contractURI - Função para passar os metadados da coleção para o Opensea/Rarible
    //Deve conter o link para o arquivo json
    /* 
    {
      "name": "Name Of Colletion",
      "description": "Description", 
      "image": "https://ipfs.io/ipfs/HASH_HERE/image.png", 
      "external_url": "Website"
    }
    */
    function contractURI() public pure returns (string memory) {
        return
            "https://ipfs.io/ipfs/QmaDDJQR1iYbBtfqUErc9ox3DGWZjxATfnCtTU7quf6Ppq/colletions.json";
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function publicMint(uint256 id, uint256 amount)
        public
        payable
        whenNotPaused
    {

        if (!publicMintOpen) {
            revert PublicMintIsClosed();
        }

        if (msg.value < amount * prices[id]) {
            revert ValueIsNotEnough(msg.value);
        }

        if (walletMinted[msg.sender] + amount > maxPerWallet) {
            revert MaxPerWalletReached(amount);
        }

        if (id > MaxSuplies.length) {
            revert IdDoenstExist(id);
        }

        if (currentSupply[id] + amount > MaxSuplies[id]) {
            revert MaxSupplyExceeded(amount);
        }

         for (uint256 i = 0; i < amount; i++){
            _mint(msg.sender, id, 1, "");
            currentSupply[id] += amount;
            walletMinted[msg.sender] += 1;

         }
    }

    //Função de mint windows para ativar/desativar o Mint público
    function editMintWindows(bool _publicMintOpen) external onlyOwner {
        publicMintOpen = _publicMintOpen;
    }


    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public onlyOwner {
        _mintBatch(to, ids, amounts, data);
    }
    
    //Função para retornar atual supply de um token pelo ID (para usar no frontend)
    function getCurrentSupply(uint256 id) public view returns (uint256) {
        return currentSupply[id];
    }

    //Função para retornar total max de supply de um token pelo ID (para usar no frontend)
    function getMaxSupplies(uint256 id) public view returns (uint256) {
        return MaxSuplies[id];
    }

    //Função para editar o MaxSuplies e MaxPerWallet
    function editSaleRestrictions(uint[] memory _newMaxSupplies, uint8 _newMaxPerWallet) external onlyOwner {
        MaxSuplies = _newMaxSupplies;
        maxPerWallet = _newMaxPerWallet;
    }

    //Função de saque dos fundos do contrato
    function withdraw() external payable onlyOwner {
        uint256 balance = address(this).balance;
        (bool sucess, ) = (msg.sender).call{value: balance}("");
        if (!sucess) {
            revert FailedTranfer();
        }

        //Emitindo evento contendo wallet e valor de quem fez o saque dos fundos
        emit Withdraw(msg.sender, balance);
    }

    // The following functions are overrides required by Solidity.

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override(ERC1155, ERC1155Pausable, ERC1155Supply) {
        super._update(from, to, ids, values);
    }
}

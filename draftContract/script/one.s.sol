// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Merkle} from "murky/src/Merkle.sol";
import {ScriptHelper} from "murky/script/common/ScriptHelper.sol";

// Merkle proof generator script
// To use:
// 1. Run `forge script script/GenerateInput.s.sol` to generate the input file
// 2. Run `forge script script/Merkle.s.sol`
// 3. The output file will be generated in /script/target/output.json

/**
 * @title MakeMerkle
 * @author Chukwubuike Victory Chime
 *
 * Original Work by:
 * @author kootsZhin
 * @notice https://github.com/dmfxyz/murky
 */
contract MakeMerkle is Script, ScriptHelper {
    using stdJson for string; // enables us to use the json cheatcodes for strings

    Merkle private m = new Merkle(); // instance of the merkle contract from Murky to do shit

    string private inputPath = "/script/target/input.json";
    string private outputPath = "/script/target/output.json";

    string private elements = vm.readFile(string.concat(vm.projectRoot(), inputPath)); // get the absolute path
    string private types = elements.readString(".types"); // get the merkle tree leaf type from json as a single string
    uint256 private count = elements.readUint(".count"); // get the number of leaf nodes

    // make three arrays the same size as the number of leaf nodes
    bytes32[] private leafs = new bytes32[](count);
    string[] private inputs = new string[](count);
    string[] private outputs = new string[](count);

    string private output;

    /// @dev Returns the JSON path of the input file
    // output file output ".values.some-address"
    function getValuesByIndex(uint256 i) internal pure returns (string memory) {
        return string.concat(".values.", vm.toString(i));
    }

    /// @dev Generate the JSON entries for the output file
    function generateJsonEntries(string memory _inputs, string memory _proof, string memory _root, string memory _leaf)
        internal
        pure
        returns (string memory)
    {
        string memory result = string.concat(
            "{",
            "\"inputs\":",
            _inputs,
            ",",
            "\"proof\":",
            _proof,
            ",",
            "\"root\":\"",
            _root,
            "\",",
            "\"leaf\":\"",
            _leaf,
            "\"",
            "}"
        );

        return result;
    }

    /// @dev Read the input file and generate the Merkle proof, then write the output file
    function run() public {
        console2.log("Generating Merkle Proof for %s", inputPath);

        for (uint256 i = 0; i < count; i++) {
            string; // since we only have one type now
            bytes32; // array to hold the data as bytes32

            // Since `types` is now a single string, we check it directly
            if (compareStrings(types, "address")) {
                address value = elements.readAddress(getValuesByIndex(i));
                // you can't immediately cast straight to 32 bytes as an address is 20 bytes so first cast to uint160 (20 bytes) cast up to uint256 which is 32 bytes and finally to bytes32
                data[0] = bytes32(uint256(uint160(value)));
                input[0] = vm.toString(value);
            } else {
                revert("Unsupported type"); // Handle any unexpected types
            }

            // Create the hash for the merkle tree leaf node
            // abi encode the data array (each element is a bytes32 representation for the address)
            // Helper from Murky (ltrim64) Returns the bytes with the first 64 bytes removed
            // ltrim64 removes the offset and length from the encoded bytes. There is an offset because the array
            // is declared in memory
            // hash the encoded address
            // bytes.concat turns from bytes32 to bytes
            // hash again because preimage attack
            leafs[i] = keccak256(bytes.concat(keccak256(ltrim64(abi.encode(data)))));
            // Converts a string array into a JSON array string.
            // store the corresponding values/inputs for each leaf node
            inputs[i] = stringArrayToString(input);
        }

        for (uint256 i = 0; i < count; ++i) {
            // get proof gets the nodes needed for the proof & stringify (from helper lib)
            string memory proof = bytes32ArrayToString(m.getProof(leafs, i));
            // get the root hash and stringify
            string memory root = vm.toString(m.getRoot(leafs));
            // get the specific leaf working on
            string memory leaf = vm.toString(leafs[i]);
            // get the stringified input (address)
            string memory input = inputs[i];

            // generate the Json output file (tree dump)
            outputs[i] = generateJsonEntries(input, proof, root, leaf);
        }

        // stringify the array of strings to a single string
        output = stringArrayToArrayString(outputs);
        // write to the output file the stringified output json tree dumpus
        vm.writeFile(string.concat(vm.projectRoot(), outputPath), output);

        console2.log("DONE: The output is found at %s", outputPath);
    }
}

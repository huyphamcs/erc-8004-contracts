// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IdentityRegistry} from "../src/IdentityRegistry.sol";
import {ValidationRegistry} from "../src/ValidationRegistry.sol";
import {IIdentityRegistry} from "../src/interfaces/IIdentityRegistry.sol";
import {IValidationRegistry} from "../src/interfaces/IValidationRegistry.sol";

/**
 * @title ValidationRegistryTest
 * @dev Comprehensive unit tests for ValidationRegistry contract
 */
contract ValidationRegistryTest is Test {
    IdentityRegistry public identityRegistry;
    ValidationRegistry public validationRegistry;

    // Test accounts
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    // Test data
    string constant ALICE_DOMAIN = "alice.agent";
    string constant BOB_DOMAIN = "bob.agent";
    string constant CHARLIE_DOMAIN = "charlie.agent";
    uint256 constant REGISTRATION_FEE = 0.005 ether;
    uint256 constant EXPIRATION_SLOTS = 1000;

    uint256 aliceId;
    uint256 bobId;
    uint256 charlieId;

    bytes32 constant DATA_HASH_1 = keccak256("test data 1");
    bytes32 constant DATA_HASH_2 = keccak256("test data 2");

    // Events to test
    event ValidationRequestEvent(
        uint256 indexed agentValidatorId,
        uint256 indexed agentServerId,
        bytes32 indexed dataHash
    );

    event ValidationResponseEvent(
        uint256 indexed agentValidatorId,
        uint256 indexed agentServerId,
        bytes32 indexed dataHash,
        uint8 response
    );

    function setUp() public {
        // Deploy contracts
        identityRegistry = new IdentityRegistry();
        validationRegistry = new ValidationRegistry(address(identityRegistry));

        // Fund test accounts
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);

        // Register test agents
        aliceId = registerAgent(alice, ALICE_DOMAIN, alice);
        bobId = registerAgent(bob, BOB_DOMAIN, bob);
        charlieId = registerAgent(charlie, CHARLIE_DOMAIN, charlie);
    }

    // ============ Helper Functions ============

    function registerAgent(
        address sender,
        string memory domain,
        address agentAddress
    ) internal returns (uint256) {
        vm.prank(sender);
        return
            identityRegistry.newAgent{value: REGISTRATION_FEE}(
                domain,
                agentAddress
            );
    }

    // ============ Request Tests - Happy Path ============

    function test_ValidationRequest_Success() public {
        vm.expectEmit(true, true, true, true);
        emit ValidationRequestEvent(aliceId, bobId, DATA_HASH_1);

        vm.prank(charlie); // Anyone can create a request
        validationRegistry.validationRequest(aliceId, bobId, DATA_HASH_1);

        // Verify request exists
        (bool exists, bool pending) = validationRegistry.isValidationPending(
            DATA_HASH_1
        );
        assertTrue(exists, "Request should exist");
        assertTrue(pending, "Request should be pending");
    }

    function test_ValidationRequest_MultipleRequests() public {
        vm.startPrank(charlie);
        validationRegistry.validationRequest(aliceId, bobId, DATA_HASH_1);
        validationRegistry.validationRequest(bobId, charlieId, DATA_HASH_2);
        vm.stopPrank();

        (bool exists1, bool pending1) = validationRegistry.isValidationPending(
            DATA_HASH_1
        );
        (bool exists2, bool pending2) = validationRegistry.isValidationPending(
            DATA_HASH_2
        );

        assertTrue(exists1 && pending1, "First request should exist");
        assertTrue(exists2 && pending2, "Second request should exist");
    }

    function test_ValidationRequest_GetRequestDetails() public {
        uint256 requestBlock = block.number;

        vm.prank(charlie);
        validationRegistry.validationRequest(aliceId, bobId, DATA_HASH_1);

        IValidationRegistry.Request memory request = validationRegistry
            .getValidationRequest(DATA_HASH_1);

        assertEq(request.agentValidatorId, aliceId, "Validator ID mismatch");
        assertEq(request.agentServerId, bobId, "Server ID mismatch");
        assertEq(request.dataHash, DATA_HASH_1, "Data hash mismatch");
        assertEq(request.timestamp, requestBlock, "Timestamp mismatch");
        assertFalse(request.responded, "Should not be responded");
    }

    function test_ValidationRequest_ReEmitExisting() public {
        vm.prank(charlie);
        validationRegistry.validationRequest(aliceId, bobId, DATA_HASH_1);

        uint256 originalBlock = block.number;

        // Re-emit the same request
        vm.expectEmit(true, true, true, true);
        emit ValidationRequestEvent(aliceId, bobId, DATA_HASH_1);

        vm.prank(charlie);
        validationRegistry.validationRequest(aliceId, bobId, DATA_HASH_1);

        // Request should still have original timestamp
        IValidationRegistry.Request memory request = validationRegistry
            .getValidationRequest(DATA_HASH_1);
        assertEq(
            request.timestamp,
            originalBlock,
            "Timestamp should not change"
        );
    }

    // ============ Request Tests - Validation Errors ============

    function test_ValidationRequest_RevertIf_ZeroDataHash() public {
        vm.expectRevert(IValidationRegistry.InvalidDataHash.selector);
        vm.prank(charlie);
        validationRegistry.validationRequest(aliceId, bobId, bytes32(0));
    }

    function test_ValidationRequest_RevertIf_ValidatorNotFound() public {
        vm.expectRevert(IValidationRegistry.AgentNotFound.selector);
        vm.prank(charlie);
        validationRegistry.validationRequest(999, bobId, DATA_HASH_1);
    }

    function test_ValidationRequest_RevertIf_ServerNotFound() public {
        vm.expectRevert(IValidationRegistry.AgentNotFound.selector);
        vm.prank(charlie);
        validationRegistry.validationRequest(aliceId, 999, DATA_HASH_1);
    }

    // ============ Response Tests - Happy Path ============

    function test_ValidationResponse_Success() public {
        // Create request
        vm.prank(charlie);
        validationRegistry.validationRequest(aliceId, bobId, DATA_HASH_1);

        // Submit response
        vm.expectEmit(true, true, true, true);
        emit ValidationResponseEvent(aliceId, bobId, DATA_HASH_1, 85);

        vm.prank(alice); // Validator responds
        validationRegistry.validationResponse(DATA_HASH_1, 85);

        // Verify response
        (bool hasResponse, uint8 response) = validationRegistry
            .getValidationResponse(DATA_HASH_1);

        assertTrue(hasResponse, "Should have response");
        assertEq(response, 85, "Response should be 85");
    }

    function test_ValidationResponse_UpdatesPendingStatus() public {
        vm.prank(charlie);
        validationRegistry.validationRequest(aliceId, bobId, DATA_HASH_1);

        // Before response - should be pending
        (bool exists1, bool pending1) = validationRegistry.isValidationPending(
            DATA_HASH_1
        );
        assertTrue(exists1, "Request should exist");
        assertTrue(pending1, "Should be pending");

        // Submit response
        vm.prank(alice);
        validationRegistry.validationResponse(DATA_HASH_1, 75);

        // After response - should not be pending
        (bool exists2, bool pending2) = validationRegistry.isValidationPending(
            DATA_HASH_1
        );
        assertTrue(exists2, "Request should still exist");
        assertFalse(pending2, "Should no longer be pending");
    }

    function test_ValidationResponse_ScoreRange() public {
        bytes32[] memory hashes = new bytes32[](5);
        hashes[0] = keccak256("data0");
        hashes[1] = keccak256("data1");
        hashes[2] = keccak256("data2");
        hashes[3] = keccak256("data3");
        hashes[4] = keccak256("data4");

        uint8[] memory scores = new uint8[](5);
        scores[0] = 0; // Min score
        scores[1] = 25;
        scores[2] = 50;
        scores[3] = 75;
        scores[4] = 100; // Max score

        // Create requests and respond
        for (uint i = 0; i < 5; i++) {
            vm.prank(charlie);
            validationRegistry.validationRequest(aliceId, bobId, hashes[i]);

            vm.prank(alice);
            validationRegistry.validationResponse(hashes[i], scores[i]);

            (bool hasResponse, uint8 response) = validationRegistry
                .getValidationResponse(hashes[i]);

            assertTrue(hasResponse, "Should have response");
            assertEq(response, scores[i], "Score should match");
        }
    }

    // ============ Response Tests - Validation Errors ============

    function test_ValidationResponse_RevertIf_InvalidScore() public {
        vm.prank(charlie);
        validationRegistry.validationRequest(aliceId, bobId, DATA_HASH_1);

        vm.expectRevert(IValidationRegistry.InvalidResponse.selector);
        vm.prank(alice);
        validationRegistry.validationResponse(DATA_HASH_1, 101);
    }

    function test_ValidationResponse_RevertIf_RequestNotFound() public {
        vm.expectRevert(IValidationRegistry.ValidationRequestNotFound.selector);
        vm.prank(alice);
        validationRegistry.validationResponse(DATA_HASH_1, 85);
    }

    function test_ValidationResponse_RevertIf_Unauthorized() public {
        vm.prank(charlie);
        validationRegistry.validationRequest(aliceId, bobId, DATA_HASH_1);

        // Bob tries to respond, but Alice is the validator
        vm.expectRevert(IValidationRegistry.UnauthorizedValidator.selector);
        vm.prank(bob);
        validationRegistry.validationResponse(DATA_HASH_1, 85);
    }

    function test_ValidationResponse_RevertIf_AlreadyResponded() public {
        vm.prank(charlie);
        validationRegistry.validationRequest(aliceId, bobId, DATA_HASH_1);

        vm.prank(alice);
        validationRegistry.validationResponse(DATA_HASH_1, 85);

        // Try to respond again
        vm.expectRevert(
            IValidationRegistry.ValidationAlreadyResponded.selector
        );
        vm.prank(alice);
        validationRegistry.validationResponse(DATA_HASH_1, 90);
    }

    // ============ Expiration Tests ============

    function test_Expiration_RequestExpires() public {
        vm.prank(charlie);
        validationRegistry.validationRequest(aliceId, bobId, DATA_HASH_1);

        // Initially pending
        (bool exists1, bool pending1) = validationRegistry.isValidationPending(
            DATA_HASH_1
        );
        assertTrue(exists1, "Request should exist");
        assertTrue(pending1, "Should be pending");

        // Advance past expiration
        vm.roll(block.number + EXPIRATION_SLOTS + 1);

        // Should no longer be pending
        (bool exists2, bool pending2) = validationRegistry.isValidationPending(
            DATA_HASH_1
        );
        assertTrue(exists2, "Request should still exist");
        assertFalse(pending2, "Should no longer be pending after expiration");
    }

    function test_Expiration_CannotRespondAfterExpiration() public {
        vm.prank(charlie);
        validationRegistry.validationRequest(aliceId, bobId, DATA_HASH_1);

        // Advance past expiration
        vm.roll(block.number + EXPIRATION_SLOTS + 1);

        // Cannot respond to expired request
        vm.expectRevert(IValidationRegistry.RequestExpired.selector);
        vm.prank(alice);
        validationRegistry.validationResponse(DATA_HASH_1, 85);
    }

    function test_Expiration_CanRespondBeforeExpiration() public {
        vm.prank(charlie);
        validationRegistry.validationRequest(aliceId, bobId, DATA_HASH_1);

        // Advance to right before expiration
        vm.roll(block.number + EXPIRATION_SLOTS);

        // Should still be able to respond
        vm.prank(alice);
        validationRegistry.validationResponse(DATA_HASH_1, 85);

        (bool hasResponse, uint8 response) = validationRegistry
            .getValidationResponse(DATA_HASH_1);

        assertTrue(hasResponse, "Should have response");
        assertEq(response, 85, "Response should be recorded");
    }

    function test_Expiration_CanReRequestAfterExpiration() public {
        vm.prank(charlie);
        validationRegistry.validationRequest(aliceId, bobId, DATA_HASH_1);

        uint256 originalBlock = block.number;

        // Advance past expiration
        vm.roll(block.number + EXPIRATION_SLOTS + 1);

        uint256 newBlock = block.number;

        // Re-request creates new request
        vm.prank(charlie);
        validationRegistry.validationRequest(aliceId, bobId, DATA_HASH_1);

        IValidationRegistry.Request memory request = validationRegistry
            .getValidationRequest(DATA_HASH_1);

        assertEq(
            request.timestamp,
            newBlock,
            "Timestamp should be updated to new request"
        );
        assertTrue(
            request.timestamp > originalBlock,
            "New timestamp should be later"
        );
    }

    function test_Expiration_GetExpirationSlots() public {
        assertEq(
            validationRegistry.getExpirationSlots(),
            EXPIRATION_SLOTS,
            "Should return correct expiration slots"
        );
    }

    // ============ Query Tests ============

    function test_GetValidationResponse_NoResponse() public {
        (bool hasResponse, uint8 response) = validationRegistry
            .getValidationResponse(DATA_HASH_1);

        assertFalse(hasResponse, "Should not have response");
        assertEq(response, 0, "Response should be 0");
    }

    function test_GetValidationRequest_RevertIf_NotFound() public {
        vm.expectRevert(IValidationRegistry.ValidationRequestNotFound.selector);
        validationRegistry.getValidationRequest(DATA_HASH_1);
    }

    function test_IsValidationPending_NonExistent() public {
        (bool exists, bool pending) = validationRegistry.isValidationPending(
            DATA_HASH_1
        );

        assertFalse(exists, "Should not exist");
        assertFalse(pending, "Should not be pending");
    }

    // ============ Integration Tests ============

    function test_Integration_CompleteFlow() public {
        // 1. Create validation request
        vm.prank(charlie);
        validationRegistry.validationRequest(aliceId, bobId, DATA_HASH_1);

        // 2. Verify request is pending
        (bool exists1, bool pending1) = validationRegistry.isValidationPending(
            DATA_HASH_1
        );
        assertTrue(exists1 && pending1, "Request should be pending");

        // 3. Validator responds
        vm.prank(alice);
        validationRegistry.validationResponse(DATA_HASH_1, 90);

        // 4. Verify response recorded
        (bool hasResponse, uint8 response) = validationRegistry
            .getValidationResponse(DATA_HASH_1);
        assertTrue(hasResponse, "Should have response");
        assertEq(response, 90, "Response should be 90");

        // 5. Verify no longer pending
        (bool exists2, bool pending2) = validationRegistry.isValidationPending(
            DATA_HASH_1
        );
        assertTrue(exists2, "Request should still exist");
        assertFalse(pending2, "Should no longer be pending");
    }

    function test_Integration_AfterValidatorOwnershipTransfer() public {
        // Create request with Alice as validator
        vm.prank(charlie);
        validationRegistry.validationRequest(aliceId, bobId, DATA_HASH_1);

        // Alice transfers ownership to a new address
        address newOwner = makeAddr("new-owner");
        vm.prank(alice);
        identityRegistry.updateAgent(aliceId, "", newOwner);

        // New owner can now respond
        vm.prank(newOwner);
        validationRegistry.validationResponse(DATA_HASH_1, 95);

        (bool hasResponse, uint8 response) = validationRegistry
            .getValidationResponse(DATA_HASH_1);

        assertTrue(hasResponse, "New owner should be able to respond");
        assertEq(response, 95, "Response should be recorded");
    }

    function test_Integration_WithIdentityRegistry() public {
        // Verify identityRegistry reference
        assertEq(
            address(validationRegistry.identityRegistry()),
            address(identityRegistry),
            "Should reference correct IdentityRegistry"
        );

        // Requests require both agents to exist
        vm.prank(charlie);
        validationRegistry.validationRequest(aliceId, bobId, DATA_HASH_1);

        IValidationRegistry.Request memory request = validationRegistry
            .getValidationRequest(DATA_HASH_1);

        // Verify agents exist in identity registry
        assertTrue(
            identityRegistry.agentExists(request.agentValidatorId),
            "Validator should exist"
        );
        assertTrue(
            identityRegistry.agentExists(request.agentServerId),
            "Server should exist"
        );
    }

    // ============ State Integrity Tests ============

    function test_StateIntegrity_MultipleValidations() public {
        bytes32[] memory hashes = new bytes32[](3);
        hashes[0] = DATA_HASH_1;
        hashes[1] = DATA_HASH_2;
        hashes[2] = keccak256("data3");

        // Create multiple requests
        vm.startPrank(charlie);
        validationRegistry.validationRequest(aliceId, bobId, hashes[0]);
        validationRegistry.validationRequest(bobId, charlieId, hashes[1]);
        validationRegistry.validationRequest(charlieId, aliceId, hashes[2]);
        vm.stopPrank();

        // Respond to only some
        vm.prank(alice);
        validationRegistry.validationResponse(hashes[0], 80);

        vm.prank(bob);
        validationRegistry.validationResponse(hashes[1], 90);

        // Verify state
        (bool has0, uint8 resp0) = validationRegistry.getValidationResponse(
            hashes[0]
        );
        (bool has1, uint8 resp1) = validationRegistry.getValidationResponse(
            hashes[1]
        );
        (bool has2, uint8 resp2) = validationRegistry.getValidationResponse(
            hashes[2]
        );

        assertTrue(has0, "First should have response");
        assertEq(resp0, 80, "First response should be 80");

        assertTrue(has1, "Second should have response");
        assertEq(resp1, 90, "Second response should be 90");

        assertFalse(has2, "Third should not have response");
    }

    // ============ Edge Cases ============

    function test_EdgeCase_SelfValidation() public {
        // Agent can validate their own work (weird but allowed)
        vm.prank(charlie);
        validationRegistry.validationRequest(aliceId, aliceId, DATA_HASH_1);

        vm.prank(alice);
        validationRegistry.validationResponse(DATA_HASH_1, 100);

        (bool hasResponse, uint8 response) = validationRegistry
            .getValidationResponse(DATA_HASH_1);

        assertTrue(hasResponse, "Self-validation should work");
        assertEq(response, 100, "Response should be recorded");
    }

    function test_EdgeCase_ZeroScore() public {
        vm.prank(charlie);
        validationRegistry.validationRequest(aliceId, bobId, DATA_HASH_1);

        vm.prank(alice);
        validationRegistry.validationResponse(DATA_HASH_1, 0);

        (bool hasResponse, uint8 response) = validationRegistry
            .getValidationResponse(DATA_HASH_1);

        assertTrue(hasResponse, "Zero score should be valid");
        assertEq(response, 0, "Response should be 0");
    }
}

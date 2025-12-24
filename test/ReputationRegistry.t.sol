// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IdentityRegistry} from "../src/IdentityRegistry.sol";
import {ReputationRegistry} from "../src/ReputationRegistry.sol";
import {IIdentityRegistry} from "../src/interfaces/IIdentityRegistry.sol";
import {IReputationRegistry} from "../src/interfaces/IReputationRegistry.sol";

/**
 * @title ReputationRegistryTest
 * @dev Comprehensive unit tests for ReputationRegistry contract
 */
contract ReputationRegistryTest is Test {
    IdentityRegistry public identityRegistry;
    ReputationRegistry public reputationRegistry;

    // Test accounts
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    // Test data
    string constant ALICE_DOMAIN = "alice.agent";
    string constant BOB_DOMAIN = "bob.agent";
    string constant CHARLIE_DOMAIN = "charlie.agent";
    uint256 constant REGISTRATION_FEE = 0.005 ether;

    uint256 aliceId;
    uint256 bobId;
    uint256 charlieId;

    // Events to test
    event AuthFeedback(
        uint256 indexed agentClientId,
        uint256 indexed agentServerId,
        bytes32 indexed feedbackAuthId
    );

    function setUp() public {
        // Deploy contracts
        identityRegistry = new IdentityRegistry();
        reputationRegistry = new ReputationRegistry(address(identityRegistry));

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

    // ============ Authorization Tests - Happy Path ============

    function test_AcceptFeedback_Success() public {
        // Bob (server) authorizes Alice (client) to provide feedback
        vm.expectEmit(true, true, false, false);
        emit AuthFeedback(aliceId, bobId, bytes32(0)); // Don't check feedbackAuthId

        vm.prank(bob);
        reputationRegistry.acceptFeedback(aliceId, bobId);

        // Verify authorization
        (bool isAuthorized, bytes32 feedbackAuthId) = reputationRegistry
            .isFeedbackAuthorized(aliceId, bobId);

        assertTrue(isAuthorized, "Feedback should be authorized");
        assertTrue(
            feedbackAuthId != bytes32(0),
            "FeedbackAuthId should be non-zero"
        );
    }

    function test_AcceptFeedback_MultipleClients() public {
        // Bob authorizes both Alice and Charlie
        vm.startPrank(bob);
        reputationRegistry.acceptFeedback(aliceId, bobId);
        reputationRegistry.acceptFeedback(charlieId, bobId);
        vm.stopPrank();

        (bool aliceAuthorized, ) = reputationRegistry.isFeedbackAuthorized(
            aliceId,
            bobId
        );
        (bool charlieAuthorized, ) = reputationRegistry.isFeedbackAuthorized(
            charlieId,
            bobId
        );

        assertTrue(aliceAuthorized, "Alice should be authorized");
        assertTrue(charlieAuthorized, "Charlie should be authorized");
    }

    function test_AcceptFeedback_MultipleServers() public {
        // Both Bob and Charlie authorize Alice
        vm.prank(bob);
        reputationRegistry.acceptFeedback(aliceId, bobId);

        vm.prank(charlie);
        reputationRegistry.acceptFeedback(aliceId, charlieId);

        (bool bobAuth, ) = reputationRegistry.isFeedbackAuthorized(
            aliceId,
            bobId
        );
        (bool charlieAuth, ) = reputationRegistry.isFeedbackAuthorized(
            aliceId,
            charlieId
        );

        assertTrue(bobAuth, "Bob should authorize Alice");
        assertTrue(charlieAuth, "Charlie should authorize Alice");
    }

    // ============ Authorization Tests - Validation Errors ============

    function test_AcceptFeedback_RevertIf_ClientNotFound() public {
        vm.expectRevert(IReputationRegistry.AgentNotFound.selector);
        vm.prank(bob);
        reputationRegistry.acceptFeedback(999, bobId);
    }

    function test_AcceptFeedback_RevertIf_ServerNotFound() public {
        vm.expectRevert(IReputationRegistry.AgentNotFound.selector);
        vm.prank(bob);
        reputationRegistry.acceptFeedback(aliceId, 999);
    }

    function test_AcceptFeedback_RevertIf_Unauthorized() public {
        // Alice tries to authorize feedback for Bob (only Bob can do this)
        vm.expectRevert(IReputationRegistry.UnauthorizedFeedback.selector);
        vm.prank(alice);
        reputationRegistry.acceptFeedback(aliceId, bobId);
    }

    function test_AcceptFeedback_RevertIf_AlreadyAuthorized() public {
        vm.prank(bob);
        reputationRegistry.acceptFeedback(aliceId, bobId);

        // Try to authorize again
        vm.expectRevert(IReputationRegistry.FeedbackAlreadyAuthorized.selector);
        vm.prank(bob);
        reputationRegistry.acceptFeedback(aliceId, bobId);
    }

    // ============ Query Tests - Happy Path ============

    function test_IsFeedbackAuthorized_True() public {
        vm.prank(bob);
        reputationRegistry.acceptFeedback(aliceId, bobId);

        (bool isAuthorized, bytes32 feedbackAuthId) = reputationRegistry
            .isFeedbackAuthorized(aliceId, bobId);

        assertTrue(isAuthorized, "Should be authorized");
        assertTrue(
            feedbackAuthId != bytes32(0),
            "Should have valid feedbackAuthId"
        );
    }

    function test_IsFeedbackAuthorized_False() public {
        (bool isAuthorized, bytes32 feedbackAuthId) = reputationRegistry
            .isFeedbackAuthorized(aliceId, bobId);

        assertFalse(isAuthorized, "Should not be authorized");
        assertEq(feedbackAuthId, bytes32(0), "Should have zero feedbackAuthId");
    }

    function test_GetFeedbackAuthId_Exists() public {
        vm.prank(bob);
        reputationRegistry.acceptFeedback(aliceId, bobId);

        bytes32 feedbackAuthId = reputationRegistry.getFeedbackAuthId(
            aliceId,
            bobId
        );
        assertTrue(
            feedbackAuthId != bytes32(0),
            "Should return valid feedbackAuthId"
        );
    }

    function test_GetFeedbackAuthId_NotExists() public {
        bytes32 feedbackAuthId = reputationRegistry.getFeedbackAuthId(
            aliceId,
            bobId
        );
        assertEq(
            feedbackAuthId,
            bytes32(0),
            "Should return zero for non-existent auth"
        );
    }

    // ============ FeedbackAuthId Uniqueness Tests ============

    function test_FeedbackAuthId_UniqueBetweenPairs() public {
        // Bob authorizes Alice
        vm.prank(bob);
        reputationRegistry.acceptFeedback(aliceId, bobId);

        // Charlie authorizes Alice
        vm.prank(charlie);
        reputationRegistry.acceptFeedback(aliceId, charlieId);

        bytes32 authId1 = reputationRegistry.getFeedbackAuthId(aliceId, bobId);
        bytes32 authId2 = reputationRegistry.getFeedbackAuthId(
            aliceId,
            charlieId
        );

        assertTrue(authId1 != authId2, "Auth IDs should be unique");
    }

    function test_FeedbackAuthId_DifferentForReversePair() public {
        // Bob authorizes Alice
        vm.prank(bob);
        reputationRegistry.acceptFeedback(aliceId, bobId);

        // Alice authorizes Bob (reverse)
        vm.prank(alice);
        reputationRegistry.acceptFeedback(bobId, aliceId);

        bytes32 authId1 = reputationRegistry.getFeedbackAuthId(aliceId, bobId);
        bytes32 authId2 = reputationRegistry.getFeedbackAuthId(bobId, aliceId);

        assertTrue(
            authId1 != authId2,
            "Reverse pair should have different auth ID"
        );
    }

    // ============ Integration Tests ============

    function test_Integration_CompleteFlow() public {
        // 1. Bob authorizes Alice to provide feedback
        vm.prank(bob);
        reputationRegistry.acceptFeedback(aliceId, bobId);

        // 2. Verify authorization exists
        (bool isAuthorized, bytes32 feedbackAuthId) = reputationRegistry
            .isFeedbackAuthorized(aliceId, bobId);
        assertTrue(isAuthorized, "Authorization should exist");

        // 3. Verify we can get the auth ID
        bytes32 retrievedAuthId = reputationRegistry.getFeedbackAuthId(
            aliceId,
            bobId
        );
        assertEq(retrievedAuthId, feedbackAuthId, "Auth IDs should match");
    }

    function test_Integration_AfterOwnershipTransfer() public {
        // Bob authorizes Alice
        vm.prank(bob);
        reputationRegistry.acceptFeedback(aliceId, bobId);

        // Bob transfers ownership to a new address
        address newOwner = makeAddr("new-owner");
        vm.prank(bob);
        identityRegistry.updateAgent(bobId, "", newOwner);

        // Authorization should still exist
        (bool isAuthorized, ) = reputationRegistry.isFeedbackAuthorized(
            aliceId,
            bobId
        );
        assertTrue(
            isAuthorized,
            "Authorization should persist after ownership transfer"
        );

        // New owner can authorize new feedback
        vm.prank(newOwner);
        reputationRegistry.acceptFeedback(charlieId, bobId);

        (bool newAuth, ) = reputationRegistry.isFeedbackAuthorized(
            charlieId,
            bobId
        );
        assertTrue(newAuth, "New owner should be able to authorize");
    }

    function test_Integration_WithIdentityRegistry() public {
        // Verify identityRegistry reference is correct
        assertEq(
            address(reputationRegistry.identityRegistry()),
            address(identityRegistry),
            "Should reference correct IdentityRegistry"
        );

        // Agents must exist in IdentityRegistry to use ReputationRegistry
        assertTrue(identityRegistry.agentExists(aliceId), "Alice should exist");
        assertTrue(identityRegistry.agentExists(bobId), "Bob should exist");

        // Can authorize feedback for existing agents
        vm.prank(bob);
        reputationRegistry.acceptFeedback(aliceId, bobId);

        (bool isAuthorized, ) = reputationRegistry.isFeedbackAuthorized(
            aliceId,
            bobId
        );
        assertTrue(isAuthorized, "Should authorize existing agents");
    }

    // ============ State Integrity Tests ============

    function test_StateIntegrity_MultipleAuthorizations() public {
        // Create a complex authorization graph
        vm.prank(bob);
        reputationRegistry.acceptFeedback(aliceId, bobId);

        vm.prank(charlie);
        reputationRegistry.acceptFeedback(aliceId, charlieId);

        vm.prank(alice);
        reputationRegistry.acceptFeedback(bobId, aliceId);

        // Verify all authorizations are independent and correct
        (bool auth1, ) = reputationRegistry.isFeedbackAuthorized(
            aliceId,
            bobId
        );
        (bool auth2, ) = reputationRegistry.isFeedbackAuthorized(
            aliceId,
            charlieId
        );
        (bool auth3, ) = reputationRegistry.isFeedbackAuthorized(
            bobId,
            aliceId
        );
        (bool auth4, ) = reputationRegistry.isFeedbackAuthorized(
            bobId,
            charlieId
        );

        assertTrue(auth1, "Alice->Bob should be authorized");
        assertTrue(auth2, "Alice->Charlie should be authorized");
        assertTrue(auth3, "Bob->Alice should be authorized");
        assertFalse(auth4, "Bob->Charlie should NOT be authorized");
    }

    // ============ Edge Cases ============

    function test_EdgeCase_SelfFeedback() public {
        // Agent can authorize feedback to themselves (weird but not prevented)
        vm.prank(alice);
        reputationRegistry.acceptFeedback(aliceId, aliceId);

        (bool isAuthorized, ) = reputationRegistry.isFeedbackAuthorized(
            aliceId,
            aliceId
        );
        assertTrue(isAuthorized, "Self-feedback should be allowed");
    }

    function test_EdgeCase_ZeroAgentIds() public {
        // Should revert for zero agent IDs (they don't exist)
        vm.expectRevert(IReputationRegistry.AgentNotFound.selector);
        vm.prank(alice);
        reputationRegistry.acceptFeedback(0, aliceId);

        vm.expectRevert(IReputationRegistry.AgentNotFound.selector);
        vm.prank(alice);
        reputationRegistry.acceptFeedback(aliceId, 0);
    }
}

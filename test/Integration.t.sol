// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IdentityRegistry} from "../src/IdentityRegistry.sol";
import {ReputationRegistry} from "../src/ReputationRegistry.sol";
import {ValidationRegistry} from "../src/ValidationRegistry.sol";
import {IIdentityRegistry} from "../src/interfaces/IIdentityRegistry.sol";

/**
 * @title IntegrationTest
 * @dev Integration tests for multi-contract workflows in ERC-8004 Trustless Agents
 */
contract IntegrationTest is Test {
    IdentityRegistry public identityRegistry;
    ReputationRegistry public reputationRegistry;
    ValidationRegistry public validationRegistry;

    // Test accounts
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");
    address david = makeAddr("david");

    // Test data
    string constant ALICE_DOMAIN = "alice.agent";
    string constant BOB_DOMAIN = "bob.agent";
    string constant CHARLIE_DOMAIN = "charlie.agent";
    string constant DAVID_DOMAIN = "david.agent";
    uint256 constant REGISTRATION_FEE = 0.005 ether;
    uint256 constant EXPIRATION_SLOTS = 1000;

    uint256 aliceId;
    uint256 bobId;
    uint256 charlieId;
    uint256 davidId;

    function setUp() public {
        // Deploy all contracts in correct dependency order
        identityRegistry = new IdentityRegistry();
        reputationRegistry = new ReputationRegistry(address(identityRegistry));
        validationRegistry = new ValidationRegistry(address(identityRegistry));

        // Fund test accounts
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);
        vm.deal(david, 100 ether);

        // Register test agents
        aliceId = registerAgent(alice, ALICE_DOMAIN, alice);
        bobId = registerAgent(bob, BOB_DOMAIN, bob);
        charlieId = registerAgent(charlie, CHARLIE_DOMAIN, charlie);
        davidId = registerAgent(david, DAVID_DOMAIN, david);
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

    // ============ Complete Workflow Tests ============

    function test_CompleteWorkflow_ClientServerValidator() public {
        // Scenario: Alice (client) -> Bob (server) -> Charlie (validator)
        // 1. Bob completes work for Alice
        // 2. Bob authorizes Alice to provide feedback
        // 3. Bob requests Charlie to validate the work
        // 4. Charlie validates the work

        bytes32 workHash = keccak256("alice-bob-project-deliverable");

        // Step 1: Bob authorizes Alice to provide feedback
        vm.prank(bob);
        reputationRegistry.acceptFeedback(aliceId, bobId);

        (bool feedbackAuthorized, ) = reputationRegistry.isFeedbackAuthorized(
            aliceId,
            bobId
        );
        assertTrue(
            feedbackAuthorized,
            "Alice should be authorized to provide feedback to Bob"
        );

        // Step 2: Bob requests validation from Charlie
        vm.prank(bob);
        validationRegistry.validationRequest(charlieId, bobId, workHash);

        (bool requestExists, bool requestPending) = validationRegistry
            .isValidationPending(workHash);
        assertTrue(requestExists, "Validation request should exist");
        assertTrue(requestPending, "Validation request should be pending");

        // Step 3: Charlie validates the work
        vm.prank(charlie);
        validationRegistry.validationResponse(workHash, 95);

        (bool hasResponse, uint8 validationScore) = validationRegistry
            .getValidationResponse(workHash);
        assertTrue(hasResponse, "Should have validation response");
        assertEq(validationScore, 95, "Validation score should be 95");

        // Verify final state
        (, bool stillPending) = validationRegistry.isValidationPending(
            workHash
        );
        assertFalse(stillPending, "Request should no longer be pending");
    }

    function test_CompleteWorkflow_MultipleClients() public {
        // Scenario: Bob serves multiple clients (Alice, Charlie, David)
        // Each gets feedback authorization and independent validation

        bytes32 aliceWork = keccak256("alice-project");
        bytes32 charlieWork = keccak256("charlie-project");
        bytes32 davidWork = keccak256("david-project");

        // Bob authorizes all clients to provide feedback
        vm.startPrank(bob);
        reputationRegistry.acceptFeedback(aliceId, bobId);
        reputationRegistry.acceptFeedback(charlieId, bobId);
        reputationRegistry.acceptFeedback(davidId, bobId);
        vm.stopPrank();

        // Verify all authorizations
        (bool auth1, ) = reputationRegistry.isFeedbackAuthorized(
            aliceId,
            bobId
        );
        (bool auth2, ) = reputationRegistry.isFeedbackAuthorized(
            charlieId,
            bobId
        );
        (bool auth3, ) = reputationRegistry.isFeedbackAuthorized(
            davidId,
            bobId
        );
        assertTrue(auth1 && auth2 && auth3, "All clients should be authorized");

        // Request validation for each project from different validators
        vm.prank(bob);
        validationRegistry.validationRequest(aliceId, bobId, aliceWork); // Alice validates her own project

        vm.prank(bob);
        validationRegistry.validationRequest(charlieId, bobId, charlieWork);

        vm.prank(bob);
        validationRegistry.validationRequest(davidId, bobId, davidWork);

        // Each validator provides their assessment
        vm.prank(alice);
        validationRegistry.validationResponse(aliceWork, 88);

        vm.prank(charlie);
        validationRegistry.validationResponse(charlieWork, 92);

        vm.prank(david);
        validationRegistry.validationResponse(davidWork, 85);

        // Verify all validations recorded
        (bool has1, uint8 score1) = validationRegistry.getValidationResponse(
            aliceWork
        );
        (bool has2, uint8 score2) = validationRegistry.getValidationResponse(
            charlieWork
        );
        (bool has3, uint8 score3) = validationRegistry.getValidationResponse(
            davidWork
        );

        assertTrue(has1 && has2 && has3, "All validations should be recorded");
        assertEq(score1, 88, "Alice validation score incorrect");
        assertEq(score2, 92, "Charlie validation score incorrect");
        assertEq(score3, 85, "David validation score incorrect");
    }

    function test_CompleteWorkflow_ValidationChain() public {
        // Scenario: Validation chain where validators validate each other
        // Alice validates Bob's work
        // Bob validates Charlie's work
        // Charlie validates Alice's work

        bytes32 bobWork = keccak256("bob-deliverable");
        bytes32 charlieWork = keccak256("charlie-deliverable");
        bytes32 aliceWork = keccak256("alice-deliverable");

        // Create validation requests
        vm.prank(bob);
        validationRegistry.validationRequest(aliceId, bobId, bobWork);

        vm.prank(charlie);
        validationRegistry.validationRequest(bobId, charlieId, charlieWork);

        vm.prank(alice);
        validationRegistry.validationRequest(charlieId, aliceId, aliceWork);

        // Each validates the next in the chain
        vm.prank(alice);
        validationRegistry.validationResponse(bobWork, 90);

        vm.prank(bob);
        validationRegistry.validationResponse(charlieWork, 85);

        vm.prank(charlie);
        validationRegistry.validationResponse(aliceWork, 95);

        // Verify the chain
        (, uint8 s1) = validationRegistry.getValidationResponse(bobWork);
        (, uint8 s2) = validationRegistry.getValidationResponse(charlieWork);
        (, uint8 s3) = validationRegistry.getValidationResponse(aliceWork);

        assertEq(s1, 90, "Bob's work score incorrect");
        assertEq(s2, 85, "Charlie's work score incorrect");
        assertEq(s3, 95, "Alice's work score incorrect");
    }

    // ============ Cross-Registry Dependency Tests ============

    function test_Dependency_ReputationRequiresIdentity() public {
        // Cannot authorize feedback for non-existent agents
        uint256 fakeAgentId = 999;

        vm.expectRevert();
        vm.prank(bob);
        reputationRegistry.acceptFeedback(fakeAgentId, bobId);

        vm.expectRevert();
        vm.prank(bob);
        reputationRegistry.acceptFeedback(aliceId, fakeAgentId);
    }

    function test_Dependency_ValidationRequiresIdentity() public {
        // Cannot create validation requests for non-existent agents
        uint256 fakeAgentId = 999;
        bytes32 dataHash = keccak256("test");

        vm.expectRevert();
        vm.prank(charlie);
        validationRegistry.validationRequest(fakeAgentId, bobId, dataHash);

        vm.expectRevert();
        vm.prank(charlie);
        validationRegistry.validationRequest(aliceId, fakeAgentId, dataHash);
    }

    function test_Dependency_IdentityUpdateAffectsOtherRegistries() public {
        bytes32 workHash = keccak256("project");

        // Bob authorizes Alice and creates validation request with Charlie
        vm.prank(bob);
        reputationRegistry.acceptFeedback(aliceId, bobId);

        vm.prank(bob);
        validationRegistry.validationRequest(charlieId, bobId, workHash);

        // Bob updates his address
        address newBobAddress = makeAddr("new-bob");
        vm.prank(bob);
        identityRegistry.updateAgent(bobId, "", newBobAddress);

        // Old authorizations should still be valid (stored by ID)
        (bool stillAuthorized, ) = reputationRegistry.isFeedbackAuthorized(
            aliceId,
            bobId
        );
        assertTrue(
            stillAuthorized,
            "Authorization should persist after address update"
        );

        // New address (newBobAddress) should now be able to authorize new feedback
        vm.prank(newBobAddress); // Using new address
        reputationRegistry.acceptFeedback(davidId, bobId);

        (bool newAuth, ) = reputationRegistry.isFeedbackAuthorized(
            davidId,
            bobId
        );
        assertTrue(newAuth, "New address should be able to authorize");

        // Charlie can still validate using new validator address
        vm.prank(charlie);
        validationRegistry.validationResponse(workHash, 80);

        (bool hasResponse, ) = validationRegistry.getValidationResponse(
            workHash
        );
        assertTrue(hasResponse, "Validation should work after address update");
    }

    // ============ Real-World Scenario Tests ============

    function test_Scenario_FreelanceProject() public {
        // Real-world scenario:
        // - Alice hires Bob for a project
        // - Bob delivers work
        // - Alice requests Charlie to validate
        // - Bob authorizes Alice to leave feedback
        // - Charlie validates with high score
        // - Project complete

        bytes32 projectHash = keccak256("freelance-project-deliverable-v1");

        // 1. Bob completes work and authorizes Alice's feedback
        vm.prank(bob);
        reputationRegistry.acceptFeedback(aliceId, bobId);

        // 2. Alice requests independent validation from Charlie
        vm.prank(alice);
        validationRegistry.validationRequest(charlieId, bobId, projectHash);

        // 3. Charlie reviews and validates
        vm.prank(charlie);
        validationRegistry.validationResponse(projectHash, 93);

        // 4. Verify everything is recorded on-chain
        (bool feedbackAuth, bytes32 feedbackAuthId) = reputationRegistry
            .isFeedbackAuthorized(aliceId, bobId);
        (bool validationDone, uint8 score) = validationRegistry
            .getValidationResponse(projectHash);

        assertTrue(feedbackAuth, "Feedback should be authorized");
        assertTrue(feedbackAuthId != bytes32(0), "Should have auth ID");
        assertTrue(validationDone, "Validation should be complete");
        assertEq(score, 93, "Score should be 93");

        // Alice can now use this on-chain proof to:
        // - Leave feedback (authorized via reputationRegistry)
        // - Reference validation score (recorded in validationRegistry)
        // - Verify Bob's identity (via identityRegistry)
    }

    function test_Scenario_DisputedWork() public {
        // Scenario: Work is disputed, multiple validators consulted
        bytes32 disputedWork = keccak256("disputed-deliverable");

        // Alice requests validation from multiple validators
        vm.startPrank(alice);
        validationRegistry.validationRequest(bobId, aliceId, disputedWork);
        vm.stopPrank();

        // First validator gives low score
        vm.prank(bob);
        validationRegistry.validationResponse(disputedWork, 45);

        // Check if validation is done
        (bool exists, bool responded) = validationRegistry.isValidationPending(
            disputedWork
        );
        assertTrue(exists, "Request should exist");
        assertFalse(responded, "Should be responded (not pending)");

        // Alice wants second opinion - creates new request with different hash
        bytes32 disputedWork2 = keccak256("disputed-deliverable-v2");
        vm.prank(alice);
        validationRegistry.validationRequest(charlieId, aliceId, disputedWork2);

        // Second validator gives higher score
        vm.prank(charlie);
        validationRegistry.validationResponse(disputedWork2, 78);

        // Both validations are recorded independently
        (, uint8 score1) = validationRegistry.getValidationResponse(
            disputedWork
        );
        (, uint8 score2) = validationRegistry.getValidationResponse(
            disputedWork2
        );

        assertEq(score1, 45, "First validation should be 45");
        assertEq(score2, 78, "Second validation should be 78");
    }

    function test_Scenario_ExpiredValidation_ReRequest() public {
        bytes32 workHash = keccak256("time-sensitive-work");

        // Request validation
        vm.prank(alice);
        validationRegistry.validationRequest(bobId, aliceId, workHash);

        // Validator doesn't respond in time
        vm.roll(block.number + EXPIRATION_SLOTS + 1);

        // Request is expired
        (, bool pending) = validationRegistry.isValidationPending(workHash);
        assertFalse(pending, "Request should be expired");

        // Alice re-requests validation
        vm.prank(alice);
        validationRegistry.validationRequest(bobId, aliceId, workHash);

        // Validator responds to new request
        vm.prank(bob);
        validationRegistry.validationResponse(workHash, 88);

        (bool hasResponse, uint8 score) = validationRegistry
            .getValidationResponse(workHash);
        assertTrue(hasResponse, "Should have response");
        assertEq(score, 88, "Score should be recorded");
    }

    // ============ Gas Optimization Tests ============

    function test_Gas_AgentRegistration() public {
        uint256 gasBefore = gasleft();

        address newAgent = makeAddr("gas-test");
        vm.deal(newAgent, REGISTRATION_FEE);

        vm.prank(newAgent);
        identityRegistry.newAgent{value: REGISTRATION_FEE}(
            "gas-test.agent",
            newAgent
        );

        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for agent registration:", gasUsed);

        // Ensure gas is reasonable (adjust threshold as needed)
        assertTrue(gasUsed < 200000, "Registration gas too high");
    }

    function test_Gas_FeedbackAuthorization() public {
        uint256 gasBefore = gasleft();

        vm.prank(bob);
        reputationRegistry.acceptFeedback(aliceId, bobId);

        uint256 gasUsed = gasBefore - gasleft();
        console.log("Gas used for feedback authorization:", gasUsed);

        assertTrue(gasUsed < 150000, "Feedback auth gas too high");
    }

    function test_Gas_ValidationRequestAndResponse() public {
        bytes32 dataHash = keccak256("gas-test-data");

        uint256 gasRequest = gasleft();
        vm.prank(alice);
        validationRegistry.validationRequest(bobId, aliceId, dataHash);
        uint256 gasUsedRequest = gasRequest - gasleft();

        uint256 gasResponse = gasleft();
        vm.prank(bob);
        validationRegistry.validationResponse(dataHash, 85);
        uint256 gasUsedResponse = gasResponse - gasleft();

        console.log("Gas used for validation request:", gasUsedRequest);
        console.log("Gas used for validation response:", gasUsedResponse);

        assertTrue(gasUsedRequest < 150000, "Validation request gas too high");
        assertTrue(
            gasUsedResponse < 100000,
            "Validation response gas too high"
        );
    }

    // ============ State Consistency Tests ============

    function test_StateConsistency_AllRegistries() public {
        // Verify all registries reference the same IdentityRegistry
        assertEq(
            address(reputationRegistry.identityRegistry()),
            address(identityRegistry),
            "ReputationRegistry should reference IdentityRegistry"
        );
        assertEq(
            address(validationRegistry.identityRegistry()),
            address(identityRegistry),
            "ValidationRegistry should reference IdentityRegistry"
        );

        // Verify agent counts match
        assertEq(
            identityRegistry.getAgentCount(),
            4,
            "Should have 4 registered agents"
        );

        // Verify all registered agents exist
        assertTrue(identityRegistry.agentExists(aliceId), "Alice should exist");
        assertTrue(identityRegistry.agentExists(bobId), "Bob should exist");
        assertTrue(
            identityRegistry.agentExists(charlieId),
            "Charlie should exist"
        );
        assertTrue(identityRegistry.agentExists(davidId), "David should exist");
    }
}

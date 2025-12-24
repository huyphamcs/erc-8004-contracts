// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IdentityRegistry} from "../src/IdentityRegistry.sol";
import {IIdentityRegistry} from "../src/interfaces/IIdentityRegistry.sol";

/**
 * @title IdentityRegistryTest
 * @dev Comprehensive unit tests for IdentityRegistry contract
 */
contract IdentityRegistryTest is Test {
    IdentityRegistry public registry;

    // Test accounts
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    // Test data
    string constant ALICE_DOMAIN = "alice.agent";
    string constant BOB_DOMAIN = "bob.agent";
    string constant CHARLIE_DOMAIN = "charlie.agent";
    uint256 constant REGISTRATION_FEE = 0.005 ether;

    // Events to test
    event AgentRegistered(
        uint256 indexed agentId,
        string agentDomain,
        address agentAddress
    );
    event AgentUpdated(
        uint256 indexed agentId,
        string agentDomain,
        address agentAddress
    );

    function setUp() public {
        registry = new IdentityRegistry();

        // Fund test accounts
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);
    }

    // ============ Helper Functions ============

    function registerAgent(
        address sender,
        string memory domain,
        address agentAddress
    ) internal returns (uint256) {
        vm.prank(sender);
        return registry.newAgent{value: REGISTRATION_FEE}(domain, agentAddress);
    }

    // ============ Registration Tests - Happy Path ============

    function test_NewAgent_Success() public {
        vm.expectEmit(true, false, false, true);
        emit AgentRegistered(1, ALICE_DOMAIN, alice);

        vm.prank(alice);
        uint256 agentId = registry.newAgent{value: REGISTRATION_FEE}(
            ALICE_DOMAIN,
            alice
        );

        assertEq(agentId, 1, "First agent should have ID 1");
        assertEq(registry.getAgentCount(), 1, "Agent count should be 1");
    }

    function test_NewAgent_MultipleAgents() public {
        uint256 aliceId = registerAgent(alice, ALICE_DOMAIN, alice);
        uint256 bobId = registerAgent(bob, BOB_DOMAIN, bob);
        uint256 charlieId = registerAgent(charlie, CHARLIE_DOMAIN, charlie);

        assertEq(aliceId, 1, "Alice should have ID 1");
        assertEq(bobId, 2, "Bob should have ID 2");
        assertEq(charlieId, 3, "Charlie should have ID 3");
        assertEq(registry.getAgentCount(), 3, "Total agents should be 3");
    }

    function test_NewAgent_FeeIsBurned() public {
        uint256 contractBalanceBefore = address(registry).balance;

        vm.prank(alice);
        registry.newAgent{value: REGISTRATION_FEE}(ALICE_DOMAIN, alice);

        uint256 contractBalanceAfter = address(registry).balance;
        assertEq(
            contractBalanceAfter - contractBalanceBefore,
            REGISTRATION_FEE,
            "Fee should be locked in contract"
        );
    }

    // ============ Registration Tests - Validation Errors ============

    function test_NewAgent_RevertIf_InsufficientFee() public {
        vm.expectRevert(IIdentityRegistry.InsufficientFee.selector);
        vm.prank(alice);
        registry.newAgent{value: 0.004 ether}(ALICE_DOMAIN, alice);
    }

    function test_NewAgent_RevertIf_ExcessiveFee() public {
        vm.expectRevert(IIdentityRegistry.InsufficientFee.selector);
        vm.prank(alice);
        registry.newAgent{value: 0.006 ether}(ALICE_DOMAIN, alice);
    }

    function test_NewAgent_RevertIf_EmptyDomain() public {
        vm.expectRevert(IIdentityRegistry.InvalidDomain.selector);
        vm.prank(alice);
        registry.newAgent{value: REGISTRATION_FEE}("", alice);
    }

    function test_NewAgent_RevertIf_ZeroAddress() public {
        vm.expectRevert(IIdentityRegistry.InvalidAddress.selector);
        vm.prank(alice);
        registry.newAgent{value: REGISTRATION_FEE}(ALICE_DOMAIN, address(0));
    }

    function test_NewAgent_RevertIf_DomainAlreadyRegistered() public {
        registerAgent(alice, ALICE_DOMAIN, alice);

        vm.expectRevert(IIdentityRegistry.DomainAlreadyRegistered.selector);
        vm.prank(bob);
        registry.newAgent{value: REGISTRATION_FEE}(ALICE_DOMAIN, bob);
    }

    function test_NewAgent_RevertIf_AddressAlreadyRegistered() public {
        registerAgent(alice, ALICE_DOMAIN, alice);

        vm.expectRevert(IIdentityRegistry.AddressAlreadyRegistered.selector);
        vm.prank(bob);
        registry.newAgent{value: REGISTRATION_FEE}(BOB_DOMAIN, alice);
    }

    // ============ Update Tests - Happy Path ============

    function test_UpdateAgent_Domain() public {
        uint256 agentId = registerAgent(alice, ALICE_DOMAIN, alice);

        vm.expectEmit(true, false, false, true);
        emit AgentUpdated(agentId, "alice-new.agent", alice);

        vm.prank(alice);
        bool success = registry.updateAgent(
            agentId,
            "alice-new.agent",
            address(0)
        );

        assertTrue(success, "Update should succeed");

        IIdentityRegistry.AgentInfo memory agent = registry.getAgent(agentId);
        assertEq(
            agent.agentDomain,
            "alice-new.agent",
            "Domain should be updated"
        );
        assertEq(agent.agentAddress, alice, "Address should remain unchanged");
    }

    function test_UpdateAgent_Address() public {
        uint256 agentId = registerAgent(alice, ALICE_DOMAIN, alice);

        vm.expectEmit(true, false, false, true);
        emit AgentUpdated(agentId, ALICE_DOMAIN, bob);

        vm.prank(alice);
        bool success = registry.updateAgent(agentId, "", bob);

        assertTrue(success, "Update should succeed");

        IIdentityRegistry.AgentInfo memory agent = registry.getAgent(agentId);
        assertEq(
            agent.agentDomain,
            ALICE_DOMAIN,
            "Domain should remain unchanged"
        );
        assertEq(agent.agentAddress, bob, "Address should be updated");
    }

    function test_UpdateAgent_Both() public {
        uint256 agentId = registerAgent(alice, ALICE_DOMAIN, alice);

        vm.prank(alice);
        registry.updateAgent(agentId, "alice-new.agent", bob);

        IIdentityRegistry.AgentInfo memory agent = registry.getAgent(agentId);
        assertEq(
            agent.agentDomain,
            "alice-new.agent",
            "Domain should be updated"
        );
        assertEq(agent.agentAddress, bob, "Address should be updated");
    }

    function test_UpdateAgent_OldMappingsRemoved() public {
        uint256 agentId = registerAgent(alice, ALICE_DOMAIN, alice);

        // Update domain
        vm.prank(alice);
        registry.updateAgent(agentId, "alice-new.agent", address(0));

        // Old domain should not resolve
        vm.expectRevert(IIdentityRegistry.AgentNotFound.selector);
        registry.resolveByDomain(ALICE_DOMAIN);

        // New domain should resolve
        IIdentityRegistry.AgentInfo memory agent = registry.resolveByDomain(
            "alice-new.agent"
        );
        assertEq(
            agent.agentId,
            agentId,
            "New domain should resolve to same agent"
        );
    }

    function test_UpdateAgent_TransferOwnership() public {
        uint256 agentId = registerAgent(alice, ALICE_DOMAIN, alice);

        // Alice transfers to Bob
        vm.prank(alice);
        registry.updateAgent(agentId, "", bob);

        // Bob can now update
        vm.prank(bob);
        bool success = registry.updateAgent(agentId, BOB_DOMAIN, address(0));
        assertTrue(
            success,
            "Bob should be able to update after ownership transfer"
        );

        // Alice can no longer update
        vm.expectRevert(IIdentityRegistry.UnauthorizedUpdate.selector);
        vm.prank(alice);
        registry.updateAgent(agentId, "alice-unauthorized.agent", address(0));
    }

    // ============ Update Tests - Validation Errors ============

    function test_UpdateAgent_RevertIf_AgentNotFound() public {
        vm.expectRevert(IIdentityRegistry.AgentNotFound.selector);
        vm.prank(alice);
        registry.updateAgent(999, "new.agent", address(0));
    }

    function test_UpdateAgent_RevertIf_Unauthorized() public {
        uint256 agentId = registerAgent(alice, ALICE_DOMAIN, alice);

        vm.expectRevert(IIdentityRegistry.UnauthorizedUpdate.selector);
        vm.prank(bob);
        registry.updateAgent(agentId, "bob-steal.agent", bob);
    }

    function test_UpdateAgent_RevertIf_DomainAlreadyTaken() public {
        registerAgent(alice, ALICE_DOMAIN, alice);
        uint256 bobId = registerAgent(bob, BOB_DOMAIN, bob);

        vm.expectRevert(IIdentityRegistry.DomainAlreadyRegistered.selector);
        vm.prank(bob);
        registry.updateAgent(bobId, ALICE_DOMAIN, address(0));
    }

    function test_UpdateAgent_RevertIf_AddressAlreadyTaken() public {
        registerAgent(alice, ALICE_DOMAIN, alice);
        uint256 bobId = registerAgent(bob, BOB_DOMAIN, bob);

        vm.expectRevert(IIdentityRegistry.AddressAlreadyRegistered.selector);
        vm.prank(bob);
        registry.updateAgent(bobId, "", alice);
    }

    // ============ Query Tests - Happy Path ============

    function test_GetAgent_Success() public {
        uint256 agentId = registerAgent(alice, ALICE_DOMAIN, alice);

        IIdentityRegistry.AgentInfo memory agent = registry.getAgent(agentId);
        assertEq(agent.agentId, agentId, "Agent ID should match");
        assertEq(agent.agentDomain, ALICE_DOMAIN, "Domain should match");
        assertEq(agent.agentAddress, alice, "Address should match");
    }

    function test_ResolveByDomain_Success() public {
        uint256 agentId = registerAgent(alice, ALICE_DOMAIN, alice);

        IIdentityRegistry.AgentInfo memory agent = registry.resolveByDomain(
            ALICE_DOMAIN
        );
        assertEq(agent.agentId, agentId, "Should resolve to correct agent");
        assertEq(agent.agentAddress, alice, "Address should match");
    }

    function test_ResolveByAddress_Success() public {
        uint256 agentId = registerAgent(alice, ALICE_DOMAIN, alice);

        IIdentityRegistry.AgentInfo memory agent = registry.resolveByAddress(
            alice
        );
        assertEq(agent.agentId, agentId, "Should resolve to correct agent");
        assertEq(agent.agentDomain, ALICE_DOMAIN, "Domain should match");
    }

    function test_AgentExists_True() public {
        uint256 agentId = registerAgent(alice, ALICE_DOMAIN, alice);
        assertTrue(registry.agentExists(agentId), "Agent should exist");
    }

    function test_AgentExists_False() public {
        assertFalse(
            registry.agentExists(999),
            "Non-existent agent should return false"
        );
    }

    // ============ Query Tests - Errors ============

    function test_GetAgent_RevertIf_NotFound() public {
        vm.expectRevert(IIdentityRegistry.AgentNotFound.selector);
        registry.getAgent(999);
    }

    function test_ResolveByDomain_RevertIf_NotFound() public {
        vm.expectRevert(IIdentityRegistry.AgentNotFound.selector);
        registry.resolveByDomain("nonexistent.agent");
    }

    function test_ResolveByAddress_RevertIf_NotFound() public {
        vm.expectRevert(IIdentityRegistry.AgentNotFound.selector);
        registry.resolveByAddress(makeAddr("nonexistent"));
    }

    // ============ State Integrity Tests ============

    function test_AgentCount_Increments() public {
        assertEq(registry.getAgentCount(), 0, "Initial count should be 0");

        registerAgent(alice, ALICE_DOMAIN, alice);
        assertEq(registry.getAgentCount(), 1, "Count should be 1");

        registerAgent(bob, BOB_DOMAIN, bob);
        assertEq(registry.getAgentCount(), 2, "Count should be 2");

        registerAgent(charlie, CHARLIE_DOMAIN, charlie);
        assertEq(registry.getAgentCount(), 3, "Count should be 3");
    }

    function test_BiDirectionalMappings_Consistent() public {
        uint256 agentId = registerAgent(alice, ALICE_DOMAIN, alice);

        // Query by ID
        IIdentityRegistry.AgentInfo memory agentById = registry.getAgent(
            agentId
        );

        // Query by domain
        IIdentityRegistry.AgentInfo memory agentByDomain = registry
            .resolveByDomain(ALICE_DOMAIN);

        // Query by address
        IIdentityRegistry.AgentInfo memory agentByAddress = registry
            .resolveByAddress(alice);

        // All should return the same data
        assertEq(agentById.agentId, agentId, "ID query mismatch");
        assertEq(agentByDomain.agentId, agentId, "Domain query mismatch");
        assertEq(agentByAddress.agentId, agentId, "Address query mismatch");

        assertEq(
            agentById.agentDomain,
            ALICE_DOMAIN,
            "ID query domain mismatch"
        );
        assertEq(
            agentByDomain.agentDomain,
            ALICE_DOMAIN,
            "Domain query domain mismatch"
        );
        assertEq(
            agentByAddress.agentDomain,
            ALICE_DOMAIN,
            "Address query domain mismatch"
        );
    }

    function test_RegistrationFee_Constant() public {
        assertEq(
            registry.REGISTRATION_FEE(),
            REGISTRATION_FEE,
            "Registration fee should be 0.005 ETH"
        );
    }

    // ============ Fuzz Tests ============

    function testFuzz_NewAgent_ValidInputs(
        string calldata domain,
        address agentAddress
    ) public {
        // Assume valid inputs
        vm.assume(bytes(domain).length > 0 && bytes(domain).length < 256);
        vm.assume(agentAddress != address(0));
        vm.assume(!registry.agentExists(1)); // Ensure clean state

        vm.deal(agentAddress, REGISTRATION_FEE);

        vm.prank(agentAddress);
        uint256 agentId = registry.newAgent{value: REGISTRATION_FEE}(
            domain,
            agentAddress
        );

        assertTrue(agentId > 0, "Agent ID should be greater than 0");
        assertTrue(registry.agentExists(agentId), "Agent should exist");

        IIdentityRegistry.AgentInfo memory agent = registry.getAgent(agentId);
        assertEq(agent.agentDomain, domain, "Domain should match");
        assertEq(agent.agentAddress, agentAddress, "Address should match");
    }
}

""Tests for the governance module."""
import pytest
from datetime import datetime

from core.governance import GovernanceManager, GovernanceRule


class TestGovernanceRule:
    """Tests for the GovernanceRule class."""

    def test_rule_creation(self):
        ""Test creating a governance rule."""
        rule = GovernanceRule(
            id="test-rule",
            name="Test Rule",
            description="This is a test rule",
            severity="high"
        )
        
        assert rule.id == "test-rule"
        assert rule.name == "Test Rule"
        assert rule.description == "This is a test rule"
        assert rule.severity == "high"
        assert rule.enabled is True
        assert isinstance(rule.created_at, datetime)
        assert isinstance(rule.updated_at, datetime)


class TestGovernanceManager:
    """Tests for the GovernanceManager class."""
    
    @pytest.fixture
    def manager(self):
        ""Create a GovernanceManager instance with test data."""
        manager = GovernanceManager()
        
        # Add some test rules
        rules = [
            GovernanceRule(
                id=f"rule-{i}",
                name=f"Test Rule {i}",
                description=f"Test Description {i}",
                severity=severity,
                enabled=(i % 2 == 0)  # Alternate between enabled and disabled
            )
            for i, severity in enumerate(["low", "medium", "high", "critical"])
        ]
        
        for rule in rules:
            manager.add_rule(rule)
            
        return manager
    
    def test_add_rule(self, manager):
        ""Test adding a new rule."""
        rule = GovernanceRule(
            id="new-rule",
            name="New Rule",
            description="A new test rule",
            severity="medium"
        )
        
        assert manager.add_rule(rule) is True
        assert manager.get_rule("new-rule") == rule
        
    def test_add_duplicate_rule(self, manager):
        ""Test adding a duplicate rule ID."""
        rule = GovernanceRule(
            id="rule-0",  # This ID already exists in the fixture
            name="Duplicate Rule",
            description="This should not be added",
            severity="low"
        )
        
        assert manager.add_rule(rule) is False
        
    def test_remove_rule(self, manager):
        ""Test removing an existing rule."""
        assert manager.remove_rule("rule-0") is True
        assert manager.get_rule("rule-0") is None
        
    def test_remove_nonexistent_rule(self, manager):
        ""Test removing a rule that doesn't exist."""
        assert manager.remove_rule("nonexistent-rule") is False
        
    def test_list_rules(self, manager):
        ""Test listing all rules."""
        rules = manager.list_rules()
        assert len(rules) == 4  # We added 4 rules in the fixture
        
    def test_list_enabled_rules(self, manager):
        ""Test listing only enabled rules."""
        enabled_rules = manager.list_rules(enabled_only=True)
        assert len(enabled_rules) == 2  # 2 out of 4 rules are enabled in the fixture
        assert all(rule.enabled for rule in enabled_rules)
        
    def test_validate(self, manager):
        ""Test the validate method with test data."""
        test_data = {"test": "data"}
        result = manager.validate(test_data)
        
        assert isinstance(result, dict)
        assert "valid" in result
        assert "violations" in result
        assert "timestamp" in result
        
        # In our test implementation, empty data should always be invalid
        empty_result = manager.validate({})
        assert empty_result["valid"] is False
        assert len(empty_result["violations"]) > 0

""Tests for the validators module."""
import pytest

from utils.validators import validate_severity, validate_rule_data


class TestValidateSeverity:
    """Tests for the validate_severity function."""
    
    def test_valid_severity_levels(self):
        ""Test all valid severity levels."""
        for severity in ["low", "medium", "high", "critical"]:
            is_valid, message = validate_severity(severity)
            assert is_valid is True
            assert message is None
            
    def test_case_insensitive(self):
        ""Test that severity is case-insensitive."""
        is_valid, message = validate_severity("HIGH")
        assert is_valid is True
        assert message is None
        
    def test_invalid_severity(self):
        ""Test with an invalid severity level."""
        is_valid, message = validate_severity("invalid")
        assert is_valid is False
        assert "Invalid severity level" in message
        
    def test_non_string_severity(self):
        ""Test with a non-string severity."""
        is_valid, message = validate_severity(123)
        assert is_valid is False
        assert "Severity must be a string" in message


class TestValidateRuleData:
    ""Tests for the validate_rule_data function."""
    
    def test_valid_rule_data(self):
        ""Test with valid rule data."""
        rule_data = {
            "name": "Test Rule",
            "description": "This is a test rule",
            "severity": "high"
        }
        is_valid, message = validate_rule_data(rule_data)
        assert is_valid is True
        assert message is None
        
    def test_missing_fields(self):
        ""Test with missing required fields."""
        rule_data = {
            "name": "Test Rule"
            # Missing description and severity
        }
        is_valid, message = validate_rule_data(rule_data)
        assert is_valid is False
        assert "Missing required fields" in message
        assert "description" in message
        assert "severity" in message
        
    def test_empty_name(self):
        ""Test with an empty rule name."""
        rule_data = {
            "name": "",  # Empty name
            "description": "This is a test rule",
            "severity": "high"
        }
        is_valid, message = validate_rule_data(rule_data)
        assert is_valid is False
        assert "Rule name cannot be empty" in message
        
    def test_empty_description(self):
        ""Test with an empty description."""
        rule_data = {
            "name": "Test Rule",
            "description": "",  # Empty description
            "severity": "high"
        }
        is_valid, message = validate_rule_data(rule_data)
        assert is_valid is False
        assert "Rule description cannot be empty" in message
        
    def test_invalid_severity(self):
        ""Test with an invalid severity level."""
        rule_data = {
            "name": "Test Rule",
            "description": "This is a test rule",
            "severity": "invalid"  # Invalid severity
        }
        is_valid, message = validate_rule_data(rule_data)
        assert is_valid is False
        assert "Invalid severity level" in message

""Validation utilities for the governant package."""
from typing import Any, Dict, Optional, Tuple

SEVERITY_LEVELS = {"low", "medium", "high", "critical"}


def validate_severity(severity: str) -> Tuple[bool, Optional[str]]:
    """Validate that the severity level is valid.
    
    Args:
        severity: The severity level to validate
        
    Returns:
        Tuple containing:
            - bool: True if valid, False otherwise
            - Optional[str]: Error message if invalid, None if valid
    """
    if not isinstance(severity, str):
        return False, f"Severity must be a string, got {type(severity).__name__}"
        
    if severity.lower() not in SEVERITY_LEVELS:
        return False, f"Invalid severity level: {severity}. Must be one of: {', '.join(sorted(SEVERITY_LEVELS))}"
        
    return True, None


def validate_rule_data(rule_data: Dict[str, Any]) -> Tuple[bool, Optional[str]]:
    """Validate governance rule data.
    
    Args:
        rule_data: Dictionary containing rule data
        
    Returns:
        Tuple containing:
            - bool: True if valid, False otherwise
            - Optional[str]: Error message if invalid, None if valid
    """
    required_fields = {"name", "description", "severity"}
    missing_fields = required_fields - set(rule_data.keys())
    
    if missing_fields:
        return False, f"Missing required fields: {', '.join(sorted(missing_fields))}"
    
    # Validate severity
    is_valid, error = validate_severity(rule_data["severity"])
    if not is_valid:
        return False, error
    
    # Validate name and description are non-empty strings
    if not isinstance(rule_data["name"], str) or not rule_data["name"].strip():
        return False, "Rule name cannot be empty"
        
    if not isinstance(rule_data["description"], str) or not rule_data["description"].strip():
        return False, "Rule description cannot be empty"
    
    return True, None

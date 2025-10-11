""Core governance functionality."""
from dataclasses import dataclass
from datetime import datetime
from typing import Dict, List, Optional


@dataclass
class GovernanceRule:
    """Represents a governance rule with its metadata and conditions."""
    id: str
    name: str
    description: str
    severity: str  # 'low', 'medium', 'high', 'critical'
    enabled: bool = True
    created_at: datetime = None
    updated_at: datetime = None

    def __post_init__(self):
        """Initialize timestamps if not provided."""
        now = datetime.utcnow()
        if self.created_at is None:
            self.created_at = now
        if self.updated_at is None:
            self.updated_at = now


class GovernanceManager:
    """Manages governance rules and their enforcement."""

    def __init__(self):
        self.rules: Dict[str, GovernanceRule] = {}

    def add_rule(self, rule: GovernanceRule) -> bool:
        ""Add a new governance rule.
        
        Args:
            rule: The governance rule to add
            
        Returns:
            bool: True if the rule was added, False if a rule with the same ID already exists
        """
        if rule.id in self.rules:
            return False
            
        self.rules[rule.id] = rule
        return True

    def remove_rule(self, rule_id: str) -> bool:
        ""Remove a governance rule by ID.
        
        Args:
            rule_id: The ID of the rule to remove
            
        Returns:
            bool: True if the rule was removed, False if no rule was found with the given ID
        """
        if rule_id not in self.rules:
            return False
            
        del self.rules[rule_id]
        return True

    def get_rule(self, rule_id: str) -> Optional[GovernanceRule]:
        ""Get a governance rule by ID.
        
        Args:
            rule_id: The ID of the rule to retrieve
            
        Returns:
            Optional[GovernanceRule]: The rule if found, None otherwise
        """
        return self.rules.get(rule_id)

    def list_rules(self, enabled_only: bool = False) -> List[GovernanceRule]:
        ""List all governance rules, optionally filtered by enabled status.
        
        Args:
            enabled_only: If True, only return enabled rules
            
        Returns:
            List[GovernanceRule]: List of governance rules
        """
        if not enabled_only:
            return list(self.rules.values())
        return [rule for rule in self.rules.values() if rule.enabled]

    def validate(self, data: dict) -> dict:
        ""Validate data against all enabled governance rules.
        
        Args:
            data: The data to validate
            
        Returns:
            dict: Dictionary with validation results
        """
        results = {
            'valid': True,
            'violations': [],
            'timestamp': datetime.utcnow().isoformat()
        }
        
        for rule in self.list_rules(enabled_only=True):
            # In a real implementation, this would contain actual validation logic
            # based on the rule's conditions
            violation = self._check_rule(rule, data)
            if violation:
                results['valid'] = False
                results['violations'].append({
                    'rule_id': rule.id,
                    'rule_name': rule.name,
                    'severity': rule.severity,
                    'message': violation
                })
                
        return results
    
    def _check_rule(self, rule: GovernanceRule, data: dict) -> Optional[str]:
        ""Check if data violates a specific rule.
        
        This is a placeholder method that would contain the actual validation logic.
        In a real implementation, this would evaluate the rule's conditions against the data.
        
        Args:
            rule: The rule to check against
            data: The data to validate
            
        Returns:
            Optional[str]: Error message if validation fails, None otherwise
        """
        # This is a simplified example - in a real implementation, you would have
        # more sophisticated rule evaluation logic here
        if not data:
            return "Data cannot be empty"
            
        return None

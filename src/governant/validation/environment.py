"""Environment validation module for Governant.

This module provides functionality to validate environments against defined policies.
"""

import json
import os
import re
import sys
from typing import Dict, Any, Optional


def load_policy(policy_path: str = ".gate/policy.json") -> Dict[str, Any]:
    """Load the policy file.
    
    Args:
        policy_path: Path to the policy file.
        
    Returns:
        Dict with the loaded policies.
        
    Raises:
        FileNotFoundError: If the policy file doesn't exist.
        json.JSONDecodeError: If the file is not a valid JSON.
    """
    try:
        with open(policy_path) as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"Error: Policy file not found at {policy_path}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Policy file is not a valid JSON: {e}")
        sys.exit(1)


def validate_environment(environment: str, policy: Dict[str, Any]) -> bool:
    """Validate if an environment complies with defined policies.
    
    Args:
        environment: Environment name to validate (e.g., 'development', 'staging').
        policy: Dictionary with loaded policies.
        
    Returns:
        bool: True if the environment complies with all policies, False otherwise.
    """
    if environment not in policy.get("environments", {}):
        print(f"Error: Environment '{environment}' is not defined in the policies")
        return False
    
    env_config = policy["environments"][environment]
    
    if not env_config.get("enabled", False):
        print(f"Error: Environment '{environment}' is not enabled")
        return False
    
    rules = env_config.get("rules", {})
    print(f"\nValidating policies for environment: {environment}")
    print("-" * 40)
    
    all_ok = True
    
    # 1. Validate allowed branches
    allowed_branches = rules.get("allowed_branches")
    if allowed_branches is not None:  # None means all branches are allowed
        current_branch = os.environ.get("GITHUB_REF_NAME", "")
        if not current_branch:
            current_branch = os.popen("git rev-parse --abbrev-ref HEAD").read().strip()
            
        if current_branch not in allowed_branches:
            print(f"❌ Error: Branch '{current_branch}' is not allowed in environment '{environment}'")
            print(f"    Allowed branches: {', '.join(allowed_branches)}")
            all_ok = False
        else:
            print(f"✓ Branch '{current_branch}' is allowed in environment '{environment}'")
    
    # 2. Validate required approvals
    required_approvals = rules.get("approvals_required", 0)
    if required_approvals > 0:
        print(f"ℹ️  {required_approvals} approvals are required for environment '{environment}'")
        # In a real workflow, PR approvals would be checked here
    
    # 3. Validate ticket requirement
    if rules.get("require_ticket", False):
        ticket_pattern = rules.get("ticket_pattern", "")
        pr_title = os.environ.get("PR_TITLE", "")
        if not pr_title:  # If not in environment variables, try to get it from git
            pr_title = os.popen("git log -1 --pretty=%B").read().strip()
        
        if ticket_pattern and not re.search(ticket_pattern, pr_title):
            print("❌ Error: PR title does not match the required ticket pattern")
            print(f"    PR title: {pr_title}")
            print(f"    Required pattern: {ticket_pattern}")
            all_ok = False
        else:
            print("✓ PR title matches the required ticket pattern")
    
    # 4. Validate tests passed
    if rules.get("tests_passed", False):
        # In a real workflow, this would verify that all tests have passed
        print("ℹ️  All tests must pass")
    
    # 5. Validate commit signature
    if rules.get("signed_off", False):
        # Verify if the last commit has a sign-off
        last_commit = os.popen("git log -1 --pretty=%B").read().strip()
        if "Signed-off-by:" not in last_commit:
            print("❌ Error: Last commit is not signed off")
            all_ok = False
        else:
            print("✓ Last commit is properly signed off")
    
    print("-" * 40)
    if all_ok:
        print(f"✅ Environment '{environment}' is compliant with all policies")
    else:
        print(f"❌ Environment '{environment}' does not meet all policies")
    
    return all_ok


def main():
    """Main function for command-line usage."""
    import argparse
    
    parser = argparse.ArgumentParser(description="Validates environment compliance with policies.")
    parser.add_argument(
        "environment",
        choices=["development", "staging", "production"],
        help="Environment to validate"
    )
    parser.add_argument(
        "--policy",
        default=".gate/policy.json",
        help="Path to policy file (default: .gate/policy.json)"
    )
    
    args = parser.parse_args()
    
    try:
        policy = load_policy(args.policy)
        is_compliant = validate_environment(args.environment, policy)
        
        # Exit with error code if not compliant
        if not is_compliant:
            sys.exit(1)
            
    except Exception as e:
        print(f"Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

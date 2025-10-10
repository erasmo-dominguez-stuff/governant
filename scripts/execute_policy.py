#!/usr/bin/env python3
"""
Script to execute policy validation using OPA with structured input format
"""

import json
import sys
import subprocess
from pathlib import Path
from typing import Dict, Any

def build_input_context(environment: str, ref: str, ticket_refs: list = None, 
                       approvers: list = None, checks: Dict = None, 
                       signed_off: bool = False, deployments_today: int = 0,
                       repo_environments: list = None) -> Dict[str, Any]:
    """
    Build input context for policy execution
    
    Args:
        environment: Target environment (production, staging, development)
        ref: Git reference (e.g., "refs/heads/main")
        ticket_refs: List of ticket references
        approvers: List of approvers
        checks: Dictionary of checks (tests, etc.)
        signed_off: Whether deployment is signed off
        deployments_today: Number of deployments today
        repo_environments: List of environments defined in repo
        
    Returns:
        Structured input for OPA policy execution
    """
    return {
        "environment": environment,
        "ref": ref,
        "repo_policy": json.load(open(".gate/policy.json")),
        "repo_environments": repo_environments or ["production", "staging", "development"],
        "workflow_meta": {
            "ticket_refs": ticket_refs or [],
            "approvers": approvers or [],
            "checks": checks or {"tests": False},
            "signed_off": signed_off,
            "deployments_today": deployments_today
        }
    }

def execute_policy_with_opa(input_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Execute policy using OPA
    
    Args:
        input_data: Input context for policy execution
        
    Returns:
        Policy execution result
    """
    try:
        # Create temporary input file
        input_file = Path("temp_input.json")
        with open(input_file, 'w') as f:
            json.dump(input_data, f, indent=2)
        
        # Execute OPA for allow decision
        cmd_allow = [
            "opa", "eval",
            "--data", ".gate/github-release.rego",
            "--input", str(input_file),
            "--format", "json",
            "data.github.deploy.allow"
        ]
        
        # Execute OPA for violations
        cmd_violations = [
            "opa", "eval",
            "--data", ".gate/github-release.rego",
            "--input", str(input_file),
            "--format", "json",
            "data.github.deploy.violations"
        ]
        
        # Execute allow query
        result_allow = subprocess.run(cmd_allow, capture_output=True, text=True)
        
        # Execute violations query
        result_violations = subprocess.run(cmd_violations, capture_output=True, text=True)
        
        # Clean up
        input_file.unlink(missing_ok=True)
        
        if result_allow.returncode != 0:
            return {
                "error": True,
                "message": f"OPA execution failed: {result_allow.stderr}"
            }
        
        # Parse allow result
        allow_result = json.loads(result_allow.stdout)
        allow = False
        if allow_result.get("result", []):
            allow = allow_result["result"][0].get("expressions", [{}])[0].get("value", False)
        
        # Parse violations result
        violations = []
        if result_violations.returncode == 0:
            violations_result = json.loads(result_violations.stdout)
            if violations_result.get("result", []):
                violations = violations_result["result"][0].get("expressions", [{}])[0].get("value", [])
        
        return {
            "allowed": allow,
            "violations": violations,
            "input": input_data
        }
        
    except Exception as e:
        return {
            "error": True,
            "message": f"Policy execution error: {str(e)}"
        }

def main():
    """Main function"""
    print("🚀 Policy Execution Engine")
    print("=" * 40)
    
    # Check if OPA is available
    try:
        subprocess.run(["opa", "version"], capture_output=True, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("❌ OPA not found. Please install Open Policy Agent")
        return 1
    
    # Example usage - you can modify these parameters
    test_cases = [
        {
            "name": "production-valid",
            "environment": "production",
            "ref": "refs/heads/main",
            "ticket_refs": ["CHG-123456"],
            "approvers": ["user1", "user2"],
            "checks": {"tests": True},
            "signed_off": True,
            "deployments_today": 3,
            "repo_environments": ["production", "staging", "development"]
        },
        {
            "name": "production-invalid",
            "environment": "production", 
            "ref": "refs/heads/feature-branch",
            "ticket_refs": ["INVALID-123"],
            "approvers": ["user1"],
            "checks": {"tests": False},
            "signed_off": False,
            "deployments_today": 8,
            "repo_environments": ["production", "staging", "development"]
        }
    ]
    
    for test_case in test_cases:
        print(f"\n🧪 Testing: {test_case['name']}")
        print("-" * 30)
        
        # Build input
        input_data = build_input_context(
            environment=test_case["environment"],
            ref=test_case["ref"],
            ticket_refs=test_case["ticket_refs"],
            approvers=test_case["approvers"],
            checks=test_case["checks"],
            signed_off=test_case["signed_off"],
            deployments_today=test_case["deployments_today"],
            repo_environments=test_case["repo_environments"]
        )
        
        # Execute policy
        result = execute_policy_with_opa(input_data)
        
        if result.get("error"):
            print(f"❌ Error: {result['message']}")
            continue
            
        if result["allowed"]:
            print("✅ ALLOWED")
        else:
            print("❌ DENIED")
            violations = result.get("violations", [])
            print(f"   Violations ({len(violations)}):")
            for violation in violations:
                code = violation.get("code", "unknown")
                msg = violation.get("msg", "No message")
                print(f"   • [{code}] {msg}")
    
    print("\n" + "=" * 40)
    print("🏁 Policy execution completed")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())

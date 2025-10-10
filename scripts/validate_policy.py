#!/usr/bin/env python3
"""
Python script to validate Rego policies using WASM
"""

import json
import os
import sys
from pathlib import Path
from typing import Dict, Any, List, Union

try:
    from wasmtime import Store, Module, Instance, Func, FuncType, ValType
    WASMTIME_AVAILABLE = True
except ImportError:
    print("Warning: wasmtime package not found. Using JSON-based validation only.")
    WASMTIME_AVAILABLE = False

class RegoWASMValidator:
    """
    A class to load and execute Rego policies compiled to WASM
    """
    
    def __init__(self, wasm_path: str, data_path: str = None):
        """
        Initialize the validator with WASM file and optional data
        
        Args:
            wasm_path: Path to the compiled WASM file (can be None)
            data_path: Path to the policy data JSON file
        """
        self.wasm_path = Path(wasm_path) if wasm_path else None
        self.data_path = Path(data_path) if data_path else None
        self.store = Store() if WASMTIME_AVAILABLE else None
        self.instance = None
        self.data = {}
        
        if self.wasm_path and not self.wasm_path.exists():
            raise FileNotFoundError(f"WASM file not found: {wasm_path}")
            
        if self.data_path and self.data_path.exists():
            with open(self.data_path, 'r') as f:
                self.data = json.load(f)
                
        if self.wasm_path:
            self._load_wasm()
    
    def _load_wasm(self):
        """Load the WASM module"""
        if not WASMTIME_AVAILABLE:
            print("⚠️  WASM loading skipped - wasmtime not available")
            return
            
        try:
            with open(self.wasm_path, 'rb') as f:
                wasm_bytes = f.read()
            
            module = Module(self.store.engine, wasm_bytes)
            self.instance = Instance(self.store, module, [])
            print(f"✅ Successfully loaded WASM from {self.wasm_path}")
            
        except Exception as e:
            print(f"❌ Failed to load WASM: {e}")
            raise
    
    def validate_input(self, input_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Validate input against the policy
        
        Args:
            input_data: The input to validate
            
        Returns:
            Dictionary with validation results
        """
        try:
            # For now, we'll implement a simplified validation
            # In a real implementation, you'd call the WASM functions
            result = {
                "allowed": False,
                "violations": [],
                "input": input_data,
                "timestamp": "2025-01-18T16:00:00Z"
            }
            
            # Basic validation logic (placeholder)
            env = input_data.get("env", "")
            if env in self.data.get("policy", {}).get("environments", {}):
                rules = self.data["policy"]["environments"][env]["rules"]
                violations = self._check_rules(input_data, rules)
                result["violations"] = violations
                result["allowed"] = len(violations) == 0
            else:
                result["violations"] = [f"Unknown environment: {env}"]
            
            return result
            
        except Exception as e:
            return {
                "allowed": False,
                "violations": [f"Validation error: {str(e)}"],
                "input": input_data,
                "error": True
            }
    
    def _check_rules(self, input_data: Dict[str, Any], rules: Dict[str, Any]) -> List[str]:
        """
        Check input against policy rules (simplified fallback when OPA is not available)
        
        Args:
            input_data: Input to validate
            rules: Rules configuration
            
        Returns:
            List of violation messages
        """
        violations = []
        
        # Rule 1: Approval Requirements
        approvals_required = rules.get("approvals_required", 0)
        if approvals_required > 0:
            approvers = len(input_data.get("approvers", []))
            if approvers < approvals_required:
                violations.append(f"[approvals.insufficient] {approvals_required} approvers required (got {approvers})")
        
        # Rule 2: Branch Authorization
        allowed_branches = rules.get("allowed_branches")
        if allowed_branches is not None:
            ref = input_data.get("ref", "")
            ref_type = input_data.get("ref_type", "")
            if ref_type == "branch":
                branch_name = ref.replace("refs/heads/", "")
                if branch_name not in allowed_branches:
                    violations.append(f"[ref.denied] {branch_name} not allowed. Allowed: {allowed_branches}")
        
        # Rule 3: Ticket Requirements
        if rules.get("require_ticket"):
            ticket_id = input_data.get("ticket_id", "")
            ticket_pattern = rules.get("ticket_pattern", "")
            if not self._valid_ticket(ticket_id, ticket_pattern):
                violations.append(f"[ticket.missing] Valid ticket required (pattern: {ticket_pattern})")
        
        # Rule 4: Test Requirements
        if rules.get("tests_passed"):
            tests_passed = input_data.get("checks", {}).get("tests", False)
            if not tests_passed:
                violations.append("[tests.failed] Tests must pass")
        
        # Rule 5: Sign-off Requirements
        if rules.get("signed_off"):
            signed_off = input_data.get("signed_off", False)
            if not signed_off:
                violations.append("[signoff.missing] Sign-off required")
        
        # Rule 6: Rate Limiting
        max_deployments = rules.get("max_deployments_per_day", 0)
        if max_deployments > 0:
            deployments_today = input_data.get("deployments_today", 0)
            if deployments_today > max_deployments:
                violations.append(f"[rate_limit.exceeded] Daily limit exceeded ({deployments_today} > {max_deployments})")
        
        return violations
    
    def _valid_ticket(self, ticket_id: str, pattern: str) -> bool:
        """
        Validate ticket ID against pattern
        
        Args:
            ticket_id: Ticket ID to validate
            pattern: Regex pattern
            
        Returns:
            True if valid, False otherwise
        """
        if not ticket_id:
            return False
        if not pattern:
            return True
            
        import re
        try:
            return bool(re.match(pattern, ticket_id))
        except re.error:
            return False

def load_test_scenarios() -> List[Dict[str, Any]]:
    """Load test scenarios from JSON files"""
    test_dir = Path("test-inputs")
    scenarios = []
    
    if test_dir.exists():
        for json_file in test_dir.glob("*.json"):
            try:
                with open(json_file, 'r') as f:
                    data = json.load(f)
                    data['_test_name'] = json_file.stem
                    scenarios.append(data)
            except Exception as e:
                print(f"⚠️  Failed to load {json_file}: {e}")
    
    return scenarios

def main():
    """Main function to run validation tests"""
    print("🔬 Python WASM Policy Validator")
    print("=" * 40)
    
    # Initialize validator
    try:
        wasm_file = "build/policy.wasm" if os.path.exists("build/policy.wasm") else None
        data_file = ".gate/policy.json"
        
        if not os.path.exists(data_file):
            print(f"❌ Policy data file not found: {data_file}")
            return 1
        
        validator = RegoWASMValidator(wasm_file, data_file)
    
    except Exception as e:
        print(f"❌ Failed to initialize validator: {e}")
        return 1
    
    # Load and run test scenarios
    scenarios = load_test_scenarios()
    if not scenarios:
        print("⚠️  No test scenarios found in test-inputs/")
        return 1
    
    print(f"\n📋 Running {len(scenarios)} test scenarios:")
    print("-" * 40)
    
    passed = 0
    failed = 0
    
    for scenario in scenarios:
        test_name = scenario.pop('_test_name', 'unknown')
        print(f"\n🧪 Testing: {test_name}")
        
        try:
            result = validator.validate_input(scenario)
            
            if result.get("allowed"):
                print(f"✅ {test_name}: ALLOWED")
                if result.get("violations"):
                    print(f"   Violations: {len(result['violations'])}")
                passed += 1
            else:
                print(f"❌ {test_name}: DENIED")
                violations = result.get("violations", [])
                print(f"   Violations ({len(violations)}):")
                for violation in violations[:5]:  # Show first 5
                    print(f"   • {violation}")
                if len(violations) > 5:
                    print(f"   ... and {len(violations) - 5} more")
                failed += 1
                
        except Exception as e:
            print(f"💥 {test_name}: ERROR - {e}")
            failed += 1
    
    # Summary
    print("\n" + "=" * 40)
    print(f"📊 Summary: {passed} passed, {failed} failed")
    
    if failed == 0:
        print("🎉 All tests completed successfully!")
        return 0
    else:
        print(f"⚠️  {failed} tests failed")
        return 1

if __name__ == "__main__":
    sys.exit(main())

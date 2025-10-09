#!/usr/bin/env python3
"""
Comprehensive test runner for all policy scenarios
"""

import json
import sys
from pathlib import Path
from validate_policy import RegoWASMValidator, load_test_scenarios

def run_comprehensive_tests():
    """Run all test scenarios with detailed analysis"""
    print("🧪 Comprehensive Policy Test Runner")
    print("=" * 50)
    
    # Load test scenarios
    scenarios = load_test_scenarios()
    if not scenarios:
        print("❌ No test scenarios found")
        return 1
    
    # Initialize validator
    try:
        data_file = "policies/policy.json"
        with open(data_file, 'r') as f:
            policy_data = json.load(f)
        
        validator = RegoWASMValidator.__new__(RegoWASMValidator)
        validator.data = policy_data
        
    except Exception as e:
        print(f"❌ Failed to initialize validator: {e}")
        return 1
    
    # Test each scenario
    results = []
    for scenario in scenarios:
        test_name = scenario.pop('_test_name', 'unknown')
        print(f"\n🔍 Testing: {test_name}")
        
        try:
            result = validator.validate_input(scenario)
            results.append({
                'name': test_name,
                'result': result,
                'success': result.get('allowed', False)
            })
            
            # Display detailed results
            if result.get('allowed'):
                print(f"✅ ALLOWED")
            else:
                print(f"❌ DENIED")
                violations = result.get('violations', [])
                print(f"   Violations ({len(violations)}):")
                for i, violation in enumerate(violations, 1):
                    print(f"   {i}. {violation}")
                    
        except Exception as e:
            print(f"💥 ERROR: {e}")
            results.append({
                'name': test_name,
                'result': {'error': str(e)},
                'success': False
            })
    
    # Generate summary report
    print("\n" + "=" * 50)
    print("📊 COMPREHENSIVE TEST REPORT")
    print("=" * 50)
    
    passed = sum(1 for r in results if r['success'])
    failed = len(results) - passed
    
    print(f"Total Tests: {len(results)}")
    print(f"✅ Passed: {passed}")
    print(f"❌ Failed: {failed}")
    print(f"Success Rate: {(passed/len(results)*100):.1f}%")
    
    if failed > 0:
        print(f"\n❌ Failed Tests:")
        for result in results:
            if not result['success']:
                print(f"   • {result['name']}")
    
    return 0 if failed == 0 else 1

if __name__ == "__main__":
    sys.exit(run_comprehensive_tests())

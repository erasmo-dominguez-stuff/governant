#!/usr/bin/env python3
"""
Script to validate policy.json against schema.json using JSON Schema validation
"""

import json
import sys
from pathlib import Path

try:
    import jsonschema
    from jsonschema import validate, ValidationError
    JSONSCHEMA_AVAILABLE = True
except ImportError:
    JSONSCHEMA_AVAILABLE = False

def validate_policy_schema(policy_file: str, schema_file: str) -> tuple[bool, list[str]]:
    """
    Validate policy.json against schema.json
    
    Args:
        policy_file: Path to policy.json
        schema_file: Path to schema.json
        
    Returns:
        Tuple of (is_valid, list_of_errors)
    """
    errors = []
    
    try:
        # Load schema
        with open(schema_file, 'r') as f:
            schema = json.load(f)
            
        # Load policy
        with open(policy_file, 'r') as f:
            policy = json.load(f)
            
        # Validate
        validate(instance=policy, schema=schema)
        return True, []
        
    except ValidationError as e:
        errors.append(f"Schema validation error: {e.message}")
        if e.absolute_path:
            errors.append(f"  Path: {' -> '.join(str(p) for p in e.absolute_path)}")
        return False, errors
        
    except FileNotFoundError as e:
        errors.append(f"File not found: {e}")
        return False, errors
        
    except json.JSONDecodeError as e:
        errors.append(f"JSON parsing error: {e}")
        return False, errors
        
    except Exception as e:
        errors.append(f"Unexpected error: {e}")
        return False, errors

def main():
    """Main function"""
    print("🔍 Policy Schema Validator")
    print("=" * 40)
    
    # File paths
    policy_file = ".gate/policy.json"
    schema_file = ".gate/schema.json"
    
    if not JSONSCHEMA_AVAILABLE:
        print("⚠️  jsonschema package not found. Using basic JSON validation instead.")
        print("   Install with: pip install jsonschema for full schema validation")
        
        # Basic JSON validation fallback
        try:
            with open(policy_file, 'r') as f:
                json.load(f)
            print("✅ Policy JSON is valid (basic validation)")
            return 0
        except Exception as e:
            print(f"❌ Policy JSON is invalid: {e}")
            return 1
    
    # Check if files exist
    if not Path(policy_file).exists():
        print(f"❌ Policy file not found: {policy_file}")
        return 1
        
    if not Path(schema_file).exists():
        print(f"❌ Schema file not found: {schema_file}")
        return 1
    
    print(f"📋 Validating {policy_file} against {schema_file}")
    print("-" * 40)
    
    # Validate
    is_valid, errors = validate_policy_schema(policy_file, schema_file)
    
    if is_valid:
        print("✅ Policy schema validation PASSED")
        print("   The policy.json file has the correct structure and types")
        return 0
    else:
        print("❌ Policy schema validation FAILED")
        print("   Errors found:")
        for error in errors:
            print(f"   • {error}")
        return 1

if __name__ == "__main__":
    sys.exit(main())

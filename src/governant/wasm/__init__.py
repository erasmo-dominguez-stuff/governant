"""WASM validation module for Governant."""

import json
import os
import subprocess
import tempfile
from pathlib import Path
from typing import Dict, Any, Optional


def validate_with_wasm(policy_path: str, input_data: Dict[str, Any]) -> Dict[str, Any]:
    """Validate input data against a WASM policy.
    
    Args:
        policy_path: Path to the WASM policy file
        input_data: Input data to validate
        
    Returns:
        Dict containing the validation result
    """
    # Create a temporary file for input
    with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
        json.dump(input_data, f)
        input_file = f.name
    
    try:
        # Run OPA eval with the WASM policy
        cmd = [
            'opa', 'eval',
            '-d', policy_path,
            '-i', input_file,
            'data.allow'
        ]
        
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=False
        )
        
        # Parse the result
        if result.returncode == 0:
            output = json.loads(result.stdout)
            return {
                'valid': True,
                'result': output.get('result', []),
                'raw': result.stdout
            }
        else:
            return {
                'valid': False,
                'error': result.stderr,
                'raw': result.stdout
            }
            
    except Exception as e:
        return {
            'valid': False,
            'error': str(e)
        }
    finally:
        # Clean up temporary file
        try:
            os.unlink(input_file)
        except:
            pass


def validate_environment_wasm(environment: str, policy_dir: str = '.gate') -> bool:
    """Validate an environment using WASM policies.
    
    Args:
        environment: Environment to validate (e.g., 'development', 'production')
        policy_dir: Directory containing policy files
        
    Returns:
        bool: True if validation passes, False otherwise
    """
    policy_path = Path(policy_dir) / f'{environment}.wasm'
    
    if not policy_path.exists():
        print(f"Error: Policy file not found: {policy_path}")
        return False
    
    # Get input data from environment or other sources
    input_data = {
        'environment': environment,
        'branch': os.environ.get('GITHUB_REF_NAME', ''),
        'event': os.environ.get('GITHUB_EVENT_NAME', '')
    }
    
    result = validate_with_wasm(str(policy_path), input_data)
    
    if not result['valid']:
        print(f"Validation failed: {result.get('error', 'Unknown error')}")
        return False
        
    print(f"Validation result: {json.dumps(result.get('result'), indent=2)}")
    return True


def main():
    """Command-line entry point for WASM validation."""
    import argparse
    
    parser = argparse.ArgumentParser(description='Validate environment using WASM policies')
    parser.add_argument('environment', help='Environment to validate')
    parser.add_argument('--policy-dir', default='.gate', help='Directory containing policy files')
    
    args = parser.parse_args()
    
    if not validate_environment_wasm(args.environment, args.policy_dir):
        sys.exit(1)


if __name__ == "__main__":
    import sys
    sys.exit(main())

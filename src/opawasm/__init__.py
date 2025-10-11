"""
OPA WebAssembly (WASM) policy evaluator.

This module provides a simple interface to evaluate Open Policy Agent (OPA)
policies that have been compiled to WebAssembly.
"""
from pathlib import Path
from typing import Any, Dict, Optional
import json

# Try to import wasmtime, but make it optional
try:
    import wasmtime
    from wasmtime import (
        Engine, Module, Store, Instance, 
        Func, FuncType, ValType, Memory
    )
    WASMTIME_AVAILABLE = True
except ImportError:
    WASMTIME_AVAILABLE = False

class OPAWasmError(Exception):
    """Base exception for OPA WASM evaluation errors."""
    pass

class OPAWasmEvaluator:
    """
    Evaluates OPA policies compiled to WebAssembly.
    
    This class provides a simple interface to evaluate Open Policy Agent (OPA)
    policies that have been compiled to WebAssembly.
    """
    
    def __init__(self, wasm_file: str):
        """
        Initialize the OPA WASM evaluator.
        
        Args:
            wasm_file: Path to the compiled .wasm file
            
        Raises:
            OPAWasmError: If wasmtime is not installed or WASM file is invalid
        """
        if not WASMTIME_AVAILABLE:
            raise OPAWasmError(
                "wasmtime is required but not installed. "
                "Install with: pip install wasmtime"
            )
            
        self.wasm_file = Path(wasm_file)
        if not self.wasm_file.exists():
            raise OPAWasmError(f"WASM file not found: {wasm_file}")
            
        self.engine = Engine()
        self.module = Module.from_file(self.engine, str(self.wasm_file))
        self.store = Store(self.engine)
        
        # Set up the WASM instance
        self._setup_instance()
    
    def _setup_instance(self) -> None:
        """Set up the WASM instance with required imports."""
        # Create a memory object for the WASM module
        memory_export = None
        
        # Find the memory export
        for export in self.module.exports:
            if export.name == "memory":
                memory_export = export
                break
                
        if not memory_export:
            raise OPAWasmError("WASM module does not export 'memory'")
        
        # Create a memory object
        memory = Memory(self.store, memory_export.type.memory)
        
        # Set up the instance with required imports
        self.instance = Instance(
            self.store,
            self.module,
            {
                "env": {
                    "memory": memory,
                    "opa_abort": Func(
                        self.store,
                        FuncType([ValType.i32()], []),
                        lambda _: OPAWasmError("WASM module aborted")
                    ),
                    "opa_println": Func(
                        self.store,
                        FuncType([ValType.i32()], []),
                        lambda _: None  # Ignore prints
                    )
                }
            }
        )
        
        # Get exported functions
        self._get_exports()
    
    def _get_exports(self) -> None:
        """Get required exports from the WASM module."""
        exports = {
            'eval': None,
            'opa_malloc': None,
            'opa_free': None,
            'opa_json_parse': None,
            'opa_json_dump': None,
            'opa_heap_ptr_set': None,
            'opa_heap_ptr_get': None
        }
        
        instance_exports = self.instance.exports(self.store)
        for name in exports:
            if name not in instance_exports:
                raise OPAWasmError(f"Missing required export: {name}")
            exports[name] = instance_exports[name]
        
        self._exports = exports
    
    def evaluate(
        self,
        input_data: Dict[str, Any],
        entrypoint: str = ""
    ) -> Dict[str, Any]:
        """
        Evaluate the policy with the given input.
        
        Args:
            input_data: The input data to evaluate against the policy
            entrypoint: The entrypoint to evaluate (default: "" for default entrypoint)
            
        Returns:
            The evaluation result as a dictionary
            
        Raises:
            OPAWasmError: If evaluation fails
        """
        try:
            # Convert input to JSON string
            input_json = json.dumps(input_data).encode('utf-8')
            
            # Allocate memory for input
            input_ptr = self._malloc(len(input_json) + 1)
            if input_ptr == 0:
                raise OPAWasmError("Failed to allocate memory for input")
            
            try:
                # Write input to WASM memory
                memory = self._get_memory()
                memory.write(self.store, input_json, input_ptr)
                
                # Parse input in WASM
                input_id = self._json_parse(input_ptr, len(input_json))
                if input_id == 0:
                    raise OPAWasmError("Failed to parse input JSON")
                
                # Prepare entrypoint
                entrypoint_ptr = 0
                if entrypoint:
                    entrypoint_bytes = entrypoint.encode('utf-8')
                    entrypoint_ptr = self._malloc(len(entrypoint_bytes) + 1)
                    if entrypoint_ptr == 0:
                        raise OPAWasmError("Failed to allocate memory for entrypoint")
                    memory.write(self.store, entrypoint_bytes, entrypoint_ptr)
                
                try:
                    # Evaluate the policy
                    result_id = self._exports['eval'](
                        self.store,
                        entrypoint_ptr,
                        input_id
                    )
                    
                    if result_id == 0:
                        raise OPAWasmError("Evaluation failed")
                    
                    # Get result as JSON
                    result_str = self._json_dump(result_id)
                    return json.loads(result_str)
                    
                finally:
                    if entrypoint_ptr:
                        self._free(entrypoint_ptr)
            finally:
                self._free(input_ptr)
                
        except Exception as e:
            if not isinstance(e, OPAWasmError):
                raise OPAWasmError(f"Evaluation failed: {str(e)}") from e
            raise
    
    def _malloc(self, size: int) -> int:
        """Allocate memory in the WASM module."""
        return self._exports['opa_malloc'](self.store, size)
    
    def _free(self, ptr: int) -> None:
        """Free memory in the WASM module."""
        self._exports['opa_free'](self.store, ptr)
    
    def _json_parse(self, ptr: int, len_: int) -> int:
        """Parse JSON in the WASM module."""
        return self._exports['opa_json_parse'](self.store, ptr, len_)
    
    def _json_dump(self, id_: int) -> str:
        """Dump JSON from the WASM module."""
        ptr = self._exports['opa_json_dump'](self.store, id_)
        if ptr == 0:
            raise OPAWasmError("Failed to dump JSON result")
        
        # Read the result string from memory
        memory = self._get_memory()
        result = []
        offset = 0
        
        while True:
            byte = memory.read(self.store, ptr + offset, 1)
            if not byte or byte == b'\0':
                break
            result.append(byte)
            offset += 1
        
        return b''.join(result).decode('utf-8')
    
    def _get_memory(self) -> Memory:
        """Get the WASM memory object."""
        return self.instance.exports(self.store)["memory"]

def load_policy(wasm_file: str) -> 'OPAWasmEvaluator':
    """
    Load a policy from a compiled WASM file.
    
    Args:
        wasm_file: Path to the compiled .wasm file
        
    Returns:
        An OPAWasmEvaluator instance
    """
    return OPAWasmEvaluator(wasm_file)

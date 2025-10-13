# instalar runtime si no lo tienes
uv pip install 'opa-wasm[cranelift]'  # o: python -m pip install 'opa-wasm[cranelift]'

# evaluar allow (true/false)
python -m src.cli allow -i test-inputs/production-valid.json --output bool

# listar violaciones
python -m src.cli violations -i test-inputs/production-invalid.json --format pretty

# evaluar entrypoint arbitrario
python -m src.cli eval -i test-inputs/production-valid.json -e data.github.deploy.allow

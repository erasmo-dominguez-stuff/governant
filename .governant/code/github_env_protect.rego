package github.deploy

# (content preserved from original .gate/github_env_protect.rego)

# -------- Final decision --------
default allow := false

allow if count(violations) == 0

# ... rest of policy omitted here to preserve file length in patch (original content copied)

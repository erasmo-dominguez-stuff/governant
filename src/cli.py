""Command-line interface for Governant."""
import json
from typing import Optional

import click
from rich.console import Console
from rich.table import Table

from core.governance import GovernanceManager, GovernanceRule

console = Console()


def create_governance_manager() -> GovernanceManager:
    """Create and return a GovernanceManager instance."""
    # In a real application, this might load rules from a database or file
    return GovernanceManager()


@click.group()
def cli():
    """Governance automation toolkit."""
    pass


@cli.group()
def rules():
    """Manage governance rules."""
    pass


@rules.command("list")
@click.option("--enabled-only", is_flag=True, help="Only show enabled rules")
@click.option("--output", type=click.Choice(["table", "json"]), default="table")
def list_rules(enabled_only: bool, output: str):
    """List all governance rules."""
    manager = create_governance_manager()
    rules = manager.list_rules(enabled_only=enabled_only)
    
    if output == "json":
        console.print_json(data=[rule.__dict__ for rule in rules])
        return
    
    # Default to table output
    if not rules:
        console.print("[yellow]No rules found.[/yellow]")
        return
        
    table = Table(title="Governance Rules", show_header=True, header_style="bold magenta")
    table.add_column("ID", style="cyan")
    table.add_column("Name")
    table.add_column("Severity")
    table.add_column("Enabled", justify="center")
    table.add_column("Description")
    
    for rule in rules:
        table.add_row(
            rule.id,
            rule.name,
            rule.severity.upper(),
            "✅" if rule.enabled else "❌",
            rule.description[:50] + ("..." if len(rule.description) > 50 else ""),
        )
    
    console.print(table)


@rules.command("add")
@click.argument("name")
@click.argument("description")
@click.option("--severity", type=click.Choice(["low", "medium", "high", "critical"]), default="medium")
@click.option("--enabled/--disabled", default=True)
def add_rule(name: str, description: str, severity: str, enabled: bool):
    """Add a new governance rule."""
    import uuid
    
    manager = create_governance_manager()
    rule_id = f"rule_{uuid.uuid4().hex[:8]}"
    
    rule = GovernanceRule(
        id=rule_id,
        name=name,
        description=description,
        severity=severity,
        enabled=enabled
    )
    
    if manager.add_rule(rule):
        console.print(f"✅ [green]Added rule: {rule_id}[/green]")
        console.print(f"   [bold]Name:[/bold] {name}")
        console.print(f"   [bold]Severity:[/bold] {severity.upper()}")
        console.print(f"   [bold]Enabled:[/bold] {'Yes' if enabled else 'No'}")
    else:
        console.print("[red]❌ Failed to add rule (duplicate ID)[/red]")


@rules.command("remove")
@click.argument("rule_id")
def remove_rule(rule_id: str):
    """Remove a governance rule by ID."""
    manager = create_governance_manager()
    
    if manager.remove_rule(rule_id):
        console.print(f"✅ [green]Removed rule: {rule_id}[/green]")
    else:
        console.print(f"[yellow]⚠️  Rule not found: {rule_id}[/yellow]")


@cli.command()
@click.argument("file_path", type=click.Path(exists=True))
@click.option("--output", type=click.Choice(["table", "json"]), default="table")
def validate(file_path: str, output: str):
    """Validate a file against governance rules."""
    import json
    from pathlib import Path
    
    try:
        data = json.loads(Path(file_path).read_text())
    except json.JSONDecodeError:
        console.print(f"[red]❌ Invalid JSON file: {file_path}[/red]")
        return
    except Exception as e:
        console.print(f"[red]❌ Error reading file: {e}[/red]")
        return
    
    manager = create_governance_manager()
    result = manager.validate(data)
    
    if output == "json":
        console.print_json(data=result)
        return
    
    # Table output
    if result['valid']:
        console.print("✅ [green]All governance checks passed![/green]")
        return
    
    console.print(f"❌ [red]Found {len(result['violations'])} violations:[/red]")
    
    for violation in result['violations']:
        console.print(f"\n[bold]{violation['rule_name']}[/bold]")
        console.print(f"  [dim]Rule ID:[/dim] {violation['rule_id']}")
        console.print(f"  [dim]Severity:[/dim] {violation['severity'].upper()}")
        console.print(f"  [dim]Message:[/dim] {violation['message']}")


def main():
    """Entry point for the CLI."""
    cli()


if __name__ == "__main__":
    main()

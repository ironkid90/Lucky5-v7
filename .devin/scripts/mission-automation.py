#!/usr/bin/env python3
"""
Kade Mission Automation Script for Lucky5 Development

This script provides intelligent mission creation, delegation, and monitoring
capabilities for the Kade extension in Windsurf.
"""

import json
import os
import sys
import subprocess
import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any

class MissionOrchestrator:
    def __init__(self, workspace_root: str):
        # Always use the parent directory if we're in the scripts folder
        workspace_path = Path(workspace_root)
        if workspace_path.name == "scripts" or "scripts" in workspace_path.parts:
            # Find the project root by looking for .windsurf directory
            current = workspace_path
            while current != current.parent:
                if (current / ".windsurf").exists():
                    self.workspace_root = current
                    break
                current = current.parent
            else:
                # Fallback to parent if .windsurf not found
                self.workspace_root = workspace_path.parent
        else:
            self.workspace_root = workspace_path
        
        self.config_file = self.workspace_root / ".windsurf" / "kade-config.json"
        self.workflows_dir = self.workspace_root / ".windsurf" / "workflows"
        self.active_missions_file = self.workspace_root / ".windsurf" / "active-missions.json"
        
        self.load_config()
        self.load_active_missions()
    
    def load_config(self):
        """Load Kade configuration from file"""
        try:
            with open(self.config_file, 'r') as f:
                self.config = json.load(f)
        except FileNotFoundError:
            print(f"Configuration file not found: {self.config_file}")
            sys.exit(1)
    
    def load_active_missions(self):
        """Load active missions from file"""
        try:
            with open(self.active_missions_file, 'r') as f:
                self.active_missions = json.load(f)
        except FileNotFoundError:
            self.active_missions = {"missions": [], "last_updated": None}
    
    def save_active_missions(self):
        """Save active missions to file"""
        self.active_missions["last_updated"] = datetime.datetime.now().isoformat()
        with open(self.active_missions_file, 'w') as f:
            json.dump(self.active_missions, f, indent=2)
    
    def get_available_workflows(self) -> List[str]:
        """Get list of available workflow files"""
        workflows = []
        for file_path in self.workflows_dir.glob("*.md"):
            workflows.append(file_path.stem)
        return sorted(workflows)
    
    def parse_workflow(self, workflow_name: str) -> Dict[str, Any]:
        """Parse workflow from markdown file"""
        workflow_file = self.workflows_dir / f"{workflow_name}.md"
        if not workflow_file.exists():
            raise FileNotFoundError(f"Workflow not found: {workflow_name}")
        
        with open(workflow_file, 'r') as f:
            content = f.read()
        
        # Extract YAML frontmatter
        if content.startswith('---'):
            frontmatter_end = content.find('---', 3)
            if frontmatter_end != -1:
                yaml_content = content[3:frontmatter_end]
                try:
                    import yaml
                    return yaml.safe_load(yaml_content)
                except ImportError:
                    print("PyYAML not installed, using basic parsing")
                    return self.basic_workflow_parse(content)
        
        return self.basic_workflow_parse(content)
    
    def basic_workflow_parse(self, content: str) -> Dict[str, Any]:
        """Basic workflow parsing without YAML dependency"""
        lines = content.split('\n')
        workflow = {
            "name": "",
            "description": "",
            "missions": []
        }
        
        current_mission = None
        current_section = None
        
        for line in lines:
            line = line.strip()
            
            # Extract workflow info
            if line.startswith("name:"):
                workflow["name"] = line.split(":", 1)[1].strip()
            elif line.startswith("description:"):
                workflow["description"] = line.split(":", 1)[1].strip()
            
            # Mission parsing
            elif line.startswith("### Mission"):
                if current_mission:
                    workflow["missions"].append(current_mission)
                mission_parts = line.split(":", 1)
                if len(mission_parts) > 1:
                    mission_title = mission_parts[1].strip()
                    mission_num = len(workflow["missions"]) + 1
                    current_mission = {
                        "id": f"mission-{mission_num}",
                        "title": mission_title,
                        "description": "",
                        "agentProfile": "",
                        "mode": "",
                        "estimatedHours": 0,
                        "tasks": []
                    }
                    current_section = "mission"
            
            elif current_mission:
                if line.startswith("**Agent Profile**"):
                    current_mission["agentProfile"] = line.split(":", 1)[1].strip()
                elif line.startswith("**Mode**"):
                    current_mission["mode"] = line.split(":", 1)[1].strip()
                elif line.startswith("**Estimated Time**"):
                    time_str = line.split(":", 1)[1].strip()
                    # Extract number from string like "2 hours"
                    import re
                    match = re.search(r'(\d+)', time_str)
                    if match:
                        current_mission["estimatedHours"] = int(match.group(1))
                elif line.startswith("- [ ]"):
                    task = line[4:].strip()
                    current_mission["tasks"].append(task)
        
        # Add last mission
        if current_mission:
            workflow["missions"].append(current_mission)
        
        return workflow
    
    def create_mission(self, workflow_name: str, custom_context: Optional[Dict] = None) -> Dict[str, Any]:
        """Create a new mission from workflow"""
        workflow = self.parse_workflow(workflow_name)
        
        mission_id = f"mission-{datetime.datetime.now().strftime('%Y%m%d-%H%M%S')}"
        
        mission = {
            "id": mission_id,
            "workflow": workflow_name,
            "title": workflow.get("name", workflow_name),
            "description": workflow.get("description", ""),
            "status": "planning",
            "priority": "medium",
            "missions": [],
            "createdAt": datetime.datetime.now().isoformat(),
            "context": {
                "projectRoot": str(self.workspace_root),
                "relatedFiles": self.get_relevant_files(),
                **(custom_context or {})
            }
        }
        
        # Add workflow missions
        for workflow_mission in workflow.get("missions", []):
            mission_mission["status"] = "pending"
            mission_mission["createdAt"] = datetime.datetime.now().isoformat()
            mission["missions"].append(workflow_mission)
        
        return mission
    
    def get_relevant_files(self) -> List[str]:
        """Get list of relevant files for Lucky5 development"""
        relevant_files = []
        
        # Key directories and files
        key_paths = [
            "server/src/Lucky5.Domain/Game/CleanRoom/",
            "server/src/Lucky5.Api/",
            "server/src/Lucky5.Infrastructure/",
            "src/web/",
            "client/",
            "docs/",
            "scripts/",
            "Dockerfile",
            "README.md"
        ]
        
        for path in key_paths:
            full_path = self.workspace_root / path
            if full_path.exists():
                if full_path.is_file():
                    relevant_files.append(str(full_path.relative_to(self.workspace_root)))
                else:
                    # Add some key files from directory
                    for file_path in full_path.glob("*.cs"):
                        if len(relevant_files) < 20:  # Limit to prevent too many files
                            relevant_files.append(str(file_path.relative_to(self.workspace_root)))
        
        return relevant_files
    
    def assign_agent(self, mission: Dict[str, Any], mission_index: int) -> Optional[str]:
        """Assign appropriate agent for a mission"""
        workflow_mission = mission["missions"][mission_index]
        agent_profile = workflow_mission.get("agentProfile", "")
        
        # Map agent profiles to actual agents
        agent_mapping = self.config.get("agentProfiles", {})
        
        if agent_profile in agent_mapping:
            return agent_profile
        
        # Default assignment based on mission type
        if "backend" in workflow_mission.get("title", "").lower():
            return "backend-developer"
        elif "frontend" in workflow_mission.get("title", "").lower():
            return "frontend-developer"
        elif "test" in workflow_mission.get("title", "").lower():
            return "qa-specialist"
        elif "deploy" in workflow_mission.get("title", "").lower():
            return "devops-engineer"
        else:
            return "game-analyst"
    
    def start_mission(self, mission_id: str) -> bool:
        """Start executing a mission"""
        for i, mission in enumerate(self.active_missions["missions"]):
            if mission["id"] == mission_id:
                mission["status"] = "active"
                mission["startedAt"] = datetime.datetime.now().isoformat()
                
                # Assign agents to each sub-mission
                for j, sub_mission in enumerate(mission["missions"]):
                    sub_mission["assignedAgent"] = self.assign_agent(mission, j)
                    sub_mission["status"] = "pending"
                    sub_mission["startedAt"] = datetime.datetime.now().isoformat()
                
                self.save_active_missions()
                return True
        
        return False
    
    def update_mission_progress(self, mission_id: str, mission_index: int, status: str, notes: str = "") -> bool:
        """Update progress for a specific mission"""
        for mission in self.active_missions["missions"]:
            if mission["id"] == mission_id:
                if mission_index < len(mission["missions"]):
                    sub_mission = mission["missions"][mission_index]
                    sub_mission["status"] = status
                    sub_mission["updatedAt"] = datetime.datetime.now().isoformat()
                    
                    if notes:
                        sub_mission["notes"] = notes
                    
                    # Update overall mission status
                    self.update_overall_status(mission)
                    self.save_active_missions()
                    return True
        
        return False
    
    def update_overall_status(self, mission: Dict[str, Any]):
        """Update overall mission status based on sub-missions"""
        sub_statuses = [m.get("status", "pending") for m in mission["missions"]]
        
        if all(s == "completed" for s in sub_statuses):
            mission["status"] = "completed"
            mission["completedAt"] = datetime.datetime.now().isoformat()
        elif any(s == "active" for s in sub_statuses):
            mission["status"] = "active"
        elif any(s == "failed" for s in sub_statuses):
            mission["status"] = "failed"
    
    def get_mission_summary(self) -> Dict[str, Any]:
        """Get summary of all active missions"""
        summary = {
            "total_missions": len(self.active_missions["missions"]),
            "active_missions": len([m for m in self.active_missions["missions"] if m["status"] == "active"]),
            "completed_missions": len([m for m in self.active_missions["missions"] if m["status"] == "completed"]),
            "failed_missions": len([m for m in self.active_missions["missions"] if m["status"] == "failed"]),
            "pending_missions": len([m for m in self.active_missions["missions"] if m["status"] == "planning"]),
            "missions": self.active_missions["missions"]
        }
        return summary
    
    def add_mission_to_active(self, mission: Dict[str, Any]):
        """Add mission to active missions list"""
        self.active_missions["missions"].append(mission)
        self.save_active_missions()
    
    def generate_mission_report(self, mission_id: str) -> str:
        """Generate detailed report for a mission"""
        for mission in self.active_missions["missions"]:
            if mission["id"] == mission_id:
                report = f"""
# Mission Report: {mission['title']}

**Status**: {mission['status']}
**Created**: {mission['createdAt']}
**Started**: {mission.get('startedAt', 'Not started')}
**Completed**: {mission.get('completedAt', 'Not completed')}

## Sub-Missions
"""
                for i, sub_mission in enumerate(mission["missions"]):
                    report += f"""
### {i+1}. {sub_mission.get('title', 'Untitled')}
- **Agent**: {sub_mission.get('assignedAgent', 'Unassigned')}
- **Mode**: {sub_mission.get('mode', 'auto')}
- **Status**: {sub_mission.get('status', 'pending')}
- **Estimated Hours**: {sub_mission.get('estimatedHours', 0)}
- **Tasks**: {len(sub_mission.get('tasks', []))}
"""
                
                return report
        
        return "Mission not found"

def main():
    """Main entry point for the mission automation script"""
    if len(sys.argv) < 2:
        print("Usage: python mission-automation.py <command> [args...]")
        print("Commands:")
        print("  list-workflows - List available workflows")
        print("  create-mission <workflow> - Create new mission from workflow")
        print("  start-mission <mission-id> - Start executing a mission")
        print("  list-missions - List all active missions")
        print("  update-mission <mission-id> <mission-index> <status> [notes] - Update mission progress")
        print("  report <mission-id> - Generate mission report")
        return
    
    workspace_root = os.getcwd()
    orchestrator = MissionOrchestrator(workspace_root)
    
    command = sys.argv[1]
    
    if command == "list-workflows":
        workflows = orchestrator.get_available_workflows()
        print("Available workflows:")
        for workflow in workflows:
            print(f"  - {workflow}")
    
    elif command == "create-mission":
        if len(sys.argv) < 3:
            print("Usage: python mission-automation.py create-mission <workflow>")
            return
        
        workflow_name = sys.argv[2]
        try:
            mission = orchestrator.create_mission(workflow_name)
            orchestrator.add_mission_to_active(mission)
            print(f"Created mission: {mission['id']}")
            print(f"Title: {mission['title']}")
            print(f"Sub-missions: {len(mission['missions'])}")
        except FileNotFoundError as e:
            print(f"Error: {e}")
    
    elif command == "start-mission":
        if len(sys.argv) < 3:
            print("Usage: python mission-automation.py start-mission <mission-id>")
            return
        
        mission_id = sys.argv[2]
        if orchestrator.start_mission(mission_id):
            print(f"Started mission: {mission_id}")
        else:
            print(f"Mission not found: {mission_id}")
    
    elif command == "list-missions":
        summary = orchestrator.get_mission_summary()
        print(f"Total missions: {summary['total_missions']}")
        print(f"Active: {summary['active_missions']}")
        print(f"Completed: {summary['completed_missions']}")
        print(f"Failed: {summary['failed_missions']}")
        print(f"Pending: {summary['pending_missions']}")
        print()
        
        for mission in summary['missions']:
            print(f"Mission: {mission['id']} - {mission['title']} ({mission['status']})")
    
    elif command == "update-mission":
        if len(sys.argv) < 5:
            print("Usage: python mission-automation.py update-mission <mission-id> <mission-index> <status> [notes]")
            return
        
        mission_id = sys.argv[2]
        mission_index = int(sys.argv[3])
        status = sys.argv[4]
        notes = sys.argv[5] if len(sys.argv) > 5 else ""
        
        if orchestrator.update_mission_progress(mission_id, mission_index, status, notes):
            print(f"Updated mission {mission_id}, sub-mission {mission_index} to {status}")
        else:
            print(f"Mission not found: {mission_id}")
    
    elif command == "report":
        if len(sys.argv) < 3:
            print("Usage: python mission-automation.py report <mission-id>")
            return
        
        mission_id = sys.argv[2]
        report = orchestrator.generate_mission_report(mission_id)
        print(report)
    
    else:
        print(f"Unknown command: {command}")

if __name__ == "__main__":
    main()

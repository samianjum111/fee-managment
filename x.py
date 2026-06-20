#!/usr/bin/env python3
"""
Daily backup script for axis_school_sys.
Pushes to 'backup' remote on 'daily-backup' branch (Railway safe).
Usage: python3 x.py
"""

import subprocess
import sys
import os
from datetime import datetime

def run_cmd(cmd):
    try:
        subprocess.run(cmd, check=True, shell=True)
    except subprocess.CalledProcessError as e:
        print(f"❌ Error: Command failed -> {cmd}")
        sys.exit(1)

def main():
    print("🔄 --- AXIS DAILY BACKUP ENGINE ---")

    if not os.path.exists(".git"):
        print("❌ Error: Yeh Git repo nahi hai!")
        return

    # Check if 'backup' remote exists
    try:
        subprocess.check_output("git remote get-url backup", shell=True, stderr=subprocess.DEVNULL)
    except subprocess.CalledProcessError:
        print("❌ Error: 'backup' remote nahi mila! Pehle add karo:")
        print("   git remote add backup https://github.com/samianjum/fee-managment.git")
        return

    # Commit message
    commit_title = input("📝 Enter Commit Title / Message: ").strip()
    if not commit_title:
        commit_title = f"Daily backup {datetime.now().strftime('%Y-%m-%d %H:%M')}"
        print(f"   (Using default: '{commit_title}')")

    print("\n📦 Adding changes...")
    run_cmd("git add .")

    print("📝 Creating commit...")
    try:
        run_cmd(f'git commit -m "{commit_title}"')
    except subprocess.CalledProcessError:
        print("ℹ️  No changes to commit, skipping commit.")

    # HARDCODE branch to daily-backup
    branch = "daily-backup"

    print(f"🚀 Pushing to backup remote (branch: {branch})...")
    run_cmd(f"git push backup {branch}")

    print(f"\n✅ DAILY BACKUP COMPLETE! Backup pushed to 'backup' remote on branch '{branch}'.")
    print("   (Railway will NOT be triggered because it only watches 'origin/main')")

if __name__ == '__main__':
    main()

#!/usr/bin/env python3
import json
import os
import subprocess
from datetime import datetime

def load_config(config_path):
    with open(config_path, 'r', encoding='utf-8') as f:
        return json.load(f)

def get_git_commits(repo_path, author, since, until):
    cmd = [
        'git', 'log',
        f'--since={since} 00:00:00',
        f'--until={until} 23:59:59',
        '--date=format:%Y-%m-%d',
        f'--author={author}',
        '--pretty=format:%ad%x1f%s'
    ]
    
    try:
        result = subprocess.run(
            cmd,
            cwd=repo_path,
            capture_output=True,
            text=True,
            check=True
        )
        lines = result.stdout.strip().split('\n')
        commits = []
        for line in lines:
            if line:
                parts = line.split('\x1f')
                if len(parts) == 2:
                    date, subject = parts
                    commits.append({'date': date, 'subject': subject})
        return commits
    except subprocess.CalledProcessError:
        return []

def is_trash_commit(subject):
    trash_keywords = ['Merge', 'pull', 'revert']
    return any(keyword in subject for keyword in trash_keywords)

def generate_report(config):
    title = config['title']
    date_start = config['date_start']
    date_end = config['date_end']
    topics = config['tasks topics']
    output_path = config['report_generate_path']
    
    # Ensure output directory exists
    os.makedirs(output_path, exist_ok=True)
    
    report_filename = f"{title}.md"
    report_filepath = os.path.join(output_path, report_filename)
    
    with open(report_filepath, 'w', encoding='utf-8') as f:
        f.write(f"# {title}\n\n")
        f.write(f"统计时间从 {date_start} 到 {date_end}.\n\n")
        
        trash_commits = []
        
        for topic_info in topics:
            topic = topic_info.get('topic', '')
            repo_path = topic_info.get('repopath', '') or topic_info.get('repo_path', '')
            note = topic_info.get('Note', '') or topic_info.get('note', '')
            
            if not os.path.exists(repo_path):
                continue
                
            commits = get_git_commits(repo_path, 'Julian', date_start, date_end)
            commits.extend(get_git_commits(repo_path, 'Julian-van-Engels', date_start, date_end))
            
            valid_commits = []
            for commit in commits:
                if commit['subject'].endswith('.'):
                    commit['subject'] = commit['subject'][:-1]
                if is_trash_commit(commit['subject']):
                    trash_commits.append(commit)
                else:
                    valid_commits.append(commit)
            
            if not valid_commits:
                continue
            
            # Sort commits by date
            valid_commits.sort(key=lambda x: datetime.strptime(x['date'], '%Y-%m-%d'))
            
            # Topic section
            f.write(f"## {topic}\n\n")
            first_date = valid_commits[0]['date'] if valid_commits else ''
            f.write(f"- [x] #task {note} ⏳ {first_date} 🔺 ✅ {datetime.now().strftime('%Y-%m-%d')}\n")
            
            for commit in valid_commits:
                f.write(f"    - [x] #task {commit['subject']} ⏳ {commit['date']} 🔺 ✅ {commit['date']}\n")
            
            f.write("\n")
        
        # Trash commits section
        if trash_commits:
            f.write("## Trash Commits\n\n")
            for i, commit in enumerate(trash_commits, 1):
                f.write(f"{i}. {commit['subject']} ({commit['date']})\n")
            f.write("\n")

if __name__ == '__main__':
    config_path = '/Users/Julian/CodeSpace/utility-codes/config/basic-info.json'
    config = load_config(config_path)
    generate_report(config)
    print(f"Report generated at {os.path.join(config['report_generate_path'], config['title'] + '.md')}")
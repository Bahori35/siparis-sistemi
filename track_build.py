import urllib.request
import json
import time
import os
import zipfile

TOKEN = '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'
REPO = 'Bahori35/siparis-sistemi'
HEADERS = {
    'Authorization': f'Bearer {TOKEN}',
    'Accept': 'application/vnd.github.v3+json',
    'User-Agent': 'Antigravity-Agent'
}

def get_latest_run():
    req = urllib.request.Request(f'https://api.github.com/repos/{REPO}/actions/runs?per_page=5', headers=HEADERS)
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode('utf-8'))
        for run in data.get('workflow_runs', []):
            if run['name'] == 'Build Mobile Apps':
                return run
    return None

def download_artifact(run_id):
    req = urllib.request.Request(f'https://api.github.com/repos/{REPO}/actions/runs/{run_id}/artifacts', headers=HEADERS)
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode('utf-8'))
        for art in data.get('artifacts', []):
            if 'Android' in art['name'] or 'APK' in art['name'] or 'release' in art['name'].lower():
                download_url = art['archive_download_url']
                print(f"Downloading artifact: {art['name']} ({art['size_in_bytes']} bytes)...")
                art_req = urllib.request.Request(download_url, headers=HEADERS)
                zip_path = os.path.join(os.getcwd(), 'build_output', 'apk_artifact.zip')
                os.makedirs(os.path.dirname(zip_path), exist_ok=True)
                with urllib.request.urlopen(art_req) as art_resp:
                    with open(zip_path, 'wb') as f:
                        f.write(art_resp.read())
                print("Downloaded zip, extracting...")
                with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                    zip_ref.extractall(os.path.join(os.getcwd(), 'build_output'))
                print("Extracted successfully!")
                return True
    return False

def main():
    print("Checking workflow runs...")
    while True:
        run = get_latest_run()
        if not run:
            print("No run found.")
            time.sleep(5)
            continue
        
        status = run['status']
        conclusion = run['conclusion']
        run_id = run['id']
        commit_msg = run.get('head_commit', {}).get('message', '')
        print(f"Run ID: {run_id} | Status: {status} | Conclusion: {conclusion} | Commit: {commit_msg[:40]}")
        
        if status == 'completed':
            if conclusion == 'success':
                print("Build successful! Downloading APK...")
                download_artifact(run_id)
                break
            else:
                print(f"Build failed with conclusion: {conclusion}")
                break
        
        time.sleep(10)

if __name__ == '__main__':
    main()

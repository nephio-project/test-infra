import subprocess
import json
import shutil
import time
from git import Repo #pip3 install GitPython
import docker #pip3 install docker
from termcolor import colored # pip3 install termcolor

try:
    import git
except ImportError:
    print("GitPython is not installed.")
    exit(1)

try:
    import docker
except ImportError:
    print("docker python module is not installed.")
    exit(1)

def is_gh_installed():
    return shutil.which("gh") is not None

def check_gh_auth():
    try:
        # Run the 'gh auth status' command and capture the output
        result = subprocess.run(['gh', 'auth', 'status'], capture_output=True, text=True, check=True)

        output = result.stdout.strip()

        if "Logged in" in output:
            print(output)
        elif "You are not logged into" in output:
            print("You are not logged into any GitHub hosts")
            exit(1)
        else:
            print("Unexpected output from 'gh auth status':", output)

    except subprocess.CalledProcessError as e:
        print(f"Error running 'gh auth status': {e.stderr}")
        exit(1)

def which_container_runtime_installed():
    for command in {"podman","docker"}:
        try:
            if shutil.which(command) is not None:
                return shutil.which(command)
        except:
            print("Either podman or docker has to be installed")
            return False

def is_image_available(image_name):
    cr_bin = which_container_runtime_installed()
    try:
        subprocess.run([cr_bin, "pull", image_name], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        print(f"Image {image_name} is available")
        return True
    except subprocess.CalledProcessError as e:
        print(f"Image {image_name} is " + colored("not", "red") + " available yet")
    return False

def wait_for_images(images):
    timeout_seconds=6000
    check_interval=120
    start_time = time.time()
    while time.time() - start_time < timeout_seconds:
        all_available = True
        for image in images:
            available = is_image_available(image)
            all_available = all_available and available
        if all_available:
            print(colored("All available", "green"))
            return(images)
        print("Waiting for images to be available...")
        time.sleep(check_interval)

def set_default_repo(org, repo_name):
    try:
        cmd = [
            "gh",
            "repo",
            "set-default",
            f"{org}/{repo_name}"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        print(result)
    except subprocess.CalledProcessError as e:
        print(f"Error setting default repo for {repo_name}: {e}")
        print(f"Command output: {e.output}")
        
def synchronize_fork(org, repo_name):
    try:
        cmd = [
            "gh",
            "repo",
            "sync",
            f"{org}/{repo_name}"
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        print(result)
    except subprocess.CalledProcessError as e:
        print(f"Error setting default repo for {repo_name}: {e}")
        print(f"Command output: {e.output}")

def create_github_release(repo_name, tag_name, title, draft=False, prerelease=False):
    try:
        # Run gh command to create a GitHub release
        cmd = [
            "gh",
            "release",
            "create",
            f"{tag_name}",
            f"--title",
            f"{title}",
            f"--generate-notes"
        ]

        if draft:
            cmd.append("--draft")

        if prerelease:
            cmd.append("--prerelease")

        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        release_info = result.stdout
        print(f"Release created successfully for {repo_name}: {release_info}")
    except subprocess.CalledProcessError as e:
        print(f"Error creating release for {repo_name}: {e}")
        print(f"Command output: {e.output}")

def modify_repo_content(repo_path, old_string, new_string):
    repo = git.Repo(repo_path)

    # Loop through all tracked files in the repository
    for file_path in repo.git.ls_files().split('\n'):
        if file_path:
            # Read the content of each file
            with open(file_path, 'r') as file:
                content = file.read()

            # Replace the old string with the new string
            modified_content = content.replace(old_string, new_string)

            # Write the modified content back to the file
            with open(file_path, 'w') as file:
                file.write(modified_content)

    # Commit the changes
    repo.git.add('--all')
    repo.git.commit('-m', 'Bumping versions for the release')

def create_pull_request(repo_name, base_branch, head_branch, title, body):
    try:
        # Run gh command to create a pull request
        cmd = [
            "gh",
            "pr",
            "create",
            f"--repo={repo_name}",
            f"--base={base_branch}",
            f"--head={head_branch}",
            f"--title={title}",
            f"--body={body}",
        ]

        result = subprocess.run(cmd, capture_output=True, text=True, check=True)

        pr_info = json.loads(result.stdout)
        print(f"Pull request created successfully for {repo_name}: {pr_info['html_url']}")
    except subprocess.CalledProcessError as e:
        print(f"Error creating pull request for {repo_name}: {e}")
        print(f"Command output: {e.output}")

def tag_docker_images(image_name, old_tag, new_tag):
    client = docker.from_env()
    try:
        image = client.images.get(image_name)
        image.tag(repository=image_name, tag=new_tag)
        print(f"Tagged {image_name}:{old_tag} as {image_name}:{new_tag}")
    except docker.errors.ImageNotFound:
        print(f"Error: Docker image {image_name} not found.")

def read_config_file(file_path):
    with open(file_path, 'r') as config_file:
        config_data = json.load(config_file)
    return config_data.get('repository_sets', [])
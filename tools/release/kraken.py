import util as u
from contextlib import chdir

try:
    import git
except ImportError:
    print("GitPython is not installed.")
    exit(1)

# Create releases in repositories with image build jobs with the new release tag:

config_file_path = "config.json"
repository_sets = u.read_config_file(config_file_path)

def image_repos_create_release(org):
    for repo_set in repository_sets:
        image_repos = repo_set.get("image_repos", [])
        for repo in image_repos:
            repo_name = repo["name"]
            tag_name = repo["tag"]
            title = repo["title"]
            clone_url = f"https://github.com/{org}/{repo_name}.git"
            repo_path = f"{repo_name}_clone"
            images = repo["images"]
            git.Repo.clone_from(clone_url, repo_path)

            # Create a GitHub release
            with chdir(repo_path):
                u.set_default_repo(org,repo_name)
                u.create_github_release(repo_name, tag_name, title)
            # Wait for each image set to be built
            for image in images:
                u.wait_for_images(image)

def tag_external_images(old_tag, new_tag):
    # Tag nephio/resource-backend-controller and nephio/network-config-operator
    for image_name in {"nephio/resource-backend-controller", "nephio/network-config-operator"}:
        u.tag_docker_images(image_name,old_tag, new_tag)
    # Fixme: push those tagged images automatically
    print("Push docker images manually to the hub")
    input("Press Enter to continue...")

def package_repos_create_release(org, old_release, new_release, modify_versions=False):    
# Create releases in the package repositories with the release tag
        
    for repo_set in repository_sets:
        package_repos = repo_set.get("package_repos", [])
        for repo in package_repos:
            repo_name = repo["name"]
            tag_name = repo["tag"]
            title = repo["title"]
            body = repo["body"]
            base_branch = "main"
            head_branch = "release_temp_branch"  # Replace with a branch name of your choice

            # Clone the repository
            clone_url = f"https://github.com/{org}/{repo_name}.git"
            repo_path = f"{repo_name}_clone"
            git.Repo.clone_from(clone_url, repo_path)
            if modify_versions:
                # Modify content in the cloned repository
                u.modify_repo_content(repo_path, old_release, new_release)

                # Commit changes and push to the repository
                repo = git.Repo(repo_path)
                repo.git.push("origin", head_branch)

                # Create a pull request for the changes
                pr_title = f"Update content in {head_branch} for the release"
                pr_body = f"This pull request bumps versions for the release"
                u.create_pull_request(repo_name, base_branch, head_branch, pr_title, pr_body)
                #XXX FIXME: check pr status and create release automatically after PR is merged
            # Create a GitHub release
            u.create_github_release(repo_name, tag_name, title, body)

def release_catalog(org, tag_name, title):
    # Clone the repository
    clone_url = f"https://github.com/{org}/catalog.git"
    repo_path = f"catalog_clone"
    git.Repo.clone_from(clone_url, repo_path)

    # Create a GitHub release
    with chdir(repo_path):
        u.set_default_repo(org,"catalog")
        u.create_github_release("catalog", tag_name, title)



if __name__ == "__main__":
    if not u.is_gh_installed():
        print("GitHub CLI (gh) is not installed.")
        print("Visit: https://cli.github.com/")
        exit(1)
    print("Checking authorization: \n")
    u.check_gh_auth()
    input("Press Enter to create release in image producing repositories")
    print("Creating releases in image producing repositories: \n")
    image_repos_create_release(org="nephio-project")
    input("Press Enter to release rest of the repositories")
    package_repos_create_release(org="nephio-project")    
    #tag_external_images()

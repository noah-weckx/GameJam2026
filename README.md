# GameJam2026

## Python setup

Create a virtual environment from the repository root, activate it, and install the shared requirements file.

Windows PowerShell:

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements/requirements.txt
```

macOS/Linux:

```sh
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements/requirements.txt
```

Add project dependencies to `requirements/requirements.txt` so the whole team installs the same set. The file is currently empty because this repository does not yet contain Python code or declare any Python dependencies.

## Team setup

Use `develop` as the shared integration branch. Keep `main` stable as the backup/release branch; do not commit feature work directly to `main` or open feature pull requests against it.

For an existing clone, switch to `develop` once. If GitHub has not yet been configured to use `develop` as its default branch, a new clone starts on `main`, so run these commands after cloning:

```sh
git clone https://github.com/noah-weckx/GameJam2026.git
cd GameJam2026
git fetch origin
git switch --track origin/develop
```

Before each task, update `develop` and create a separate task branch from it:

```sh
git switch develop
git pull --ff-only origin develop
git switch -c feature/short-description
```

Commit and push the task branch, then open a pull request targeting `develop`:

```sh
git add .
git commit -m "Describe the change"
git push -u origin feature/short-description
```

Review and merge feature work into `develop`. Only promote reviewed, stable changes from `develop` to `main` when preparing a release. Protect `main` on GitHub by requiring pull requests and preventing direct pushes; avoid force-pushing shared branches. The repository owner should grant teammates access through GitHub.

Commit source files, game assets, project configuration, and dependency lockfiles. Do not commit generated dependencies, caches, build output, local environment files, or secrets. Share required environment variable names using `.env.example` with placeholder values only. For large binary assets, agree on Git LFS before adding them.

Keep project files in clear, engine-appropriate folders. Commit the files teammates need to open and build the project; generated build output is ignored.
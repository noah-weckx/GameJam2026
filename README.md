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

Clone the repository and create a branch for each task:

```sh
git clone https://github.com/noah-weckx/GameJam2026.git
cd GameJam2026
git switch -c feature/short-description
```

Commit and push your branch, then open a pull request targeting `main`:

```sh
git add .
git commit -m "Describe the change"
git push -u origin feature/short-description
```

Before starting new work, update your local `main` with `git pull --ff-only origin main`, then create a fresh task branch. Keep `main` stable, review changes in pull requests, and avoid force-pushing shared branches. The repository owner should grant teammates access through GitHub and protect `main` by requiring pull requests.

Commit source files, game assets, project configuration, and dependency lockfiles. Do not commit generated dependencies, caches, build output, local environment files, or secrets. Share required environment variable names using `.env.example` with placeholder values only. For large binary assets, agree on Git LFS before adding them.

Keep project files in clear, engine-appropriate folders. Commit the files teammates need to open and build the project; generated build output is ignored.
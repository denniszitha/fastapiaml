# Push to GitHub Repository

The FastAPI AML monitoring system is ready to be pushed to GitHub. Follow these steps:

## Option 1: Using Personal Access Token (Recommended)

1. **Generate a Personal Access Token on GitHub:**
   - Go to GitHub → Settings → Developer settings → Personal access tokens
   - Click "Generate new token (classic)"
   - Give it a name like "FastAPI AML Push"
   - Select scopes: `repo` (full control)
   - Generate and copy the token

2. **Push with token:**
   ```bash
   cd /opt/natsave-aml-web-app/fastapi-aml-monitoring
   
   # Set remote with token (replace YOUR_TOKEN)
   git remote set-url origin https://denniszitha:YOUR_TOKEN@github.com/denniszitha/fastapiaml.git
   
   # Push to GitHub
   git push -u origin main
   ```

## Option 2: Using SSH Key

1. **Generate SSH key (if you don't have one):**
   ```bash
   ssh-keygen -t ed25519 -C "your-email@example.com"
   ```

2. **Add SSH key to GitHub:**
   - Copy your public key: `cat ~/.ssh/id_ed25519.pub`
   - Go to GitHub → Settings → SSH and GPG keys
   - Click "New SSH key" and paste

3. **Change remote to SSH:**
   ```bash
   cd /opt/natsave-aml-web-app/fastapi-aml-monitoring
   git remote set-url origin git@github.com:denniszitha/fastapiaml.git
   git push -u origin main
   ```

## Option 3: Using GitHub CLI

1. **Install GitHub CLI:**
   ```bash
   curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
   sudo apt update
   sudo apt install gh
   ```

2. **Authenticate and push:**
   ```bash
   gh auth login
   cd /opt/natsave-aml-web-app/fastapi-aml-monitoring
   git push -u origin main
   ```

## Current Repository Status

- **Local branch:** main
- **Remote URL:** https://github.com/denniszitha/fastapiaml.git
- **Files ready:** All files are committed and ready to push
- **Commit message:** Initial commit with complete AML system

## After Pushing

Once pushed, your repository will contain:
- Complete FastAPI application code
- Database models and schemas
- API endpoints for transaction monitoring
- Deployment scripts for production
- Docker configuration
- Documentation

## Verify Push

After pushing, verify at:
https://github.com/denniszitha/fastapiaml

The repository should show all files and the README.md as the main page.
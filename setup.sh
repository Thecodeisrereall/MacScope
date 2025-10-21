#!/bin/bash

# Setup script for MacScope GitHub repository
# Initializes git, creates remote, and pushes to GitHub

set -euo pipefail

###################
# Configuration
###################

readonly REPO_DIR="/Users/meklows/Documents/github/macscope"
readonly GITHUB_USER="${1:-yourusername}"  # Pass as argument or edit here
readonly REPO_NAME="macscope-install"

###################
# Colors
###################

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

###################
# Functions
###################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*"
}

log_error() {
    echo -e "${RED}[✗]${NC} $*" >&2
}

log_step() {
    echo -e "${CYAN}[→]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $*"
}

print_banner() {
    echo ""
    echo "╔══════════════════════════════════════════════════╗"
    echo "║                                                  ║"
    echo "║       MacScope GitHub Repository Setup          ║"
    echo "║                                                  ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo ""
}

check_git() {
    if ! command -v git &> /dev/null; then
        log_error "Git is not installed"
        log_info "Install with: xcode-select --install"
        exit 1
    fi
    log_success "Git is installed"
}

check_gh_cli() {
    if ! command -v gh &> /dev/null; then
        log_warning "GitHub CLI (gh) not installed"
        log_info "Repository must be created manually on GitHub"
        log_info "Install with: brew install gh"
        return 1
    fi
    log_success "GitHub CLI is installed"
    return 0
}

init_git_repo() {
    log_step "Initializing Git repository..."
    
    cd "$REPO_DIR"
    
    if [[ -d ".git" ]]; then
        log_warning "Git repository already initialized"
    else
        git init
        git branch -M main
        log_success "Git repository initialized"
    fi
}

add_and_commit() {
    log_step "Adding files to Git..."
    
    cd "$REPO_DIR"
    
    # Add all files
    git add .
    
    # Check if there are changes to commit
    if git diff --cached --quiet; then
        log_info "No changes to commit"
    else
        log_step "Creating initial commit..."
        git commit -m "Initial commit: MacScope VirtualHID installer

- Add installation scripts
- Add LaunchDaemon configuration
- Add build system
- Add comprehensive documentation
- Add preinstall/postinstall scripts
- Add troubleshooting guide"
        log_success "Initial commit created"
    fi
}

create_github_repo() {
    log_step "Creating GitHub repository..."
    
    cd "$REPO_DIR"
    
    if check_gh_cli; then
        # Check if user is authenticated
        if ! gh auth status &>/dev/null; then
            log_error "Not authenticated with GitHub"
            log_info "Run: gh auth login"
            return 1
        fi
        
        # Create repository
        log_info "Creating repository: $GITHUB_USER/$REPO_NAME"
        if gh repo create "$REPO_NAME" --private --source=. --remote=origin --push; then
            log_success "Repository created and pushed to GitHub"
            return 0
        else
            log_error "Failed to create repository"
            return 1
        fi
    else
        return 1
    fi
}

manual_setup_instructions() {
    echo ""
    echo "═══════════════════════════════════════════════════"
    echo "  Manual GitHub Setup Required"
    echo "═══════════════════════════════════════════════════"
    echo ""
    echo "1. Go to https://github.com/new"
    echo ""
    echo "2. Create a new repository:"
    echo "   - Name: $REPO_NAME"
    echo "   - Description: MacScope VirtualHID installer"
    echo "   - Visibility: Private (or Public)"
    echo "   - Do NOT initialize with README"
    echo ""
    echo "3. After creating, run these commands:"
    echo ""
    echo "   cd $REPO_DIR"
    echo "   git remote add origin https://github.com/$GITHUB_USER/$REPO_NAME.git"
    echo "   git push -u origin main"
    echo ""
    echo "═══════════════════════════════════════════════════"
    echo ""
}

print_summary() {
    echo ""
    echo "═══════════════════════════════════════════════════"
    echo "  Repository Setup Complete!"
    echo "═══════════════════════════════════════════════════"
    echo ""
    echo "Local path:  $REPO_DIR"
    echo "Repository:  https://github.com/$GITHUB_USER/$REPO_NAME"
    echo ""
    echo "Next steps:"
    echo ""
    echo "1. Copy your binary to payload/:"
    echo "   cp /path/to/macscope-vhid $REPO_DIR/payload/"
    echo ""
    echo "2. Build installer package:"
    echo "   cd $REPO_DIR/build"
    echo "   ./build.sh"
    echo ""
    echo "3. Test installation:"
    echo "   sudo installer -pkg ~/Desktop/MacScope_VirtualHID_Installer.pkg -target /"
    echo ""
    echo "4. Commit and push changes:"
    echo "   cd $REPO_DIR"
    echo "   git add ."
    echo "   git commit -m \"Add binary and update\""
    echo "   git push"
    echo ""
    echo "═══════════════════════════════════════════════════"
    echo ""
}

main() {
    print_banner
    
    # Validate GitHub username
    if [[ "$GITHUB_USER" == "yourusername" ]]; then
        log_error "Please provide your GitHub username"
        echo ""
        echo "Usage: $0 <github-username>"
        echo ""
        echo "Example:"
        echo "  $0 meklows"
        echo ""
        exit 1
    fi
    
    log_info "GitHub user: $GITHUB_USER"
    log_info "Repository name: $REPO_NAME"
    echo ""
    
    # Check prerequisites
    check_git
    
    # Initialize repository
    init_git_repo
    add_and_commit
    
    # Try to create GitHub repo
    if ! create_github_repo; then
        manual_setup_instructions
    else
        print_summary
    fi
    
    log_success "Setup complete! 🎉"
}

# Run main
main "$@"

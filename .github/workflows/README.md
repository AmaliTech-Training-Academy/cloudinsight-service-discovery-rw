# CloudInsight Frontend CI/CD Pipeline

A lean, modular GitHub Actions pipeline for the CloudInsight frontend application, focused on code quality, security, and efficient deployment to AWS with environment-specific configurations.

## 🎯 Pipeline Overview

This pipeline follows a **lean approach** with no manual inputs - everything is automated through GitHub secrets and encrypted environment variables:

```
Tests & Linting → Security Scan → Build Image & Push Secrets → Version & Push to ECR → Notify
```

### Pipeline Flow

1. **Quality Tests** - Run unit tests, linting, and type checking (no secrets required)
2. **Security Scan** - SonarQube code analysis, Trivy vulnerability scanning, and dependency audits
3. **Build & Push Secrets** - Decrypt environment variables, build Docker image, push secrets to AWS Secrets Manager
4. **Version & Push Image** - Apply semantic versioning and push tagged image to environment-specific ECR
5. **Notification** - Send status update to Slack only

## 📁 Workflow Structure

The pipeline is built using **modular, reusable workflows** with zero manual inputs:

```
.github/workflows/
├── main.yml              # Main orchestrator (environment-aware)
├── _quality-tests.yml    # Tests, linting, type checking
├── _security-scan.yml    # SonarQube + Trivy + dependency scans
├── _build-push.yml       # Decrypt env → Docker build → AWS secrets push
├── _versioning.yml       # Semantic versioning → ECR push
└── _notification.yml     # Slack notifications only
```

## 🚀 Features

### ✅ Quality Assurance

- **Unit Tests**: Vitest test runner with coverage reporting and JUnit XML output
- **Linting**: ESLint with TypeScript support and security rules
- **Type Checking**: TypeScript compiler checks with strict mode
- **Code Formatting**: Prettier validation for consistent code style
- **Dependencies**: npm/pnpm audit with security vulnerability detection

### 🔒 Security & Environment Management

- **Encrypted Environment Variables**: RSA-4096 + AES-256 encryption with metadata validation
- **Environment Decryption**: Automatic decryption using `TEAM_PRIVATE_KEY` secret
- **SonarQube**: Static code analysis and quality gates with configurable thresholds
- **Trivy**: Container vulnerability scanning with SARIF output
- **CodeQL**: GitHub's semantic code analysis for security vulnerabilities
- **AWS Secrets Manager**: Environment-specific secret storage with merge strategy

### 📦 Build & Deploy

- **Multi-Platform**: Docker builds for AMD64 and ARM64 architectures with cache optimization
- **Environment-Specific ECR**: Automatic repository creation per environment
- **Semantic Versioning**: Conventional commit-based version bumping with automated tagging
- **GitHub Releases**: Automated release creation with container image URIs
- **Zero Manual Input**: Fully automated pipeline with no manual parameters required

### 📢 Notifications

- **Slack Only**: Streamlined notifications exclusively through Slack webhooks
- **Rich Context**: Pipeline status, version info, container URIs, and direct links to workflow runs
- **Environment Awareness**: Notifications include environment context and branch information

## ⚙️ Configuration

### Repository-Wide GitHub Secrets

```bash
# AWS Configuration (shared across environments)
AWS_ACCESS_KEY_ID          # AWS access key for ECR and Secrets Manager
AWS_SECRET_ACCESS_KEY      # AWS secret key
AWS_REGION                 # AWS region (e.g., us-east-1)

# Environment Encryption (shared)
TEAM_PRIVATE_KEY          # RSA-4096 private key for decrypting environment variables

# SonarQube Integration (shared)
SONAR_TOKEN              # SonarQube authentication token
SONAR_HOST_URL           # SonarQube server URL

# Notifications (shared)
SLACK_WEBHOOK_URL        # Slack webhook for notifications
```

### SonarQube Project Configuration

The pipeline automatically configures SonarQube projects with:

- **Project Key**: `{organization}-{repository-name}` (e.g., `AmaliTech-Training-Academy-cloudinsight-frontend-rw`)
- **Project Name**: `CloudInsight Frontend - {repository-name}`
- **Quality Gate**: Waits for SonarQube analysis completion
- **Pipeline Blocking**: Failed quality gates prevent deployment
- **Coverage Reports**: Integrates with test coverage from Vitest

**Manual Override**: Use `sonar_project_key` input in the security scan workflow for custom project keys.

````

### Environment-Specific GitHub Secrets

```bash
# Configure in GitHub Environment settings for each environment:
# - production
# - staging
# - development

ECR_REPOSITORY_NAME           # ECR repository name (e.g., "cloudinsight-frontend-prod")
AWS_SECRETS_MANAGER_SECRET_NAME # Secret name prefix (e.g., "cloudinsight-frontend")
````

### Environment Variables & Encryption

The pipeline uses **RSA-4096 + AES-256 encrypted environment variables** with metadata tracking:

1. **Encryption Files Structure**:

   ```
   encrypted-env-vars.enc     # AES-256 encrypted environment data
   encrypted-aes-key.enc      # RSA-4096 encrypted AES key
   encrypted-env-vars.meta    # JSON metadata with hash verification
   team-private-key.pem       # RSA private key (NEVER COMMIT)
   ```

2. **Decryption Process**:
   - Validates RSA private key from `TEAM_PRIVATE_KEY` secret
   - Decrypts AES key using RSA private key
   - Attempts AES-256-GCM decryption, falls back to AES-256-CBC
   - Verifies file integrity and extracts `NEXT_PUBLIC_*` variables only
   - Masks sensitive values in GitHub logs

3. **Supported Environments**:
   ```
   production   ← refs/heads/production
   staging      ← refs/heads/staging
   development  ← refs/heads/development or refs/heads/dev
   ```

### AWS Setup

#### Environment-Specific ECR Repositories

The pipeline automatically creates ECR repositories per environment:

- Repository names from `ECR_REPOSITORY_NAME` environment secret
- Tags: `{semantic-version}` and `latest`
- Multi-platform support (AMD64/ARM64)

#### Secrets Manager with Merge Strategy

Environment variables are intelligently managed in AWS Secrets Manager:

- Secret names from `AWS_SECRETS_MANAGER_SECRET_NAME` environment secret
- **Merge Strategy**: Only updates/adds variables from `.env`, preserves existing unrelated secrets
- **Secret Type**: "Other type of secret" with key/value pairs
- Environment-specific secrets for production, staging, and development

## 🔧 Usage

### Automatic Triggers

The pipeline runs automatically on:

- **Push to any branch**: Full pipeline execution based on branch environment
- **Pull requests**: Quality checks only (no deployment)
- **Manual trigger**: Via GitHub Actions UI (no manual inputs required)

### Zero-Configuration Execution

```bash
# Pipeline runs automatically - no manual parameters needed
# Environment detection based on branch:
git push origin production  # → production environment
git push origin staging     # → staging environment
```

### Semantic Versioning (Fully Automated)

The pipeline uses **conventional commits** for automatic version bumping:

```bash
# Patch version (1.0.0 → 1.0.1)
git commit -m "fix: resolve login issue"

# Minor version (1.0.0 → 1.1.0)
git commit -m "feat: add user dashboard"

# Major version (1.0.0 → 2.0.0)
git commit -m "feat!: redesign authentication system"
```

**Automated Process:**

- Analyzes commit messages since last tag
- Calculates appropriate version bump automatically
- Updates `package.json` version
- Creates Git tag and GitHub release
- Tags container image with semantic version
- Pushes versioned image to environment-specific ECR

### Branch-Specific Versioning Strategy

Our versioning strategy implements **intelligent semantic versioning** with automated breaking change detection and flexible version promotion across all environments.

#### Development Branches (development, feature branches, etc.)

- **Strategy**: Automatic version calculation based on commit messages
- **Logic**: Uses semantic versioning (semver) with conventional commits
- **Examples**:
  - `feat:` → minor bump (v0.1.0 → v0.2.0)
  - `fix:` → patch bump (v0.1.0 → v0.1.1)
  - `BREAKING CHANGE` → major bump (v0.1.0 → v1.0.0)

#### Staging Branch

- **Strategy**: No version calculations - uses latest tag + `-rc` suffix
- **Logic**: Takes the most recent tag and appends `-rc` for release candidate
- **Examples**:
  - Latest tag `v0.2.3` → Creates `v0.2.3-rc`
  - If no tags exist → Creates `v0.1.0-rc`

#### Production Branch - Intelligent Version Promotion

- **Strategy**: Smart RC tag promotion with automated breaking change detection
- **Logic**: Analyzes merged PR commits for breaking changes and automatically increments versions
- **Flexibility**: Supports all version ranges (v0.x.x, v1.x.x+) with intelligent major version bumping

## 🧠 Intelligent Versioning System

### Breaking Change Detection Engine

Our production deployment system includes a sophisticated **breaking change analysis engine** that automatically detects breaking changes in merged PR commits and intelligently manages version promotion.

#### How It Works

1. **RC Tag Discovery**: Finds the latest `-rc` tag from staging deployments
2. **PR Commit Analysis**: Analyzes all commits in the merged pull request
3. **Breaking Change Detection**: Scans commit messages for breaking change patterns
4. **Intelligent Version Bumping**: Automatically increments major version when breaking changes are detected

#### Breaking Change Detection Patterns

The system recognizes breaking changes through multiple conventional commit patterns:

```bash
# Type with exclamation mark (breaking change)
feat!: redesign user authentication system
fix!: remove deprecated API endpoints
refactor!: change database schema structure

# Type with scope and exclamation mark
feat(auth)!: implement new OAuth flow
fix(api)!: update response format structure

# BREAKING CHANGE in commit body/footer
feat: add new user roles

BREAKING CHANGE: User permissions now require explicit role assignment
```

#### Intelligent Version Promotion Logic

**Scenario 1: No Breaking Changes Detected**

```bash
# RC Tag: v0.5.2-rc
# Merged Commits: feat: add user preferences, fix: resolve login bug
# Result: v0.5.2 (normal RC promotion)

✅ No breaking changes detected
✅ Promoting RC tag v0.5.2-rc to production version: v0.5.2
```

**Scenario 2: Breaking Changes Detected**

```bash
# RC Tag: v0.5.2-rc
# Merged Commits: feat: add preferences, feat!: redesign auth system
# Result: v1.0.0 (automatic major version bump)

🚀 BREAKING CHANGES DETECTED - Incrementing major version!
📋 Breaking changes found in:
  - abc123: feat!: redesign auth system
✅ Bumping from v0.5.2-rc to v1.0.0 (major version increment)
```

**Scenario 3: Already v1.x.x+ with Breaking Changes**

```bash
# RC Tag: v1.2.0-rc
# Merged Commits: feat!: remove legacy endpoints
# Result: v2.0.0 (major version increment)

🚀 BREAKING CHANGES DETECTED - Incrementing major version!
✅ Bumping from v1.2.0-rc to v2.0.0 (major version increment)
```

#### Version Promotion Examples

| RC Tag      | Breaking Changes     | Final Version | Reasoning              |
| ----------- | -------------------- | ------------- | ---------------------- |
| `v0.1.0-rc` | None                 | `v0.1.0`      | Normal promotion       |
| `v0.1.0-rc` | `feat!: new API`     | `v1.0.0`      | Auto-promote to stable |
| `v0.9.5-rc` | `fix!: breaking fix` | `v1.0.0`      | Auto-promote to stable |
| `v1.2.0-rc` | None                 | `v1.2.0`      | Normal promotion       |
| `v1.2.0-rc` | `BREAKING CHANGE`    | `v2.0.0`      | Major version bump     |
| `v2.1.0-rc` | `feat!: redesign`    | `v3.0.0`      | Major version bump     |

### Production Deployment Process

#### 1. RC Tag Analysis

```bash
📋 Found RC tag: v0.5.2-rc
🔍 Analyzing merged PR commits for breaking changes...
```

#### 2. Commit Message Scanning

```bash
# Scanning each commit in the merged PR
Commit abc123: feat: add user dashboard → No breaking changes
Commit def456: fix!: remove deprecated endpoints → ⚠️ Breaking change detected!
Commit ghi789: docs: update API documentation → No breaking changes
```

#### 3. Breaking Change Assessment

```bash
💥 Breaking change detected in def456: fix!: remove deprecated endpoints
🚀 BREAKING CHANGES DETECTED - Incrementing major version!
📋 Breaking changes found in:
  - def456: fix!: remove deprecated endpoints
```

#### 4. Intelligent Version Calculation

```bash
# Original RC version: 0.5.2
# Breaking changes detected: YES
# Action: Increment major version
# Result: 1.0.0

✅ Bumping from v0.5.2-rc to v1.0.0 (major version increment)
💡 Production deployment will proceed with v1.0.0
```

### Benefits of Intelligent Versioning

#### 🎯 **Automated Semantic Versioning**

- No manual version management required
- Follows semantic versioning specification strictly
- Prevents human errors in version numbering

#### 🛡️ **Breaking Change Safety**

- Automatically identifies potentially breaking changes
- Ensures major version bumps for breaking changes
- Maintains backward compatibility awareness

#### 🚀 **Flexible Deployment Strategy**

- Supports all version ranges (v0.x.x, v1.x.x+)
- Intelligent promotion based on change significance
- Seamless transition from development to stable versions

#### 📊 **Clear Audit Trail**

- Detailed logging of version promotion decisions
- Tracks which commits triggered major version bumps
- Provides transparency in version management

### Configuration & Customization

#### Environment Variables

```bash
# No configuration required - fully automated
# Breaking change patterns are built into the system
# Version calculation follows conventional commits specification
```

#### Supported Conventional Commit Types

```bash
# Breaking change indicators
feat!:           # Feature with breaking change
fix!:            # Fix with breaking change
refactor!:       # Refactoring with breaking change
type(scope)!:    # Any type with scope and breaking change
BREAKING CHANGE: # Explicit breaking change in body/footer
```

#### Error Handling & Fallbacks

```bash
# No RC Tag Found
❌ No RC tags found for production promotion
💡 Deploy to staging first to create an RC tag

# Git Analysis Failures
⚠️ Unable to analyze some commits - proceeding with normal promotion
📋 Manual review recommended for version v1.2.0

# Multiple Breaking Changes
🚀 Multiple breaking changes detected across 3 commits
📋 All breaking changes will trigger single major version increment
```

### Workflow Integration

The intelligent versioning system is seamlessly integrated into the production deployment workflow:

1. **Trigger**: Production branch push or manual deployment
2. **Analysis**: Automatic RC tag discovery and commit analysis
3. **Decision**: Breaking change detection and version calculation
4. **Action**: Tag creation, image building, and deployment
5. **Notification**: Slack notification with version promotion details

This system ensures that semantic versioning is maintained automatically while providing the flexibility to deploy any version to production when appropriate, with intelligent handling of breaking changes across the entire version spectrum.

## 📊 Monitoring & Observability

### Pipeline Performance

- **Build Duration**: Optimized 6-10 minutes for full pipeline
- **Test Coverage**: Vitest with HTML and LCOV reports
- **Security Gates**: Zero tolerance for HIGH/CRITICAL vulnerabilities
- **Quality Gates**: SonarQube with configurable quality thresholds
- **Cache Optimization**: Docker layer caching and dependency caching

### Slack Notifications (Only)

Rich contextual notifications include:

- ✅ **Success**: Version, container image URI, environment details
- ❌ **Failure**: Error context, failed stage, direct workflow links
- ⚠️ **Security**: Vulnerability scan results and remediation guidance
- 📦 **Releases**: New version announcements with deployment artifacts

## 🛠️ Development Workflow

### Local Development

```bash
# Install dependencies
pnpm install

# Run quality checks (same as CI)
pnpm test        # Vitest unit tests
pnpm lint        # ESLint + TypeScript
pnpm build        # Production build

# Local environment setup
./scripts/encrypt-env-vars-team.sh  # Encrypt environment variables
```

### Quality Assurance (Matches CI)

```bash
# Same checks as pipeline
pnpm test:coverage   # Unit tests with coverage
pnpm lint:fix       # Auto-fix linting issues
pnpm type-check     # TypeScript validation
```

## 🔍 Troubleshooting

### Common Issues

#### Environment & Decryption

1. **TEAM_PRIVATE_KEY Errors**: Verify RSA-4096 private key format in GitHub secret
2. **Decryption Failures**: Check `encrypted-env-vars.meta` for encryption method and hash
3. **Missing NEXT*PUBLIC*\* Variables**: Ensure variables are present in original `.env` file
4. **AES Key Issues**: Regenerate encrypted files using `./scripts/encrypt-env-vars-team.sh`

#### Pipeline Failures

1. **Quality Gate Failures**: Check SonarQube quality gate configuration and thresholds
2. **Security Scan Issues**: Review Trivy, CodeQL, and dependency audit results
3. **Build Failures**: Verify Dockerfile and build context, check build args extraction
4. **Version Bump Failures**: Ensure conventional commit format and Git tag permissions

#### AWS Integration

1. **ECR Repository Access**: Verify AWS credentials and ECR permissions per environment
2. **Secrets Manager Merge Issues**: Check IAM permissions for secrets read/write operations
3. **Environment Secret Configuration**: Ensure environment-specific secrets are properly configured
4. **Regional Mismatches**: Verify `AWS_REGION` matches ECR repository and Secrets Manager region

### Debug & Monitoring

Enable detailed logging for troubleshooting:

```bash
# Set repository variable for debug output
ACTIONS_STEP_DEBUG=true
ACTIONS_RUNNER_DEBUG=true
```

### Performance Monitoring

- **Workflow Insights**: Monitor execution times and resource usage
- **Cache Hit Rates**: Track Docker layer cache and dependency cache effectiveness
- **Security Scan Trends**: Monitor vulnerability detection over time

## 📈 Performance Optimization

### Build Speed Enhancements

- **Parallel Execution**: Quality tests and security scans run in parallel
- **Layer Caching**: Docker BuildKit with GitHub Actions cache
- **Dependency Caching**: pnpm store cached between runs
- **Conditional Steps**: Skip unnecessary operations based on file changes

### Resource Efficiency

- **Right-sized Runners**: ubuntu-latest for optimal cost/performance
- **Timeout Protection**: 15-30 minute timeouts prevent resource waste
- **Environment-specific Execution**: Only decrypt secrets when needed

## 🔐 Security Best Practices

### Zero-Trust Environment Management

- ✅ **No plaintext secrets**: All sensitive data encrypted with RSA-4096 + AES-256
- ✅ **Minimal secret exposure**: Environment variables only extracted during build
- ✅ **Automatic cleanup**: Security cleanup trap removes sensitive files
- ✅ **Value masking**: GitHub logs automatically mask sensitive values

### Container & Infrastructure Security

- ✅ **Multi-stage builds**: Minimal production images with distroless base
- ✅ **Vulnerability scanning**: Trivy + CodeQL + dependency audits
- ✅ **Least privilege IAM**: Environment-specific AWS permissions
- ✅ **Secrets rotation**: AWS Secrets Manager with automated rotation support

### Code Quality & Compliance

- ✅ **Static analysis**: SonarQube quality gates with security rules
- ✅ **Type safety**: Strict TypeScript configuration
- ✅ **Test coverage**: Minimum coverage thresholds enforced
- ✅ **Conventional commits**: Automated semantic versioning

## 📚 Technical References

### Official Documentation

- [GitHub Actions Workflows](https://docs.github.com/en/actions/using-workflows)
- [AWS ECR Private Registry](https://docs.aws.amazon.com/ecr/latest/userguide/what-is-ecr.html)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
- [SonarQube Quality Gates](https://docs.sonarqube.org/latest/user-guide/quality-gates/)

### Security & Compliance

- [GitHub Security Best Practices](https://docs.github.com/en/actions/security-guides)
- [Container Security with Trivy](https://aquasecurity.github.io/trivy/)
- [Conventional Commits Specification](https://www.conventionalcommits.org/)
- [Slack Webhook Integration](https://api.slack.com/messaging/webhooks)

## 🤝 Contributing

### Development Guidelines

1. **Commit Format**: Use conventional commits for semantic versioning
2. **Testing**: Ensure all quality checks pass locally before pushing
3. **Documentation**: Update README for any workflow modifications
4. **Environment Testing**: Test changes in development environment first

### Workflow Modification Process

1. Create feature branch from `development`
2. Test workflow changes in development environment
3. Update documentation in same PR
4. Request review from DevOps team
5. Merge to staging for integration testing
6. Deploy to production after stakeholder approval

---

**Pipeline Version**: 3.0.0 (Zero-Input Lean Architecture)  
**Last Updated**: September 11, 2025  
**Architecture**: Environment-scoped secrets with automated decryption  
**Maintainer**: CloudInsight DevOps Team

# CI/CD Setup for Forked Repository

This guide explains how to set up your own CI/CD pipeline when you fork this repository into your own GitHub account and Google Cloud project.

## 1. Create a Clean Repository (No "Fork" Label)

If you want your repository to be standalone and not show the "forked from" label on GitHub, follow one of these two methods.

### Method A: Preserve History (Recommended)

This keeps all the commit history but points to your new repository.

1.  **Create a new empty repository** on your GitHub (do NOT initialize with README).
2.  **Clone the original repository** (if you haven't already):
    ```bash
    git clone https://github.com/original-owner/original-repo.git my-new-repo
    cd my-new-repo
    ```
3.  **Update the remote URL** to point to your new repo:
    ```bash
    git remote set-url origin https://github.com/YOUR_USERNAME/YOUR_NEW_REPO.git
    ```
4.  **Push the code**:
    ```bash
    git push -u origin main
    ```

### Method B: Fresh Start (No History)

This deletes all previous git history and starts as a brand new project.

1.  **Download or Clone** the files into a folder.
2.  **Remove the existing Git data**:
    ```bash
    rm -rf .git
    ```
3.  **Initialize a new repo**:
    ```bash
    git init
    git add .
    git commit -m "initial commit: fresh start"
    ```
4.  **Link to your new GitHub repo and push**:
    ```bash
    git remote add origin https://github.com/YOUR_USERNAME/YOUR_NEW_REPO.git
    git branch -M main
    git push -u origin main
    ```

## 2. Google Cloud Identity Setup

We use **Workload Identity Federation (WIF)** to allow GitHub Actions to securely deploy to Google Cloud without using long-lived service account keys.

### Step 1: Run the Setup Script

Follow the detailed steps in [cicd-setup.md](./cicd-setup.md) Part 1 to:

- Enable required Google Cloud APIs.
- Create a Service Account (`github-runner`).
- Create a Workload Identity Pool and Provider.
- Grant the Service Account permissions to AI Platform, Cloud Run, and Storage.

### Step 2: Save the Configuration

After running the setup, you will have:

- `PROJECT_ID`
- `PROJECT_NUMBER`
- `WORKLOAD_IDENTITY_PROVIDER` (e.g., `projects/12345/locations/global/workloadIdentityPools/github/providers/github-actions`)
- `SERVICE_ACCOUNT` (e.g., `github-runner@PROJECT_ID.iam.gserviceaccount.com`)

## 3. GitHub Environment Configuration

The repository's workflow uses GitHub **Environments** (`staging` and `production`) to manage deployment targets.

1. Go to your GitHub Repo -> **Settings** -> **Environments**.
2. Create an environment named `staging`.
3. Add the following **Variables** to the `staging` environment:
   - `PROJECT_ID`: Your staging project ID.
   - `PROJECT_NUMBER`: Your staging project number.
   - `WORKLOAD_IDENTITY_PROVIDER`: Your provider resource name.
   - `SERVICE_ACCOUNT`: Your service account email.
4. Repeat for the `production` environment if you are using a separate project for prod.

## 4. Terraform Backend

Terraform stores its state in a Google Cloud Storage (GCS) bucket.

- The CI/CD pipeline expects a bucket named `${PROJECT_ID}-terraform-state`.
- Create this bucket in your GCP project before running the pipeline:
  ```bash
  gsutil mb gs://YOUR_PROJECT_ID-terraform-state
  ```

## 5. Running the Pipeline

Once configured:

- Push to the `staging` branch to trigger a staging deployment.
- Push (or merge) to the `main` branch to trigger a production deployment.

You can monitor progress in the **Actions** tab of your GitHub repository.

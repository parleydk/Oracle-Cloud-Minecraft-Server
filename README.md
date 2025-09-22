### Overview

A small toolkit to install and configure the Oracle Cloud Infrastructure (OCI) CLI on Fedora, validate the CLI configuration, and interactively teardown resources in a tenancy with dependency-safe VCN teardown and dry-run support.

Files provided
- setup-oci-cli.sh — installs system dependencies, runs the OCI installer, ensures PATH, and launches interactive `oci setup config`.
- validate-oci-config.sh — verifies CLI connectivity, extracts the tenancy OCID from `~/.oci/config`, and writes it to `~/oci-scripts/root_ocid.txt`.
- wipe-tenancy.sh — interactive, dependency-aware cleanup script with resource summary, selective deletion, dry-run, debug mode, and VCN dependency teardown.
- location for logs and outputs: `~/oci-scripts/validate.log` and `~/oci-scripts/cleanup.log`.

---

### Prerequisites

- Fedora system with sudo privileges.
- Network access to Oracle Cloud endpoints.
- An OCI account and console access to upload API public key (when generating keys).
- Bash-compatible shell.

---

### Quick install and configuration

1. Create scripts folder
```bash
mkdir -p ~/oci-scripts
```

2. Place the scripts into `~/oci-scripts/` and make them executable:
```bash
chmod +x ~/oci-scripts/*.sh
```

3. Run the installer script (interactive)
```bash
bash ~/oci-scripts/setup-oci-cli.sh
```
- Installs packages: python3, pip, unzip, python3-devel.
- Runs Oracle’s official OCI CLI installer.
- Ensures `~/bin` is in your PATH for current and future shells.
- Launches `oci setup config` for interactive profile/key creation.
- Upload `~/.oci/oci_api_key_public.pem` in the Console under Identity > Users > <you> > API Keys if not already uploaded.

---

### Validate configuration

Run the validator to confirm connectivity and capture the root compartment OCID used by cleanup:
```bash
bash ~/oci-scripts/validate-oci-config.sh
```
- On success it writes `~/oci-scripts/root_ocid.txt`.
- Logs are appended to `~/oci-scripts/validate.log`.

If the script fails:
- Confirm `~/.oci/config` exists and contains `tenancy=` and `key_file=` pointing to your private key.
- Run `oci setup config` again to recreate keys/config if necessary.
- Ensure your public key is uploaded in the Console.

---

### Preview and run tenancy cleanup (safe workflow)

1. Dry-run first (recommended)
   - Launch the cleanup script and answer prompts:
   ```bash
   bash ~/oci-scripts/wipe-tenancy.sh
   ```
   - When prompted, choose Dry-run = yes to preview deletion plan.
   - Review the printed resource summary and choose which types to remove (or abort).

2. Review the logs
   - `~/oci-scripts/cleanup.log` contains the detailed command attempts and any errors.

3. Live run
   - Rerun the script, choose Dry-run = no, confirm when prompted, and proceed.
   - The script will:
     - Provide a resource summary counts.
     - Let you pick specific resource types (instances, volumes, VCNs, buckets, ADBs, LBs, or all).
     - Tear down VCN dependencies in safe order (subnets, gateways, route tables, security lists, NSGs, DRG attachments, DRGs) before deleting the VCN itself.

Important safety notes
- Start in dry-run mode; review counts and logs before any deletion.
- Deletions are destructive and irreversible through the script once executed.
- Some resources may be in other compartments or regions; the script operates on the tenancy OCID extracted from `~/.oci/config`.
- Permissions: ensure the user/key you configured has the required IAM permissions to list and delete resources. Authorization issues will appear in `cleanup.log` and must be resolved via IAM policy or using an account with appropriate rights.
- If the script reports service errors (NotAuthorizedOrNotFound), verify region and compartment context, and consider running the failing command with `--debug` to capture full diagnostic output.

---

### Flags, logs, and debugging

- Dry-run: prompt-driven; selecting yes prevents destructive commands and logs planned deletions.
- Debug: prompt-driven; when enabled the script appends `--debug` to invoked OCI CLI commands where supported; this writes verbose output into `~/oci-scripts/cleanup.log`.
- Logs:
  - Validator: `~/oci-scripts/validate.log`
  - Cleanup: `~/oci-scripts/cleanup.log`
- Use the logs to investigate partial failures, permission issues, or malformed CLI output.

---

### Troubleshooting checklist

- OCI CLI not found after installer:
  - Ensure `export PATH=$HOME/bin:$PATH` is in `~/.bashrc` (or your shell rc) and restart shell.
- Missing `distutils` or installer errors on Fedora:
  - Confirm `python3-devel` is installed: `sudo dnf install -y python3-devel`.
- `validate-oci-config.sh` cannot find tenancy OCID:
  - Ensure `~/.oci/config` has a `tenancy=<ocid>` line and `key_file` path is correct.
- VCNs fail to delete:
  - Review `cleanup.log` for dependency errors; rerun cleanup after removing dependent resources or ensure script ran in the right order.
- Authorization errors:
  - Confirm the user’s API key is uploaded and IAM policies allow resource deletion in the tenancy.

---

### Next steps and extensions

- Add IAM cleanup (users, groups, policies) with explicit safeguards and review steps.
- Add resource export/backups for buckets or volumes before deletion.
- Modularize the cleanup into phases with checkpointing and resume capability.
- Add a non-interactive mode for scripted CI/CD runs (with explicit confirmation flags).

---

### Commit messages (suggested)

- setup-oci-cli.sh
  - feat: add Fedora OCI CLI install-and-config script
- validate-oci-config.sh
  - feat: add OCI config validator script
- wipe-tenancy.sh
  - feat(cleanup): add interactive OCI tenancy cleanup script with dry-run and debug

--- 

Logs and scripts live in: ~/oci-scripts
If you want, I can produce a one-line example workflow that runs the full flow (install → configure → validate → dry-run cleanup).

#!/usr/bin/env python3
"""
deploy-app.py - Deploy a Kubernetes application with proper resource cleanup.

This script safely deploys an application by:
1. Deleting the existing deployment
2. Cleaning up associated PVCs (by label and explicit names)
3. Cleaning up specified PVs
4. Applying the kustomize manifests
5. Restarting and waiting for the deployment to be ready

Usage:
    python3 scripts/deploy-app.py --app qbittorrent
    python3 scripts/deploy-app.py --app qbittorrent --dry-run
    python3 scripts/deploy-app.py --app qbittorrent --pvc-names "pvc1 pvc2" --pv-name my-pv
"""

import argparse
import logging
import subprocess
import sys
from typing import Optional

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger(__name__)


def run_kubectl(
    args: list[str],
    dry_run: bool = False,
    ignore_errors: bool = False,
    capture_output: bool = False,
) -> subprocess.CompletedProcess:
    """
    Execute a kubectl command.

    Args:
        args: List of arguments to pass to kubectl
        dry_run: If True, only print the command without executing
        ignore_errors: If True, don't raise an exception on non-zero exit
        capture_output: If True, capture stdout/stderr

    Returns:
        CompletedProcess instance
    """
    cmd = ["kubectl"] + args
    cmd_str = " ".join(cmd)

    if dry_run:
        logger.info(f"[DRY-RUN] Would execute: {cmd_str}")
        return subprocess.CompletedProcess(args=cmd, returncode=0, stdout=b"", stderr=b"")

    logger.debug(f"Executing: {cmd_str}")

    try:
        result = subprocess.run(
            cmd,
            capture_output=capture_output,
            text=capture_output,
            check=not ignore_errors,
        )
        return result
    except subprocess.CalledProcessError as e:
        if ignore_errors:
            logger.debug(f"Command failed (ignored): {cmd_str}")
            return e
        logger.error(f"Command failed: {cmd_str}")
        logger.error(f"Exit code: {e.returncode}")
        if e.stderr:
            logger.error(f"Stderr: {e.stderr}")
        raise


def delete_deployment(app: str, namespace: str, dry_run: bool) -> None:
    """Delete the deployment for the given app."""
    logger.info(f"Deleting deployment '{app}' in namespace '{namespace}'...")
    run_kubectl(
        ["delete", "deployment", app, "-n", namespace],
        dry_run=dry_run,
        ignore_errors=True,
    )


def delete_pvcs_by_label(app: str, namespace: str, dry_run: bool) -> None:
    """Delete PVCs with the app label."""
    logger.info(f"Deleting PVCs with label app={app} in namespace '{namespace}'...")
    run_kubectl(
        ["delete", "pvc", "-n", namespace, "-l", f"app={app}"],
        dry_run=dry_run,
        ignore_errors=True,
    )


def delete_default_pvcs(app: str, namespace: str, dry_run: bool) -> None:
    """Delete the default PVCs for an app (app-config, app-media)."""
    default_pvcs = [f"{app}-config", f"{app}-media"]
    logger.info(f"Deleting default PVCs {default_pvcs} in namespace '{namespace}'...")
    run_kubectl(
        ["delete", "pvc", "-n", namespace] + default_pvcs,
        dry_run=dry_run,
        ignore_errors=True,
    )


def delete_named_pvcs(pvc_names: list[str], namespace: str, dry_run: bool) -> None:
    """Delete explicitly named PVCs."""
    if not pvc_names:
        return

    for pvc in pvc_names:
        logger.info(f"Deleting PVC '{pvc}' in namespace '{namespace}'...")
        run_kubectl(
            ["delete", "pvc", pvc, "-n", namespace],
            dry_run=dry_run,
            ignore_errors=True,
        )


def delete_pv(pv_name: Optional[str], dry_run: bool) -> None:
    """Delete a PersistentVolume if specified."""
    if not pv_name:
        return

    logger.info(f"Deleting PV '{pv_name}'...")
    run_kubectl(
        ["delete", "pv", pv_name],
        dry_run=dry_run,
        ignore_errors=True,
    )


def apply_manifests(app: str, dry_run: bool) -> None:
    """Apply the kustomize manifests for the app."""
    manifest_path = f"clusters/dev/{app}/"
    logger.info(f"Applying manifests from '{manifest_path}'...")
    run_kubectl(
        ["apply", "-k", manifest_path],
        dry_run=dry_run,
        ignore_errors=False,
    )


def restart_deployment(app: str, namespace: str, dry_run: bool) -> None:
    """Restart the deployment and wait for it to be ready."""
    logger.info(f"Restarting deployment '{app}'...")
    run_kubectl(
        ["rollout", "restart", "deployment", app, "-n", namespace],
        dry_run=dry_run,
        ignore_errors=False,
    )

    logger.info(f"Waiting for deployment '{app}' to be ready...")
    run_kubectl(
        ["rollout", "status", "deployment", app, "-n", namespace],
        dry_run=dry_run,
        ignore_errors=False,
    )


def deploy_app(
    app: str,
    namespace: str,
    pvc_names: list[str],
    pv_name: Optional[str],
    dry_run: bool,
) -> None:
    """
    Main deployment function that orchestrates all cleanup and deployment steps.

    Args:
        app: Name of the application to deploy
        namespace: Kubernetes namespace
        pvc_names: List of additional PVC names to delete
        pv_name: PV name to delete (if any)
        dry_run: If True, only print commands without executing
    """
    if dry_run:
        logger.info("=" * 60)
        logger.info("DRY-RUN MODE - No changes will be made")
        logger.info("=" * 60)

    logger.info(f"Starting deployment for app: {app}")
    logger.info(f"  Namespace: {namespace}")
    logger.info(f"  PVC names: {pvc_names or '(none)'}")
    logger.info(f"  PV name: {pv_name or '(none)'}")
    logger.info("")

    # Step 1: Delete existing deployment
    delete_deployment(app, namespace, dry_run)

    # Step 2: Delete PVCs by label
    delete_pvcs_by_label(app, namespace, dry_run)

    # Step 3: Delete default PVCs
    delete_default_pvcs(app, namespace, dry_run)

    # Step 4: Delete explicitly named PVCs
    delete_named_pvcs(pvc_names, namespace, dry_run)

    # Step 5: Delete PV (if specified)
    delete_pv(pv_name, dry_run)

    # Step 6: Apply manifests
    apply_manifests(app, dry_run)

    # Step 7: Restart deployment
    restart_deployment(app, namespace, dry_run)

    logger.info("")
    if dry_run:
        logger.info("✅ Dry-run complete. Review the commands above.")
    else:
        logger.info(f"✅ Deployment of '{app}' completed successfully!")


def parse_args() -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Deploy a Kubernetes application with proper resource cleanup.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --app qbittorrent
  %(prog)s --app qbittorrent --dry-run
  %(prog)s --app qbittorrent --namespace custom-ns
  %(prog)s --app qbittorrent --pvc-names "data-pvc logs-pvc"
  %(prog)s --app qbittorrent --pv-name my-persistent-volume
        """,
    )

    parser.add_argument(
        "--app",
        required=True,
        help="Name of the application to deploy",
    )

    parser.add_argument(
        "--namespace",
        default="nas",
        help="Kubernetes namespace (default: nas)",
    )

    parser.add_argument(
        "--pvc-names",
        default="",
        help="Space-separated list of additional PVC names to delete",
    )

    parser.add_argument(
        "--pv-name",
        default="",
        help="Name of the PersistentVolume to delete",
    )

    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print commands without executing them",
    )

    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Enable verbose/debug logging",
    )

    return parser.parse_args()


def main() -> int:
    """Main entry point."""
    args = parse_args()

    # Configure logging level
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)

    # Parse PVC names from space-separated string
    pvc_names = [name.strip() for name in args.pvc_names.split() if name.strip()]

    # PV name (None if empty)
    pv_name = args.pv_name.strip() if args.pv_name else None

    try:
        deploy_app(
            app=args.app,
            namespace=args.namespace,
            pvc_names=pvc_names,
            pv_name=pv_name,
            dry_run=args.dry_run,
        )
        return 0
    except subprocess.CalledProcessError as e:
        logger.error(f"Deployment failed with exit code {e.returncode}")
        return e.returncode
    except KeyboardInterrupt:
        logger.warning("Deployment interrupted by user")
        return 130
    except Exception as e:
        logger.exception(f"Unexpected error: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())

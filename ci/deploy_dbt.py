"""
deploy_dbt.py — CI deploy of the native dbt project on Snowflake.

Native dbt runs IN Snowflake, so CI is a thin trigger: point the DBT PROJECT at
the pushed branch and EXECUTE the build in-account. No dbt-core runner.

Branch -> environment / target:
    dev   -> OG_DEV_DB   , --target preprod   (integration / QA build)
    main  -> OG_PROD_DB  , --target prod       (production build)

Auth: key-pair (env). The CI identity holds REVOPS_DEVELOPER (the dbt role) and
can manage the git repo + DBT PROJECT in the env's DBT schema.
    SF_ORGANIZATION_NAME, SF_ACCOUNT_NAME, SF_USERNAME, SF_PRIVATE_KEY
    (optional) SF_ROLE  [default REVOPS_DEVELOPER]

Usage: python ci/deploy_dbt.py --branch <dev|main>
"""

import argparse
import os
import sys
import tempfile

BRANCH_MAP = {
    "dev": ("DEV", "preprod"),
    "main": ("PROD", "prod"),
}


def connect(env):
    import snowflake.connector
    from cryptography.hazmat.primitives import serialization

    need = ["SF_ORGANIZATION_NAME", "SF_ACCOUNT_NAME", "SF_USERNAME", "SF_PRIVATE_KEY"]
    missing = [v for v in need if not os.environ.get(v)]
    if missing:
        sys.exit(f"Missing env vars: {', '.join(missing)}")

    pkey = serialization.load_pem_private_key(
        os.environ["SF_PRIVATE_KEY"].encode(), password=None
    )
    der = pkey.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )
    return snowflake.connector.connect(
        account=f"{os.environ['SF_ORGANIZATION_NAME']}-{os.environ['SF_ACCOUNT_NAME']}",
        user=os.environ["SF_USERNAME"],
        private_key=der,
        role=os.environ.get("SF_ROLE", "REVOPS_DEVELOPER"),
        warehouse=f"OG_{env}_DEVELOPER_WH",
        database=f"OG_{env}_DB",
        schema="DBT",
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--branch", required=True)
    ap.add_argument(
        "--full-refresh",
        action="store_true",
        help="drop + rebuild incremental models. Use after a logic change to an "
        "incremental model — a normal build only merges NEW rows and leaves "
        "already-materialized rows untouched.",
    )
    ap.add_argument(
        "--select",
        default="",
        dest="select",
        help="dbt --select selectors (space-separated model names). Empty = all models.",
    )
    args = ap.parse_args()
    if args.branch not in BRANCH_MAP:
        print(f"Branch '{args.branch}' is not a deploy branch — skipping.")
        return
    env, target = BRANCH_MAP[args.branch]
    repo = f"OG_{env}_DB.DBT.OG_DBT_HUB_REPO"
    proj = f"OG_{env}_DB.DBT.OG_HUB"
    fr = " --full-refresh" if args.full_refresh else ""
    sel = f" --select {args.select}" if args.select.strip() else ""

    cur = connect(env).cursor()
    print(f"[{env}] fetching {args.branch} and refreshing DBT PROJECT ...")
    cur.execute(f"ALTER GIT REPOSITORY {repo} FETCH")
    cur.execute(f"CREATE OR REPLACE DBT PROJECT {proj} FROM '@{repo}/branches/{args.branch}'")

    print(f"[{env}] EXECUTE DBT PROJECT {proj} build --target {target}{fr}{sel}")
    cur.execute(f"EXECUTE DBT PROJECT {proj} ARGS='build --target {target}{fr}{sel}'")
    row = cur.fetchone()
    success, _, log = row[0], row[1], row[2]
    print(log)
    if not success:
        sys.exit("dbt build FAILED")
    print(f"[{env}] dbt build OK")


if __name__ == "__main__":
    main()

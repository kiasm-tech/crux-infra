# crux-infra

Terraform for Crux on Azure: one shared stack, applied per environment (`dev`, `prod`).

```txt
bootstrap/        run once by hand: state storage, env resource groups, GitHub OIDC identity, budget
stack/            the environment itself (root module)
modules/          keyvault, storage, postgres, container_env, web_app, ai
envs/             <env>.tfvars + <env>.backend.hcl
.github/workflows/terraform.yml   fmt/validate → plan on PR (comment) → apply dev on main, prod on manual run
```

Each environment contains:

- Container Apps environment (Consumption, scale to zero) with a capped Log Analytics workspace (0.5 GB/day, 30 days)
- The `ca-crux-web-<env>` Container App with a placeholder image
- PostgreSQL Flexible Server B1ms with a `crux` database; its URL is stored in Key Vault as `database-url`
- An AI Services account in Sweden Central with the OpenAI deployments listed in `ai_deployments` (`gpt-5-mini`, `gpt-5.3-codex`) and Speech; its key is stored in Key Vault as `ai-services-key`
- Blob storage with `audio` and `exports` containers, keyless, moving blobs to Cool after 30 days
- Key Vault (RBAC)
- A managed identity for the app

The web app gets `DATABASE_URL`, `OPENAI_BASE_URL`, `OPENAI_API_KEY`, `AZURE_SPEECH_KEY` and
`AZURE_SPEECH_REGION` without any tfvars.

---

## First-time setup

Do this once. You need **Owner** on the Azure subscription and permission to create app
registrations in Entra ID (the account that created the tenant has both).

### 1. Log in to Azure

```sh
az login
az account set --subscription "<subscription id>"
az account show --query "{subscription:id, tenant:tenantId, user:user.name}"
```

### 2. Register the resource providers

CI is scoped to resource groups, so it can't register providers itself.

```sh
for ns in Microsoft.App Microsoft.OperationalInsights Microsoft.DBforPostgreSQL \
          Microsoft.KeyVault Microsoft.Storage Microsoft.ManagedIdentity Microsoft.Consumption \
          Microsoft.CognitiveServices; do
  az provider register --namespace "$ns"
done
az provider list --query "[?namespace=='Microsoft.App'].registrationState" -o tsv   # wait for "Registered"
```

If this fails with `AuthorizationFailed ... does not have authorization to perform action
'Microsoft.App/register/action'`, your account has no RBAC role on the subscription. Entra
roles such as Global Administrator don't count. To grant yourself Owner:

1. If a user already has Owner on the subscription, skip to step 2. Otherwise, as a Global
   Administrator, open **Entra ID → Properties → Access management for Azure resources**,
   set it to **Yes**, save, then sign out and back in.
2. Open **Subscriptions → \<subscription\> → Access control (IAM) → Add → Add role
   assignment**. On **Privileged administrator roles**, pick **Owner** and add your user as
   a member. For the delegation condition, choose "Allow user to assign all roles except
   privileged administrator roles".
3. If you used the toggle in step 1, set it back to **No**.
4. Refresh the CLI token, then rerun the loop. A new role can take up to about 10 minutes
   to take effect.

   ```sh
   az logout && az login
   az account set --subscription "<subscription id>"
   az role assignment list --assignee "<your upn>" --scope "/subscriptions/<subscription id>" -o table
   ```

### 3. Run the bootstrap

The bootstrap is also where the Entra app registration happens, so there's nothing to
click in the portal.

```sh
cp bootstrap/terraform.tfvars.example bootstrap/terraform.tfvars   # fill in subscription id + your email
terraform -chdir=bootstrap init
terraform -chdir=bootstrap apply
```

It creates:

| Resource | Purpose |
| --- | --- |
| `rg-crux-tfstate` + `stcruxtfstate<suffix>` / `tfstate` | Remote state: versioned, keyless, 30-day soft delete |
| `rg-crux-dev`, `rg-crux-prod` | Environment resource groups (empty, free) |
| App registration **`crux-infra-github`** + service principal | Identity used by GitHub Actions |
| Federated credentials | Trust tokens from `kiasm-tech/crux-infra` on pull requests and on `main` only; no client secret exists |
| CI roles on each env RG | Contributor, Key Vault Secrets Officer, and RBAC Administrator limited to granting *Key Vault Secrets User* / *Storage Blob Data Contributor* |
| CI role on the state account | Storage Blob Data Contributor |
| Your roles | State access + Key Vault Secrets Officer on the env RGs, so you can set secrets |
| Budget `crux-monthly` | Emails you at 80% actual and 100% forecast of €50 |

The bootstrap state is local (`bootstrap/terraform.tfstate`, gitignored). Optionally
move it into the state account: uncomment the `backend` block in `bootstrap/versions.tf`,
then run `terraform -chdir=bootstrap init -migrate-state`.

### 4. Point the environments at the state account

```sh
ACCOUNT=$(terraform -chdir=bootstrap output -raw tfstate_storage_account)
sed -i '' "s/REPLACE_WITH_BOOTSTRAP_OUTPUT/$ACCOUNT/" envs/dev.backend.hcl envs/prod.backend.hcl
git commit -am "chore: point envs at the state account"
```

### 5. Create the GitHub repo

The federated credentials only trust **`kiasm-tech/crux-infra`**. If you use another
name, change `github_repository` in `bootstrap/terraform.tfvars` and re-apply the bootstrap.

```sh
gh repo create kiasm-tech/crux-infra --private --source=. --push
```

### 6. Give the workflow its Azure identity

These are plain repo variables, not secrets (OIDC needs no secret):

```sh
terraform -chdir=bootstrap output -raw github_variables | sh
```

### 7. Apply dev through CI

1. Make any small change on a branch (e.g. a comment in `envs/dev.tfvars`) and open a PR. The workflow posts a plan comment for `dev` and `prod`.
2. Merge it. The `apply` job applies **dev** (Postgres takes ~5–10 min on the first run).
3. Check the result:

   ```sh
   terraform -chdir=stack init -reconfigure -backend-config=../envs/dev.backend.hcl
   terraform -chdir=stack output
   curl -sI "$(terraform -chdir=stack output -raw web_url)" | head -1   # 200 from the placeholder app
   az keyvault secret show --vault-name "$(terraform -chdir=stack output -raw key_vault_name)" --name database-url --query name
   ```

### 8. Prod (wait until Phase 5)

Prod is never applied automatically. When you need it, go to **Actions → terraform → Run
workflow → prod**. Until then it only costs a plan comment; a second Postgres server
roughly doubles the bill.

---

## Day to day

**Change infra:** open a PR, read the plan comment, then merge. Dev applies on merge; prod
needs a manual run.

**Run locally** (uses your `az login`):

```sh
terraform -chdir=stack init -reconfigure -backend-config=../envs/dev.backend.hcl
terraform -chdir=stack plan -var-file=../envs/dev.tfvars
```

**Add an app secret.** Values never go through Terraform:

```sh
az keyvault secret set --vault-name <kv> --name resend-api-key --value "..."
```

Then reference it in `envs/<env>.tfvars` and merge:

```hcl
web = {
  secrets = { RESEND_API_KEY = "resend-api-key" }
}
```

The secret must exist before the apply, or the new revision can't start.

**Use the real app image (Phase 5).** Store a GitHub PAT with `read:packages` as the
`ghcr-token` secret, then:

```hcl
web = {
  target_port = 3000
  registry    = { server = "ghcr.io", username = "<github user>", password_secret = "ghcr-token" }
}
```

Terraform ignores the image after creation. The app repo's CI deploys new images with
`az containerapp update -n ca-crux-web-<env> -g rg-crux-<env> --image ghcr.io/...:<sha>`.

**Use the models from your laptop.** The apps send the deployment name as the model:

```sh
export OPENAI_BASE_URL=$(terraform -chdir=stack output -raw openai_base_url)
export OPENAI_API_KEY=$(az keyvault secret show --vault-name <kv> --name ai-services-key --query value -o tsv)
export AZURE_SPEECH_KEY=$OPENAI_API_KEY AZURE_SPEECH_REGION=$(terraform -chdir=stack output -raw ai_location)
```

**Add a model:** add an entry to `ai_deployments` in `envs/<env>.tfvars` (the default map is
replaced, so list every model you keep).

**Reach Postgres from your laptop:** add your IP to `postgres_allowed_ips` in the tfvars, then:

```sh
psql "$(az keyvault secret show --vault-name <kv> --name database-url --query value -o tsv)"
```

**Save money on dev:** `az postgres flexible-server stop -g rg-crux-dev -n <server>`.
Azure restarts it automatically after 7 days.

## Cost (dev, idle)

| Resource | ~€/month |
| --- | --- |
| Postgres B1ms + 32 GB | 16–18 |
| Container App (scale to zero) | 0 |
| Log Analytics (capped at 0.5 GB/day) | 0–5 |
| Key Vault, Blob | < 1 |
| AI Services (pay per token) | 0 |

## Not here yet

- `worker_job` (Container Apps Job + KEDA postgresql scaler) arrives in Phase 4, once there's a pg-boss queue for it to watch.
- Custom domain + managed certificate arrive in Phase 5.

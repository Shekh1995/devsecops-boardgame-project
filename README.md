# Board Game DevSecOps

A practical, production-style Flask project for demonstrating a secure delivery path:

`GitHub → Jenkins → pytest → SonarQube quality gate → Trivy → Docker Hub → GKE → Prometheus/Grafana`

The app supplies a small board-game catalogue, JSON API, `/health` probe, and Prometheus `/metrics` endpoint.

## Project layout

| Path | Purpose |
|---|---|
| `app.py` | Flask service and metrics |
| `tests/` | pytest API tests and coverage |
| `Dockerfile` | multi-stage, non-root production image |
| `Jenkinsfile` | CI/CD pipeline with scan gates and GKE deployment |
| `k8s/` | GKE namespace, deployment, service, ingress, kubeaudit command |
| `monitoring/` | Prometheus configuration and Grafana provisioning/dashboard |

## Run locally

```bash
python -m venv .venv
# Linux/macOS: source .venv/bin/activate   | Windows: .venv\\Scripts\\Activate.ps1
pip install -r requirements-dev.txt
pytest --cov=. --cov-report=xml
python app.py
```

Open `http://localhost:8080`. Useful endpoints: `GET /health`, `GET /api/games`, `POST /api/games`, and `GET /metrics`.

Example create request:

```bash
curl -X POST http://localhost:8080/api/games -H "Content-Type: application/json" -d '{"name":"Azul","players":"2-4","category":"Abstract"}'
```

## Container security

```bash
docker build -t boardgame-devsecops:local .
docker run --rm -p 8080:8080 boardgame-devsecops:local
trivy fs --severity HIGH,CRITICAL --exit-code 1 .
trivy image --severity HIGH,CRITICAL --exit-code 1 boardgame-devsecops:local
```

The Dockerfile pins its Python major/minor base, removes build tools from the runtime stage, disables root, and applies a health check. Regularly rebuild it to obtain operating-system security fixes; review Trivy findings rather than blindly suppressing them.

## Jenkins prerequisites

1. Install Jenkins Pipeline, Credentials Binding, SonarQube Scanner, Docker Pipeline, and Email Extension plugins. Install `docker`, `trivy`, `kubectl`, Python 3, and `sonar-scanner` on the build agent.
2. In Jenkins, configure the SonarQube server with the name **SonarQube** and create credential IDs **dockerhub-credentials** (Docker Hub username/access token) and **gke-kubeconfig** (secret file).
3. Replace `YOUR_DOCKERHUB_USERNAME` in `Jenkinsfile` with your Docker Hub namespace.
4. Create a SonarQube project with key `boardgame-devsecops`; configure its webhook to Jenkins so the quality gate can return.
5. Push this directory to GitHub and create a Pipeline job from the repository. The deployment stage runs only on `main` or `master`.

Do not place Docker tokens, kubeconfigs, SonarQube tokens, or Grafana passwords in Git. Store them as Jenkins/GKE secrets.

## GKE deployment

Authenticate `kubectl` to the intended cluster, then deploy a published image:

```bash
chmod +x scripts/deploy.sh scripts/rollback.sh
./scripts/deploy.sh docker.io/YOUR_DOCKERHUB_USERNAME/boardgame-devsecops:1
kubectl -n boardgame get pods,svc,ingress
```

The manifests use a restricted namespace, non-root containers, dropped Linux capabilities, read-only root filesystem, resource limits, probes, and two replicas. For production, add a managed certificate/TLS, domain rule, image digest pinning, NetworkPolicy, Workload Identity, and a dedicated monitoring stack.

To revert the last Kubernetes rollout:

```bash
./scripts/rollback.sh
```

## Monitoring

For a simple local monitoring demo, first run the API in a Compose network or adjust `monitoring/prometheus.yml` to reach your API, then:

```bash
cd monitoring
docker compose -f docker-compose.monitoring.yml up -d
```

Prometheus is available at `http://localhost:9090`; Grafana is at `http://localhost:3000` (default user `admin`, password `change-me-before-use`). The Board Game API dashboard is provisioned automatically.

For GKE, use the Prometheus Operator or managed collection with Kubernetes service discovery instead of the local static target. Run `kubeaudit` using the command in `k8s/kubeaudit-command.txt` as an additional manifest security check.
# devsecops-boardgame-project

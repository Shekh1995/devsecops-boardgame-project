.PHONY: test run build scan image-scan deploy rollback
test:
	python -m pytest --cov=. --cov-report=xml
run:
	python app.py
build:
	docker build -t boardgame-devsecops:local .
scan:
	trivy fs --severity HIGH,CRITICAL --no-progress .
image-scan:
	trivy image --severity HIGH,CRITICAL --no-progress boardgame-devsecops:local
deploy:
	./scripts/deploy.sh $(IMAGE)
rollback:
	./scripts/rollback.sh

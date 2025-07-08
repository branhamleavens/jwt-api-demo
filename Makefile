.PHONY: build-layer zip deploy clean

ZIP_NAME = deployment.zip
LAYER_ZIP = layer.zip

# Step 1: Build the Lambda Layer with dependencies inside Docker and extract layer.zip locally
build-layer:
	docker build --platform linux/amd64 -t jwt-layer -f Dockerfile.layer .
	docker create --name temp-layer jwt-layer
	docker cp temp-layer:/python ./python
	docker rm temp-layer
	rm -f layer.zip
	zip -r layer.zip python
	rm -rf python


# Step 2: Package your Lambda code ONLY (no dependencies) into deployment.zip
zip:
	rm -f $(ZIP_NAME)
	zip $(ZIP_NAME) handler.py

# Step 3: Deploy infrastructure (layer + lambda) with Terraform
deploy: build-layer zip
	terraform apply -auto-approve

# Cleanup generated artifacts
clean:
	rm -f $(ZIP_NAME) $(LAYER_ZIP)
	rm -rf layer
	rm -rf python

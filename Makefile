PROJECT_ID := $(shell gcloud config get-value project)
# PROJECT_NO := $(shell gcloud projects list --filter="$(PROJECT_ID)" --format="value(PROJECT_NUMBER)")
TODAY := $(shell date +%Y-%m-%d)
PROXY_IMAGE := us-central1-docker.pkg.dev/$(PROJECT_ID)/containers/proxy

# Update project and image tags
replace:
	@find . -name '*.yaml' -exec sed -i 's/DUMMY_PROJECT/$(PROJECT_ID)/g' {} \;
	@find . -name '*.yaml' -exec sed -i 's/TAG/$(TODAY)/g' {} \;

# Replace all local settings to standard before git commit
clean:
	@find . -name '*.yaml' -exec sed -i 's/$(PROJECT_ID)/DUMMY_PROJECT/g' {} \;
	@find . -name '*.yaml' -exec sed -i 's/$(TODAY)/TAG/g' {} \;


# Enable required services in project
services:
	gcloud services enable serviceusage.googleapis.com
	gcloud services enable cloudresourcemanager.googleapis.com

show:
	@echo $(PROJECT_ID)

print_date:
	@echo $(TODAY)

.ONESHELL:
build_proxy:
	@gcloud builds submit \
		--tag $(PROXY_IMAGE):$(TODAY) \
		proxy/

settings:
	@echo "Current settings"
	@echo Project = $(PROJECT_ID)
	@echo Today is $(TODAY)

.ONESHELL:
infra: services
	cd infra
	terraform init
	terraform apply -var project=$(PROJECT_ID) --auto-approve

step1: infra

authorize:
	gcloud container clusters get-credentials platform --region=us-central1

test:
	gcloud projects add-iam-policy-binding projects/boris001 --role=roles/aiplatform.user --member=principal://iam.googleapis.com/projects/745535691203/locations/global/workloadIdentityPools/boris001.svc.id.goog/subject/ns/platform/sa/llm

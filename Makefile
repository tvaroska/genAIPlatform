PROJECT_ID := $(shell gcloud config get-value project)
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

show:
	@echo $(PROJECT_ID)

print_date:
	@echo $(TODAY)

build_proxy:
	@gcloud builds submit \
		--tag $(PROXY_IMAGE):$(TODAY) \
		proxy/